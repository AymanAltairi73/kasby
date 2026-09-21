-- Add geographic coordinates to agents table for map view
ALTER TABLE public.agents
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

-- Index for geo queries
CREATE INDEX IF NOT EXISTS idx_agents_coordinates 
  ON public.agents (latitude, longitude) 
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Allow agents to update their own coordinates
CREATE POLICY "agents_update_own_coordinates" ON public.agents
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
