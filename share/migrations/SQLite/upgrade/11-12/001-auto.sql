-- Convert schema 'share/migrations/_source/deploy/11/001-auto.yml' to 'share/migrations/_source/deploy/12/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE job_history ADD COLUMN pwrand text;

;

COMMIT;

