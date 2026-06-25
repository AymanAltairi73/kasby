export function logOtp(
  level: "info" | "error",
  flow: string,
  details: Record<string, unknown>,
) {
  const prefix = `[OTP][${flow}]`
  const payload = JSON.stringify({ timestamp: new Date().toISOString(), ...details })
  if (level === "error") console.error(prefix, payload)
  else console.log(prefix, payload)
}

export function maskDestination(value: string, type: "email" | "phone"): string {
  if (type === "email") {
    const at = value.indexOf("@")
    if (at <= 1) return "***"
    return `${value[0]}***${value.substring(at)}`
  }
  const digits = value.replace(/\D/g, "")
  if (digits.length < 4) return "***"
  return `***${digits.slice(-4)}`
}
