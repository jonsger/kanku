-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Sun Feb 14 23:34:44 2016
-- 

;
BEGIN TRANSACTION;
--
-- Table: job_history
--
CREATE TABLE job_history (
  id INTEGER PRIMARY KEY NOT NULL,
  name text,
  state text,
  args text,
  result text,
  creation_time integer DEFAULT 0,
  start_time integer DEFAULT 0,
  end_time integer DEFAULT 0,
  last_modified integer DEFAULT 0
);
--
-- Table: job_history_sub
--
CREATE TABLE job_history_sub (
  id INTEGER PRIMARY KEY NOT NULL,
  job_id integer,
  name text,
  state text,
  result text,
  FOREIGN KEY (job_id) REFERENCES job_history(id) ON DELETE CASCADE ON UPDATE NO ACTION
);
CREATE INDEX job_history_sub_idx_job_id ON job_history_sub (job_id);
COMMIT;
