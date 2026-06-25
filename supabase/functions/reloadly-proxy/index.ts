// Supabase Edge Function: reloadly-proxy
// Reloadly Gift Cards API proxy — OAuth + all documented endpoints.
// Credentials: RELOADLY_CLIENT_ID, RELOADLY_CLIENT_SECRET (Supabase secrets)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const AUTH_URL = "https://auth.reloadly.com/oauth/token";

const GIFT_CARDS_BASE: Record<string, string> = {
  sandbox: "https://giftcards-sandbox.reloadly.com",
  production: "https://giftcards.reloadly.com",
};

const GIFT_CARDS_AUDIENCE: Record<string, string> = {
  sandbox: "https://giftcards-sandbox.reloadly.com",
  production: "https://giftcards.reloadly.com",
};

const ACCEPT = "application/com.reloadly.giftcards-v1+json";

interface TokenCache {
  token: string;
  expiresAt: number;
}

const tokenCache: Record<string, TokenCache> = {};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function resolveEnvironment(raw: unknown): "sandbox" | "production" {
  return raw === "production" ? "production" : "sandbox";
}

async function getAccessToken(
  clientId: string,
  clientSecret: string,
  environment: "sandbox" | "production",
): Promise<string> {
  const cacheKey = environment;
  const cached = tokenCache[cacheKey];
  if (cached && Date.now() < cached.expiresAt - 60_000) {
    return cached.token;
  }

  const response = await fetch(AUTH_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "client_credentials",
      audience: GIFT_CARDS_AUDIENCE[environment],
    }),
  });

  const payload = await response.json();
  if (!response.ok) {
    const message =
      payload?.message ??
      payload?.error_description ??
      "Reloadly OAuth failed";
    throw new Error(message);
  }

  const token = payload.access_token as string;
  const expiresIn = (payload.expires_in as number) ?? 3600;
  tokenCache[cacheKey] = {
    token,
    expiresAt: Date.now() + expiresIn * 1000,
  };
  return token;
}

async function reloadlyFetch(
  token: string,
  environment: "sandbox" | "production",
  path: string,
  init?: RequestInit,
): Promise<Response> {
  const base = GIFT_CARDS_BASE[environment];
  return fetch(`${base}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: ACCEPT,
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
}

async function parseReloadlyError(response: Response): Promise<string> {
  try {
    const body = await response.json();
    return body?.message ?? body?.error ?? `Reloadly HTTP ${response.status}`;
  } catch {
    return `Reloadly HTTP ${response.status}`;
  }
}

async function timedFetch(
  token: string,
  environment: "sandbox" | "production",
  path: string,
  init?: RequestInit,
): Promise<{ response: Response; latencyMs: number }> {
  const start = Date.now();
  const response = await reloadlyFetch(token, environment, path, init);
  return { response, latencyMs: Date.now() - start };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const clientId = Deno.env.get("RELOADLY_CLIENT_ID");
    const clientSecret = Deno.env.get("RELOADLY_CLIENT_SECRET");

    if (!clientId || !clientSecret) {
      return json(
        {
          error:
            "Reloadly credentials not configured. Set RELOADLY_CLIENT_ID and RELOADLY_CLIENT_SECRET in Supabase Edge Function secrets.",
        },
        503,
      );
    }

    const body = await req.json();
    const environment = resolveEnvironment(body.environment);
    const action = body.action as string;
    const params = (body.params ?? {}) as Record<string, unknown>;
    const payload = (body.payload ?? {}) as Record<string, unknown>;

    // ── Health check (OAuth + catalog probe + optional balance) ───────────
    if (action === "health_check") {
      const oauthStart = Date.now();
      let oauthStatus = "ok";
      let oauthError: string | null = null;
      let token: string | null = null;

      try {
        token = await getAccessToken(clientId, clientSecret, environment);
      } catch (e) {
        oauthStatus = "failed";
        oauthError = String(e);
      }
      const oauthLatencyMs = Date.now() - oauthStart;

      let catalogCount = 0;
      let apiLatencyMs: number | null = null;
      let balanceAmount: number | null = null;
      let balanceCurrency: string | null = null;
      let apiError: string | null = null;
      let countriesCount = 0;
      let brandsCount = 0;

      if (token) {
        const { response: productsRes, latencyMs } = await timedFetch(
          token,
          environment,
          "/products",
        );
        apiLatencyMs = latencyMs;

        if (productsRes.ok) {
          const products = await productsRes.json();
          if (Array.isArray(products)) {
            catalogCount = products.length;
            const countries = new Set<string>();
            const brands = new Set<string>();
            for (const p of products) {
              if (p?.country?.isoName) countries.add(p.country.isoName);
              if (p?.global) countries.add("GLOBAL");
              if (p?.brand?.brandName) brands.add(p.brand.brandName);
            }
            countriesCount = countries.size;
            brandsCount = brands.size;
          }
        } else {
          apiError = await parseReloadlyError(productsRes);
        }

        const balanceRes = await reloadlyFetch(
          token,
          environment,
          "/accounts/balance",
        );
        if (balanceRes.ok) {
          const balance = await balanceRes.json();
          balanceAmount = balance?.balance ?? null;
          balanceCurrency = balance?.currencyCode ?? null;
        }
      }

      return json({
        reloadlyStatus: oauthStatus === "ok" && !apiError ? "healthy" : "degraded",
        oauthStatus,
        oauthError,
        oauthLatencyMs,
        apiLatencyMs,
        catalogCount,
        countriesCount,
        brandsCount,
        balanceAmount,
        balanceCurrency,
        apiError,
        environment,
        provider: "reloadly",
        checkedAt: new Date().toISOString(),
      });
    }

    // ── Full catalog for validation / sync ──────────────────────────────────
    if (action === "validate_catalog" || action === "sync_catalog") {
      const token = await getAccessToken(clientId, clientSecret, environment);
      const { response: res, latencyMs } = await timedFetch(
        token,
        environment,
        "/products",
      );
      if (!res.ok) {
        return json({ error: await parseReloadlyError(res) }, res.status);
      }
      const products = await res.json();
      const list = Array.isArray(products) ? products : [];
      const countries = new Set<string>();
      const brands = new Map<number, string>();
      for (const p of list) {
        if (p?.country?.isoName) countries.add(p.country.isoName);
        if (p?.global) countries.add("GLOBAL");
        if (p?.brand?.brandId != null) {
          brands.set(p.brand.brandId, p.brand.brandName ?? "");
        }
      }
      return json({
        products: list,
        catalogCount: list.length,
        countries: [...countries].sort(),
        brands: [...brands.entries()].map(([id, name]) => ({ brandId: id, brandName: name })),
        latencyMs,
        environment,
        syncedAt: new Date().toISOString(),
      });
    }

    const token = await getAccessToken(clientId, clientSecret, environment);

    switch (action) {
      // ── Products ────────────────────────────────────────────────────────
      case "get_products": {
        const qs = new URLSearchParams();
        if (params.productName) qs.set("productName", String(params.productName));
        if (params.countryCode) qs.set("countryCode", String(params.countryCode));
        if (params.includeFixed !== undefined) {
          qs.set("includeFixed", String(params.includeFixed));
        }
        if (params.includeRange !== undefined) {
          qs.set("includeRange", String(params.includeRange));
        }
        const query = qs.toString();
        const path = query ? `/products?${query}` : "/products";
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          path,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const products = await res.json();
        return json({ products, latencyMs });
      }

      case "get_product": {
        const productId = params.productId;
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          `/products/${productId}`,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const product = await res.json();
        return json({ product, latencyMs });
      }

      case "get_products_by_country": {
        const countryCode = params.countryCode;
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          `/countries/${countryCode}/products`,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const products = await res.json();
        return json({ products, latencyMs });
      }

      // ── Orders & transactions ───────────────────────────────────────────
      case "place_order": {
        const start = Date.now();
        const res = await reloadlyFetch(token, environment, "/orders", {
          method: "POST",
          body: JSON.stringify({
            productId: payload.productId,
            unitPrice: payload.unitPrice,
            quantity: payload.quantity,
            recipientEmail: payload.recipientEmail,
            senderName: payload.senderName,
            customIdentifier: payload.customIdentifier,
            ...(payload.countryCode
              ? { countryCode: payload.countryCode }
              : {}),
            ...(payload.recipientPhoneDetails
              ? { recipientPhoneDetails: payload.recipientPhoneDetails }
              : {}),
          }),
        });
        const latencyMs = Date.now() - start;
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const order = await res.json();
        return json({ order, latencyMs });
      }

      case "get_redeem_codes": {
        const transactionId = params.transactionId;
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          `/orders/transactions/${transactionId}/cards`,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const cards = await res.json();
        return json({ cards, latencyMs });
      }

      case "get_transaction": {
        const transactionId = params.transactionId;
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          `/reports/transactions/${transactionId}`,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const transaction = await res.json();
        return json({ transaction, latencyMs });
      }

      case "get_transactions": {
        const qs = new URLSearchParams();
        if (params.startDate) qs.set("startDate", String(params.startDate));
        if (params.endDate) qs.set("endDate", String(params.endDate));
        const query = qs.toString();
        const path = query
          ? `/reports/transactions?${query}`
          : "/reports/transactions";
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          path,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const transactions = await res.json();
        return json({ transactions, latencyMs });
      }

      // ── Redeem instructions (brand index) ───────────────────────────────
      case "get_redeem_instructions": {
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          "/redeem-instructions",
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const instructions = await res.json();
        return json({ instructions, latencyMs });
      }

      case "get_redeem_instructions_by_brand": {
        const brandId = params.brandId;
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          `/redeem-instructions/${brandId}`,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const instruction = await res.json();
        return json({ instruction, latencyMs });
      }

      // ── Discounts ───────────────────────────────────────────────────────
      case "get_discounts": {
        const qs = new URLSearchParams();
        if (params.size != null) qs.set("size", String(params.size));
        if (params.page != null) qs.set("page", String(params.page));
        const query = qs.toString();
        const path = query ? `/discounts?${query}` : "/discounts";
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          path,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const discounts = await res.json();
        return json({ discounts, latencyMs });
      }

      case "get_product_discount": {
        const productId = params.productId;
        const { response: res, latencyMs } = await timedFetch(
          token,
          environment,
          `/products/${productId}/discounts`,
        );
        if (!res.ok) {
          return json({ error: await parseReloadlyError(res) }, res.status);
        }
        const discount = await res.json();
        return json({ discount, latencyMs });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
