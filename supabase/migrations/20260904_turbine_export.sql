-- Turbine export to grid: units fed back by the wind turbine.
-- Subtracted from import in net billing (same as solar export_kwh).
ALTER TABLE public.energy_logs
  ADD COLUMN IF NOT EXISTS turbine_export_kwh numeric DEFAULT NULL;