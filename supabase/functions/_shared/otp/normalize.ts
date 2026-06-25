const E164_REGEX = /^\+[1-9]\d{6,14}$/

export function normalizeEmail(email: string): string {
  return String(email).trim().toLowerCase()
}

export function normalizePhoneE164(phone: string): string {
  let value = String(phone).trim().replace(/[\s\-()]/g, "")
  if (!value.startsWith("+")) {
    value = `+${value.replace(/^\+/, "")}`
  }
  return value
}

export function isValidE164(phone: string): boolean {
  return E164_REGEX.test(normalizePhoneE164(phone))
}

export function isValidEmail(email: string): boolean {
  const normalized = normalizeEmail(email)
  return normalized.includes("@") && normalized.includes(".") &&
    normalized.length >= 5
}

export function phoneLookupVariants(phone: string): string[] {
  const e164 = normalizePhoneE164(phone)
  const withoutPlus = e164.slice(1)
  return [...new Set([e164, withoutPlus, `+${withoutPlus}`])]
}
