-- Update all user wallets with fixed balance and profit
-- This script sets available_balance to 5000 and profit_balance to 2000 for all users.

UPDATE wallets
SET 
    available_balance = 5000.0000,
    profit_balance = 2000.0000,
    updated_at = CURRENT_TIMESTAMP;

-- Optionally, add a transaction record for each user to maintain ledger consistency (Adjustment)
-- This assumes we want a record of why the balance changed suddenly.
INSERT INTO transactions (
    user_id, 
    wallet_id, 
    type, 
    amount, 
    currency, 
    status, 
    description,
    reason
)
SELECT 
    user_id, 
    id as wallet_id, 
    'adjustment'::txn_type, 
    5000.0000, 
    'USD', 
    'completed'::txn_status, 
    'Balance and profit update by admin',
    'manual_update'
FROM wallets;
