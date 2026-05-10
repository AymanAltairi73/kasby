-- Upsert Investment Plans
-- Gold Investment
INSERT INTO investment_plans (
    id, name_ar, name_en, description_ar, description_en, image_url, 
    profit_percentage, duration_days, min_amount, available_amounts, risk_level, is_active
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000', -- Static UUID for Gold
    'مركز استثمار الذهب', 'Gold Investment Center', 
    'استثمار في سبائك الذهب عيار 24.', 'Invest in 24K Gold Bullion.', 
    'assets/images/gold.png', 8.0, 30, 500, '[500, 1000, 1500, 2000, 2500]', 'medium', true
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    profit_percentage = EXCLUDED.profit_percentage,
    min_amount = EXCLUDED.min_amount,
    available_amounts = EXCLUDED.available_amounts;

-- Silver Investment
INSERT INTO investment_plans (
    id, name_ar, name_en, description_ar, description_en, image_url, 
    profit_percentage, duration_days, min_amount, available_amounts, risk_level, is_active
) VALUES (
    '550e8400-e29b-41d4-a716-446655440001', -- Static UUID for Silver
    'مركز استثمار الفضة', 'Silver Investment Center', 
    'استثمار في الفضة النقية.', 'Invest in pure silver.', 
    'assets/images/sliver.png', 6.0, 30, 100, '[100, 200, 300, 400, 500]', 'low', true
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    profit_percentage = EXCLUDED.profit_percentage,
    min_amount = EXCLUDED.min_amount,
    available_amounts = EXCLUDED.available_amounts;

-- Real Estate Investment
INSERT INTO investment_plans (
    id, name_ar, name_en, description_ar, description_en, image_url, 
    profit_percentage, duration_days, min_amount, available_amounts, risk_level, is_active
) VALUES (
    '550e8400-e29b-41d4-a716-446655440002', -- Static UUID for Real Estate
    'مركز استثمار العقارات', 'Real Estate Investment Center', 
    'استثمار في العقارات المتميزة.', 'Invest in premium real estate.', 
    'assets/images/real_estate.png', 10.0, 30, 2000, '[2000, 4000, 6000, 8000, 10000]', 'high', true
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    profit_percentage = EXCLUDED.profit_percentage,
    min_amount = EXCLUDED.min_amount,
    available_amounts = EXCLUDED.available_amounts;
