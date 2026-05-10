-- ============================================================
-- KASBY – Test Data Seed: Balances, Transactions, Check-Ins
-- Run this in your Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. DEFAULT WALLETS: Give all zero-balance wallets test funds
-- ============================================================
UPDATE wallets
SET available_balance = 5000.00,
    profit_balance    = 250.00,
    invested_balance  = 1000.00
WHERE available_balance = 0
  AND profit_balance = 0
  AND invested_balance = 0;

-- ============================================================
-- 2. INVESTMENT PLANS: Add available_amounts (JSONB array)
-- ============================================================
UPDATE investment_plans
SET available_amounts = '[500, 1000, 2500, 5000, 10000]'
WHERE id = 'f0f0f0f0-f0f0-4f0f-8f0f-f0f0f0f0f0f0';

UPDATE investment_plans
SET available_amounts = '[1000, 5000, 10000, 25000, 50000]'
WHERE id = 'f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1';

UPDATE investment_plans
SET available_amounts = '[500, 1000, 2500, 5000]'
WHERE id = 'f2f2f2f2-f2f2-4f2f-8f2f-f2f2f2f2f2f2';

-- ============================================================
-- 3. TRANSACTIONS: Insert sample transactions for ALL users
-- ============================================================
INSERT INTO transactions (user_id, wallet_id, type, amount, status, running_balance, description, created_at)
SELECT
  w.user_id,
  w.id,
  'deposit',
  5000.00,
  'completed',
  5000.00,
  'إيداع أولي للاختبار',
  NOW() - INTERVAL '7 days'
FROM wallets w
WHERE NOT EXISTS (
  SELECT 1 FROM transactions t WHERE t.user_id = w.user_id AND t.type::text = 'deposit'
);

INSERT INTO transactions (user_id, wallet_id, type, amount, status, running_balance, description, created_at)
SELECT
  w.user_id,
  w.id,
  'profit',
  250.00,
  'completed',
  5250.00,
  'أرباح يومية - الصندوق الذهبي',
  NOW() - INTERVAL '3 days'
FROM wallets w
WHERE NOT EXISTS (
  SELECT 1 FROM transactions t WHERE t.user_id = w.user_id AND t.type::text = 'profit'
);

INSERT INTO transactions (user_id, wallet_id, type, amount, status, running_balance, description, created_at)
SELECT
  w.user_id,
  w.id,
  'investment',
  1000.00,
  'completed',
  4250.00,
  'استثمار في الصندوق الذهبي العراقي',
  NOW() - INTERVAL '5 days'
FROM wallets w
WHERE NOT EXISTS (
  SELECT 1 FROM transactions t WHERE t.user_id = w.user_id AND t.type::text = 'investment'
);

-- ============================================================
-- 4. DAILY CHECK-INS: Insert sample check-in records for ALL users
-- ============================================================
INSERT INTO daily_check_ins (user_id, streak, points_awarded, created_at)
SELECT
  p.id,
  1,
  10,
  NOW() - INTERVAL '3 days'
FROM profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM daily_check_ins d WHERE d.user_id = p.id
);

INSERT INTO daily_check_ins (user_id, streak, points_awarded, created_at)
SELECT
  p.id,
  2,
  10,
  NOW() - INTERVAL '2 days'
FROM profiles p
WHERE (SELECT COUNT(*) FROM daily_check_ins d WHERE d.user_id = p.id) = 1;

INSERT INTO daily_check_ins (user_id, streak, points_awarded, created_at)
SELECT
  p.id,
  3,
  15,
  NOW() - INTERVAL '1 day'
FROM profiles p
WHERE (SELECT COUNT(*) FROM daily_check_ins d WHERE d.user_id = p.id) = 2;

-- ============================================================
-- 5. USER POINTS: Ensure all users have a points record
-- ============================================================
INSERT INTO user_points (user_id, current_balance, total_earned)
SELECT p.id, 35, 35
FROM profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM user_points up WHERE up.user_id = p.id
)
ON CONFLICT DO NOTHING;

-- Update existing zero-balance point records
UPDATE user_points
SET current_balance = 35,
    total_earned = 35
WHERE current_balance = 0;

-- ============================================================
-- DONE! Refresh the app to see the changes.
-- ============================================================
