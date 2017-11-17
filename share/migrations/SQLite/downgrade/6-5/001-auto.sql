-- Convert schema 'share/migrations/_source/deploy/6/001-auto.yml' to 'share/migrations/_source/deploy/5/001-auto.yml':;

;
BEGIN;

;
DROP INDEX api_url_project_package_unique;

;
CREATE UNIQUE INDEX unique_obscheck ON obs_check_history (api_url, project, package);

;
CREATE TEMPORARY TABLE role_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  role varchar(32) NOT NULL
);

;
INSERT INTO role_temp_alter( id, role) SELECT id, role FROM role;

;
DROP TABLE role;

;
CREATE TABLE role (
  id INTEGER PRIMARY KEY NOT NULL,
  role varchar(32) NOT NULL
);

;
INSERT INTO role SELECT id, role FROM role_temp_alter;

;
DROP TABLE role_temp_alter;

;
CREATE TEMPORARY TABLE user_temp_alter (
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

;
INSERT INTO user_temp_alter( id, username, password, name, email, deleted, lastlogin, pw_changed, pw_reset_code) SELECT id, username, password, name, email, deleted, lastlogin, pw_changed, pw_reset_code FROM user;

;
DROP TABLE user;

;
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

;
INSERT INTO user SELECT id, username, password, name, email, deleted, lastlogin, pw_changed, pw_reset_code FROM user_temp_alter;

;
DROP TABLE user_temp_alter;

;
DROP INDEX user_roles_fk_role_id;

;
DROP INDEX user_roles_fk_user_id;

;

;

;
DROP TABLE ws_session;

;
DROP TABLE wstoken;

;

COMMIT;

