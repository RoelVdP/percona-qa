USE test;
SET COLLATION_CONNECTION=utf32_myanmar_ci, CHARACTER_SET_CLIENT=binary;
CREATE TABLE t (a CHAR(1));
ALTER TABLE t CHANGE a a ENUM('a','a') CHARACTER SET utf32;

USE test;
SET SQL_MODE='';
SET MAX_SORT_LENGTH=29;
SET COLLATION_CONNECTION=utf32_unicode_ci;
CREATE TEMPORARY TABLE t1 (a INT);
INSERT INTO t1 VALUES (_ucs2 0x00fd),(_ucs2 0x00dd);
SELECT * FROM t1 ORDER BY (oct(a));

USE test;
SET COLLATION_CONNECTION=utf32_czech_ci;
CREATE TABLE t (a INT);
INSERT INTO t VALUES (1);
SELECT 1 FROM t ORDER BY @x:=makedate(a,a);
