-- Enterprise auth, KYC, notification, permission, and reactivation fixes

-- ─── Deduplicated notification helper ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_notification_sent_recently(
  p_user_id UUID,
  p_type TEXT,
  p_entity_id TEXT DEFAULT NULL,
  p_within_seconds INTEGER DEFAULT 120
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.user_id = p_user_id
      AND n.type = p_type
      AND n.deleted_at IS NULL
      AND (p_entity_id IS NULL OR n.entity_id = p_entity_id)
      AND COALESCE(n.sent_at, n.created_at) > NOW() - make_interval(secs => p_within_seconds)
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_create_notification_once(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_type TEXT,
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id TEXT DEFAULT NULL,
  p_deep_link TEXT DEFAULT NULL,
  p_role_target TEXT DEFAULT 'user',
  p_priority TEXT DEFAULT 'normal',
  p_dedupe_seconds INTEGER DEFAULT 120
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_existing UUID;
BEGIN
  IF public.fn_notification_sent_recently(
    p_user_id, p_type, p_entity_id, p_dedupe_seconds
  ) THEN
    SELECT n.id
      INTO v_existing
    FROM public.notifications n
    WHERE n.user_id = p_user_id
      AND n.type = p_type
      AND n.deleted_at IS NULL
      AND (p_entity_id IS NULL OR n.entity_id = p_entity_id)
    ORDER BY COALESCE(n.sent_at, n.created_at) DESC
    LIMIT 1;
    RETURN v_existing;
  END IF;

  RETURN public.fn_create_notification(
    p_user_id,
    p_title,
    p_body,
    p_type,
    p_entity_type,
    p_entity_id,
    p_deep_link,
    p_role_target,
    p_priority
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_notification_sent_recently(UUID, TEXT, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_create_notification_once(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER) TO authenticated;

-- ─── Financial permission: KYC required for transfer + QR receive ───────────
CREATE OR REPLACE FUNCTION public.fn_check_financial_permission(
  p_user_id UUID,
  p_operation TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_profile RECORD;
  v_wallet RECORD;
  v_settings RECORD;
BEGIN
  PERFORM public.fn_assert_user_can_write(p_user_id);

  SELECT status, kyc_status, role
    INTO v_profile
  FROM public.profiles
  WHERE id = p_user_id;

  IF p_operation IN ('withdrawal', 'investment', 'loan', 'transfer', 'qr_receive')
     AND v_profile.kyc_status IS DISTINCT FROM 'verified' THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: KYC verification required. Current status: %',
      COALESCE(v_profile.kyc_status, 'unverified');
  END IF;

  SELECT is_frozen
    INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id AND currency = 'USD'
  LIMIT 1;

  IF COALESCE(v_wallet.is_frozen, FALSE) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Wallet is frozen. Contact support.';
  END IF;

  SELECT *
    INTO v_settings
  FROM public.system_settings
  LIMIT 1;

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
$$;

-- ─── Remove duplicate KYC notifications from admin RPC ──────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_set_kyc_status(
  p_user_id UUID,
  p_status TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  IF p_status NOT IN ('unverified', 'pending', 'verified', 'rejected') THEN
    RAISE EXCEPTION 'Invalid KYC status: %', p_status;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  UPDATE public.profiles
  SET
    kyc_status = p_status,
    kyc_rejection_reason = CASE
      WHEN p_status = 'rejected' THEN COALESCE(NULLIF(TRIM(p_reason), ''), kyc_rejection_reason)
      ELSE NULL
    END,
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- ─── Profile notification trigger (single source of truth) ──────────────────
CREATE OR REPLACE FUNCTION public.fn_trigger_kyc_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_ids UUID[];
  v_user_name TEXT := COALESCE(NEW.full_name, 'مستخدم');
BEGIN
  IF NEW.kyc_status = 'verified' AND OLD.kyc_status IS DISTINCT FROM 'verified' THEN
    PERFORM public.fn_create_notification_once(
      NEW.id,
      'تم توثيق حسابك ✅ | Account Verified',
      'تهانينا! تم التحقق من هويتك بنجاح. يمكنك الآن استخدام جميع خدمات كاسبي.'
        || E'\n'
        || 'Congratulations! Your identity has been verified. You can now use all Kasby services.',
      'kyc_approved',
      'profile',
      NEW.id::TEXT,
      '/kyc',
      'user',
      'high'
    );

    PERFORM public.fn_create_notification_once(
      NEW.id,
      'تم تفعيل السحب ✅ | Withdrawal Enabled',
      'يمكنك الآن سحب الأموال من محفظتك.'
        || E'\n'
        || 'You can now withdraw funds from your wallet.',
      'permission_withdrawal_granted',
      'profile',
      NEW.id::TEXT,
      '/withdraw',
      'user',
      'normal'
    );

    PERFORM public.fn_create_notification_once(
      NEW.id,
      'تم تفعيل التحويل ✅ | Transfer Enabled',
      'يمكنك الآن تحويل الأموال إلى المستخدمين الآخرين.'
        || E'\n'
        || 'You can now transfer funds to other users.',
      'permission_transfer_granted',
      'profile',
      NEW.id::TEXT,
      '/transfer',
      'user',
      'normal'
    );

    PERFORM public.fn_create_notification_once(
      NEW.id,
      'تم تفعيل استلام QR ✅ | QR Receive Enabled',
      'يمكنك الآن استلام المدفوعات عبر رمز QR الخاص بك.'
        || E'\n'
        || 'You can now receive payments using your personal QR code.',
      'permission_qr_receive_granted',
      'profile',
      NEW.id::TEXT,
      '/my-qr',
      'user',
      'normal'
    );
  END IF;

  IF NEW.kyc_status = 'rejected' AND OLD.kyc_status IS DISTINCT FROM 'rejected' THEN
    PERFORM public.fn_create_notification_once(
      NEW.id,
      'تم رفض التوثيق ❌ | Verification Rejected',
      COALESCE(
        NULLIF(TRIM(NEW.kyc_rejection_reason), ''),
        'تم رفض مستندات التوثيق. يرجى المحاولة مجدداً.'
      ),
      'kyc_rejected',
      'profile',
      NEW.id::TEXT,
      '/kyc',
      'user',
      'high'
    );
  END IF;

  IF NEW.kyc_status = 'pending' AND OLD.kyc_status IS DISTINCT FROM 'pending' THEN
    SELECT ARRAY_AGG(id)
      INTO v_admin_ids
    FROM public.admin_profiles
    WHERE is_active = TRUE;

    IF v_admin_ids IS NOT NULL THEN
      PERFORM public.fn_create_bulk_notification(
        v_admin_ids,
        'طلب توثيق جديد 📋',
        'طلب KYC من ' || v_user_name || ' بانتظار المراجعة.',
        'admin_kyc_pending',
        'profile',
        NEW.id::TEXT,
        '/kyc',
        'admin',
        'high'
      );
    END IF;
  END IF;

  IF NEW.status = 'blocked' AND OLD.status IS DISTINCT FROM 'blocked' THEN
    PERFORM public.fn_create_notification_once(
      NEW.id,
      'تم تقييد حسابك ⛔ | Account Restricted',
      'تم تقييد حسابك بواسطة إدارة كاسبي. يرجى التواصل مع الدعم.'
        || E'\n'
        || 'Your account has been restricted by Kasby administration. Please contact support.',
      'account_blocked',
      'profile',
      NEW.id::TEXT,
      '/support',
      'user',
      'critical'
    );
  END IF;

  IF NEW.status = 'active'
     AND OLD.status IN ('blocked', 'suspended') THEN
    PERFORM public.fn_create_notification_once(
      NEW.id,
      'تم إعادة تفعيل حسابك ✅ | Account Reactivated',
      'تم إعادة تفعيل حسابك بنجاح ويمكنك الآن استخدام جميع خدمات كاسبي.'
        || E'\n'
        || 'Your account has been successfully reactivated. You can now use all Kasby services.',
      'account_reactivated',
      'profile',
      NEW.id::TEXT,
      '/home',
      'user',
      'high'
    );
  END IF;

  IF NEW.role = 'agent' AND OLD.role IS DISTINCT FROM 'agent' THEN
    PERFORM public.fn_create_notification_once(
      NEW.id,
      'مبروك! تمت ترقيتك إلى وكيل 🎉',
      'تم ترقية حساب ' || v_user_name || ' إلى وكيل كاسبي.',
      'role_upgraded',
      'profile',
      NEW.id::TEXT,
      '/agent-dashboard',
      'user',
      'high'
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profile_notification ON public.profiles;
CREATE TRIGGER trg_profile_notification
  AFTER UPDATE OF kyc_status, status, role
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trigger_kyc_notification();

-- ─── Admin delete confirmation notification ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_notify_deletion_complete(
  p_deleted_user_id UUID,
  p_deleted_user_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_name TEXT := COALESCE(NULLIF(TRIM(p_deleted_user_name), ''), 'مستخدم');
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  PERFORM public.fn_create_notification_once(
    v_admin_id,
    'تم حذف المستخدم بنجاح ✅',
    'اكتمل حذف حساب ' || v_name || ' وجميع البيانات المرتبطة به.',
    'admin_user_deleted',
    'user',
    p_deleted_user_id::TEXT,
    '/users',
    'admin',
    'high',
    30
  );

  INSERT INTO public.activity_logs (actor_id, actor_role, action, entity_type, entity_id, details)
  VALUES (
    v_admin_id,
    'admin',
    'admin_delete_user_confirmed',
    'user',
    p_deleted_user_id::TEXT,
    jsonb_build_object('deleted_user_name', v_name)
  );

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_notify_deletion_complete(UUID, TEXT) TO authenticated;
