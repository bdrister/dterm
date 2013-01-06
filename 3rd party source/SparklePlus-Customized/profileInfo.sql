-- $Id: profileInfo.sql 3 2006-06-09 22:30:25Z atomicbird $
-- $HeadURL: http://sparkleplus.googlecode.com/svn/tags/release-0.3/profileInfo.sql $

-- The schema may look a little boneheaded in that it will accept any sort of key/value pair and uses
-- two tables where one would be sufficient.  It was done this way so that it'll be flexible enough to
-- handle a varying set of keys.  If/when new keys are added to Sparkle, it'd be nice if developers using
-- the previous version could keep using the same tables as-is instead of altering or re-creating them.
DROP TABLE IF EXISTS reportRecord;
DROP TABLE IF EXISTS profileReport;

-- There's one of these per appcast lookup
CREATE TABLE profileReport (
		REPORT_ID	INT NOT NULL AUTO_INCREMENT,
		IP_ADDR		CHAR(16) NOT NULL,
		REPORT_DATE	DATETIME NOT NULL,

		PRIMARY KEY(REPORT_ID)
) ENGINE=InnoDB;

-- There's one of these per profile key/value pair.  Each must reference an entry in profileReport.
CREATE TABLE reportRecord (
		RECORD_ID	INT NOT NULL AUTO_INCREMENT,
		REPORT_KEY	VARCHAR(255) NOT NULL,
		REPORT_VALUE	VARCHAR(255) NOT NULL,
		REPORT_ID	INT NOT NULL,

		FOREIGN KEY(REPORT_ID) REFERENCES profileReport(REPORT_ID),
		PRIMARY KEY (RECORD_ID)
) ENGINE=InnoDB;
