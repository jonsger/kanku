-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Sun Apr 24 22:03:42 2016
-- 

;
BEGIN TRANSACTION;
--
-- Table: image_download_history
--
CREATE TABLE image_download_history (
  vm_image_url text NOT NULL,
  vm_image_file text,
  download_time integer,
  PRIMARY KEY (vm_image_url)
);
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
-- Table: obs_check_history
--
CREATE TABLE obs_check_history (
  id INTEGER PRIMARY KEY NOT NULL,
  api_url text,
  project text,
  package text,
  vm_image_url text,
  check_time integer
);
CREATE UNIQUE INDEX unique_obscheck ON obs_check_history (api_url, project, package);
--
-- Table: role
--
CREATE TABLE role (
  id INTEGER PRIMARY KEY NOT NULL,
  role varchar(32) NOT NULL
);
--
-- Table: user
--
CREATE TABLE user (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(32) NOT NULL,
  password varchar(40),
  name varchar(128),
  email varchar(255),
  deleted boolean NOT NULL DEFAULT 0,
  lastlogin datetime,
  pw_changed datetime,
  pw_reset_code varchar(255)
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
--
-- Table: user_roles
--
CREATE TABLE user_roles (
  user_id integer NOT NULL,
  role_id integer NOT NULL,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY (role_id) REFERENCES role(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX user_roles_idx_role_id ON user_roles (role_id);
CREATE INDEX user_roles_idx_user_id ON user_roles (user_id);
COMMIT;
