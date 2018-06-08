-- Convert schema 'share/migrations/_source/deploy/9/001-auto.yml' to 'share/migrations/_source/deploy/10/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE image_download_history ADD COLUMN etag text;

;

COMMIT;

