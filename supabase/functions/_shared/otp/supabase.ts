import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

export async function resolveUserIdFromJwt(
  admin: SupabaseClient,
  authHeader: string | null,
): Promise<string | null> {
  if (!authHeader?.startsWith("Bearer ")) return null
  const token = authHeader.replace("Bearer ", "").trim()
  if (!token.includes(".") || token.length < 40) return null
  const { data: { user } } = await admin.auth.getUser(token)
  return user?.id ?? null
}
