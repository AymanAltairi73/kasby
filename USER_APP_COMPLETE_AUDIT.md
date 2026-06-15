# Kasby User App — Complete End-to-End Production Audit

**Audit Date**: June 10, 2026  
**App Version**: 1.0.0+1  
**Flutter SDK**: ^3.9.0  
**Total Files Audited**: 105 Dart files (full lib/ codebase)  
**Total Issues Found**: 190+  
**Production Readiness Score**: 38/100

---

## Table of Contents

1. [Application Overview](#1-application-overview)
2. [Screen-by-Screen Verification](#2-screen-by-screen-verification)
3. [Data Loading Verification](#3-data-loading-verification)
4. [Supabase Backend Verification](#4-supabase-backend-verification)
5. [Business Flow Verification](#5-business-flow-verification)
6. [UI Verification](#6-ui-verification)
7. [Performance Report](#7-performance-report)
8. [Runtime Validation](#8-runtime-validation)
9. [Security Observations](#9-security-observations)
10. [Dead Code Report](#10-dead-code-report)
11. [Bugs Found](#11-bugs-found)
12. [Missing Implementations](#12-missing-implementations)
13. [Improvement Roadmap](#13-improvement-roadmap)

---

## 1. Application Overview

### Architecture
- **Pattern**: Feature-based Clean Architecture + GetX (routing, state, DI)
- **Backend**: Supabase (PostgreSQL + Realtime + Auth + Edge Functions + Storage)
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Default Locale**: Arabic (`ar_SA`), with English (`en_US`) support
- **Theme**: Dark/Light mode with reactive switching

### Feature Modules (10 total)
| Module | Screens | Responsibility |
|--------|---------|----------------|
| `auth` | 5 views | Login, register, OTP, phone auth, forgot password |
| `home` | 7 views | Dashboard, notifications, spin wheel, daily check-in, subscription, KSP wallet |
| `investment` | 3 views | Plans, details, my investments |
| `onboarding` | 1 view | First-run onboarding |
| `profile` | 9 views | Profile, KYC, social network, agent dashboard, team, legal, support |
| `qr_payment` | 2 views | QR scanner, my QR |
| `splash` | 1 view | Splash screen |
| `support` | 1 view | Support/social/agent chat |
| `wallet` | 6 views | Wallet, deposit, withdraw, transfer, loan, agents, transactions |
| `routes` | 2 files | 42 registered GetPage routes |

### Dependencies
36 runtime packages including `supabase_flutter ^2.8.4`, `get ^4.7.3`, `firebase_core ^3.11.0`, `firebase_messaging ^15.2.10`, `mobile_scanner ^6.0.4`, `local_auth ^2.3.0`, `pdf ^3.11.1`.

### Supabase Backend
- **9 incremental migrations** (base schema predates these)
- **7 edge functions** (admin-proxy, send-otp, send-otp-hardened, verify-otp, reset-password-secure, secure-profile-update, send-fcm)
- **12 RPC functions** defined in migrations
- **2 active triggers** on chat_messages and chat_conversations
- **9 RLS policies** covering chat and OTP tables
- **6 indexes** across phone_otps, chat_messages, profiles

---

## 2. Screen-by-Screen Verification

### 2.1 Splash Screen (`splash_view.dart` — 107 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| UI Render | PARTIAL | Logo commented out, only text + spinner shown |
| Loading State | PASS | CircularProgressIndicator shown during auth check |
| Empty State | N/A | — |
| Error State | FAIL | No timeout/fallback if auth check hangs forever |
| Navigation | FAIL | Race condition: `ever()` + `addPostFrameCallback` can both fire `_navigateToNext()` |
| Lifecycle | FAIL | `ever()` listener never disposed — can navigate after widget disposal |
| Memory Safety | FAIL | `_controller.lastElapsedDuration` unreliable for delay calculation |

**Critical Bugs**:
- Double navigation race condition between `ever()` listener and `addPostFrameCallback`
- Splash hangs indefinitely if `AuthController._checkInitialSession()` throws and `authStatus` never updates
- No `mounted` check before scheduling `Future.delayed` navigation

### 2.2 Onboarding Screen (`onboarding_view.dart` — 167 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| UI Render | PARTIAL | No SafeArea — content clips behind status bar on notched phones |
| Navigation | FAIL | Uses `Get.offNamed` instead of `Get.offAllNamed` — leaves route on stack |
| Persistence | FAIL | No onboarding completion flag — always shown after logout |
| Localization | PASS | Language toggle button present |
| RTL | PARTIAL | Language toggle at `top: 50` may overlap notch in RTL |

**Issues**:
- No "Skip" button for onboarding pages
- `AppColors.textSecondary` used without theme awareness

### 2.3 Login Screen (`login_view.dart` — 173 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| UI Render | FAIL | No SafeArea |
| Validation | FAIL | No `validator` on form fields — validation always passes |
| Controller | FAIL | `Get.put(AuthController())` creates duplicate instance |
| Phone Login | FAIL | No `CountrySelector` widget — user can't select country code |

### 2.4 Registration Screen (`register_view.dart` — 267 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| UI Render | FAIL | No SafeArea |
| Validation | FAIL | No confirm password field |
| Controller | FAIL | Same duplicate `Get.put(AuthController())` issue |
| Referral | FAIL | Debounce is broken — creates new `RxString` each keystroke |
| UI Bug | FAIL | Referral spinner clipped (padding > SizedBox dimensions) |

### 2.5 OTP Screen (`otp_view.dart` — 407 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| UI Render | PARTIAL | Fixed-width boxes (46px × 6) may overflow on narrow screens |
| Auto-verify | FAIL | FCM auto-fill and manual entry can both call `_verifyOtp()` simultaneously |
| Loading State | FAIL | Local `_isLoading` vs `AuthController.isLoading` inconsistency |
| Paste Support | FAIL | No OTP paste support for 6-digit codes |
| Missing | N/A | `@override` annotation missing on `build` method |

### 2.6 Forgot Password Screen (`forgot_password_view.dart` — 240 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| UI Render | PASS | Clean two-method selection with animated transitions |
| Validation | FAIL | No form validator on email/phone fields |
| Legacy OTP | FAIL | `verifyPasswordResetOTP` is a no-op (does nothing) |

### 2.7 Dashboard / Home Screen (`home_view.dart` — 1733 lines, `main_shell_view.dart` — 233 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| UI Render | PARTIAL | Balance card glow orbs overflow with negative offsets |
| Loading State | PARTIAL | No overall dashboard loading skeleton — shows $0.00 during load |
| Error State | FAIL | `hasError` flag declared but never rendered in UI |
| Pull-to-refresh | PASS | `RefreshIndicator` present |
| Navigation | FAIL | "Investments" quick action navigates to `/subscription` (wrong destination) |
| Performance | FAIL | `_FloatingActionMasterpiece` rotating animation never pauses |
| Architecture | FAIL | Portfolio distribution logic (gold/silver/real estate) in View, not Controller |
| Controller | FAIL | `HomeController` is 948 lines — God Controller managing 10+ concerns |

### 2.8 Wallet Screen (`wallet_view.dart` — 1017 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| UI Render | PARTIAL | Hardcoded fake card number `4589 **** **** 8892` displayed |
| Balance | FAIL | `totalBalance` variable actually holds `availableBalance` — naming mismatch |
| Error State | FAIL | No error state for transaction loading failure |
| Frozen Wallet | FAIL | `WalletModel.isFrozen` never checked — frozen wallets fully operable |
| Performance | FAIL | Gradient animation runs continuously even off-screen |
| Type Mismatch | FAIL | `tx.type == 'withdraw'` vs `'withdrawal'` inconsistency affects amount sign display |

### 2.9 Deposit Screen (`deposit_view.dart` — 447 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Validation | FAIL | No maximum deposit limit, no KYC gate |
| Security | FAIL | No biometric/PIN authentication before deposit |
| Idempotency | FAIL | Timestamp-based key instead of UUID — collision risk |
| Agent Fetch | FAIL | Error silently swallowed — user sees "No agents" with no retry |
| Post-success | FAIL | No balance refresh after successful deposit |
| UI | FAIL | Nested redundant `Obx` in agent selector |

### 2.10 Withdrawal Screen (`withdraw_view.dart` — 580 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Fee Display | FAIL | Hardcoded `$0.00` fee — will be wrong if fees are introduced |
| Notes Field | FAIL | User can type notes but they're never sent to server RPC |
| Max Amount | FAIL | No maximum withdrawal limit validation |
| UI | FAIL | Nested redundant `Obx` in agent selector (same as deposit) |

### 2.11 Transfer Screen (`transfer_view.dart` — 598 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Recipient | FAIL | No pre-transfer recipient verification/name preview |
| Idempotency | FAIL | No idempotency key sent to `create_transfer` RPC |
| Points | FAIL | Fractional points (0.5 KSP) accepted — should be integers |
| Navigation | FAIL | `Get.back()` × 2 after bottom sheet — can pop unintended routes |
| Localization | FAIL | Uses `deposit_amount` translation key for transfer amount field |

### 2.12 All Transactions Screen (`all_transactions_view.dart` — 635 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Date Logic | FAIL | "Yesterday" detection broken on 1st of month (`now.day - 1 = 0`) |
| Pagination | FAIL | `hasMoreTransactions` logic flawed for "all" filter |
| Filter | FAIL | `'withdrawal'` vs `'withdraw'` type mismatch with wallet view |
| Time Format | FAIL | 24-hour without hour padding (inconsistent with wallet view's 12-hour) |

### 2.13 Transaction Details Screen (`transaction_details_view.dart` — 852 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Date Format | FAIL | Manual `day/month/year` without zero-padding |
| Code Quality | FAIL | `_getTypeInfo` and `_getStatusInfo` duplicated across 2 files |

### 2.14 Investment Plans Screen (`investment_plans_view.dart` — 148 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Duration | FAIL | Hardcoded `30_months_2_5_years` regardless of plan's actual `durationDays` |
| Language | FAIL | Always shows Arabic plan names (`plan.nameAr`) regardless of locale |
| Profit % | FAIL | Truncated to `int` — 7.5% displays as 7% |

### 2.15 Investment Details Screen (`investment_details_view.dart` — 474 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Validation | FAIL | No minimum/maximum amount validation against plan bounds |
| Referral | FAIL | Commission processed client-side — not atomic with investment |
| Navigation | FAIL | `Get.offAllNamed('/home')` destroys entire navigation stack |
| Dropdown | FAIL | Value mismatch risk if `amountController.text` changes independently |

### 2.16 My Investments Screen (`my_investments_view.dart` — 413 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Daily Profit | FAIL | Client-side calculation hardcodes 30-day month |
| Plan Names | FAIL | No join — `inv.investment` is always null in active tab |
| Code Quality | FAIL | `_InvestmentPlansList` duplicates entire `InvestmentPlansView` |

### 2.17 Loan Screen (`loan_view.dart` — 1108 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Interest Rate | FAIL | Hardcoded 10% per month (120% APR) regardless of server config |
| Dead Toggle | FAIL | `receiveAsPoints` toggle has no effect — never sent to RPC |
| Active Loans | FAIL | No check for existing active loans before new application |
| Theme | FAIL | Full repayment dialog hardcodes dark theme colors |
| Repayment | FAIL | No minimum repayment amount — user can repay $0.01 |
| State Management | FAIL | Mixed `Obx` reactive and `setState` in same widget |

### 2.18 Subscription Screen (`subscription_view.dart` — 525 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Plans | FAIL | Subscription plans/prices entirely hardcoded in UI — no server fetch |
| Upgrade | FAIL | No upgrade/downgrade flow — blocked by generic warning dialog |
| Toggle | FAIL | Yearly/monthly toggle compares against translated string — breaks on locale |
| Commission | FAIL | Hardcoded $89/$9 prices for referral commission |
| Payment | FAIL | No payment method selection specified |

### 2.19 KSP Wallet Screen (`ksp_wallet_view.dart` — 561 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| USD Conversion | FAIL | Line 519 uses `amount / 1000` directly instead of `KspConverter.kspToUsd()` |
| Pagination | FAIL | Hardcoded `limit(50)` with no "load more" |
| Date Format | FAIL | Raw `day/month/year` without locale-aware formatting |

### 2.20 Spin Wheel Screen (`spin_wheel_view.dart`)

| Aspect | Status | Details |
|--------|--------|---------|
| Timer Leak | FAIL | `_countdownTimer` never cancelled in `dispose()` |
| Performance | FAIL | `shouldRepaint` always returns `true` in `WheelPainter` |
| UX | FAIL | No confirmation dialog before buying spin bundles |

### 2.21 Daily Check-In Screen (`daily_check_in_view.dart`)

| Aspect | Status | Details |
|--------|--------|---------|
| Streak Display | FAIL | Visual capped at 7 circles — streaks >7 look identical to day 7 |
| Pagination | FAIL | History hardcoded to `limit(14)` |
| Server Time | PASS | Server-side time validation via RPCs |

### 2.22 Chat Screen (`support_chat_view.dart` — 1590 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Memory | FAIL | `.stream()` fetches ALL messages on every change — unbounded growth |
| Reconnect | FAIL | No backoff — old subscription never cancelled before re-subscribing |
| Typing | FAIL | Global `chat_typing` channel — all users see all typing events |
| Edit | FAIL | Edit UI exists but send always creates new message (no UPDATE call) |
| Dead Code | FAIL | `_listenToConversation()` does nothing useful, wastes Realtime slot |
| Quick Actions | FAIL | Hardcoded Arabic strings, not using `.tr` |
| Reactions | FAIL | No tracking of who reacted — only emoji existence tracked |

### 2.23 Notifications Screen (`notifications_view.dart` — 239 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Pagination | FAIL | Hardcoded `limit(50)`, no "load more" |
| iOS | FAIL | Foreground notifications never shown (Android guard blocks iOS) |
| Tap Handler | FAIL | Not all notification types have navigation handlers |
| Scheduling | FAIL | `Future.delayed` for scheduling — won't fire if app killed |

### 2.24 Social Network / Friends Screen (`social_network_view.dart` — 830 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| State | FAIL | All state in StatefulWidget — lost on navigation |
| Realtime | FAIL | No realtime updates for friend requests |
| Search | FAIL | Local filter only — no server-side user search |
| Deep Links | FAIL | Shared URL `https://kasby.app/join?ref=CODE` has no handler |
| Arabic | FAIL | Hardcoded Arabic strings in snackbar and share text |

### 2.25 Profile Screen (`profile_view.dart` — 675 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Logout | FAIL | `Get.offAllNamed(Routes.login)` without calling `HomeController.clearData()` |
| Avatar | FAIL | Raw `NetworkImage` without caching (inconsistent with home) |
| Delete | FAIL | No "Delete Account" feature — Apple App Store requirement |

### 2.26 Edit Profile Screen (`edit_profile_view.dart` — 578 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Error Messages | FAIL | Hardcoded Arabic error strings bypass i18n |
| Controller | FAIL | `Get.put()` in `initState` — could fail if already registered |

### 2.27 KYC Screen (`kyc_view.dart` — 597 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Arabic | FAIL | Hardcoded Arabic error strings |
| Routes | FAIL | Uses raw string `'/home'` instead of `Routes.home` |
| Lifecycle | FAIL | `dobController` never disposed in `onClose()` |

### 2.28 Change Password Screen (`change_password_view.dart` — 313 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Security | FAIL | Non-recovery mode doesn't verify current password |

### 2.29 QR Scanner Screen (`qr_scanner_view.dart` — 237 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Overlay | FAIL | Blend mode `dstOut` doesn't create proper scanner cutout |
| Validation | FAIL | No QR timestamp validation — expired codes accepted indefinitely |
| Route | FAIL | Hardcoded `'/transfer'` string instead of `Routes.transfer` |

### 2.30 My QR Screen (`my_qr_view.dart` — 182 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Share/Save | FAIL | Buttons are placeholders with empty `onPressed` callbacks |
| Amount | FAIL | No min/max validation on amount field |

### 2.31 Presence Service (`presence_service.dart` — 123 lines)

| Aspect | Status | Details |
|--------|--------|---------|
| Scalability | FAIL | Single `global-presence` channel for all users |
| Lifecycle | FAIL | Leave+join on every app resume — floods channel |
| DB Writes | FAIL | `fn_update_last_seen` called on every lifecycle pause |

---

## 3. Data Loading Verification

### Supabase Operations Catalog

| Feature | Table/View | RPC | Realtime | Issues |
|---------|------------|-----|----------|--------|
| Auth | `auth.users`, `profiles` | `recover_account_by_email`, `admin_reset_password_with_otp` | `onAuthStateChange` | Dual navigation on login/register |
| Wallet | `wallets` | — | `.stream()` on wallets | `totalBalance` = `availableBalance` naming mismatch |
| Deposit | `transactions` | `fn_create_deposit_request` | — | Timestamp idempotency, no balance refresh after success |
| Withdrawal | `transactions` | `create_withdrawal` | — | Notes field never sent, inconsistent RPC naming (`fn_` prefix) |
| Transfer | `transactions` | `create_transfer` | — | No idempotency key |
| Transactions | `transactions`, `point_history` | — | `.stream()` on transactions | Merge pagination logic flawed |
| Investments | `investment_plans`, `user_investments` | `create_investment`, `claim_rewards` | `.stream()` on user_investments | No join in active tab, client-side commission |
| Loans | `loans`, `loan_repayments` | `create_loan`, `repay_loan` | None | No realtime updates |
| Subscriptions | `subscriptions` | `activate_free_plan`, `buy_subscription` | None | No realtime, plans hardcoded in UI |
| KSP | `user_points`, `point_history` | — | `.stream()` on user_points | Inconsistent USD conversion |
| Spin Wheel | `spin_wheel_rewards` | `spin_wheel`, `buy_spins_bundle` | — | Timer leak on dispose |
| Daily Check-In | `daily_check_ins` | `daily_check_in`, `get_check_in_status` | — | Pagination hardcoded |
| Chat | `chat_conversations`, `chat_messages` | `fn_send_chat_message`, `fn_mark_messages_read`, `fn_mark_messages_delivered` | `.stream()` on messages | Full table sync on every change |
| Notifications | `notifications` | `fn_create_notification` | `.stream()` on notifications | Reconnection without backoff |
| Friends | — | `get_friend_requests`, `get_friends`, `get_friend_suggestions`, `accept_friend_request`, etc. | None | No realtime, local state only |
| Profile | `profiles` | — | Partial (via auth) | Avatar not cached consistently |
| KYC | `profiles` (kyc fields), Storage buckets | — | — | Hardcoded Arabic errors |
| Presence | `profiles.last_seen_at` | `fn_update_last_seen` | Supabase Presence channel | Single global channel |
| Dashboard | `v_user_dashboard` | — | None | Stale values until manual refresh |
| Agents | `agents`, `profiles` | — | None | Complex fallback logic in model |

### Field Mapping Issues

| Model | Issue |
|-------|-------|
| `WalletModel` | `double` for currency — floating-point precision loss |
| `TransactionModel` | `type` is raw string with no enum validation |
| `AgentModel` | `.tr` called inside `fromJson()` — side effect in model layer |
| `NotificationModel` | `toJson()` omits `id`, `sent_at`, `read_at` |
| `LoanModel` | `repaymentDate` defaults to `DateTime.now()` on null — hides data issues |
| `UserInvestmentModel` | `copyWith` missing `investment` and `createdAt` |
| All Models | No `==` / `hashCode` overrides — identity issues in collections |

### Null Handling Issues

| Location | Issue |
|----------|-------|
| `SupabaseService.userId!` | Force-unwrap after `isLoggedIn` check — race condition risk |
| `LoanModel.id` | Defaults to empty string on null instead of throwing |
| `DashboardModel` | No `toJson`, `copyWith`, or equality |
| `SocialNetworkView` | RPC response cast `as Map<String, dynamic>` without null check |

---

## 4. Supabase Backend Verification

### Migration Coverage

| Migration | Objects | Status |
|-----------|---------|--------|
| `20260312000000_phone_otps` | 2 tables, 2 RPCs, 2 indexes, 2 RLS policies | Applied |
| `20260324000000_recover_account_rpc` | 1 RPC | Applied |
| `20260324000001_admin_reset_password_with_otp` | 1 RPC + pgcrypto extension | Applied |
| `20260605000000_remediation_and_stabilization` | Private schema, secrets, chat triggers, notification RPCs | Applied |
| `20260607000000_chat_read_delivered_presence` | 2 RPCs, 3 indexes, column alterations | Applied |
| `20260610000000_revoke_public_admin_functions` | Permission revocation only | Applied |
| `20260610000001_add_idempotency_to_financial_rpcs` | 2 RPC replacements | Applied |
| `20260610000002_chat_send_message_rpc` | 1 RPC, 1 index, 2 RLS policies | Applied |
| `20260610000003_drop_duplicate_fn_send_chat_message` | 1 RPC replacement, 1 RLS policy | Applied |

### Key Backend Concerns

1. **Base schema not in migrations** — The original master SQL (`KASBY_MASTER_PRODUCTION_V5.sql`) was deleted from the repo. Tables like `profiles`, `wallets`, `transactions`, `loans`, `investments`, `notifications` etc. are referenced but their creation schema is not version-controlled.
2. **Two OTP systems coexist** — Older `phone_otps` table + `check_otp_rate_limit` vs. newer `otp_verifications` used by edge functions. `admin_reset_password_with_otp` uses `phone_otps`; hardened OTP flow uses `otp_verifications`.
3. **`send-otp` and `verify-otp` have `verify_jwt = false`** in config.toml — These functions are publicly accessible without authentication.
4. **Edge function `send-otp` (legacy)** — Uses direct Resend API and FCM but lacks the hardening of `send-otp-hardened`. Both coexist.
5. **No seed files under `supabase/`** — Archived seeds exist at `kasby/sql/archive/` but aren't wired into Supabase CLI.
6. **RLS policies only cover chat and OTP tables** — Other tables (transactions, wallets, profiles, loans, investments, subscriptions, notifications) either have RLS defined in the missing base schema or lack RLS entirely.

### Edge Function Security

| Function | Auth | Issues |
|----------|------|--------|
| `admin-proxy` | JWT + admin role check | Good — properly validates caller is admin |
| `send-otp` | No JWT required | Rate limiting via RPC, but endpoint is public |
| `send-otp-hardened` | Optional JWT | Better — OTP never in HTTP response, sent via FCM |
| `verify-otp` | API key only | Rate limited (15 attempts/15 min) |
| `reset-password-secure` | No JWT | Relies on OTP verification for authorization |
| `secure-profile-update` | JWT required | Good — validates session token |
| `send-fcm` | Multiple auth methods | Good — service_role or FCM_SECRET or valid JWT |

---

## 5. Business Flow Verification

### Authentication Flow

```
Login View → AuthController.login() → Supabase signInWithPassword → onAuthStateChange → Navigate to Home
```

**Issues Found**:
- `login()` navigates to home AND `_listenToAuthChanges()` also navigates on `signedIn` — **double navigation race**
- Same issue on registration — `register()` and auth listener both navigate
- `LoginView` and `RegisterView` both call `Get.put(AuthController())` creating **duplicate instances**
- Phone login has no `CountrySelector` widget — user can't select/see country code
- No email confirmation check after `signUp` — user lands on home without confirmed email
- Logout clears some state but not all (`FCMService.fcmToken`, profile state, currency state)

### Wallet Operations Flow

```
Wallet UI → [deposit/withdraw/transfer] → Supabase RPC → Transaction record → Balance update → UI refresh
```

**Issues Found**:
- Frozen wallet state (`isFrozen`) never checked before operations
- Deposit: timestamp-based idempotency key, no KYC check, no max limit, no balance refresh
- Withdrawal: notes field silently discarded, fee hardcoded as $0.00
- Transfer: no idempotency key, no recipient name preview, fractional points accepted

### Investment Flow

```
Investment Plans → Select Plan → Enter Amount → create_investment RPC → processReferralCommission (client-side) → Navigate Home
```

**Issues Found**:
- No min/max amount validation against plan bounds
- Referral commission processed client-side (not atomic — can fail silently after investment succeeds)
- Hardcoded duration display regardless of plan's actual `durationDays`
- Daily profit calculated client-side with hardcoded 30-day month

### Loan Flow

```
Loan View → Enter Amount → create_loan RPC → Wait for Admin Approval → repay_loan RPC
```

**Issues Found**:
- Interest rate hardcoded at 10% per month regardless of `LoanModel.interestRate`
- `receiveAsPoints` toggle is dead code — never sent to server
- No check for existing active loans before new application
- No minimum repayment amount — $0.01 partial repayment possible

### Chat Flow

```
Chat View → SupportChatController → fn_send_chat_message RPC → DB Trigger (unread counter, push notification) → Realtime stream → UI update
```

**Issues Found**:
- Message stream fetches entire conversation on every change (unbounded growth)
- Typing indicator uses global channel — all users see all typing events
- Edit message UI is broken (no UPDATE call — always creates new message)
- Reconnection has no backoff — can create duplicate listeners

### KSP / Rewards Flow

```
Daily Check-In / Spin Wheel / Investment → KSP earned → user_points updated → Realtime stream → KSP balance UI
```

**Issues Found**:
- Inconsistent USD conversion (`amount / 1000` in some places vs `KspConverter.kspToUsd()` in others)
- Referral code generation has no uniqueness check
- Client-side aggregation for total referral earnings (loads all rows)

---

## 6. UI Verification

### Loading States

| Screen | Loading State | Status |
|--------|--------------|--------|
| Splash | CircularProgressIndicator | PASS |
| Home | Shimmer on balance card | PARTIAL — no overall skeleton |
| Wallet | Shimmer + loading flag | PARTIAL — no error state |
| Transactions | Loading indicator | PASS |
| Chat | Loading indicator | PASS |
| Investments | Loading indicator | PASS |
| Loan | Loading indicator | PASS |
| KSP Wallet | Loading indicator | PASS |
| Notifications | Loading indicator | PASS |
| Friends | Loading indicator | PASS |

### Empty States

| Screen | Empty State | Status |
|--------|------------|--------|
| Transactions | EmptyStateWidget | PASS |
| Chat | Empty message widget | PASS |
| Investments | Empty state text | PASS |
| Notifications | "No notifications" text | PARTIAL |
| Friends | "No friends" text | PARTIAL |
| Loan History | Empty text | PARTIAL |

### Error States

| Screen | Error State | Status |
|--------|------------|--------|
| All Screens | Generic | FAIL — most screens have no error UI |
| Home Dashboard | `hasError` flag exists | FAIL — never rendered |
| Wallet | — | FAIL — no error state |
| Chat | Reconnect on error | PARTIAL — no user-visible error |

### Localization Issues

| Issue | Count | Details |
|-------|-------|---------|
| Hardcoded Arabic strings | 15+ | Scattered across social network, chat, KYC, edit profile, connectivity banner |
| Missing Arabic translations | ~50 | `en_US` has ~1112 keys, `ar_SA` has ~1057 keys |
| Wrong translation keys | 2 | `deposit_amount` used for transfer, `كود الاحالة` not using `.tr` |
| Translation file size | — | 2169 lines in single monolithic file |

### RTL Support

- Default locale is Arabic (`ar_SA`) with Material RTL delegates
- `ConnectivityBanner` explicitly sets `TextDirection.rtl`
- Most layouts use `Column`/`ListView` which auto-handle RTL
- **Risk areas**: `Positioned` widgets with hardcoded left/right offsets, `Row` children order

### Responsive Design

- No explicit responsive breakpoints
- Fixed-width widgets risk overflow on narrow screens (<320px): OTP boxes (276px), card numbers
- `Stack` with `Positioned` elements use absolute positioning that breaks on different screen sizes
- No tablet layout considerations

### Widget Issues

| Widget | Issue |
|--------|-------|
| `KasbyButton` | Disabled state not accessible to screen readers (screen reader can't detect disabled) |
| `KasbyCard` | `.animate()` on every build — retriggered animations on rebuilds |
| `EmptyStateWidget` | `Lottie.network` without caching or error timeout |
| `InvestmentPlanCard` | `Image.asset` with no error builder — crashes on missing asset |
| `TransactionReceipt` | PDF generation on UI thread — should use `compute()` |
| `CountrySelector` | Completely broken in light mode — hardcoded white text on light backgrounds |
| `ConnectivityBanner` | Uses deprecated `withOpacity()` |

---

## 7. Performance Report

### Database Query Performance

| Issue | Impact | Location |
|-------|--------|----------|
| `fetchAll()` fires 10 parallel Supabase queries on every app resume | HIGH | `home_controller.dart:351-362` |
| `fetchTotalReferralEarnings()` loads all rows, sums client-side | MEDIUM | `referral_service.dart:154` |
| Chat `.stream()` fetches full message table on every change | HIGH | `support_chat_controller.dart:325-355` |
| No API response caching | MEDIUM | All screens hit network on every visit |
| Points + money transactions merged creates unbounded list growth | MEDIUM | `home_controller.dart` |

### Widget Rebuild Performance

| Issue | Impact | Location |
|-------|--------|----------|
| Two per-second `Timer.periodic` running continuously | HIGH | `HomeController` + `SubscriptionController` |
| `_FloatingActionMasterpiece` rotating animation never pauses | MEDIUM | `home_view.dart:1637-1731` |
| Gradient animation controller runs indefinitely even off-screen | MEDIUM | `wallet_view.dart:32-37` |
| `WheelPainter.shouldRepaint` always returns `true` | MEDIUM | `spin_wheel_view.dart` |
| `.animate()` on every transaction list item | LOW | Multiple views |
| Nested redundant `Obx` in deposit/withdraw agent selectors | LOW | `deposit_view.dart`, `withdraw_view.dart` |

### Network Request Performance

| Issue | Impact |
|-------|--------|
| NetworkService speed-checks `8.8.8.8:53` every 30 seconds | MEDIUM — battery drain |
| No connection pooling or request deduplication | LOW |
| No retry with exponential backoff on failures | MEDIUM |
| No request timeout on Supabase calls | MEDIUM |

### Memory Usage

| Issue | Impact | Location |
|-------|--------|----------|
| Chat message stream unbounded growth | HIGH | `support_chat_controller.dart` |
| `_messageKeys` map grows indefinitely | MEDIUM | `support_chat_view.dart:32` |
| `NotificationService` AudioPlayer never disposed | LOW | `notification_service.dart` |
| `AppSnack.otp()` creates new AudioPlayer each call | LOW | `snack_service.dart` |
| Animation controllers not disposed properly | MEDIUM | Multiple views |

### Application Startup

| Step | Concern |
|------|---------|
| Firebase.initializeApp | Blocking |
| FCM Service init (async) | Blocking |
| Network Service init (async) | Blocking |
| Presence Service init (async) | Blocking |
| 6+ controllers eagerly registered | HIGH — increases startup memory footprint |
| No lazy loading for non-essential services | MEDIUM |

---

## 8. Runtime Validation

### Potential Runtime Exceptions

| Location | Exception Risk | Severity |
|----------|----------------|----------|
| `SupabaseService.userId!` | NullPointerException on auth race condition | HIGH |
| `SocialNetworkView` RPC response cast | TypeError on unexpected response | HIGH |
| `InvestmentPlanCard` Image.asset | Asset not found crash | MEDIUM |
| `AgentModel.fromJson()` calling `.tr` | Crash if GetX not initialized | HIGH |
| `ShellController` `Get.context!` | Null context | MEDIUM |
| OTP boxes on narrow screens | RenderBox overflow | LOW |

### Stream Leak Risks

| Location | Risk | Details |
|----------|------|---------|
| Splash `ever()` listener | HIGH | Never disposed |
| Chat `_messageSubscription` | HIGH | Old subscription not cancelled before reconnect |
| Notification stream reconnect | MEDIUM | Multiple delayed callbacks can stack up |
| `_listenToConversation()` | LOW | Dead listener wastes Realtime connection |
| `FCMService.onTokenRefresh` | LOW | Subscription never stored/cancelled |
| Presence channel | MEDIUM | Leave+join on every app resume |

### Duplicate Subscription Risks

| Location | Risk |
|----------|------|
| Wallet stream + fetchRecentTransactions both fire on init | Redundant DB reads |
| Two per-second timers (Home + Subscription) | Unnecessary rebuilds |
| Auth listener + manual navigation both fire on login | Double navigation |
| Chat message stream + paginated fetch overlap | Duplicate data rendering |

---

## 9. Security Observations

### Critical Security Issues

| # | Issue | Location | Impact |
|---|-------|----------|--------|
| 1 | **`double` for financial calculations** — floating-point precision loss can cause incorrect amounts | All financial models/controllers | Money calculation errors |
| 2 | **No crash reporting** (Sentry, Crashlytics) — production errors invisible | Missing entirely | Blind to production issues |
| 3 | **Tokens stored in SharedPreferences** (unencrypted) instead of flutter_secure_storage | Session management | Token theft on rooted devices |
| 4 | **Frozen wallet not enforced** — UI allows all operations on frozen wallets | `wallet_view.dart` | Financial operations on restricted accounts |
| 5 | **RLS policies missing for base tables** — only chat and OTP tables have documented RLS | Missing base schema | Potential unauthorized data access |
| 6 | **`send-otp` and `verify-otp` have `verify_jwt = false`** | `config.toml` | Public OTP endpoint (rate-limited but exposed) |

### High Security Issues

| # | Issue | Location |
|---|-------|----------|
| 7 | Client-side referral commission processing — not atomic with investment/subscription | `investment_details_view.dart`, `subscription_controller.dart` |
| 8 | No QR timestamp validation — expired QR codes accepted forever | `qr_payment_controller.dart` |
| 9 | `Future.delayed` for notification scheduling — unreliable delivery | `fcm_service.dart` |
| 10 | Password change without current password verification | `change_password_view.dart` |
| 11 | No biometric/PIN required for deposits | `deposit_view.dart` |
| 12 | Typing channel broadcasts globally — privacy leak | `support_chat_controller.dart` |
| 13 | Diagnostic code lists all storage buckets on upload failure | `support_chat_controller.dart:526-531` |
| 14 | PII logged in debug console (user ID, email, phone, profile data) | `auth_controller.dart`, `home_controller.dart` |

### Medium Security Issues

| # | Issue |
|---|-------|
| 15 | No max deposit/transfer limits (client-side) |
| 16 | Loan eligibility computed client-side — bypassable |
| 17 | Session service allows biometric bypass on unsupported devices |
| 18 | No rate limiting on login attempts (client-side) |
| 19 | Transfer idempotency key missing |
| 20 | Deposit idempotency uses timestamp instead of UUID |
| 21 | Chat messages stored unencrypted in SharedPreferences |
| 22 | `anon key` used as fallback bearer token in ProfileUpdateController |

---

## 10. Dead Code Report

| File | Dead Code | Impact |
|------|-----------|--------|
| `otp_service.dart` | 3 `@Deprecated` methods (lines 172-215) | LOW — should be removed |
| `app_pages.dart` | Commented-out `ServicesView` import and route | LOW |
| `ksp_converter.dart` | `pointsToKsp()` and `kspToPoints()` identity functions | LOW |
| `spin_reward_model.dart` | `defaultRewards` static list (superseded by DB) | LOW |
| `chat_storage_service.dart` | Entire service unused — controller never calls its methods | MEDIUM |
| `support_controller.dart` | `unreadCount` disconnected from actual Supabase tracking | MEDIUM |
| `_listenToConversation()` | Only sets `isTyping = false` — dead listener | LOW |
| `loan_view.dart` | `receiveAsPoints` toggle — never sent to RPC | MEDIUM |
| `withdraw_view.dart` | `_notesController` — collected but never sent | MEDIUM |
| `home_view.dart` | `_buildProofOfTrust` section entirely commented out | LOW |
| `verifyPasswordResetOTP` | Method is a no-op (sets loading then immediately clears) | HIGH |
| `supabase_service.dart` | Unused `import 'dart:io'` on web target | LOW |

### Unused Routes
- `services` route defined in `app_routes.dart` but commented out in `app_pages.dart`

### Duplicate Code
- `_getTypeInfo()` / `_getStatusInfo()` duplicated in `all_transactions_view.dart` and `transaction_details_view.dart`
- `_InvestmentPlansList` in `my_investments_view.dart` duplicates `InvestmentPlansView`
- Agent selector with nested `Obx` duplicated in `deposit_view.dart` and `withdraw_view.dart`

---

## 11. Bugs Found

### Critical Bugs (8)

| # | Bug | Location | Evidence |
|---|-----|----------|----------|
| B-1 | Splash race condition — double navigation from `ever()` + `addPostFrameCallback` | `splash_view.dart:30-41` | Both can fire `_navigateToNext()` |
| B-2 | Duplicate `AuthController` instantiation in Login/Register views | `login_view.dart:15`, `register_view.dart:15` | `Get.put(AuthController())` when already permanent |
| B-3 | Double navigation on login/register — controller + auth listener both navigate | `auth_controller.dart:219,349,466` | Race between manual navigation and listener |
| B-4 | Chat message stream unbounded memory growth | `support_chat_controller.dart:325-355` | Full table sync on every insert |
| B-5 | Transaction type mismatch `'withdraw'` vs `'withdrawal'` | `wallet_view.dart:871` vs `all_transactions_view.dart:519` | Wrong amount sign display |
| B-6 | Yesterday detection broken on 1st of month | `all_transactions_view.dart:489-491` | `now.day - 1 = 0` never matches |
| B-7 | "Investments" quick action navigates to `/subscription` | `home_view.dart:964-966` | Wrong destination |
| B-8 | `CountrySelector` completely broken in light mode | `country_selector.dart` | Hardcoded white text on light backgrounds |

### High Bugs (10)

| # | Bug | Location |
|---|-----|----------|
| B-9 | `verifyPasswordResetOTP` is a no-op — does nothing | `auth_controller.dart:540-544` |
| B-10 | Spin wheel `_countdownTimer` never cancelled in `dispose()` | `spin_wheel_view.dart` |
| B-11 | Chat edit UI broken — send always creates new message | `support_chat_view.dart` |
| B-12 | iOS foreground notifications never shown | `fcm_service.dart:149` |
| B-13 | Referral debounce broken — creates new Rx each keystroke | `auth_controller.dart:114-121` |
| B-14 | Transfer `Get.back()` × 2 after bottom sheet — can pop wrong routes | `transfer_view.dart:583-597` |
| B-15 | Subscription toggle compares against translated string | `subscription_view.dart:201` |
| B-16 | Notification reconnection creates unbounded listeners | `home_controller.dart:134-140` |
| B-17 | Hardcoded 10% loan interest regardless of server config | `loan_view.dart:36` |
| B-18 | Chat typing channel globally shared — privacy/scalability issue | `support_chat_controller.dart:384` |

### Medium Bugs (15+)

Including: no SafeArea on Login/Register, OTP auto-verify race, no onboarding persistence, wallet `totalBalance` naming mismatch, deposit agent error swallowed, withdrawal notes discarded, no transfer recipient preview, investment dropdown value mismatch risk, loan `receiveAsPoints` dead toggle, hardcoded subscription prices, KSP USD inconsistency, no friend request realtime, presence channel churn on app resume.

---

## 12. Missing Implementations

### Critical Missing

| Feature | Impact |
|---------|--------|
| Search functionality | Users cannot search transactions, contacts, investments, or agents |
| Delete Account | Required by Apple App Store guidelines |
| Crash reporting (Sentry/Crashlytics) | No production error visibility |
| Frozen wallet enforcement | Security bypass |
| Error states on most screens | Users get empty states instead of actionable error messages |

### High Missing

| Feature | Impact |
|---------|--------|
| Settings screen (dedicated) | No organized settings — embedded in Profile |
| Social Feed | Mentioned in app scope but entirely unimplemented |
| Deep link handling | Shared URLs have no app handler |
| Notification preferences management | No per-type notification control |
| About / Version info | No version visibility for users |
| Privacy Policy screen | Only Legal/Terms exists |
| QR Share/Save | Buttons exist but are non-functional |
| Profit history screen | No historical daily profit breakdown |
| Subscription history | No past subscription records |
| Repayment schedule/installments | No automated installment plans |

### Medium Missing

| Feature | Impact |
|---------|--------|
| User levels / XP system | No gamification progression |
| Achievements / Badges | No milestone tracking |
| Leaderboard | No competitive features |
| KSP redemption for cash | No KSP → USD conversion feature |
| Reward catalog / marketplace | Only spin bundles and P2P transfers |
| Subscription upgrade/downgrade flow | Blocked by generic warning |
| OTP paste support | 6-digit codes must be typed individually |
| Confirm password on registration | Mistype risk |
| Biometric/PIN settings screen | Lock screen exists but no configuration UI |
| Language persistence | Resets on app restart |

---

## 13. Improvement Roadmap

### 1. Critical Improvements (Must Fix Before Production)

| # | Improvement | Technical Reason | Expected Impact | Priority | Complexity | Business Value |
|---|-------------|-----------------|-----------------|----------|------------|----------------|
| C-1 | Fix splash double navigation race | `ever()` + `addPostFrameCallback` both fire, causing dual navigation and potential crash | Eliminates app startup crash | CRITICAL | LOW | HIGH |
| C-2 | Fix duplicate AuthController instantiation | `Get.put(AuthController())` in Login/Register creates second instance overwriting permanent one | Fixes auth state corruption | CRITICAL | LOW | HIGH |
| C-3 | Fix double navigation on login/register | Both `login()`/`register()` and `_listenToAuthChanges()` navigate to home | Eliminates navigation flicker/crash | CRITICAL | LOW | HIGH |
| C-4 | Add crash reporting (Crashlytics/Sentry) | Zero visibility into production crashes | Enables production debugging | CRITICAL | MEDIUM | HIGH |
| C-5 | Use precision-safe types for financial calculations | `double` causes floating-point errors on money calculations ($0.30000000000000004) | Prevents money calculation errors | CRITICAL | HIGH | HIGH |
| C-6 | Fix CountrySelector for light mode | Hardcoded white text invisible on light backgrounds | Login/Register usable in light mode | CRITICAL | LOW | HIGH |
| C-7 | Add Delete Account feature | Apple App Store requirement — app will be rejected without it | App Store approval | CRITICAL | MEDIUM | HIGH |
| C-8 | Enforce frozen wallet state | Users can operate on frozen wallets — security bypass | Prevents unauthorized financial operations | CRITICAL | LOW | HIGH |
| C-9 | Fix transaction type mismatch (`withdraw` vs `withdrawal`) | Withdrawals show as positive amounts in wallet view | Correct financial display | CRITICAL | LOW | HIGH |
| C-10 | Add error states to all screens | Users see empty states instead of error messages when data loading fails | Users can identify and retry on errors | CRITICAL | MEDIUM | HIGH |

### 2. Core Improvements (Major Enhancements)

| # | Improvement | Technical Reason | Expected Impact | Priority | Complexity | Business Value |
|---|-------------|-----------------|-----------------|----------|------------|----------------|
| CO-1 | Split HomeController (948 lines) into focused controllers | God Controller managing 10+ concerns violates SRP | Better maintainability, testability | HIGH | HIGH | MEDIUM |
| CO-2 | Add route-level middleware/guards for auth-protected routes | Any route navigable without login check at route level | Prevents unauthorized screen access | HIGH | MEDIUM | HIGH |
| CO-3 | Use `flutter_secure_storage` for tokens | SharedPreferences stores sensitive data unencrypted | Prevents token theft on rooted devices | HIGH | MEDIUM | HIGH |
| CO-4 | Fix chat message stream architecture | Full table sync on every insert causes unbounded memory growth | Eliminates memory leak, reduces bandwidth | HIGH | HIGH | MEDIUM |
| CO-5 | Scope typing channel per conversation | Global `chat_typing` channel leaks typing events to all users | Privacy and scalability fix | HIGH | MEDIUM | HIGH |
| CO-6 | Fix FCM notification scheduling | `Future.delayed` won't fire if app killed — use `zonedSchedule()` | Reliable notification delivery | HIGH | MEDIUM | HIGH |
| CO-7 | Fix iOS foreground notification display | `android != null` guard blocks iOS foreground notifications | iOS users receive in-app notifications | HIGH | LOW | HIGH |
| CO-8 | Make referral commission atomic with investment/subscription | Client-side commission processing can fail silently after investment succeeds | Commission reliability | HIGH | MEDIUM | HIGH |
| CO-9 | Add SafeArea to Login/Register/OTP screens | Content renders behind status bar on notched devices | Proper display on all devices | HIGH | LOW | HIGH |
| CO-10 | Version-control the base database schema | Base tables not in `supabase/migrations/` — no schema history | Reproducible deployments | HIGH | MEDIUM | MEDIUM |

### 3. Functional Improvements (Missing Features)

| # | Improvement | Technical Reason | Expected Impact | Priority | Complexity | Business Value |
|---|-------------|-----------------|-----------------|----------|------------|----------------|
| F-1 | Implement Search functionality | No way to search transactions, users, investments, or agents | Core user workflow improvement | HIGH | HIGH | HIGH |
| F-2 | Implement dedicated Settings screen | Settings buried in Profile tab — poor discoverability | Better UX, app store compliance | HIGH | MEDIUM | HIGH |
| F-3 | Implement Social Feed feature | Referenced in app scope but entirely unimplemented | User engagement and retention | MEDIUM | HIGH | MEDIUM |
| F-4 | Implement deep link handling | Shared referral URLs (`kasby.app/join?ref=CODE`) have no app handler | Referral conversion improvement | HIGH | MEDIUM | HIGH |
| F-5 | Implement QR Share/Save buttons | Buttons exist but are non-functional (empty callbacks) | Complete QR payment feature | HIGH | LOW | MEDIUM |
| F-6 | Add profit history screen | No historical daily profit breakdown available | Investment transparency | MEDIUM | MEDIUM | MEDIUM |
| F-7 | Add subscription history | No past subscription records visible | Financial transparency | MEDIUM | MEDIUM | LOW |
| F-8 | Add loan repayment schedule | No automated installment plans or due date reminders | Loan management UX | MEDIUM | MEDIUM | MEDIUM |
| F-9 | Add OTP paste support | Users must type each digit individually in 6-box OTP field | Onboarding friction reduction | MEDIUM | LOW | MEDIUM |
| F-10 | Add confirm password on registration | Users can mistype password with no safety net | Registration error prevention | MEDIUM | LOW | MEDIUM |

### 4. UI/UX Improvements

| # | Improvement | Technical Reason | Expected Impact | Priority | Complexity | Business Value |
|---|-------------|-----------------|-----------------|----------|------------|----------------|
| U-1 | Fix all hardcoded Arabic strings (~15+ locations) | Bypasses i18n system — breaks English locale | Proper bilingual support | HIGH | MEDIUM | HIGH |
| U-2 | Complete missing ~50 Arabic translations | `en_US` has 1112 keys, `ar_SA` has ~1057 | Complete Arabic experience | HIGH | MEDIUM | HIGH |
| U-3 | Add locale-aware plan name display | Always shows Arabic plan names regardless of locale | English users see English names | HIGH | LOW | HIGH |
| U-4 | Fix onboarding persistence | Onboarding shown every time after logout | Smooth return user experience | MEDIUM | LOW | MEDIUM |
| U-5 | Add Skip button to onboarding | Users must swipe through all 3 pages | Reduced friction | LOW | LOW | LOW |
| U-6 | Fix KYC controller text controller disposal | `dobController` never disposed | Memory leak prevention | LOW | LOW | LOW |
| U-7 | Add recipient name preview before transfer | User sees raw referral code, not recipient name | Transfer confidence | HIGH | MEDIUM | HIGH |
| U-8 | Fix "Investments" quick action navigation | Navigates to `/subscription` instead of investments | Correct navigation | HIGH | LOW | HIGH |
| U-9 | Add Semantics/accessibility labels to custom widgets | Screen readers can't detect disabled buttons | Accessibility compliance | MEDIUM | MEDIUM | MEDIUM |
| U-10 | Display actual plan duration instead of hardcoded text | All plans show "30 months / 2.5 years" regardless of `durationDays` | Accurate investment information | HIGH | LOW | HIGH |

### 5. Performance Improvements

| # | Improvement | Technical Reason | Expected Impact | Priority | Complexity | Business Value |
|---|-------------|-----------------|-----------------|----------|------------|----------------|
| P-1 | Replace chat `.stream()` with scoped Realtime channel | Full table sync on every message is O(n) and grows unbounded | Fixes memory leak, reduces bandwidth | CRITICAL | HIGH | HIGH |
| P-2 | Reduce `fetchAll()` from 10 parallel queries to progressive loading | All 10 queries fire on every app resume | Reduces API load, faster visible content | HIGH | MEDIUM | MEDIUM |
| P-3 | Eliminate per-second timer duplicates | Two `Timer.periodic(1s)` cause unnecessary rebuilds | CPU/battery savings | HIGH | MEDIUM | MEDIUM |
| P-4 | Pause animation controllers when off-screen | Gradient and rotation animations run continuously | Battery/GPU savings on low-end devices | MEDIUM | MEDIUM | LOW |
| P-5 | Add API response caching | Every screen visit hits network — no caching layer | Faster screen loads, offline support | MEDIUM | HIGH | MEDIUM |
| P-6 | Move PDF generation to isolate | `TransactionReceipt` generates PDF on UI thread | Eliminates UI jank during receipt generation | MEDIUM | LOW | LOW |
| P-7 | Server-side aggregation for referral earnings | Client fetches all rows and sums — inefficient | Reduces data transfer, faster display | MEDIUM | LOW | MEDIUM |
| P-8 | Reduce network connectivity check interval | Speed check pings `8.8.8.8:53` every 30 seconds | Battery savings | LOW | LOW | LOW |
| P-9 | Use lazy controller registration instead of eager | 6+ controllers eagerly loaded at startup | Faster startup, lower initial memory | MEDIUM | MEDIUM | MEDIUM |
| P-10 | Fix `WheelPainter.shouldRepaint` | Always returns `true` — unnecessary repaints | Smoother spin wheel animation | LOW | LOW | LOW |

### 6. Security Improvements

| # | Improvement | Technical Reason | Expected Impact | Priority | Complexity | Business Value |
|---|-------------|-----------------|-----------------|----------|------------|----------------|
| S-1 | Add RLS policies for all base tables | Only chat/OTP tables have documented RLS — others unknown | Data access control | CRITICAL | HIGH | HIGH |
| S-2 | Add QR code timestamp validation | Expired QR codes accepted indefinitely — replay attack vector | Prevents financial replay attacks | HIGH | LOW | HIGH |
| S-3 | Require current password for password change | Non-recovery mode doesn't verify current password | Prevents unauthorized password changes | HIGH | LOW | HIGH |
| S-4 | Remove PII from debug logs | User ID, email, phone, profile data logged in console | PII exposure prevention | MEDIUM | LOW | MEDIUM |
| S-5 | Add client-side rate limiting on login | No backoff on failed attempts | Brute-force protection | MEDIUM | LOW | MEDIUM |
| S-6 | Remove diagnostic code that lists storage buckets | Upload failure handler lists all infrastructure buckets | Infrastructure information disclosure | MEDIUM | LOW | MEDIUM |
| S-7 | Add biometric/PIN for deposits | Withdrawals/transfers require auth but deposits don't | Consistent security model | MEDIUM | LOW | MEDIUM |
| S-8 | Add deposit/transfer amount limits | No maximum amount validation client-side | Risk mitigation | MEDIUM | LOW | MEDIUM |
| S-9 | Use UUID for idempotency keys | Timestamp-based keys have collision risk | Duplicate transaction prevention | LOW | LOW | MEDIUM |
| S-10 | Encrypt chat messages in local storage | SharedPreferences stores support conversations in plaintext | Sensitive data protection | MEDIUM | MEDIUM | MEDIUM |

### 7. Scalability Improvements

| # | Improvement | Technical Reason | Expected Impact | Priority | Complexity | Business Value |
|---|-------------|-----------------|-----------------|----------|------------|----------------|
| SC-1 | Redesign presence architecture | Single global channel for all users hits Supabase limits at scale | Supports 1000+ concurrent users | HIGH | HIGH | HIGH |
| SC-2 | Split 2169-line translation file | Single monolithic file is unmaintainable | Developer productivity | MEDIUM | MEDIUM | MEDIUM |
| SC-3 | Extract Friends into GetxController | State lost on navigation, no realtime, no persistence | Proper state management | MEDIUM | MEDIUM | MEDIUM |
| SC-4 | Add comprehensive test suite | Only 9 test files exist — minimal coverage | Regression prevention | HIGH | HIGH | HIGH |
| SC-5 | Add CI/CD pipeline | No automated testing/deployment | Release reliability | MEDIUM | MEDIUM | MEDIUM |
| SC-6 | Add structured logging service | Only `debugPrint` — no structured production logging | Production debugging capability | MEDIUM | MEDIUM | MEDIUM |
| SC-7 | Add model equality/hashCode overrides | Identity issues in collections/sets with current models | Data integrity in state management | MEDIUM | MEDIUM | LOW |
| SC-8 | Remove `.tr` from `AgentModel.fromJson()` | Translation side effect in model layer — crashes if GetX not initialized | Model layer purity | HIGH | LOW | MEDIUM |
| SC-9 | Add force update / app version check | No mechanism to require users to update | Critical update delivery | MEDIUM | MEDIUM | HIGH |
| SC-10 | Implement proper DI with bindings per feature | Most controllers eagerly loaded in `main.dart` | Memory efficiency, startup speed | MEDIUM | HIGH | MEDIUM |

### 8. Nice-to-Have Enhancements

| # | Enhancement | Technical Reason | Expected Impact | Priority | Complexity | Business Value |
|---|-------------|-----------------|-----------------|----------|------------|----------------|
| N-1 | User levels / XP progression system | No gamification progression — reduces engagement loops | Increased user retention | LOW | HIGH | MEDIUM |
| N-2 | Achievements / Badges system | No milestone tracking or visual accomplishments | Engagement and motivation | LOW | HIGH | MEDIUM |
| N-3 | Leaderboard | No competitive features between users | Community engagement | LOW | MEDIUM | LOW |
| N-4 | KSP redemption for cash | No way to convert KSP back to USD/withdraw | Monetization of points | LOW | HIGH | MEDIUM |
| N-5 | Reward catalog / KSP marketplace | Only spin bundles available — limited spend options | Points ecosystem value | LOW | HIGH | MEDIUM |
| N-6 | Chat read receipts UI | Data exists (`read_at`, `delivered_at`) but not displayed | Chat feature completeness | LOW | MEDIUM | LOW |
| N-7 | Typing indicators display | Channel exists but typing status only tracked, not shown | Chat UX enhancement | LOW | LOW | LOW |
| N-8 | Multi-level referral tree navigation | Only level-1 referrals visible, can't drill into sub-referrals | Network visualization | LOW | MEDIUM | LOW |
| N-9 | Offline mode with sync queue | No offline support — requires network for all operations | Reliability in poor connectivity | LOW | HIGH | MEDIUM |
| N-10 | Tablet/responsive layouts | No explicit responsive breakpoints or tablet considerations | Wider device support | LOW | HIGH | LOW |
| N-11 | Dynamic subscription plans from server | Plans/prices hardcoded — requires app update to change | Business flexibility | MEDIUM | MEDIUM | HIGH |
| N-12 | Dynamic KSP exchange rate from server | Hardcoded 1 USD = 1000 KSP | Rate flexibility | LOW | LOW | MEDIUM |
| N-13 | About / Version info screen | No app version visibility for users or support | Support efficiency | LOW | LOW | LOW |
| N-14 | Privacy Policy screen | Only Legal/Terms exists | App store compliance | MEDIUM | LOW | MEDIUM |

---

## Production Readiness Score: 38/100

### Score Breakdown

| Category | Weight | Score | Weighted |
|----------|--------|-------|----------|
| Core Functionality | 25% | 50/100 | 12.5 |
| Data Integrity | 20% | 30/100 | 6.0 |
| Security | 20% | 25/100 | 5.0 |
| UI/UX Quality | 15% | 45/100 | 6.75 |
| Performance | 10% | 40/100 | 4.0 |
| Code Quality | 10% | 35/100 | 3.5 |
| **Total** | **100%** | — | **37.75 ≈ 38** |

### Rationale

- **Core Functionality (50/100)**: Most features work at a basic level but have critical bugs (double navigation, broken edit, dead toggles), missing validations, and incomplete flows.
- **Data Integrity (30/100)**: `double` for money, missing field mappings, no model equality, type string mismatches, and stale data without realtime on key tables.
- **Security (25/100)**: Frozen wallet bypass, unencrypted token storage, no crash reporting, missing RLS documentation, PII in logs, no rate limiting, expired QR acceptance.
- **UI/UX (45/100)**: Decent visual design with dark/light themes, but broken in light mode (CountrySelector), hardcoded Arabic, missing error states, and no search/settings screens.
- **Performance (40/100)**: Aggressive query patterns, per-second timers, unbounded streams, no caching, but basic Realtime integration works.
- **Code Quality (35/100)**: God Controller, duplicated code, dead code, inconsistent state management patterns (Obx + setState), 9 test files for 105 source files.

---

## Conclusion

The Kasby User App has a solid feature scope and visual design foundation, but it contains **critical bugs and security issues that must be resolved before production deployment**. The top priorities are:

1. **Fix the 8 critical bugs** (splash race, duplicate controllers, double navigation, transaction type mismatch, etc.)
2. **Add crash reporting** to gain production visibility
3. **Secure financial calculations** with precision-safe types
4. **Enforce frozen wallet state** and **fix RLS coverage**
5. **Resolve the 15+ hardcoded Arabic strings** blocking English locale
6. **Implement Delete Account** for App Store compliance
7. **Fix the chat architecture** (memory leak, global typing channel)
8. **Add comprehensive error states** across all screens

With these critical fixes (estimated 2-3 weeks of focused development), the production readiness score would improve to approximately 60-65/100. The remaining improvements in the roadmap would bring it to 80+/100 over an additional 4-6 weeks.

---

*Report generated by comprehensive static analysis of 105 Dart source files, 9 SQL migration files, 7 Edge Function files, and full architecture trace from Flutter UI through Supabase backend.*
