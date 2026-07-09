import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function logAudit(
  supabaseAdmin: ReturnType<typeof createClient>,
  actorId: string,
  action: string,
  entityId: string | null,
  details: Record<string, unknown> = {},
) {
  await supabaseAdmin.from('system_logs').insert({
    actor_id: actorId,
    action,
    entity_type: 'user',
    entity_id: entityId,
    severity: 'info',
    details,
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    )

    const { data: userData, error: userError } = await supabaseUser.auth.getUser()
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: 'Invalid or expired token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const userId = userData.user.id

    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .maybeSingle()

    if (profile?.role === 'admin') {
      return new Response(JSON.stringify({ error: 'Admin accounts cannot self-delete via this endpoint' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { error: recordError } = await supabaseAdmin.rpc('fn_record_deleted_account', {
      p_user_id: userId,
      p_deletion_type: 'self',
      p_deleted_by: userId,
    })
    if (recordError) throw recordError

    const { data: purgeResult, error: purgeError } = await supabaseAdmin.rpc(
      'fn_admin_purge_user_data',
      { p_user_id: userId },
    )
    if (purgeError) throw purgeError
    if (
      purgeResult &&
      typeof purgeResult === 'object' &&
      (purgeResult as Record<string, unknown>).success === false
    ) {
      const message =
        (purgeResult as Record<string, unknown>).message?.toString() ??
        'User data purge failed'
      throw new Error(message)
    }

    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId)
    if (deleteError) throw deleteError

    await logAudit(supabaseAdmin, userId, 'self_delete_account', userId, {
      deletion_type: 'self',
    })

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
