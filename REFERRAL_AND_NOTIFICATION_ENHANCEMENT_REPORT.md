# Kasby Platform — Referral Code & Smart Notification Navigation Report

**Date:** 2026-06-11  
**Status:** Production-ready (pending Supabase migration apply)

---

## 1. Referral Code System Redesign

### Format Implemented

| Rule | Implementation |
|------|----------------|
| Prefix `K` | Enforced in `format_referral_code()` |
| Zero-padded 4 digits (K0001–K9999) | `LPAD(seq, 4, '0')` when seq ≤ 9999 |
| Expansion after 9999 | `K10000`, `K10001`, … (no padding) |
| Case-insensitive validation | `normalize_referral_code()` + Flutter `ReferralService.normalizeCode()` |
| Unique & concurrency-safe | Postgres `referral_code_seq` + `nextval()` in `generate_sequential_referral_code()` |
| DB sole source of truth | Client-side random generation removed |

### Safe Migration Strategy

- **No user records deleted**
- **No table recreation**
- **UUID referral relationships preserved** (`referred_by` / `referred_by_id` untouched)
- **Referral earnings, commissions, wallets unchanged**
- Only `profiles.referral_code` strings reassigned by `created_at` order
- Advisory lock (`pg_advisory_xact_lock`) during migration
- Sequence reset to `COUNT(profiles)` after migration

### Database Objects Modified

**Migration:** `supabase/migrations/20260611000002_referral_code_sequential_format.sql`

| Object | Action |
|--------|--------|
| `referral_code_seq` | Created |
| `format_referral_code(BIGINT)` | Created |
| `normalize_referral_code(TEXT)` | Created |
| `is_valid_referral_code_format(TEXT)` | Created |
| `generate_sequential_referral_code()` | Created |
| `resolve_referrer_by_code(TEXT)` | Created |
| `handle_new_user()` | Replaced — sequential codes, case-insensitive referrer lookup |
| `on_auth_user_created` trigger | Re-bound |
| `create_transfer()` | Updated — normalized case-insensitive lookup |
| `process_referral_commission()` | Updated — `COALESCE(referred_by_id, referred_by)` |
| `get_my_team()` | Updated — unified referrer column support |
| `profiles.referred_by_id` | Ensured + synced with `referred_by` |

### Flutter Files Modified (Referral)

| File | Change |
|------|--------|
| `lib/core/services/referral_service.dart` | `normalizeCode()`, `isValidFormat()`, removed client generation, dual-column link |
| `lib/features/auth/presentation/controllers/auth_controller.dart` | No client code generation; normalized validation |
| `lib/features/auth/presentation/views/register_view.dart` | Hint `K0001` |
| `lib/core/services/deep_link_service.dart` | Normalized referral extraction |
| `lib/core/models/profile_model.dart` | `referred_by` fallback |
| `lib/features/wallet/presentation/views/transfer_view.dart` | Normalized code before RPC |
| `test/models/profile_model_test.dart` | Fixture updated to `K0001` |

---

## 2. Smart Notification Navigation

### Architecture

```
Notification INSERT (DB)
    → trigger_generic_notification()
    → FCM payload { type, id, route, entity_type, entity_id, target_user_id, deep_link }
    → FCMService / AdminListenerService
    → NotificationNavigationService / AdminNotificationNavigationService
    → GetX route + arguments
```

### User App (`kasby`)

| State | Handler |
|-------|---------|
| Foreground FCM | Local notification shown; navigate **on tap only** |
| Background tap | `onMessageOpenedApp` → `NotificationNavigationService` |
| Cold start | `getInitialMessage()` + `processPendingNavigation()` after splash |
| Local notification tap | `onDidReceiveNotificationResponse` → JSON payload parse |
| In-app list tap | `HomeController.navigateFromNotification()` → router |
| Realtime snackbar tap | Routes to correct destination (single) or inbox (batch) |

**New file:** `lib/core/services/notification_navigation_service.dart`

### Admin App (`kasby_admin`)

| State | Handler |
|-------|---------|
| Realtime alerts | Route metadata in payload; snackbar + local notification tap |
| DB notifications (`role_target=admin`) | Dedicated realtime channel |
| FCM cold start / background | `getInitialMessage()` + `onMessageOpenedApp` |
| Local notification tap | `AdminListenerService` init handler |

**New file:** `lib/core/services/admin_notification_navigation_service.dart`

### Database Objects Modified

**Migration:** `supabase/migrations/20260611000003_notification_navigation_enhancement.sql`

| Object | Action |
|--------|--------|
| `resolve_notification_route()` | Created — type/deep_link → route for user & admin |
| `trigger_generic_notification()` | Updated — full FCM `data` payload |
| `on_notification_inserted` trigger | Created/re-bound on `notifications` |

### Flutter Files Modified (Notifications)

**User app:**
- `lib/core/models/notification_model.dart` — added `deepLink`, `entityType`, `entityId`, `roleTarget`
- `lib/core/services/fcm_service.dart` — cold start, tap-only navigation, JSON payloads
- `lib/core/services/notification_navigation_service.dart` — **new centralized router**
- `lib/features/home/presentation/controllers/home_controller.dart` — delegates to router
- `lib/features/splash/presentation/views/splash_view.dart` — pending navigation drain
- `lib/routes/app_pages.dart` — `supportChat` accepts `conversation_id`

**Admin app:**
- `lib/core/services/admin_notification_navigation_service.dart` — **new**
- `lib/core/services/admin_listener_service.dart` — routes, payloads, tap handlers, admin notification stream
- `lib/main.dart` — FCM cold start + background tap

### Notification Type Coverage

All DB constraint types mapped including: deposits, withdrawals, transfers, loans, investments, KSP/rewards, referral bonus, KYC, social, chat, agent, admin ops, announcements, system alerts. Unknown types fall back to `/notifications` (user) or `/notifications-list` (admin).

---

## 3. Validation Results

### Static Analysis

| App | Command | Result |
|-----|---------|--------|
| Kasby User | `flutter analyze` | **No issues found** |
| Kasby Admin | `flutter analyze` | **0 errors** (37 pre-existing info/warnings unrelated to this change) |

### Unit Tests

| Test | Result |
|------|--------|
| `test/models/profile_model_test.dart` | **8/8 passed** |

### Regression Checks (Code Review)

| Check | Status |
|-------|--------|
| Existing users migrated by `created_at` order | ✅ Migration SQL |
| Referral relationships (UUID) preserved | ✅ No FK changes |
| `referral_earnings` untouched | ✅ |
| Client no longer generates conflicting codes | ✅ |
| Concurrent signups use `nextval()` | ✅ |
| FCM no longer auto-navigates on foreground receive | ✅ |
| Duplicate navigation prevention | ✅ `_lastNavigationKey` |
| Deleted transaction graceful fallback | ✅ Returns null, skips broken nav |

---

## 4. Deployment Steps

1. **Apply migrations** to Supabase (in order):
   ```bash
   supabase db push
   ```
   Or apply manually:
   - `20260611000002_referral_code_sequential_format.sql`
   - `20260611000003_notification_navigation_enhancement.sql`

2. **Post-migration verification SQL:**
   ```sql
   -- Referral codes sequential
   SELECT referral_code FROM profiles ORDER BY created_at LIMIT 10;
   SELECT last_value FROM referral_code_seq;

   -- No duplicates
   SELECT referral_code, COUNT(*) FROM profiles GROUP BY referral_code HAVING COUNT(*) > 1;

   -- Referral relationships intact
   SELECT COUNT(*) FROM profiles WHERE referred_by_id IS NOT NULL OR referred_by IS NOT NULL;

   -- Trigger exists
   SELECT tgname FROM pg_trigger WHERE tgname = 'on_notification_inserted';
   ```

3. **Notify users** that old referral code strings (e.g. `K-XXXXX`) are replaced; invite links need re-sharing.

4. **Rebuild & deploy** both Flutter apps.

---

## 5. Production Readiness

| Area | Status |
|------|--------|
| Referral migration safety | ✅ Production-safe |
| Backend/frontend sync | ✅ Complete |
| Notification routing (user) | ✅ Foreground/background/cold-start |
| Notification routing (admin) | ✅ Realtime + FCM + local tap |
| Static analysis (user) | ✅ Clean |
| Unit tests | ✅ Passing |
| DB migration apply | ⏳ Required before live |

**Overall:** Ready for production after applying the two Supabase migrations and redeploying both apps.
