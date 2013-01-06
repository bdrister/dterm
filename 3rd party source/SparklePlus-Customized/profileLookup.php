<html>
<head>
<title>Sparkle Profile Data Lookup</title>
</head>
<body>
<?php

// $Id: profileLookup.php 6 2006-06-09 23:50:23Z atomicbird $
// $HeadURL: http://sparkleplus.googlecode.com/svn/tags/release-0.3/profileLookup.php $
require("profileConfig.php");
require("profileDB.php");
$debug = 0;

/*
   always do a lookup.
   if start and end specified, use them if valid.
   if only end set, use start of 1 month ago
   if neither set, use default start & end
   */
// If end is set, make sure it looks like a date
if (isset($_GET['end']) && (dateValidate($_GET['end']))) {
	$end_date = $_GET['end'];
} else {
	// default end date is now
	$end_date = strftime("%Y-%m-%d %H:%M:%S");
}
// check that start looks like a date
if (dateValidate($_GET['start'])) {
	$start_date = $_GET['start'];
} else {
	// default start date is one month before end date
	$start_timestamp = strtotime("$end_date 1 month ago");
	$start_date = strftime("%Y-%m-%d %H:%M:%S", $start_timestamp);
}

profileLookup();

function dateValidate($date) {
	if (preg_match('/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/', $date)) {
		$timestamp = strtotime($date);
		return checkdate(date('m',$timestamp), date('d',$timestamp), date('Y',$timestamp));
	} else {
		return 0;
	}
}

function profileLookupForm() {
}

function profileLookup() {
	global $start_date, $end_date;
	// connect to the database
	if (!TryOpenDB()) {
		abortAndExit();
	}

	// Get REPORT_ID for all reports between specified dates.
	//$start_date = '2006-01-01';
	//$end_date = strftime("%Y-%m-%d %H:%m:%S");

	print "<table>\n";
	print "<tr><td>Start date:</td><td>$start_date</td>\n";
	print "<tr><td>End date:</td><td>$end_date</td>\n";
	print "</table>\n";

	$queryString = "select REPORT_ID,REPORT_DATE from profileReport where REPORT_DATE >= '" . $start_date . "' and REPORT_DATE <= '" . $end_date . " ORDER BY REPORT_DATE'";
	//print "query: $queryString<br />\n";
	// report_ids will be an associative array: keys=report_ids, values=dates
	$report_ids_lookup = mysql_query($queryString);
	if (!$report_ids_lookup) {
		abortAndExit();
		//print "Could not look up row IDs with query $queryString<br />\n";
	}
	if (mysql_num_rows($report_ids_lookup) == 0) {
		print "<p>No reports found in this date range</p>\n";
		return;
	}
	while ($row = mysql_fetch_assoc($report_ids_lookup)) {
		//print $row['REPORT_ID'] . ": " . $row['REPORT_DATE'];
		$report_ids[$row['REPORT_ID']] = $row['REPORT_DATE'];
	}
	mysql_free_result($report_ids_lookup);

	if ($debug) {
		print "Report IDs:<br />\n";
		print_r($report_ids);
		print "<br \>\n";
	}

	// Now dsplay a table of reported data for these REPORT_IDs.
	// Could find keys in advance using "select REPORT_KEY from reportRecord group by REPORT_KEY"
	// knownReportKeys is a (non-associative) array where each entry is a key used in a profile report.
	$knownReportKeysLookup = mysql_query("select REPORT_KEY from reportRecord group by REPORT_KEY");
	if (!$knownReportKeysLookup) {
		abortAndExit();
	}
	while ($row = mysql_fetch_array($knownReportKeysLookup)) {
		$knownReportKeys[] = $row[0];
	}
	mysql_free_result($knownReportKeysLookup);

	if ($debug) {
		print "known keys:<br />\n";
		print_r($knownReportKeys);
	}
	print "<table><tr><td>Date</td>\n";
	foreach($knownReportKeys as $reportKey) {
		print "<td>$reportKey</td>\n";
	}
	print "</td>\n";

	while(list($report_id, $report_date) = each($report_ids)) {
		$queryString = "select REPORT_KEY,REPORT_VALUE from reportRecord where REPORT_ID='" . $report_id . "'";
		// report_records will be an assoc array, keys from knownReportKeys, values with the corresponding value
		$reportRecordsLookup = mysql_query($queryString);
		if (!$reportRecordsLookup) {
			abortAndExit();
		}
		while ($row = mysql_fetch_assoc($reportRecordsLookup)) {
			$reportRecords[$row['REPORT_KEY']] = $row['REPORT_VALUE'];
		}
		mysql_free_result($reportRecordsLookup);
		if ($debug) {
			print "<br />report records: <br />\n";
			print_r($reportRecords);
			print "<br />\n";
		}
		print "<tr><td>$report_date</td>\n";
		foreach($knownReportKeys as $reportKey) {
			print "<td>" . $reportRecords[$reportKey] . "</td>\n";
		}
		print "</tr>\n";
	}
	print "</table>\n";

	CloseDB();
}
?>

</body>
</html>

