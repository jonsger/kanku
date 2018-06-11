-- Convert schema 'share/migrations/_source/deploy/10/001-auto.yml' to 'share/migrations/_source/deploy/11/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE job_history ADD COLUMN trigger_user text;

;

COMMIT;

