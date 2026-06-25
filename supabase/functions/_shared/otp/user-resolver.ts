import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"
import { normalizeEmail, normalizePhoneE164, phoneLookupVariants } from "./normalize.ts"

export async function findAuthUserByEmail(
  admin: SupabaseClient,
  email: string,
): Promise<string | null> {
  let page = 1
  while (page <= 5) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 })
    if (error) break
    const match = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase())
    if (match?.id) return match.id
    if (data.users.length < 200) break
    page++
  }
  return null
}

export async function resolveUserId(
  admin: SupabaseClient,
  destination: string,
  destinationType: "email" | "phone",
  purpose: string,
  authUserId: string | null,
): Promise<string | null> {
  if (authUserId) return authUserId

  if (destinationType === "email") {
    const email = normalizeEmail(destination)
    const { data: profile } = await admin.from("profiles").select("id").eq("email", email)
      .maybeSingle()
    if (profile?.id) return profile.id
    return await findAuthUserByEmail(admin, email)
  }

  for (const variant of phoneLookupVariants(destination)) {
    const { data: profile } = await admin.from("profiles").select("id").eq("phone", variant)
      .maybeSingle()
    if (profile?.id) return profile.id
  }

  if (purpose === "password_reset") return null

  return null
}

export async function provisionSignupUser(
  admin: SupabaseClient,
  email: string,
  password: string,
  metadata: Record<string, unknown>,
): Promise<string | null> {
  const normalized = normalizeEmail(email)
  const { data, error } = await admin.auth.admin.createUser({
    email: normalized,
    password,
    email_confirm: false,
    user_metadata: metadata,
  })
  if (!error && data.user?.id) return data.user.id
  if (error?.message.toLowerCase().includes("already")) {
    return await findAuthUserByEmail(admin, normalized)
  }
  throw error ?? new Error("Failed to provision user")
}
