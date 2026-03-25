-- M10: Timed strength exercises + Strava activity type expansion

-- Add is_timed flag to strength template exercises (planks, side planks, etc.)
ALTER TABLE strength_template_exercises ADD COLUMN is_timed boolean NOT NULL DEFAULT false;

-- Add is_timed flag to strength sessions
ALTER TABLE strength_sessions ADD COLUMN is_timed boolean NOT NULL DEFAULT false;

-- Add activity_type to strava_activities for non-run activities
ALTER TABLE strava_activities ADD COLUMN activity_type text NOT NULL DEFAULT 'Run';
