-- ═══════════════════════════════════════════════════════════
--  PUNAHUB DATABASE SETUP FOR SUPABASE
--  Run this in Supabase SQL Editor → New Query
-- ═══════════════════════════════════════════════════════════

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════
--  CORE TABLES
-- ═══════════════════════════════════════════════════════════

-- Users table
CREATE TABLE IF NOT EXISTS punahub_users (
  email TEXT PRIMARY KEY,
  data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reels/Posts table
CREATE TABLE IF NOT EXISTS punahub_reels (
  id TEXT PRIMARY KEY,
  data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Follow relationships
CREATE TABLE IF NOT EXISTS punahub_follows (
  email TEXT PRIMARY KEY,
  data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User settings
CREATE TABLE IF NOT EXISTS punahub_settings (
  email TEXT PRIMARY KEY,
  data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════
--  NOTIFICATION SYSTEM TABLES
-- ═══════════════════════════════════════════════════════════

-- Push notification subscriptions
CREATE TABLE IF NOT EXISTS punahub_push_subs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_email TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  p256dh TEXT,
  auth TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_email, endpoint)
);

-- Notification history
CREATE TABLE IF NOT EXISTS punahub_notifs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  to_email TEXT NOT NULL,
  from_email TEXT,
  type TEXT,
  payload JSONB NOT NULL DEFAULT '{}',
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Password Reset OTP
CREATE TABLE IF NOT EXISTS punahub_password_otps (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email TEXT NOT NULL,
  otp TEXT NOT NULL,
  attempts INTEGER DEFAULT 0,
  verified BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(email, otp)
);

CREATE INDEX IF NOT EXISTS idx_punahub_password_otps_email ON punahub_password_otps(email);
CREATE INDEX IF NOT EXISTS idx_punahub_password_otps_expires ON punahub_password_otps(expires_at);

-- Create index for faster notification queries
CREATE INDEX IF NOT EXISTS idx_punahub_notifs_to_email ON punahub_notifs(to_email);
CREATE INDEX IF NOT EXISTS idx_punahub_notifs_created_at ON punahub_notifs(created_at DESC);

-- ═══════════════════════════════════════════════════════════
--  ENGAGEMENT TABLES
-- ═══════════════════════════════════════════════════════════

-- Likes
CREATE TABLE IF NOT EXISTS punahub_likes (
  id TEXT PRIMARY KEY,
  reel_id TEXT NOT NULL,
  user_email TEXT NOT NULL,
  user_nickname TEXT,
  user_avatar TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(reel_id, user_email)
);

CREATE INDEX IF NOT EXISTS idx_punahub_likes_reel_id ON punahub_likes(reel_id);
CREATE INDEX IF NOT EXISTS idx_punahub_likes_user_email ON punahub_likes(user_email);

-- Comments
CREATE TABLE IF NOT EXISTS punahub_comments (
  id TEXT PRIMARY KEY,
  reel_id TEXT NOT NULL,
  parent_id TEXT,
  user_email TEXT NOT NULL,
  user_nickname TEXT,
  user_avatar TEXT,
  text TEXT NOT NULL,
  likes INT DEFAULT 0,
  liked_by JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_punahub_comments_reel_id ON punahub_comments(reel_id);
CREATE INDEX IF NOT EXISTS idx_punahub_comments_parent_id ON punahub_comments(parent_id);

-- ═══════════════════════════════════════════════════════════
--  ROW LEVEL SECURITY (RLS) POLICIES
-- ═══════════════════════════════════════════════════════════

-- Disable RLS for development (enable for production)
ALTER TABLE punahub_users DISABLE ROW LEVEL SECURITY;
ALTER TABLE punahub_reels DISABLE ROW LEVEL SECURITY;
ALTER TABLE punahub_follows DISABLE ROW LEVEL SECURITY;
ALTER TABLE punahub_settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE punahub_push_subs DISABLE ROW LEVEL SECURITY;
ALTER TABLE punahub_notifs DISABLE ROW LEVEL SECURITY;
ALTER TABLE punahub_likes DISABLE ROW LEVEL SECURITY;
ALTER TABLE punahub_comments DISABLE ROW LEVEL SECURITY;

/*
-- PRODUCTION RLS POLICIES (uncomment when ready):

-- Users: only read own, admin can read all
ALTER TABLE punahub_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON punahub_users
  FOR SELECT USING (auth.email() = email);
CREATE POLICY "Users can update own data" ON punahub_users
  FOR UPDATE USING (auth.email() = email);

-- Reels: public read, only owner can update/delete
ALTER TABLE punahub_reels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Reels are publicly readable" ON punahub_reels FOR SELECT USING (true);
CREATE POLICY "Only owner can modify reel" ON punahub_reels
  FOR ALL USING (data->>'email' = auth.email());

-- Push subs: only owner can manage
ALTER TABLE punahub_push_subs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own push subs" ON punahub_push_subs
  FOR ALL USING (user_email = auth.email());

-- Notifications: only recipient can read
ALTER TABLE punahub_notifs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own notifications" ON punahub_notifs
  FOR SELECT USING (to_email = auth.email());
*/

-- ═══════════════════════════════════════════════════════════
--  REALTIME SUBSCRIPTIONS
-- ═══════════════════════════════════════════════════════════

-- Enable realtime for these tables
ALTER PUBLICATION supabase_realtime ADD TABLE punahub_notifs;
ALTER PUBLICATION supabase_realtime ADD TABLE punahub_follows;
ALTER PUBLICATION supabase_realtime ADD TABLE punahub_reels;
ALTER PUBLICATION supabase_realtime ADD TABLE punahub_likes;
ALTER PUBLICATION supabase_realtime ADD TABLE punahub_comments;
ALTER PUBLICATION supabase_realtime ADD TABLE punahub_push_subs;

-- ═══════════════════════════════════════════════════════════
--  STORAGE BUCKET
-- ═══════════════════════════════════════════════════════════

-- Create storage bucket for avatars and media
INSERT INTO storage.buckets (id, name, public) 
VALUES ('punahub', 'punahub', true) 
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════
--  TRIGGERS FOR UPDATED_AT
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_punahub_users_updated_at BEFORE UPDATE ON punahub_users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_punahub_reels_updated_at BEFORE UPDATE ON punahub_reels
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_punahub_follows_updated_at BEFORE UPDATE ON punahub_follows
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_punahub_push_subs_updated_at BEFORE UPDATE ON punahub_push_subs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ═══════════════════════════════════════════════════════════
--  NOTIFICATION TRIGGER (auto-insert on follow/like/comment)
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION create_notification()
RETURNS TRIGGER AS $$
DECLARE
  v_to_email TEXT;
  v_from_email TEXT;
  v_type TEXT;
  v_payload JSONB;
BEGIN
  -- Determine notification details based on table
  CASE TG_TABLE_NAME
    WHEN 'punahub_follows' THEN
      v_to_email := NEW.email;
      v_from_email := NEW.data->>'follower_email';
      v_type := 'follow';
      v_payload := jsonb_build_object(
        'id', gen_random_uuid(),
        'type', 'follow',
        'fromEmail', v_from_email,
        'toEmail', v_to_email,
        'timestamp', extract(epoch from now())
      );
    WHEN 'punahub_likes' THEN
      -- Get reel owner from reels table
      SELECT data->>'email' INTO v_to_email FROM punahub_reels WHERE id = NEW.reel_id;
      v_from_email := NEW.user_email;
      v_type := 'like';
      v_payload := jsonb_build_object(
        'id', gen_random_uuid(),
        'type', 'like',
        'fromEmail', v_from_email,
        'fromNickname', NEW.user_nickname,
        'fromAvatar', NEW.user_avatar,
        'toEmail', v_to_email,
        'reelId', NEW.reel_id,
        'timestamp', extract(epoch from now())
      );
    WHEN 'punahub_comments' THEN
      SELECT data->>'email' INTO v_to_email FROM punahub_reels WHERE id = NEW.reel_id;
      v_from_email := NEW.user_email;
      v_type := 'comment';
      v_payload := jsonb_build_object(
        'id', gen_random_uuid(),
        'type', 'comment',
        'fromEmail', v_from_email,
        'fromNickname', NEW.user_nickname,
        'fromAvatar', NEW.user_avatar,
        'toEmail', v_to_email,
        'reelId', NEW.reel_id,
        'commentText', NEW.text,
        'timestamp', extract(epoch from now())
      );
    ELSE
      RETURN NEW;
  END CASE;

  -- Only create notification if recipient is different from sender
  IF v_to_email IS NOT NULL AND v_to_email != v_from_email THEN
    INSERT INTO punahub_notifs (to_email, from_email, type, payload)
    VALUES (v_to_email, v_from_email, v_type, v_payload);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for notifications
DROP TRIGGER IF EXISTS trg_notify_on_follow ON punahub_follows;
CREATE TRIGGER trg_notify_on_follow
  AFTER INSERT ON punahub_follows
  FOR EACH ROW EXECUTE FUNCTION create_notification();

DROP TRIGGER IF EXISTS trg_notify_on_like ON punahub_likes;
CREATE TRIGGER trg_notify_on_like
  AFTER INSERT ON punahub_likes
  FOR EACH ROW EXECUTE FUNCTION create_notification();

DROP TRIGGER IF EXISTS trg_notify_on_comment ON punahub_comments;
CREATE TRIGGER trg_notify_on_comment
  AFTER INSERT ON punahub_comments
  FOR EACH ROW EXECUTE FUNCTION create_notification();

-- ═══════════════════════════════════════════════════════════
--  DONE!
-- ═══════════════════════════════════════════════════════════
SELECT 'PunaHub database setup complete!' as status;
