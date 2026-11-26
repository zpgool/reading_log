-- 독서 기록 앱 DB (PostgreSQL)
-- 실행: createdb reading_app && psql -d reading_app -f db/reading_log.sql

DROP TABLE IF EXISTS reading_log;
DROP TABLE IF EXISTS book;

-- 책
CREATE TABLE book (
  book_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title   VARCHAR(100) NOT NULL,
  author  VARCHAR(50)  NOT NULL
);

-- 독서 기록 (타이머 1회 측정 = 1행, 측정 중이면 ended_at이 NULL)
CREATE TABLE reading_log (
  log_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  book_id    INT NOT NULL REFERENCES book(book_id),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at   TIMESTAMPTZ,
  CHECK (ended_at >= started_at)
);
