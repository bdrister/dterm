<?php
// $Id: profileDB.php 2 2006-06-08 19:33:50Z tph $
// $HeadURL: http://sparkleplus.googlecode.com/svn/tags/release-0.3/profileDB.php $
// TryOpenDb and CloseDb - Open and close the database.
// Change the username, password, and database to the correct values for your database
	$DbLink = FALSE;
	$DbError = "";

function TryOpenDb()
{
	global $DbLink;
	global $DbError;

	global $db_host;
	global $db_user;
	global $db_password;
	global $db_name;

	/* Connecting, selecting database */
	$DbLink = mysql_connect($db_host, $db_user, $db_password);

	if (!$DbLink)
	{
		$DbError = mysql_error();
		return FALSE;
	}

	if (!mysql_select_db($db_name))
	{
		$DbError = mysql_error();
		CloseDb();
		return FALSE;
	}

	mysql_query("BEGIN");
	return $DbLink;
}

function CloseDb()
{
	global $DbLink;

	if ($DbLink)
	{
		mysql_query("COMMIT");
		mysql_close($DbLink);
		$DbLink = FALSE;
	}
}

function abortAndExit()
{
	global $DbLink;
	print "Aborting database communication: " . mysql_error();
	if ($DBLink) {
		mysql_query("ROLLBACK");
		mysql_close($DbLink);
		$DbLink = FALSE;
	}
	exit();
}

?>
