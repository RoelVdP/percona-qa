USE test;
SET SQL_MODE='';
SET AUTOCOMMIT=0;
CREATE TABLE t(c CHAR (0));
SET STATEMENT gtid_domain_id=0 FOR INSERT INTO t VALUES(0),(0);
SET GLOBAL init_connect="SET @a=0";