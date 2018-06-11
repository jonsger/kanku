-- Convert schema 'share/migrations/_source/deploy/11/001-auto.yml' to 'share/migrations/_source/deploy/10/001-auto.yml':;

;
BEGIN;

;
CREATE TEMPORARY TABLE job_history_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  name text,
  state text,
  args text,
  result text,
  creation_time integer DEFAULT 0,
  start_time integer DEFAULT 0,
  end_time integer DEFAULT 0,
  last_modified integer DEFAULT 0,
  workerinfo text,
  masterinfo text
);

;
INSERT INTO job_history_temp_alter( id, name, state, args, result, creation_time, start_time, end_time, last_modified, workerinfo, masterinfo) SELECT id, name, state, args, result, creation_time, start_time, end_time, last_modified, workerinfo, masterinfo FROM job_history;

;
DROP TABLE job_history;

;
CREATE TABLE job_history (
  id INTEGER PRIMARY KEY NOT NULL,
  name text,
  state text,
  args text,
  result text,
  creation_time integer DEFAULT 0,
  start_time integer DEFAULT 0,
  end_time integer DEFAULT 0,
  last_modified integer DEFAULT 0,
  workerinfo text,
  masterinfo text
);

;
INSERT INTO job_history SELECT id, name, state, args, result, creation_time, start_time, end_time, last_modified, workerinfo, masterinfo FROM job_history_temp_alter;

;
DROP TABLE job_history_temp_alter;

;

COMMIT;

