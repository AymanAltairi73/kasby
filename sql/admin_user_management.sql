-- Admin User Management: profile updates, block/unblock, write guards, audit logs
-- Apply via Supabase migration or SQL editor

-- ─── 1. Profile metadata for account restrictions ───────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS status_reason TEXT,
  ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS status_changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.profiles.status_reason IS 'Admin-provided reason when status is blocked/suspended';

-- ─── 2. Admin check (profiles.role + admin_profiles) ────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO public
AS $body$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    ) OR EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND is_active = TRUE
    );
END;
$body$;

-- ─── 3. Central write guard for blocked/suspended users ───────────────────────
CREATE OR REPLACE FUNCTION public.fn_assert_user_can_write(p_user_id UUID) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
AS $body$
DECLARE
    v_status TEXT;
    v_reason TEXT;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Not authenticated';
    END IF;

    SELECT status, status_reason INTO v_status, v_reason
    FROM public.profiles WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Profile not found';
    END IF;

    IF v_status = 'blocked' THEN
        RAISE EXCEPTION 'ACCOUNT_RESTRICTED: تم تقييد حسابك بواسطة إدارة النظام. السبب: %. إذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يرجى التواصل مع الدعم.',
            COALESCE(NULLIF(TRIM(v_reason), ''), 'غير محدد');
    END IF;

    IF v_status = 'suspended' THEN
        RAISE EXCEPTION 'ACCOUNT_RESTRICTED: تم تعليق حسابك مؤقتاً. السبب: %. يرجى التواصل مع الدعم.',
            COALESCE(NULLIF(TRIM(v_reason), ''), 'غير محدد');
    END IF;
END;
$body$;

-- ─── 4. Financial permission check (uses central guard) ───────────────────────
CREATE OR REPLACE FUNCTION public.fn_check_financial_permission(p_user_id UUID, p_operation TEXT) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
AS $body$
DECLARE
    v_profile RECORD;
    v_wallet RECORD;
    v_settings RECORD;
BEGIN
    PERFORM public.fn_assert_user_can_write(p_user_id);

    SELECT status, kyc_status, role INTO v_profile
    FROM public.profiles WHERE id = p_user_id;

    IF v_profile.kyc_status != 'verified'
       AND p_operation IN ('withdrawal', 'investment', 'loan') THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: KYC verification required. Current status: %', v_profile.kyc_status;
    END IF;

    SELECT is_frozen INTO v_wallet FROM public.wallets WHERE user_id = p_user_id;
    IF v_wallet.is_frozen THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Wallet is frozen. Contact support.';
    END IF;

    SELECT * INTO v_settings FROM public.system_settings LIMIT 1;
    IF v_settings.system_freeze THEN
        RAISE EXCEPTION 'SYSTEM_FROZEN: All operations are temporarily suspended.';
    END IF;
    IF p_operation = 'withdrawal' AND v_settings.pause_withdrawals THEN
        RAISE EXCEPTION 'SYSTEM_PAUSED: Withdrawals are temporarily paused.';
    END IF;
    IF p_operation = 'investment' AND v_settings.pause_investments THEN
        RAISE EXCEPTION 'SYSTEM_PAUSED: Investments are temporarily paused.';
    END IF;
    IF p_operation = 'loan' AND v_settings.pause_loans THEN
        RAISE EXCEPTION 'SYSTEM_PAUSED: Loans are temporarily paused.';
    END IF;
    IF p_operation = 'deposit' AND v_settings.pause_deposits THEN
        RAISE EXCEPTION 'SYSTEM_PAUSED: Deposits are temporarily paused.';
    END IF;
END;
$body$;

-- ─── 5. Prevent users from modifying protected profile fields / writing when blocked
CREATE OR REPLACE FUNCTION public.fn_guard_profile_self_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
AS $body$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    IF auth.uid() = OLD.id AND NOT public.is_admin() THEN
        PERFORM public.fn_assert_user_can_write(OLD.id);

        IF NEW.status IS DISTINCT FROM OLD.status
           OR NEW.role IS DISTINCT FROM OLD.role
           OR NEW.kyc_status IS DISTINCT FROM OLD.kyc_status
           OR NEW.account_tier IS DISTINCT FROM OLD.account_tier
           OR NEW.referral_code IS DISTINCT FROM OLD.referral_code
           OR NEW.referred_by IS DISTINCT FROM OLD.referred_by
           OR NEW.referred_by_id IS DISTINCT FROM OLD.referred_by_id
           OR NEW.status_reason IS DISTINCT FROM OLD.status_reason
           OR NEW.status_changed_at IS DISTINCT FROM OLD.status_changed_at
           OR NEW.status_changed_by IS DISTINCT FROM OLD.status_changed_by THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: Cannot modify protected profile fields';
        END IF;
    END IF;

    RETURN NEW;
END;
$body$;

DROP TRIGGER IF EXISTS trg_guard_profile_self_update ON public.profiles;
CREATE TRIGGER trg_guard_profile_self_update
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.fn_guard_profile_self_update();

-- ─── 6. Audit helper ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_write_user_management_audit(
    p_action TEXT,
    p_target_user_id UUID,
    p_details JSONB DEFAULT '{}'::jsonb
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
AS $body$
BEGIN
    INSERT INTO public.audit_logs (
        action, entity_type, entity_id, admin_id, details, type, status, target_id, target_type
    ) VALUES (
        p_action,
        'user',
        p_target_user_id,
        auth.uid(),
        p_details::text,
        'user_management',
        'success',
        p_target_user_id::text,
        'profile'
    );
END;
$body$;

-- ─── 7. Admin: update user profile ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_update_user_profile(
    p_target_user_id UUID,
    p_updates JSONB
) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public, auth
AS $fn_update$
DECLARE
    v_admin_id UUID := auth.uid();
    v_old RECORD;
    v_changed_fields TEXT[] := ARRAY[]::TEXT[];
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Admin access required';
    END IF;

    SELECT * INTO v_old FROM public.profiles WHERE id = p_target_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: User profile not found';
    END IF;

    IF p_target_user_id = v_admin_id THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Cannot modify your own profile via admin RPC';
    END IF;

    -- Apply allowed fields only
    UPDATE public.profiles SET
        full_name = COALESCE(NULLIF(p_updates->>'full_name', ''), full_name),
        email = COALESCE(NULLIF(p_updates->>'email', ''), email),
        phone = CASE WHEN jsonb_exists(p_updates, 'phone') THEN NULLIF(p_updates->>'phone', '') ELSE phone END,
        avatar_url = CASE WHEN jsonb_exists(p_updates, 'avatar_url') THEN NULLIF(p_updates->>'avatar_url', '') ELSE avatar_url END,
        country_code = COALESCE(NULLIF(p_updates->>'country_code', ''), country_code),
        country = COALESCE(NULLIF(p_updates->>'country', ''), country),
        province = COALESCE(p_updates->>'province', province),
        city = COALESCE(p_updates->>'city', city),
        address = COALESCE(p_updates->>'address', address),
        whatsapp = COALESCE(p_updates->>'whatsapp', whatsapp),
        telegram = COALESCE(p_updates->>'telegram', telegram),
        account_tier = COALESCE(NULLIF(p_updates->>'account_tier', ''), account_tier),
        kyc_status = COALESCE(NULLIF(p_updates->>'kyc_status', ''), kyc_status),
        updated_at = now()
    WHERE id = p_target_user_id;

    IF jsonb_exists(p_updates, 'email') AND NULLIF(p_updates->>'email', '') IS NOT NULL
       AND LOWER(p_updates->>'email') IS DISTINCT FROM LOWER(v_old.email) THEN
        UPDATE auth.users
        SET email = LOWER(p_updates->>'email'),
            email_confirmed_at = COALESCE(email_confirmed_at, now()),
            updated_at = now()
        WHERE id = p_target_user_id;
    END IF;

    IF jsonb_exists(p_updates, 'full_name')
       AND NULLIF(p_updates->>'full_name', '') IS DISTINCT FROM v_old.full_name THEN
        v_changed_fields := array_append(v_changed_fields, 'full_name');
    END IF;
    IF jsonb_exists(p_updates, 'email')
       AND NULLIF(p_updates->>'email', '') IS DISTINCT FROM v_old.email THEN
        v_changed_fields := array_append(v_changed_fields, 'email');
    END IF;
    IF jsonb_exists(p_updates, 'phone')
       AND NULLIF(p_updates->>'phone', '') IS DISTINCT FROM v_old.phone THEN
        v_changed_fields := array_append(v_changed_fields, 'phone');
    END IF;
    IF jsonb_exists(p_updates, 'avatar_url')
       AND NULLIF(p_updates->>'avatar_url', '') IS DISTINCT FROM v_old.avatar_url THEN
        v_changed_fields := array_append(v_changed_fields, 'avatar_url');
    END IF;
    IF jsonb_exists(p_updates, 'country_code')
       AND NULLIF(p_updates->>'country_code', '') IS DISTINCT FROM v_old.country_code THEN
        v_changed_fields := array_append(v_changed_fields, 'country_code');
    END IF;
    IF jsonb_exists(p_updates, 'country')
       AND NULLIF(p_updates->>'country', '') IS DISTINCT FROM v_old.country THEN
        v_changed_fields := array_append(v_changed_fields, 'country');
    END IF;
    IF jsonb_exists(p_updates, 'province')
       AND (p_updates->>'province') IS DISTINCT FROM v_old.province THEN
        v_changed_fields := array_append(v_changed_fields, 'province');
    END IF;
    IF jsonb_exists(p_updates, 'city')
       AND (p_updates->>'city') IS DISTINCT FROM v_old.city THEN
        v_changed_fields := array_append(v_changed_fields, 'city');
    END IF;
    IF jsonb_exists(p_updates, 'address')
       AND (p_updates->>'address') IS DISTINCT FROM v_old.address THEN
        v_changed_fields := array_append(v_changed_fields, 'address');
    END IF;
    IF jsonb_exists(p_updates, 'whatsapp')
       AND (p_updates->>'whatsapp') IS DISTINCT FROM v_old.whatsapp THEN
        v_changed_fields := array_append(v_changed_fields, 'whatsapp');
    END IF;
    IF jsonb_exists(p_updates, 'telegram')
       AND (p_updates->>'telegram') IS DISTINCT FROM v_old.telegram THEN
        v_changed_fields := array_append(v_changed_fields, 'telegram');
    END IF;
    IF jsonb_exists(p_updates, 'account_tier')
       AND NULLIF(p_updates->>'account_tier', '') IS DISTINCT FROM v_old.account_tier THEN
        v_changed_fields := array_append(v_changed_fields, 'account_tier');
    END IF;
    IF jsonb_exists(p_updates, 'kyc_status')
       AND NULLIF(p_updates->>'kyc_status', '') IS DISTINCT FROM v_old.kyc_status THEN
        v_changed_fields := array_append(v_changed_fields, 'kyc_status');
    END IF;

    PERFORM public.fn_write_user_management_audit(
        'admin_update_user_profile',
        p_target_user_id,
        jsonb_build_object('changed_fields', v_changed_fields, 'admin_id', v_admin_id)
    );

    PERFORM public.fn_create_notification(
        p_target_user_id,
        'تم تحديث بيانات حسابك',
        'قامت إدارة النظام بتحديث بيانات حسابك. يُرجى مراجعة الملف الشخصي للاطلاع على التغييرات.',
        'profile_updated',
        'profile',
        p_target_user_id::text,
        '/personalProfile',
        'user',
        'high'
    );

    RETURN (SELECT to_jsonb(p.*) FROM public.profiles p WHERE p.id = p_target_user_id);
END;
$fn_update$;

-- ─── 8. Admin: block user ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_block_user(
    p_target_user_id UUID,
    p_reason TEXT
) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
AS $body$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Admin access required';
    END IF;

    IF p_target_user_id = v_admin_id THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Cannot block yourself';
    END IF;

    IF NULLIF(TRIM(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Block reason is required';
    END IF;

    UPDATE public.profiles SET
        status = 'blocked',
        status_reason = TRIM(p_reason),
        status_changed_at = now(),
        status_changed_by = v_admin_id,
        updated_at = now()
    WHERE id = p_target_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: User not found';
    END IF;

    PERFORM public.fn_write_user_management_audit(
        'admin_block_user',
        p_target_user_id,
        jsonb_build_object('reason', TRIM(p_reason), 'admin_id', v_admin_id)
    );

    RETURN jsonb_build_object('success', true, 'status', 'blocked');
END;
$body$;

-- ─── 9. Admin: unblock user ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_unblock_user(
    p_target_user_id UUID
) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
AS $body$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Admin access required';
    END IF;

    UPDATE public.profiles SET
        status = 'active',
        status_reason = NULL,
        status_changed_at = now(),
        status_changed_by = v_admin_id,
        updated_at = now()
    WHERE id = p_target_user_id AND status IN ('blocked', 'suspended');

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: User not found or not restricted';
    END IF;

    PERFORM public.fn_write_user_management_audit(
        'admin_unblock_user',
        p_target_user_id,
        jsonb_build_object('admin_id', v_admin_id)
    );

    RETURN jsonb_build_object('success', true, 'status', 'active');
END;
$body$;

-- ─── 10. Profile status notifications (block/unblock/update) ─────────────────
CREATE OR REPLACE FUNCTION public.fn_trigger_kyc_notification() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
AS $body$
DECLARE
    v_admin_ids UUID[];
    v_reason TEXT;
BEGIN
    IF NEW.kyc_status = 'verified' AND OLD.kyc_status IS DISTINCT FROM 'verified' THEN
        PERFORM public.fn_create_notification(
            NEW.id, 'تم توثيق حسابك ✅',
            'تهانينا! تم التحقق من هويتك بنجاح. يمكنك الآن استخدام جميع خدمات كاسبي.',
            'kyc_approved', 'profile', NEW.id::text, '/kyc'
        );
    END IF;

    IF NEW.kyc_status = 'rejected' AND OLD.kyc_status IS DISTINCT FROM 'rejected' THEN
        PERFORM public.fn_create_notification(
            NEW.id, 'تم رفض التوثيق ❌',
            'تم رفض مستندات التوثيق. يرجى المحاولة مجدداً.',
            'kyc_rejected', 'profile', NEW.id::text, '/kyc'
        );
    END IF;

    IF NEW.kyc_status = 'pending' AND OLD.kyc_status IS DISTINCT FROM 'pending' THEN
        SELECT ARRAY_AGG(id) INTO v_admin_ids
        FROM public.admin_profiles WHERE is_active = TRUE;
        IF v_admin_ids IS NOT NULL THEN
            PERFORM public.fn_create_bulk_notification(
                v_admin_ids, 'طلب توثيق جديد 📋',
                'طلب KYC جديد بانتظار المراجعة.',
                'admin_kyc_pending', 'profile', NEW.id::text, '/users', 'admin'
            );
        END IF;
    END IF;

    v_reason := COALESCE(NULLIF(TRIM(NEW.status_reason), ''), 'غير محدد');

    IF NEW.status = 'blocked' AND OLD.status IS DISTINCT FROM 'blocked' THEN
        PERFORM public.fn_create_notification(
            NEW.id, 'تم تقييد حسابك ⛔',
            'تم تقييد حسابك بواسطة إدارة النظام. السبب: ' || v_reason ||
            '. إذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يرجى التواصل مع الدعم.',
            'account_frozen', 'profile', NEW.id::text, '/support', 'user', 'critical'
        );
    END IF;

    IF NEW.status = 'active' AND OLD.status IN ('blocked', 'suspended') THEN
        PERFORM public.fn_create_notification(
            NEW.id, 'تم إلغاء تقييد حسابك ✅',
            'تم إلغاء تقييد حسابك. يمكنك الآن استخدام جميع خدمات التطبيق.',
            'account_unblocked', 'profile', NEW.id::text, '/profile', 'user', 'high'
        );
    END IF;

    IF NEW.role = 'agent' AND OLD.role IS DISTINCT FROM 'agent' THEN
        PERFORM public.fn_create_notification(
            NEW.id, 'مبروك! تمت ترقيتك إلى وكيل 🎉',
            'تم ترقية حسابك إلى وكيل كاسبي. يمكنك الآن إدارة المعاملات.',
            'role_upgraded', 'profile', NEW.id::text, '/agent-dashboard'
        );
    END IF;

    RETURN NEW;
END;
$body$;

-- ─── 11. Social RPC write guard ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_friend_request(p_receiver_id UUID) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
AS $body$
DECLARE
    v_requester_id UUID := auth.uid();
    v_last_request TIMESTAMPTZ;
BEGIN
    IF v_requester_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
    END IF;

    PERFORM public.fn_assert_user_can_write(v_requester_id);

    IF v_requester_id = p_receiver_id THEN
        RETURN json_build_object('success', FALSE, 'error', 'cannot_add_self');
    END IF;

    SELECT last_friend_request_at INTO v_last_request FROM profiles WHERE id = v_requester_id;
    IF v_last_request IS NOT NULL AND (NOW() - v_last_request) < INTERVAL '60 seconds' THEN
        RETURN json_build_object('success', FALSE, 'error', 'rate_limit_exceeded');
    END IF;

    IF EXISTS (
        SELECT 1 FROM friendships
        WHERE user_low_id = LEAST(v_requester_id, p_receiver_id)
          AND user_high_id = GREATEST(v_requester_id, p_receiver_id)
    ) THEN
        RETURN json_build_object('success', FALSE, 'error', 'already_friends');
    END IF;

    IF EXISTS (
        SELECT 1 FROM friend_requests
        WHERE requester_id = v_requester_id AND receiver_id = p_receiver_id AND status = 'pending'
    ) THEN
        RETURN json_build_object('success', FALSE, 'error', 'request_already_pending');
    END IF;

    IF EXISTS (
        SELECT 1 FROM friend_requests
        WHERE requester_id = p_receiver_id AND receiver_id = v_requester_id AND status = 'pending'
    ) THEN
        UPDATE friend_requests SET status = 'accepted'
        WHERE requester_id = p_receiver_id AND receiver_id = v_requester_id;
        INSERT INTO friendships (user_low_id, user_high_id)
        VALUES (LEAST(v_requester_id, p_receiver_id), GREATEST(v_requester_id, p_receiver_id))
        ON CONFLICT DO NOTHING;
        RETURN json_build_object('success', TRUE, 'auto_accepted', TRUE);
    END IF;

    INSERT INTO friend_requests (requester_id, receiver_id) VALUES (v_requester_id, p_receiver_id);
    UPDATE profiles SET last_friend_request_at = NOW() WHERE id = v_requester_id;
    RETURN json_build_object('success', TRUE);
END;
$body$;

-- ─── 12. Chat insert policy: active users only ────────────────────────────────
DROP POLICY IF EXISTS "Users insert own messages" ON public.chat_messages;
CREATE POLICY "Users insert own messages" ON public.chat_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND sender_type = ANY (ARRAY['user'::text, 'agent'::text])
        AND EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND status = 'active'
        )
        AND conversation_id IN (
            SELECT id FROM public.chat_conversations
            WHERE user_id = auth.uid()
        )
    );

-- ─── 13. KYC documents: active users only ─────────────────────────────────────
DO $body$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'kyc_documents') THEN
        EXECUTE 'DROP POLICY IF EXISTS "Users insert own kyc documents" ON public.kyc_documents';
        EXECUTE 'CREATE POLICY "Users insert own kyc documents" ON public.kyc_documents
            FOR INSERT TO authenticated
            WITH CHECK (
                user_id = auth.uid()
                AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND status = ''active'')
            )';
        EXECUTE 'DROP POLICY IF EXISTS "Users update own kyc documents" ON public.kyc_documents';
        EXECUTE 'CREATE POLICY "Users update own kyc documents" ON public.kyc_documents
            FOR UPDATE TO authenticated
            USING (user_id = auth.uid())
            WITH CHECK (
                user_id = auth.uid()
                AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND status = ''active'')
            )';
    END IF;
END $body$;

-- ─── 14. Grants ───────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.fn_assert_user_can_write(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_admin_update_user_profile(UUID, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_admin_block_user(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_admin_unblock_user(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_write_user_management_audit(TEXT, UUID, JSONB) TO authenticated, service_role;
