<?
// This is where all the server-side configuration happens.
// Location of the real appcast file
// $Id: profileConfig.php 17 2006-06-13 18:54:00Z schwa $
// $HeadURL: http://sparkleplus.googlecode.com/svn/tags/release-0.3/profileConfig.php $
$appcastURL = "http://ironcoder.org/svn/SparklePlus/trunk/sparkletestcast.xml";

// This is an associative array of all "good" keys expected from clients.
$appcastKeys = array('appName' => 1, 'appVersion' => 1, 'cpuFreqMHz' => 1, 'cpusubtype' => 1, 'cputype' => 1, 'lang' => 1, 'model' => 1, 'ncpu' => 1, 'osVersion' => 1, 'ramMB' => 1);

// Database connectivity
$db_host	= "DATABASE HOST";
$db_user	= "DATABASE USER NAME";
$db_password	= "DATABASE PASSWORD";
$db_name	= "DATABASE_NAME";
// end configuration
?>
