import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type AdminTier = 'admin' | 'viewer'

interface AuthContext {
  userId: string
  platformRole: string
  adminTier: AdminTier
}

const PRIVILEGED_OPERATIONS = new Set([
  'create_user',
  'delete_user',
  'update_user',
  'add_balance',
  'deduct_balance',
  'block_user',
  'unblock_user',
])

async function resolveAuth(req: Request, supabaseAdmin: ReturnType<typeof createClient>): Promise<AuthContext> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    throw new Response(JSON.stringify({ error: 'Missing authorization header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: userData, error: userError } = await supabaseUser.auth.getUser()
  if (userError || !userData.user) {
    throw new Response(JSON.stringify({ error: 'Invalid or expired token' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const userId = userData.user.id

  const { data: profile, error: profileError } = await supabaseAdmin
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .single()

  if (profileError || !profile) {
    throw new Response(JSON.stringify({ error: 'Profile not found' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const platformRole = (profile.role as string)?.toLowerCase()
  if (platformRole !== 'admin') {
    await logAudit(supabaseAdmin, userId, 'rbac_violation', 'admin_proxy', null, {
      reason: 'non_admin_platform_role',
      platform_role: platformRole,
    })
    throw new Response(JSON.stringify({ error: 'Forbidden: Admin platform role required' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const { data: adminProfile } = await supabaseAdmin
    .from('admin_profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle()

  let rawTier = (adminProfile?.role as string | undefined)?.toLowerCase() ?? 'admin'
  if (rawTier === 'superadmin' || rawTier === 'finance_ops' || rawTier === 'support') {
    rawTier = 'admin'
  }
  const adminTier: AdminTier = rawTier === 'viewer' ? 'viewer' : 'admin'

  return { userId, platformRole, adminTier }
}

function requireAdminTier(ctx: AuthContext, operation: string): void {
  if (ctx.adminTier !== 'admin') {
    throw new Response(
      JSON.stringify({
        error: 'RBAC_DENIED: Insufficient admin privileges for this operation',
        operation,
      }),
      { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
}

async function logAudit(
  supabaseAdmin: ReturnType<typeof createClient>,
  actorId: string,
  action: string,
  entityType: string,
  entityId: string | null,
  details: Record<string, unknown> = {},
) {
  await supabaseAdmin.from('system_logs').insert({
    actor_id: actorId,
    action,
    entity_type: entityType,
    entity_id: entityId,
    severity: action.includes('violation') || action.includes('denied') ? 'warning' : 'info',
    details,
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const ctx = await resolveAuth(req, supabaseAdmin)
    const body = await req.json()
    const operation = body.operation as string
    const params = (body.params ?? {}) as Record<string, unknown>

    if (!operation) {
      return new Response(JSON.stringify({ error: 'Missing operation' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (PRIVILEGED_OPERATIONS.has(operation)) {
      requireAdminTier(ctx, operation)
    }

    let result: Record<string, unknown> = {}

    switch (operation) {
      case 'create_user': {
        const email = params.email as string
        const password = params.password as string
        const userMetadata = (params.user_metadata ?? {}) as Record<string, unknown>
        const { data, error } = await supabaseAdmin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: userMetadata,
        })
        if (error) throw error
        result = { user: data.user }
        break
      }

      case 'delete_user': {
        const userId = params.user_id as string
        await supabaseAdmin.rpc('fn_admin_purge_user_data', { p_user_id: userId })
        const { error } = await supabaseAdmin.auth.admin.deleteUser(userId)
        if (error) throw error
        result = { success: true, user_id: userId }
        break
      }

      case 'update_user': {
        const userId = params.user_id as string
        const attributes = (params.attributes ?? {}) as Record<string, unknown>
        const { data, error } = await supabaseAdmin.auth.admin.updateUserById(userId, attributes)
        if (error) throw error
        result = { user: data.user }
        break
      }

      case 'list_users': {
        const page = (params.page as number) ?? 1
        const perPage = (params.per_page as number) ?? 50
        const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage })
        if (error) throw error
        result = { users: data.users }
        break
      }

      case 'get_user': {
        const userId = params.user_id as string
        const { data, error } = await supabaseAdmin.auth.admin.getUserById(userId)
        if (error) throw error
        result = { user: data.user }
        break
      }

      case 'add_balance': {
        const userId = params.user_id as string
        const amount = params.amount as number
        const { data, error } = await supabaseAdmin.rpc('fn_admin_add_balance', {
          p_user_id: userId,
          p_amount: amount,
          p_admin_id: ctx.userId,
        })
        if (error) throw error
        result = (data as Record<string, unknown>) ?? { success: true }
        await logAudit(supabaseAdmin, ctx.userId, 'admin_proxy:add_balance', 'user', userId, {
          amount,
        })
        break
      }

      case 'deduct_balance': {
        const userId = params.user_id as string
        const amount = params.amount as number
        const { data, error } = await supabaseAdmin.rpc('fn_admin_deduct_balance', {
          p_user_id: userId,
          p_amount: amount,
          p_admin_id: ctx.userId,
        })
        if (error) throw error
        result = (data as Record<string, unknown>) ?? { success: true }
        await logAudit(supabaseAdmin, ctx.userId, 'admin_proxy:deduct_balance', 'user', userId, {
          amount,
        })
        break
      }

      case 'block_user': {
        const userId = params.user_id as string
        const reason = params.reason as string
        const { error } = await supabaseAdmin.rpc('fn_admin_block_user', {
          p_user_id: userId,
          p_reason: reason,
          p_admin_id: ctx.userId,
        })
        if (error) throw error
        result = { success: true }
        break
      }

      case 'unblock_user': {
        const userId = params.user_id as string
        const { error } = await supabaseAdmin.rpc('fn_admin_unblock_user', {
          p_user_id: userId,
          p_admin_id: ctx.userId,
        })
        if (error) throw error
        result = { success: true }
        break
      }

      default:
        await logAudit(supabaseAdmin, ctx.userId, 'permission_denied', 'admin_proxy', null, {
          operation,
          reason: 'unknown_operation',
        })
        return new Response(JSON.stringify({ error: `Unknown operation: ${operation}` }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }

    await logAudit(supabaseAdmin, ctx.userId, `admin_proxy:${operation}`, 'admin_proxy', null, {
      admin_tier: ctx.adminTier,
    })

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    if (err instanceof Response) return err

    const message = err instanceof Error ? err.message : String(err)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
