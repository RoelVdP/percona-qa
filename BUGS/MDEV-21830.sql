USE test;
CREATE TABLE t1 (c1 INT) ENGINE=Aria;
CREATE TABLE t2 (c1 INT) ENGINE=Aria;
LOCK TABLES t2 AS a WRITE, t1 AS b WRITE;
CREATE TRIGGER t BEFORE INSERT ON t2 FOR EACH ROW SET @a=1;

CREATE TABLE t1 (a INT) ENGINE=Aria PARTITION BY RANGE(a) (PARTITION p1 VALUES LESS THAN (10));
CREATE TABLE t2 (a INT) ENGINE=Aria;
LOCK TABLE t1 WRITE, t2 READ;
ALTER TABLE t1 ADD PARTITION (PARTITION p2 VALUES LESS THAN (20));

CREATE TABLE t1 (a INT) ENGINE=Aria;
CREATE TABLE t2 (b INT) ENGINE=Aria;
LOCK TABLE t2 WRITE, t1 WRITE;
CREATE TRIGGER tr BEFORE DELETE ON t1 FOR EACH ROW SET @a= 1;
