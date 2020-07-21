SET max_heap_table_size= 1048576;
CREATE TABLE t1 (a INT);
INSERT INTO t1 VALUES (1),(2);
CREATE TABLE t2 (a INT,  b INT, c VARCHAR(3), d VARCHAR(35));
INSERT INTO t2 (a) SELECT seq FROM seq_1_to_130;
SET optimizer_switch = 'derived_merge=off';
SELECT * FROM t1, ( SELECT t2a.* FROM t2 AS t2a, t2 AS t2b ) AS sq;

SET max_heap_table_size= 1048576;
CREATE  TABLE t1 (a VARCHAR(4000), b INT);
INSERT INTO t1 SELECT '', seq FROM seq_1_to_258;
CREATE  TABLE t2 (c INT);
INSERT INTO t2 VALUES (1),(2);
CREATE ALGORITHM=TEMPTABLE VIEW v1 AS SELECT * FROM t1;
SELECT c FROM v1, t2 WHERE c = 1;