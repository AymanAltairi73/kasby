import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/** Ensure profile/wallet/points exist after auth user creation (trigger may fail silently). */
async function ensureUserBootstrap(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  email: string | undefined,
  metadata: Record<string, unknown>,
) {
  const { data: existing, error: existingError } = await supabaseAdmin
    .from('profiles')
    .select('id, referral_code')
    .eq('id', userId)
    .maybeSingle()

  if (existingError) throw existingError

  const profileRow: Record<string, unknown> = {
    id: userId,
    full_name: metadata.full_name ?? 'مستخدم جديد',
    email: email ?? metadata.email ?? '',
    phone: metadata.phone ?? null,
    country_code: metadata.country_code ?? null,
    role: metadata.role ?? 'user',
    status: 'active',
  }

  if (!existing) {
    const { data: refCode, error: refErr } = await supabaseAdmin.rpc(
      'generate_sequential_referral_code',
    )
    if (refErr) throw refErr
    profileRow.referral_code = refCode
    const { error: insertErr } = await supabaseAdmin.from('profiles').insert(profileRow)
    if (insertErr) throw insertErr
  } else {
    const { error: updateErr } = await supabaseAdmin
      .from('profiles')
      .update(profileRow)
      .eq('id', userId)
    if (updateErr) throw updateErr
  }

  await supabaseAdmin
    .from('wallets')
    .upsert({ user_id: userId, currency: 'USD' }, { onConflict: 'user_id,currency' })
    .then(() => {})
    .catch(() => {})

  await supabaseAdmin
    .from('user_points')
    .upsert({ user_id: userId }, { onConflict: 'user_id' })
    .then(() => {})
    .catch(() => {})
}

/**
 * ADMIN PROXY — Secure Admin Operations Edge Function
 * 
 * Replaces direct service_role key usage in admin APK.
 * All admin operations are routed through this function which:
 * 1. Validates the caller is an authenticated admin
 * 2. Executes the privileged operation server-side using service_role
 * 3. Returns the result without exposing credentials
 * 
 * Supported operations:
 * - create_user: Create a new auth user
 * - delete_user: Delete an auth user
 * - update_user: Update auth user attributes
 * - list_users: List auth users (paginated)
 * - get_user: Get a single auth user by ID
 * - add_balance: Credit user wallet via fn_admin_add_balance
 * - deduct_balance: Debit user wallet via fn_admin_deduct_balance
 */

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Authenticate the caller
    const authHeader = req.headers.get('Authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization' }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const token = authHeader.replace('Bearer ', '').trim()
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // 2. Load caller profile
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'Profile not found' }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const isAdmin = profile.role === 'admin'

    // 3. Parse the operation
    const { operation, params } = await req.json()

    if (!operation) {
      return new Response(
        JSON.stringify({ error: 'Missing operation parameter' }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // All operations except self-delete require admin role
    if (!isAdmin && operation !== 'delete_user') {
      return new Response(
        JSON.stringify({ error: 'Forbidden: Admin access required' }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    let result: any = null

    switch (operation) {
      case 'create_user': {
        const { email, password, user_metadata } = params || {}
        if (!email || !password) {
          return new Response(
            JSON.stringify({ error: 'email and password are required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        const meta = (user_metadata || {}) as Record<string, unknown>
        const { data, error } = await supabaseAdmin.auth.admin.createUser({
          email,
          password,
          user_metadata: meta,
          email_confirm: true,
        })
        if (error) throw error
        await ensureUserBootstrap(
          supabaseAdmin,
          data.user.id,
          data.user.email,
          meta,
        )
        result = { user: { id: data.user.id, email: data.user.email } }
        break
      }

      case 'delete_user': {
        const { user_id } = params || {}
        if (!user_id) {
          return new Response(
            JSON.stringify({ error: 'user_id is required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        if (!isAdmin && user_id !== user.id) {
          return new Response(
            JSON.stringify({ error: 'Forbidden: You can only delete your own account' }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }

        // Notify user before purge (profile still exists)
        await supabaseAdmin.rpc('fn_create_notification', {
          p_user_id: user_id,
          p_title: 'تم حذف حسابك',
          p_body: 'تم حذف حسابك بواسطة إدارة النظام. إذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يرجى التواصل مع الدعم.',
          p_type: 'account_deleted',
          p_entity_type: 'profile',
          p_entity_id: user_id,
          p_deep_link: '/support',
          p_role_target: 'user',
          p_priority: 'critical',
        }).then(() => {}).catch(() => {})

        await supabaseAdmin.from('audit_logs').insert({
          action: 'admin_delete_user',
          entity_type: 'user',
          entity_id: user_id,
          admin_id: user.id,
          details: JSON.stringify({ deleted_by: user.id }),
          type: 'user_management',
          status: 'success',
          target_id: user_id,
          target_type: 'profile',
        }).then(() => {}).catch(() => {})

        const { data: purgeResult, error: purgeError } = await supabaseAdmin.rpc(
          'fn_admin_purge_user_data',
          { p_user_id: user_id },
        )
        if (purgeError) throw purgeError
        const purgePayload = purgeResult as Record<string, unknown> | null
        if (purgePayload?.success === false) {
          throw new Error(String(purgePayload['message'] ?? 'User data purge failed'))
        }
        const { error } = await supabaseAdmin.auth.admin.deleteUser(user_id)
        if (error) throw error
        result = { success: true }
        break
      }

      case 'block_user': {
        const { user_id, reason } = params || {}
        if (!user_id || !reason) {
          return new Response(
            JSON.stringify({ error: 'user_id and reason are required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        const { data, error } = await supabaseAdmin.rpc('fn_admin_block_user', {
          p_target_user_id: user_id,
          p_reason: reason,
        })
        if (error) throw error
        result = { success: true, data }
        break
      }

      case 'unblock_user': {
        const { user_id } = params || {}
        if (!user_id) {
          return new Response(
            JSON.stringify({ error: 'user_id is required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        const { data, error } = await supabaseAdmin.rpc('fn_admin_unblock_user', {
          p_target_user_id: user_id,
        })
        if (error) throw error
        result = { success: true, data }
        break
      }

      case 'update_user_profile': {
        const { user_id, updates } = params || {}
        if (!user_id || !updates) {
          return new Response(
            JSON.stringify({ error: 'user_id and updates are required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        const { data, error } = await supabaseAdmin.rpc('fn_admin_update_user_profile', {
          p_target_user_id: user_id,
          p_updates: updates,
        })
        if (error) throw error
        result = { success: true, profile: data }
        break
      }

      case 'update_user': {
        const { user_id, attributes } = params || {}
        if (!user_id || !attributes) {
          return new Response(
            JSON.stringify({ error: 'user_id and attributes are required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        const { data, error } = await supabaseAdmin.auth.admin.updateUserById(user_id, attributes)
        if (error) throw error
        result = { user: { id: data.user.id, email: data.user.email } }
        break
      }

      case 'list_users': {
        const { page = 1, per_page = 50 } = params || {}
        const { data, error } = await supabaseAdmin.auth.admin.listUsers({
          page,
          perPage: per_page,
        })
        if (error) throw error
        result = {
          users: data.users.map((u: any) => ({
            id: u.id,
            email: u.email,
            phone: u.phone,
            created_at: u.created_at,
            last_sign_in_at: u.last_sign_in_at,
            user_metadata: u.user_metadata,
          })),
          total: data.users.length,
        }
        break
      }

      case 'get_user': {
        const { user_id } = params || {}
        if (!user_id) {
          return new Response(
            JSON.stringify({ error: 'user_id is required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        const { data, error } = await supabaseAdmin.auth.admin.getUserById(user_id)
        if (error) throw error
        result = {
          user: {
            id: data.user.id,
            email: data.user.email,
            phone: data.user.phone,
            created_at: data.user.created_at,
            user_metadata: data.user.user_metadata,
          },
        }
        break
      }

      case 'add_balance': {
        const { user_id, amount } = params || {}
        if (!user_id || amount == null) {
          return new Response(
            JSON.stringify({ error: 'user_id and amount are required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        const { data, error } = await supabaseAdmin.rpc('fn_admin_add_balance', {
          p_user_id: user_id,
          p_amount: amount,
        })
        if (error) throw error
        const payload = data as Record<string, unknown>
        if (payload?.success === false) {
          throw new Error(String(payload['message'] ?? 'Balance credit failed'))
        }
        result = { balance: payload }
        break
      }

      case 'deduct_balance': {
        const { user_id, amount } = params || {}
        if (!user_id || amount == null) {
          return new Response(
            JSON.stringify({ error: 'user_id and amount are required' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        const { data, error } = await supabaseAdmin.rpc('fn_admin_deduct_balance', {
          p_user_id: user_id,
          p_amount: amount,
        })
        if (error) throw error
        const payload = data as Record<string, unknown>
        if (payload?.success === false) {
          throw new Error(String(payload['message'] ?? 'Balance debit failed'))
        }
        result = { balance: payload }
        break
      }

      default:
        if (!isAdmin) {
          return new Response(
            JSON.stringify({ error: 'Forbidden: Admin access required' }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
        return new Response(
          JSON.stringify({ error: `Unknown operation: ${operation}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
    }

    // 4. Audit log
    await supabaseAdmin.from('system_logs').insert({
      actor_id: user.id,
      actor_role: isAdmin ? 'admin' : 'user',
      action: `admin_proxy:${operation}`,
      entity_type: 'auth_user',
      entity_id: params?.user_id || null,
      details: { operation, admin_id: user.id },
      severity: 'info',
    }).then(() => {}).catch(() => {})

    return new Response(
      JSON.stringify({ success: true, ...result }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (err: any) {
    console.error('[ADMIN_PROXY] Error:', err)
    return new Response(
      JSON.stringify({ error: err.message || 'Internal error' }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
