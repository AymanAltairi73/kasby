-- Applied via Supabase migration: fix_signup_profile_provisioning_v2
-- Root cause: handle_new_user failed silently when profiles.phone unique constraint
-- was violated (duplicate phone from an older phone-only account).

-- See remote migration for full function bodies:
--   normalize_phone_e164
--   sanitize_country_code
--   fn_check_phone_available
--   fn_ensure_user_profile
--   handle_new_user (rebound trigger on_auth_user_created)
