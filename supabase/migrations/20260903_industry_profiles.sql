-- Add industry_profiles table for mandatory per-client energy sources + MD mode config
-- Energy sources: none / solar / turbine / solar+turbine
-- MD mode: single (default recorded MD) vs multi (T1-T4)

CREATE TABLE IF NOT EXISTS public.industry_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Required industry identity
  industry_name text NOT NULL,
  tariff_category text NOT NULL CHECK (tariff_category IN ('ht_industrial', 'ht_industrial_seasonal', 'ht_commercial', 'lt_residential', 'lt_industrial')),
  tariff_version text NOT NULL DEFAULT 'fy2627' CHECK (tariff_version IN ('fy2526', 'fy2627')),
  voltage_level text NOT NULL CHECK (voltage_level IN ('11kV', '33kV', '132kV', 'LT')),
  contract_demand_kva numeric NOT NULL,
  -- Energy sources selection (client picks)
  energy_sources text NOT NULL DEFAULT 'none' CHECK (energy_sources IN ('none', 'solar', 'turbine', 'solar+turbine')),
  -- MD mode selection
  md_mode text NOT NULL DEFAULT 'single' CHECK (md_mode IN ('single', 'multi')),
  -- Optional additional fields
  consumer_number text,
  division text,
  circle text,
  service_type text DEFAULT 'HT',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

COMMENT ON TABLE public.industry_profiles IS 'Mandatory industry profile completed at first sign-in. Controls visible UI (energy sources, MD mode) and auto-applies tariff preset.';

COMMENT ON COLUMN public.industry_profiles.industry_name IS 'Client industry/business name';
COMMENT ON COLUMN public.industry_profiles.tariff_category IS 'MERC tariff category — matches TariffCategory enum in app';
COMMENT ON COLUMN public.industry_profiles.tariff_version IS 'MERC tariff version — matches TariffVersion enum in app';
COMMENT ON COLUMN public.industry_profiles.voltage_level IS 'Supply voltage level';
COMMENT ON COLUMN public.industry_profiles.contract_demand_kva IS 'Contracted demand in kVA (sanctioned load)';
COMMENT ON COLUMN public.industry_profiles.energy_sources IS 'none|solar|turbine|solar+turbine — gates UI & calculation logic';
COMMENT ON COLUMN public.industry_profiles.md_mode IS 'single (one recorded MD) | multi (T1-T4 separate MD fields)';
COMMENT ON COLUMN public.industry_profiles.consumer_number IS 'MSEDCL consumer number';
COMMENT ON COLUMN public.industry_profiles.division IS 'MSEDCL division office';
COMMENT ON COLUMN public.industry_profiles.circle IS 'MSEDCL circle office';
COMMENT ON COLUMN public.industry_profiles.service_type IS 'HT or LT service type';

-- RLS policies
ALTER TABLE public.industry_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own industry profile"
  ON public.industry_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own industry profile"
  ON public.industry_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own industry profile"
  ON public.industry_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Auto-apply tariff preset when profile is inserted/updated
CREATE OR REPLACE FUNCTION public.apply_tariff_preset_from_profile()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- This function can be called from app side via RPC if needed
  -- Tariff preset application happens in Flutter app_config.applyTariffPreset()
  -- but we can also maintain a denormalized view if useful
  RETURN NEW;
END;
$$;

-- Add turbine_kwh to energy_logs (like solar generation/export)
-- turbine generation subtracts from import for net billing (same as solar export)
ALTER TABLE public.energy_logs
  ADD COLUMN IF NOT EXISTS turbine_kwh DOUBLE PRECISION;

COMMENT ON COLUMN public.energy_logs.turbine_kwh IS 'Turbine generation kWh — raw meter diff before MF. Subtracted from import for net billing like solar export.';