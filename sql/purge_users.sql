-- ==============================================================================
-- KASBY - CLEANUP BROKEN ACCOUNTS
-- ==============================================================================
-- This script hard-deletes specific emails from the GoTrue (auth.users) directly.
-- This ensures they are completely purged and no "User Already Registered" 
-- errors can occur when registering them again.
-- ==============================================================================

-- Step 1: Delete from auth.users (CASCADE will clean profiles, otp_verifications, etc.)
DELETE FROM auth.users WHERE email IN (
  'aymanaltairi@gmail.com', 
  'mano@gmail.com', 
  'example@gmail.com',
  
);

-- Step 2: Optional — manually clean any orphaned otp_verifications
-- (in case FK constraint was violated and rows linger)
-- DELETE FROM public.otp_verifications 
--   WHERE user_id NOT IN (SELECT id FROM auth.users);

-- (Note: Because of CASCADE, this will automatically delete their profiles too, so everything is clean)
