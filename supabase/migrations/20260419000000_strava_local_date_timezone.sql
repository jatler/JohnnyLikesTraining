-- Record Strava activities with their local date + timezone so that day-matching
-- reflects where the run was recorded, not where the user currently is.
--
-- start_date_local is a wall-clock timestamp in the activity's own timezone
-- (Strava emits it as UTC-marked ISO-8601, but the hours/minutes are local).
-- time_zone_identifier is the IANA zone id like "America/Los_Angeles".

ALTER TABLE strava_activities ADD COLUMN start_date_local timestamptz;
ALTER TABLE strava_activities ADD COLUMN time_zone_identifier text;

-- Backfill existing rows: best-effort fill from activity_date (UTC). These rows
-- will naturally re-populate with accurate local dates on the next Strava sync
-- (upsert by strava_id). time_zone_identifier stays NULL for legacy rows.
UPDATE strava_activities
SET start_date_local = activity_date::timestamptz
WHERE start_date_local IS NULL;
