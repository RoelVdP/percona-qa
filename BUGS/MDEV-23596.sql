USE test;
SET SQL_MODE='';
CREATE TABLE t1 (a INT PRIMARY KEY, b INT, KEY(b)) ENGINE=Aria;
INSERT INTO t1 VALUES (0, 0),(1, 1);
CREATE TABLE t2 SELECT * FROM t1;
SELECT (SELECT 1 FROM t1 WHERE t1.a=t2.a ORDER BY t1.b LIMIT 1) AS c FROM t2;
