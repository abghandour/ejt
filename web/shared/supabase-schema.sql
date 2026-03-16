-- =============================================
-- Supabase schema for How Janey Learned
-- Run this in Supabase SQL Editor (supabase.com > SQL)
-- =============================================

-- Profiles (public-facing, auto-created on signup)
CREATE TABLE profiles (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Player',
  patreon_id   TEXT UNIQUE,
  patreon_tier TEXT
);
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles are publicly readable" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Note: No auto-creation trigger on auth.users.
-- Profile rows are created by the patreon-auth Edge Function via upsert.

-- User settings
CREATE TABLE user_settings (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  language   TEXT NOT NULL DEFAULT 'ru',
  theme      TEXT NOT NULL DEFAULT 'soviet',
  bg_mode    TEXT NOT NULL DEFAULT 'colors',
  bg_index   INT  NOT NULL DEFAULT 0,
  last_game  TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own settings" ON user_settings FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Daily game state
CREATE TABLE daily_game_state (
  user_id    UUID  NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game       TEXT  NOT NULL,
  language   TEXT  NOT NULL DEFAULT 'ru',
  game_date  DATE  NOT NULL,
  state_json JSONB NOT NULL,
  phase      TEXT  NOT NULL DEFAULT 'playing',
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, game, language, game_date)
);
ALTER TABLE daily_game_state ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own daily state" ON daily_game_state FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Session scores
CREATE TABLE session_scores (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game            TEXT NOT NULL,
  language        TEXT NOT NULL DEFAULT 'ru',
  difficulty      TEXT,
  score           INT  NOT NULL,
  words_completed INT  DEFAULT 0,
  duration_secs   INT,
  seed            BIGINT,
  details_json    JSONB,
  played_at       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_session_scores_user_game ON session_scores(user_id, game);
CREATE INDEX idx_session_scores_leaderboard ON session_scores(game, language, difficulty, score DESC);
ALTER TABLE session_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Subscribers insert own scores" ON session_scores FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Anyone can read scores" ON session_scores FOR SELECT
  USING (true);

-- User game stats (read-only from client, updated by trigger)
CREATE TABLE user_game_stats (
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game           TEXT NOT NULL,
  language       TEXT NOT NULL DEFAULT 'ru',
  games_played   INT  DEFAULT 0,
  best_score     INT  DEFAULT 0,
  total_score    BIGINT DEFAULT 0,
  current_streak INT  DEFAULT 0,
  best_streak    INT  DEFAULT 0,
  last_played    DATE,
  PRIMARY KEY (user_id, game, language)
);
ALTER TABLE user_game_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own stats" ON user_game_stats FOR SELECT
  USING (auth.uid() = user_id);

-- Trigger: auto-update stats on score insert
CREATE OR REPLACE FUNCTION update_user_game_stats()
RETURNS TRIGGER AS $$
DECLARE
  prev_last_played DATE;
  prev_streak INT;
BEGIN
  SELECT last_played, current_streak INTO prev_last_played, prev_streak
  FROM user_game_stats
  WHERE user_id = NEW.user_id AND game = NEW.game AND language = NEW.language;

  IF NOT FOUND THEN
    INSERT INTO user_game_stats (user_id, game, language, games_played, best_score, total_score, current_streak, best_streak, last_played)
    VALUES (NEW.user_id, NEW.game, NEW.language, 1, NEW.score, NEW.score, 1, 1, (NEW.played_at AT TIME ZONE 'UTC')::DATE);
  ELSE
    UPDATE user_game_stats SET
      games_played = games_played + 1,
      best_score = GREATEST(best_score, NEW.score),
      total_score = total_score + NEW.score,
      current_streak = CASE
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE THEN current_streak
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE - 1 THEN current_streak + 1
        ELSE 1
      END,
      best_streak = GREATEST(best_streak, CASE
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE THEN current_streak
        WHEN prev_last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE - 1 THEN current_streak + 1
        ELSE 1
      END),
      last_played = (NEW.played_at AT TIME ZONE 'UTC')::DATE
    WHERE user_id = NEW.user_id AND game = NEW.game AND language = NEW.language;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_user_game_stats
  AFTER INSERT ON session_scores
  FOR EACH ROW EXECUTE FUNCTION update_user_game_stats();
