USE test;
SET @@SESSION.sql_mode=TRADITIONAL;
CREATE TABLE t (id INT) ENGINE=Aria;
ALTER TABLE t ADD COLUMN c DATETIME NOT NULL,ALGORITHM=INPLACE;
