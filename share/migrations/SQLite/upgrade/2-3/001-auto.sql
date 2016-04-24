-- Convert schema 'share/migrations/_source/deploy/2/001-auto.yml' to 'share/migrations/_source/deploy/3/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE image_download_history (
  vm_image_url text NOT NULL,
  vm_image_file text,
  download_time integer,
  PRIMARY KEY (vm_image_url)
);

;
CREATE TABLE obs_check_history (
  id INTEGER PRIMARY KEY NOT NULL,
  api_url text,
  project text,
  package text,
  vm_image_url text,
  check_time integer
);

;
CREATE UNIQUE INDEX unique_obscheck ON obs_check_history (api_url, project, package);

;

COMMIT;

