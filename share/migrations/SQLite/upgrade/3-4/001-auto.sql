-- Convert schema 'share/migrations/_source/deploy/3/001-auto.yml' to 'share/migrations/_source/deploy/4/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE job_history ADD COLUMN worker text;

;

COMMIT;

