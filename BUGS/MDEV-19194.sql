CREATE TABLE tx (pk INT PRIMARY KEY) ENGINE=InnoDB;
CREATE TABLE t1 (a INT, CONSTRAINT fk FOREIGN KEY (a) REFERENCES tx(pk)) ENGINE=InnoDB;
ALTER IGNORE TABLE t1 DROP FOREIGN KEY fk, DROP FOREIGN KEY fk, ALGORITHM=COPY;
