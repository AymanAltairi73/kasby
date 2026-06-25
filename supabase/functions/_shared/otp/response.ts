import { corsHeaders } from "./constants.ts"

export function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

export function errorResponse(
  error: string,
  status: number,
  code?: string,
  extra?: Record<string, unknown>,
): Response {
  return jsonResponse({ success: false, error, ...(code ? { code } : {}), ...extra }, status)
}

export function successResponse(data: Record<string, unknown> = {}): Response {
  return jsonResponse({ success: true, ...data })
}
