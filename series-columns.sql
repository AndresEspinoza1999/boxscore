-- Run this in your Supabase SQL editor to add playoff series columns to the games table
-- These are all nullable so existing rows are unaffected

ALTER TABLE games
  ADD COLUMN IF NOT EXISTS series_info       text,
  ADD COLUMN IF NOT EXISTS series_type       text,
  ADD COLUMN IF NOT EXISTS home_series_wins  integer,
  ADD COLUMN IF NOT EXISTS away_series_wins  integer,
  ADD COLUMN IF NOT EXISTS is_playoff        boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS home_team_id      text,
  ADD COLUMN IF NOT EXISTS away_team_id      text;

-- Optional: index for playoff filtering
CREATE INDEX IF NOT EXISTS idx_games_is_playoff ON games(is_playoff) WHERE is_playoff = true;
