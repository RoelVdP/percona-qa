CREATE TABLE t1 (pk INT AUTO_INCREMENT, i INT, e ENUM('foo','bar') AS (i) VIRTUAL, PRIMARY KEY (pk)) ENGINE=InnoDB;
INSERT INTO t1 (i) VALUES (1),(NULL),(1),(NULL),(2),(1),(2),(NULL);
ALTER TABLE t1 ADD COLUMN f DECIMAL;
CHECKSUM TABLE t1;
