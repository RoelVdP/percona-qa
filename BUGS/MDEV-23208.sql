USE test;
SET SQL_MODE='';
CREATE FUNCTION f(z INT) RETURNS INT READS SQL DATA RETURN (SELECT x FROM t WHERE x = z);
CREATE TEMPORARY TABLE t (c INT) ENGINE=InnoDB;
SELECT f('a');
DROP TEMPORARY TABLES t;
SHOW FUNCTION CODE f;
