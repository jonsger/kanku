-- Convert schema 'share/migrations/_source/deploy/1/001-auto.yml' to 'share/migrations/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE role (
  id INTEGER PRIMARY KEY NOT NULL,
  role varchar(32) NOT NULL
);

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
CREATE TABLE user_roles (
  user_id integer NOT NULL,
  role_id integer NOT NULL,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY (role_id) REFERENCES role(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE ON UPDATE CASCADE
);

;
CREATE INDEX user_roles_idx_role_id ON user_roles (role_id);

;
CREATE INDEX user_roles_idx_user_id ON user_roles (user_id);

;

COMMIT;

