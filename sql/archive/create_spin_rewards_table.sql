-- ============================================================
-- 1. CREATE SPIN WHEEL REWARDS TABLE
-- ============================================================
DROP TABLE IF EXISTS spin_wheel_rewards CASCADE;

CREATE TABLE spin_wheel_rewards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  label TEXT NOT NULL,
  points INT NOT NULL DEFAULT 0,
  icon TEXT NOT NULL, -- Icon name (e.g., 'stars_rounded')
  color TEXT NOT NULL, -- Hex color (e.g., '#FFD700')
  weight INT DEFAULT 1, -- For probability calculations
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE spin_wheel_rewards ENABLE ROW LEVEL SECURITY;

-- Allow public read access
DROP POLICY IF EXISTS "Anyone can view active spin rewards" ON spin_wheel_rewards;
CREATE POLICY "Anyone can view active spin rewards" ON spin_wheel_rewards
FOR SELECT USING (is_active = true);

-- ============================================================
-- 2. SEED INITIAL REWARDS
-- ============================================================
INSERT INTO spin_wheel_rewards (label, points, icon, color, weight) VALUES
  ('10', 10, 'stars_rounded', '#FFD700', 1),
  ('25', 25, 'monetization_on_rounded', '#C0C0C0', 1),
  ('50', 50, 'diamond_rounded', '#E5E4E2', 1),
  ('100', 100, 'auto_awesome_rounded', '#B8860B', 1), -- AppColors.darkGold
  ('0', 0, 'sentiment_dissatisfied_rounded', '#454545', 1),
  ('5', 5, 'stars_rounded', '#CD7F32', 1),
  ('200', 200, 'card_giftcard_rounded', '#E91E63', 1),
  ('bonus', 0, 'bolt_rounded', '#2196F3', 1)
ON CONFLICT DO NOTHING;
