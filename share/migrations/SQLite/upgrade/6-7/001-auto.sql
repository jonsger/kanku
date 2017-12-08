-- Convert schema 'share/migrations/_source/deploy/6/001-auto.yml' to 'share/migrations/_source/deploy/7/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE role_request (
  id INTEGER PRIMARY KEY NOT NULL,
  user_id integer NOT NULL,
  creation_time integer NOT NULL,
  roles text NOT NULL,
  comment text NOT NULL,
  decision integer NOT NULL DEFAULT 0,
  decision_comment text NOT NULL,
  FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE ON UPDATE CASCADE
);

;
CREATE INDEX role_request_idx_user_id ON role_request (user_id);

;

COMMIT;

