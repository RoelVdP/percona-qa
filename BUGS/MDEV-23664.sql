USE test;
CREATE TABLE t (h INT);
INSERT INTO t VALUES (0);
SELECT CAST(JSON_EXTRACT(h,0) as DECIMAL(1,1)) FROM t;
