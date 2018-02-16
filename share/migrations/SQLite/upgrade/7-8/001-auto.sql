-- Convert schema 'share/migrations/_source/deploy/7/001-auto.yml' to 'share/migrations/_source/deploy/8/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE job_history_comment (
  id INTEGER PRIMARY KEY NOT NULL,
  job_id integer,
  user_id integer,
  comment text,
  FOREIGN KEY (job_id) REFERENCES job_history(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY (user_id) REFERENCES user(id)
);

;
CREATE INDEX job_history_comment_idx_job_id ON job_history_comment (job_id);

;
CREATE INDEX job_history_comment_idx_user_id ON job_history_comment (user_id);

;

COMMIT;

