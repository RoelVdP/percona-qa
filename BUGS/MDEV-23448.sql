USE test;
INSTALL SONAME 'ha_archive';
CREATE TEMPORARY TABLE t2 (c1 INT UNSIGNED ZEROFILL) ENGINE=ARCHIVE;
REPAIR NO_WRITE_TO_BINLOG TABLE t2 EXTENDED;
SELECT * FROM t2 WHERE c1 < 1;
