-- Add updated_at column to loans table if it doesn't exist
-- This is needed for loan rejection and other status updates

ALTER TABLE public.loans
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create a trigger to automatically update updated_at on row changes
CREATE OR REPLACE FUNCTION public.handle_loans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS on_loans_update ON public.loans;
CREATE TRIGGER on_loans_update
BEFORE UPDATE ON public.loans
FOR EACH ROW
EXECUTE FUNCTION public.handle_loans_updated_at();
