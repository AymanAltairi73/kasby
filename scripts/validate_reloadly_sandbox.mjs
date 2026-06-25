/**
 * Reloadly sandbox catalog validation.
 * Reads live catalog via Supabase edge function or direct OAuth.
 *
 * Usage:
 *   node scripts/validate_reloadly_sandbox.mjs
 *
 * Env (optional — direct OAuth):
 *   RELOADLY_CLIENT_ID, RELOADLY_CLIENT_SECRET
 *
 * Env (edge proxy):
 *   SUPABASE_URL, SUPABASE_ANON_KEY
 */

const REQUIRED_PRODUCTS = {
  giftCards: [
    { name: 'Google Play', keywords: ['google play', 'google'] },
    { name: 'Apple', keywords: ['apple', 'itunes', 'app store'] },
    { name: 'Steam', keywords: ['steam'] },
    { name: 'PlayStation', keywords: ['playstation', 'psn'] },
    { name: 'Xbox', keywords: ['xbox'] },
    { name: 'Amazon', keywords: ['amazon'] },
  ],
  gaming: [
    { name: 'PUBG Mobile UC', keywords: ['pubg'] },
    { name: 'Free Fire Diamonds', keywords: ['free fire', 'garena'] },
    { name: 'Mobile Legends', keywords: ['mobile legends', 'mlbb'] },
    { name: 'Call of Duty CP', keywords: ['call of duty', 'cod'] },
  ],
  subscriptions: [
    { name: 'Netflix', keywords: ['netflix'] },
    { name: 'Spotify', keywords: ['spotify'] },
    { name: 'ChatGPT', keywords: ['chatgpt', 'openai'] },
    { name: 'Canva', keywords: ['canva'] },
    { name: 'YouTube Premium', keywords: ['youtube'] },
  ],
};

function haystack(product) {
  const brand = product.brand?.brandName ?? '';
  return `${product.productName ?? ''} ${brand}`.toLowerCase();
}

function matchProduct(products, keywords) {
  return products.filter((p) => {
    const h = haystack(p);
    return keywords.some((k) => h.includes(k));
  });
}

async function fetchViaEdge() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) return null;

  const res = await fetch(`${url}/functions/v1/reloadly-proxy`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({ action: 'sync_catalog', environment: 'sandbox' }),
  });

  const body = await res.json();
  if (!res.ok) throw new Error(body.error ?? `Edge proxy HTTP ${res.status}`);
  return body.products ?? [];
}

async function fetchViaOAuth() {
  const clientId = process.env.RELOADLY_CLIENT_ID;
  const clientSecret = process.env.RELOADLY_CLIENT_SECRET;
  if (!clientId || !clientSecret) return null;

  const tokenRes = await fetch('https://auth.reloadly.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'client_credentials',
      audience: 'https://giftcards-sandbox.reloadly.com',
    }),
  });
  const tokenBody = await tokenRes.json();
  if (!tokenRes.ok) throw new Error(tokenBody.message ?? 'OAuth failed');

  const productsRes = await fetch('https://giftcards-sandbox.reloadly.com/products', {
    headers: {
      Authorization: `Bearer ${tokenBody.access_token}`,
      Accept: 'application/com.reloadly.giftcards-v1+json',
    },
  });
  if (!productsRes.ok) throw new Error(`Products HTTP ${productsRes.status}`);
  return productsRes.json();
}

function buildReport(products, source, error) {
  const brands = new Set();
  const countries = new Set();
  for (const p of products) {
    if (p.brand?.brandName) brands.add(p.brand.brandName);
    if (p.country?.isoName) countries.add(p.country.isoName);
    if (p.global) countries.add('GLOBAL');
  }

  const sections = {};
  for (const [section, items] of Object.entries(REQUIRED_PRODUCTS)) {
    sections[section] = items.map((item) => {
      const matches = products.length ? matchProduct(products, item.keywords) : [];
      const status = !products.length
        ? 'Catalog Validation Pending'
        : matches.length > 0
          ? 'Available'
          : 'Not Supported by Reloadly';

      return {
        product: item.name,
        status,
        matchCount: matches.length,
        sampleMatches: matches.slice(0, 3).map((m) => ({
          productId: m.productId,
          productName: m.productName,
          brandName: m.brand?.brandName,
          country: m.country?.isoName ?? (m.global ? 'GLOBAL' : null),
        })),
      };
    });
  }

  return {
    generatedAt: new Date().toISOString(),
    source,
    catalogAccessible: products.length > 0,
    error,
    summary: {
      totalProducts: products.length,
      uniqueBrands: brands.size,
      uniqueCountries: countries.size,
    },
    brands: [...brands].sort().slice(0, 100),
    countries: [...countries].sort(),
    productMatrix: sections,
  };
}

async function main() {
  let products = [];
  let source = 'none';
  let error = null;

  try {
    products = (await fetchViaEdge()) ?? [];
    if (products.length) source = 'supabase-edge-proxy';
  } catch (e) {
    error = String(e);
  }

  if (!products.length) {
    try {
      products = (await fetchViaOAuth()) ?? [];
      if (products.length) {
        source = 'direct-oauth';
        error = null;
      }
    } catch (e) {
      error = error ?? String(e);
    }
  }

  const report = buildReport(products, source, error);
  console.log(JSON.stringify(report, null, 2));
  return report;
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
