#!/usr/bin/perl
#File Parser For Martin Gordon Mess
use strict;
use warnings;
use File::Find;
use File::Basename;
use Storable;
use XML::LibXML;
use File::Copy;
use Perl6::Say;

# STYLE: QUICK AND DIRTY

=head1 NAME

Rename78.pl - rename the files in a special collection transparently

=head1 USAGE

Rename78.pl -h|--help			show this help

Rename78.pl source_directory  [start_tape]	
	read in source directory in file cache and proceed, start with start_tape if specified
								

Rename78.pl internal_command    process one of the internal commands


=head1 DESCRIPTION

This little script looks recursively from the specified directory for .wav files
with a specific name pattern and extract the tape, and track number from this name. 
(There is also a take number, but hopefully you don't need to bother about that). 

Then the script looks for an xml file which has the metadata from the database (mpx). 
The script attempts to lookup info in the database to determine good new filenames 
for the tracks.

I expect you to run the script the first time to read in the original 
file names. It suggests a mapping of old file names to new filenames. You can check it with
internal command show_file_map and if it's right you can commit the changes by the internal 
command copy.

I included a number of tests to check more easily if the outcome is right (see internal 
commands below). Make sure you check the report on missing associations (show_missing), 
all warnings (show_warnings) and the file map (show_file_map) before you commit the 
changes (copy). 

=head1 COMMAND LINE OPTIONS

-h or --help	display this help

=head1 INTERNAL COMMANDs

Rename78.pl stores some information in tmp file caches. So you don't have to run
everything again all the time. And you can let it run several times.

=cut

###
### in-file configuration; do change here
###

#dirs
my $home_dir = $ENV{'HOME'};
my $tmp_dir  = "$home_dir/tmp";    # on laptop
my $dest_dir =
    "/cygdrive/M/MuseumPlus/Produktiv/Multimedia/EM/Medienarchiv"
  . "/Audio/Archiv/VII_78";        #dir where files are copied
my $dest_dir =
    "/cygdrive/E/Neu/";


%main::config = (
	'home_dir'          => $ENV{'HOME'},
	'tmp_dir'           => "$home_dir/tmp",                   # on laptop
	'stored_map_fn'     => "$tmp_dir/78er_file_map.tmp",      # maping old new
	'stored_fc_fn'      => "$tmp_dir/78er_file_cache.tmp",    # file cache
	'stored_missing_fn' =>
	  "$tmp_dir/78er_missing.tmp",    # info missing tape/id pairs
	'stored_warnings_fn' => "$tmp_dir/78er_warnings.tmp",
	'stored_id_cache_fn' => "$tmp_dir/78er_id_cache.tmp",
	'xml'                => "$home_dir/EMEM-78test.lvl3.220708.mpx"
);

#list cases where xml/db title info is wrong or misleading!
#i will assume that each record has two sides.
#List only cases where a record has one side or overwrite wrong info in xml
#	2  => { 19 => [ 'VII 78/0043', 1 ], },
# 	24 => { 1  => [ 'VII 78/0725', 1 ], },
#	35 => { 15 => [ 'VII 78/0630', 1 ], }, nicht bespielt
# 	108 => {1 => ['VII 78/2245'],1}

%main::exceptions = (
	35 => {
		11 => [ 'VII 78/0626', 1 ]
		,    # does have 2 sides, but audio for 2nd side is missing!
	},
	36 => {
		5  => [ 'VII 78/063740', 1 ],
		5  => [ 'VII 78/0640',   1 ],
		6  => [ 'VII 78/0641',   1 ],
		8  => [ 'VII 78/0643',   1 ],
		9  => [ 'VII 78/0644',   1 ],
		24 => [ 'VII 78/0659',   1 ],
	},
	37 => {
		2 => [ 'VII 78/0664', 1 ],
		5 => [ 'VII 78/0667', 2 ],
		8 => [ 'VII 78/0670', 2 ]
	},

	41 => { 17 => [ 'VII 78/1065', 1 ], },
	54 => {
		16 => [ 'VII 78/1019', 1 ],
		17 => [ 'VII 78/1020', 1 ],
		18 => [ 'VII 78/1021', 1 ],
		19 => [ 'VII 78/1022', 1 ],
		20 => [ 'VII 78/1023', 1 ],
		21 => [ 'VII 78/1024', 1 ],
		22 => [ 'VII 78/1025', 1 ],
		23 => [ 'VII 78/1026', 1 ],
	},
	54 => {
		16 => [ 'VII 78/1019', 1 ],
		17 => [ 'VII 78/1020', 1 ],
		18 => [ 'VII 78/1021', 1 ],
		19 => [ 'VII 78/1022', 1 ],
		20 => [ 'VII 78/1023', 1 ],
		21 => [ 'VII 78/1024', 1 ],
		22 => [ 'VII 78/1025', 1 ],
		23 => [ 'VII 78/1026', 1 ],
	},
	55 => {    #nach Autopsie, 41 files on hard disk
		1  => [ 'VII 78/1027', 1 ],    #1
		2  => [ 'VII 78/1028', 1 ],    #2
		3  => [ 'VII 78/1029', 1 ],    #3
		4  => [ 'VII 78/1030', 2 ],    #4
		5  => [ 'VII 78/1031', 2 ],    #6
		6  => [ 'VII 78/1032', 2 ],    #8
		7  => [ 'VII 78/1033', 2 ],    #10
		8  => [ 'VII 78/1034', 2 ],    #12
		9  => [ 'VII 78/1035', 2 ],    #14
		10 => [ 'VII 78/1036', 2 ],    #16
		11 => [ 'VII 78/1037', 2 ],    #18
		12 => [ 'VII 78/1038', 2 ],    #20
		13 => [ 'VII 78/1039', 2 ],    #22
		14 => [ 'VII 78/1040', 2 ],    #24
		15 => [ 'VII 78/1041', 2 ],    #26
		16 => [ 'VII 78/1042', 1 ],    #28
		17 => [ 'VII 78/1043', 1 ],    #29
		18 => [ 'VII 78/1044', 1 ],    #30
		19 => [ 'VII 78/1045', 1 ],    #31
		20 => [ 'VII 78/1046', 1 ],    #32
		21 => [ 'VII 78/1047', 1 ],    #33
		22 => [ 'VII 78/1048', 1 ],    #34
		23 => [ 'VII 78/1049', 1 ],    #35
		24 => [ 'VII 78/1050', 1 ],    #36
		25 => [ 'VII 78/1051', 1 ],    #37
		26 => [ 'VII 78/1052', 1 ],    #38
		27 => [ 'VII 78/1053', 1 ],    #39
		28 => [ 'VII 78/1054', 1 ],    #40
		29 => [ 'VII 78/1055', 1 ],    #41

	},

# alle einseitig, NB 1088 hat 2 Tracks und 1093 hat 2 Seiten (war nicht richtig)
	56 => {                            #Autopsie 40 Tracks, but 41 Files
		1  => [ 'VII 78/1056', 1 ],    #1
		2  => [ 'VII 78/1057', 1 ],    #2
		3  => [ 'VII 78/1058', 1 ],    #3
		4  => [ 'VII 78/1059', 1 ],    #4
		5  => [ 'VII 78/1060', 1 ],    #5
		6  => [ 'VII 78/1061', 1 ],    #6
		7  => [ 'VII 78/1062', 1 ],    #7
		8  => [ 'VII 78/1063', 1 ],    #8
		9  => [ 'VII 78/1064', 1 ],    #9
		10 => [ 'VII 78/1065', 1 ],    #10
		11 => [ 'VII 78/1066', 1 ],    #11
		12 => [ 'VII 78/1067', 1 ],    #12
		13 => [ 'VII 78/1068', 1 ],    #13
		14 => [ 'VII 78/1069', 1 ],    #14
		15 => [ 'VII 78/1070', 1 ],    #15
		16 => [ 'VII 78/1071', 1 ],    #16
		17 => [ 'VII 78/1072', 1 ],    #17
		18 => [ 'VII 78/1073', 1 ],    #18
		19 => [ 'VII 78/1074', 1 ],    #19
		20 => [ 'VII 78/1075', 1 ],    #20
		21 => [ 'VII 78/1076', 1 ],    #21
		22 => [ 'VII 78/1077', 1 ],    #22
		23 => [ 'VII 78/1078', 1 ],    #23
		24 => [ 'VII 78/1079', 1 ],    #24
		25 => [ 'VII 78/1080', 1 ],    #25
		26 => [ 'VII 78/1081', 1 ],    #26
		27 => [ 'VII 78/1082', 2 ],    #27
		28 => [ 'VII 78/1083', 1 ],    #29
		29 => [ 'VII 78/1084', 1 ],    #30
		30 => [ 'VII 78/1085', 2 ],    #31
		31 => [ 'VII 78/1086', 1 ],    #33
		32 => [ 'VII 78/1087', 1 ],    #34
		33 => [ 'VII 78/1088', 1 ],    #35
		34 => [ 'VII 78/1089', 1 ],    #36
		35 => [ 'VII 78/1090', 1 ],    #37
		36 => [ 'VII 78/1091', 1 ],    #38
		37 => [ 'VII 78/1092', 1 ],    #39
		38 => [ 'VII 78/1093', 2 ],    #40,41
	},
	57 => {
		10 => [ 'VII 78/1103', 1 ],
		14 => [ 'VII 78/1107', 2 ],
		15 => [ 'VII 78/1108', 1 ],
		18 => [ 'VII 78/1111', 1 ],
		23 => [ 'VII 78/1116', 1 ],
		24 => [ 'VII 78/1117', 1 ],
		27 => [ 'VII 78/1120', 1 ],
		28 => [ 'VII 78/1121', 1 ],
		29 => [ 'VII 78/1122', 1 ],
		30 => [ 'VII 78/1123', 1 ],
		31 => [ 'VII 78/1124', 1 ],
	},    # ?? Schallplatten laut DB, 37 Files TODO
	58 => {
		19 => [ 'VII 78/1146', 1 ],
		20 => [ 'VII 78/1147', 1 ],
		21 => [ 'VII 78/1148', 1 ],
		22 => [ 'VII 78/1149', 1 ],
		23 => [ 'VII 78/1150', 1 ],

	},    # 32 Schallplatten laut DB, 41 Files bei Martin
	61 => {
		8  => [ 'VII 78/1204', 1 ],
		9  => [ 'VII 78/1205', 1 ],
		11 => [ 'VII 78/1207', 1 ],
		15 => [ 'VII 78/1211', 1 ],
		17 => [ 'VII 78/1213', 1 ],
		22 => [ 'VII 78/1218', 1 ],
		24 => [ 'VII 78/1220', 1 ],
		25 => [ 'VII 78/1221', 1 ],
		28 => [ 'VII 78/1224', 1 ],
		29 => [ 'VII 78/1225', 1 ],
		30 => [ 'VII 78/1226', 1 ],
		31 => [ 'VII 78/1227', 1 ],
		34 => [ 'VII 78/1230', 1 ],
		35 => [ 'VII 78/1231', 1 ],
		38 => [ 'VII 78/1234', 1 ],

	},    # 40 Platten laut DB, 41 Files bei Martin
	62 => {
		1  => [ 'VII 78/1237', 1 ],    # 1
		2  => [ 'VII 78/1238', 1 ],    # 2
		3  => [ 'VII 78/1239', 2 ],    # 3,4laut Atopsie 1?
		4  => [ 'VII 78/1240', 2 ],    # 5,6
		5  => [ 'VII 78/1241', 2 ],    # 7,8
		6  => [ 'VII 78/1242', 2 ],    # 9,10
		7  => [ 'VII 78/1243', 2 ],    # 11,12
		8  => [ 'VII 78/1244', 2 ],    # 13,14
		9  => [ 'VII 78/1245', 1 ],    # 15
		10 => [ 'VII 78/1246', 2 ],    # 16,17
		11 => [ 'VII 78/1247', 2 ],    #18,19
		12 => [ 'VII 78/1248', 1 ],    #20
		13 => [ 'VII 78/1249', 1 ],    #21
		14 => [ 'VII 78/1250', 1 ],    #22
		15 => [ 'VII 78/1251', 1 ],    #23

		16 => [ 'VII 78/1252', 2 ],    #24,25
		17 => [ 'VII 78/1253', 2 ],    #26,27
		18 => [ 'VII 78/1255', 2 ],    #28,29

		19 => [ 'VII 78/1256', 2 ],    #30,31
		20 => [ 'VII 78/1257', 2 ],    #32,33
		21 => [ 'VII 78/1258', 2 ],    #34,35
		21 => [ 'VII 78/1259', 2 ],    #36,37

	}, # 22 Platten laut DB, 37 Files bei Martin, wir brauchen 7 mit einer Seite
	68 => {
		12 => [ 'VII 78/1384', 2 ],  # A: does have 2 sides, db indicates only 1
		15 => [ 'VII 78/1387', 2 ],  # A: does have 2 sides, db indicates only 1
	},
	71 =>
	  { #41 Files von Martin, 21 Platten laut DB, nach Autopsie folgende Korrekturen
		15 => [ 'VII 78/1448', 2 ],
		16 => [ 'VII 78/1449', 2 ],
		17 => [ 'VII 78/1450', 2 ],
		18 => [ 'VII 78/1451', 2 ],
		19 => [ 'VII 78/1452', 2 ],
		20 => [ 'VII 78/1453', 2 ],
		21 => [ 'VII 78/1454', 2 ],
	  },
	72 => {
		1  => [ 'VII 78/1455', 2 ],  # A: does have 2 sides, db indicates only 1
		2  => [ 'VII 78/1456', 2 ],
		3  => [ 'VII 78/1457', 2 ],
		4  => [ 'VII 78/1458', 2 ],
		5  => [ 'VII 78/1459', 2 ],
		6  => [ 'VII 78/1460', 2 ],
		7  => [ 'VII 78/1461', 2 ],
		8  => [ 'VII 78/1462', 2 ],
		9  => [ 'VII 78/1463', 2 ],
		10 => [ 'VII 78/1464', 2 ],
		11 => [ 'VII 78/1465', 2 ],
		12 => [ 'VII 78/1466', 2 ],
		13 => [ 'VII 78/1467', 2 ],
		14 => [ 'VII 78/1468', 2 ],
		15 => [ 'VII 78/1469', 2 ],
		16 => [ 'VII 78/1470', 2 ],
		17 => [ 'VII 78/1471', 2 ],
		18 => [ 'VII 78/1472', 2 ],
		19 => [ 'VII 78/1473', 2 ],
		20 => [ 'VII 78/1474', 2 ],
	},
	73 => { 9  => [ 'VII 78/1483', 2 ], },
	74 => { 21 => [ 'VII 78/1516', 2 ], },
	75 => {
		3  => [ 'VII 78/1516', 2 ],
		21 => [ 'VII 78/1538', 2 ],
	},
	76 => {
		1  => [ 'VII 78/1539', 2 ],
		2  => [ 'VII 78/1540', 2 ],
		3  => [ 'VII 78/1541', 2 ],
		4  => [ 'VII 78/1542', 2 ],
		5  => [ 'VII 78/1543', 2 ],
		6  => [ 'VII 78/1544', 2 ],
		7  => [ 'VII 78/1545', 2 ],
		8  => [ 'VII 78/1546', 2 ],
		9  => [ 'VII 78/1547', 2 ],
		10 => [ 'VII 78/1548', 2 ],
		11 => [ 'VII 78/1549', 2 ],
		12 => [ 'VII 78/1550', 2 ],
		13 => [ 'VII 78/1551', 2 ],
		14 => [ 'VII 78/1552', 2 ],
		15 => [ 'VII 78/1553', 2 ],
		16 => [ 'VII 78/1554', 2 ],
		17 => [ 'VII 78/1555', 2 ],
		18 => [ 'VII 78/1556', 2 ],
		19 => [ 'VII 78/1557', 2 ],
		20 => [ 'VII 78/1558', 2 ],
	},
	77 => {

	},    # neu geschnitten, keine Korrekturen nötig.
	78 => {
		1 => [ 'VII 78/1579', 2 ],
		2 => [ 'VII 78/1580', 2 ],
		3 => [ 'VII 78/1581', 2 ]
		,    #hat laut DB nur eine Seite, in der Tat aber 2
		4 => [ 'VII 78/1582', 2 ],
		5 => [ 'VII 78/1583', 2 ],
		6 => [ 'VII 78/1584', 2 ],
		7 => [ 'VII 78/1585', 2 ],
		8 => [ 'VII 78/1587', 2 ],    #1586 zerbrochen
		9 => [ 'VII 78/1588', 2 ]
		,    #hat laut DB nur eine Seite, in der Tat aber 2
		10 => [ 'VII 78/1589', 2 ],
		11 => [ 'VII 78/1590', 1 ],    #hat 2 Seiten, Umschnitt hat aber 1
		12 => [ 'VII 78/1591', 2 ],
		13 => [ 'VII 78/1592', 2 ],
		14 => [ 'VII 78/1593', 2 ],
		15 => [ 'VII 78/1594', 2 ],
		16 => [ 'VII 78/1595', 2 ],
		17 => [ 'VII 78/1596', 2 ],
		18 => [ 'VII 78/1597', 2 ],
		19 => [ 'VII 78/1598', 2 ],
		20 => [ 'VII 78/1599', 2 ],
	},
	79 => {
		3  => [ 'VII 78/1602', 2 ],
		10 => [ 'VII 78/1609', 2 ],

		13 => [ 'VII 78/1612', 2 ],
		14 => [ 'VII 78/1613', 2 ],
		19 => [ 'VII 78/1618', 2 ],
	},
	80 => { 14 => [ 'VII 78/1632', 2 ], },
	81 => {
		8  => [ 'VII 78/1646', 2 ],
		17 => [ 'VII 78/1658', 2 ],
		15 => [ 'VII 78/1653', 1 ],
	},
	82 => { 2  => [ 'VII 78/1662', 2 ], },
	83 => { 12 => [ 'VII 78/1698', 2 ], },
	84 => { 12 => [ 'VII 78/1719', 2 ], },
	85 => {
		9  => [ 'VII 78/1740', 1 ],
		17 => [ 'VII 78/1748', 1 ],
		29 => [ 'VII 78/1760', 1 ],
		12 => [ 'VII 78/1743', 1 ],
		15 => [ 'VII 78/1746', 1 ],
		16 => [ 'VII 78/1747', 1 ],
		20 => [ 'VII 78/1751', 1 ],
		22 => [ 'VII 78/1753', 1 ],
	},    # 38 Platten laut DB, 40 Dateien, laut DB sollten 45 Tracks sein.
	      #neu schneiden !!!!!!!!!!!!!
	86 => {
		1  => [ 'VII 78/1770', 1 ],
		2  => [ 'VII 78/1771', 1 ],
		3  => [ 'VII 78/1772', 1 ],
		4  => [ 'VII 78/1773', 1 ],
		5  => [ 'VII 78/1774', 1 ],
		6  => [ 'VII 78/1775', 1 ],
		7  => [ 'VII 78/1776', 1 ],
		8  => [ 'VII 78/1777', 1 ],
		9  => [ 'VII 78/1778', 1 ],
		10 => [ 'VII 78/1779', 1 ],
		11 => [ 'VII 78/1780', 1 ],
		12 => [ 'VII 78/1781', 1 ],
		13 => [ 'VII 78/1782', 1 ],
		14 => [ 'VII 78/1783', 1 ],
		15 => [ 'VII 78/1784', 1 ],
		16 => [ 'VII 78/1785', 1 ],
		17 => [ 'VII 78/1786', 1 ],
		18 => [ 'VII 78/1787', 1 ],
		19 => [ 'VII 78/1788', 1 ],
		20 => [ 'VII 78/1789', 1 ],
		21 => [ 'VII 78/1790', 1 ],
		22 => [ 'VII 78/1791', 1 ],
		23 => [ 'VII 78/1792', 1 ],
		24 => [ 'VII 78/1793', 1 ],
		25 => [ 'VII 78/1794', 1 ],
		26 => [ 'VII 78/1795', 1 ],
		27 => [ 'VII 78/1796', 1 ],
		28 => [ 'VII 78/1797', 1 ],
		29 => [ 'VII 78/1798', 1 ],
		30 => [ 'VII 78/1799', 1 ],
		31 => [ 'VII 78/1800', 1 ],
		32 => [ 'VII 78/1801', 1 ],
		33 => [ 'VII 78/1802', 1 ],
		34 => [ 'VII 78/1803', 1 ],
		35 => [ 'VII 78/1804', 1 ],
		36 => [ 'VII 78/1805', 1 ],
		37 => [ 'VII 78/1806', 1 ],
		38 => [ 'VII 78/1807', 1 ],
		39 => [ 'VII 78/1808', 1 ],
		40 => [ 'VII 78/1809', 1 ],
		41 => [ 'VII 78/1810', 1 ],
	},
	87 => {    #Autopsie haben alle eine Seite
		1  => [ 'VII 78/1811', 1 ],
		2  => [ 'VII 78/1812', 1 ],
		3  => [ 'VII 78/1813', 1 ],
		4  => [ 'VII 78/1814', 1 ],
		5  => [ 'VII 78/1815', 1 ],
		6  => [ 'VII 78/1816', 1 ],
		7  => [ 'VII 78/1817', 1 ],
		8  => [ 'VII 78/1818', 1 ],
		9  => [ 'VII 78/1819', 1 ],
		10 => [ 'VII 78/1820', 1 ],
		11 => [ 'VII 78/1821', 1 ],
		12 => [ 'VII 78/1822', 1 ],
		13 => [ 'VII 78/1823', 1 ],
		14 => [ 'VII 78/1824', 1 ],
		15 => [ 'VII 78/1825', 1 ],
		16 => [ 'VII 78/1826', 1 ],

		17 => [ 'VII 78/1827', 1 ],
		18 => [ 'VII 78/1828', 1 ],
		19 => [ 'VII 78/1829', 1 ],
		20 => [ 'VII 78/1830', 1 ],

		21 => [ 'VII 78/1831', 1 ],
		22 => [ 'VII 78/1832', 1 ],
		23 => [ 'VII 78/1833', 1 ],
		24 => [ 'VII 78/1834', 1 ],

		25 => [ 'VII 78/1835', 1 ],
		26 => [ 'VII 78/1836', 1 ],
		27 => [ 'VII 78/1837', 1 ],
		28 => [ 'VII 78/1838', 1 ],
		29 => [ 'VII 78/1839', 1 ],
		30 => [ 'VII 78/1840', 1 ],
		31 => [ 'VII 78/1841', 1 ],
		32 => [ 'VII 78/1842', 1 ],
		33 => [ 'VII 78/1843', 1 ],
		34 => [ 'VII 78/1844', 1 ],
		35 => [ 'VII 78/1845', 1 ],
		36 => [ 'VII 78/1846', 1 ],
		37 => [ 'VII 78/1847', 1 ],
		38 => [ 'VII 78/1848', 1 ],
		39 => [ 'VII 78/1849', 1 ],

		40 => [ 'VII 78/1850', 1 ],

	},
	90 => {
		12 => [ 'VII 78/1905', 2 ],
		13 => [ 'VII 78/1906', 2 ],
		14 => [ 'VII 78/1907', 2 ],
	},
	91 => { 15 => [ 'VII 78/1928', 2 ], },
	92 => {
		7 => [ 'VII 78/1939', 2 ],
		8 => [ 'VII 78/1940', 2 ],
	},
	95 => {
		1  => [ 'VII 78/1993', 2 ],
		2  => [ 'VII 78/1994', 2 ],
		3  => [ 'VII 78/1995', 2 ],
		4  => [ 'VII 78/1996', 2 ],
		5  => [ 'VII 78/1997', 2 ],
		6  => [ 'VII 78/1998', 2 ],
		7  => [ 'VII 78/1999', 2 ],
		8  => [ 'VII 78/2000', 2 ],
		9  => [ 'VII 78/2001', 2 ],
		10 => [ 'VII 78/2002', 2 ],
		11 => [ 'VII 78/2003', 2 ],
		12 => [ 'VII 78/2004', 2 ],
		13 => [ 'VII 78/2005', 2 ],
		14 => [ 'VII 78/2006', 2 ],
		15 => [ 'VII 78/2007', 2 ],
		16 => [ 'VII 78/2008', 2 ],
		17 => [ 'VII 78/2009', 2 ],
		18 => [ 'VII 78/2010', 2 ],
		19 => [ 'VII 78/2011', 2 ],
		20 => [ 'VII 78/2012', 2 ],
	},
	96 => {
		1  => [ 'VII 78/2013', 2 ],
		2  => [ 'VII 78/2014', 2 ],
		3  => [ 'VII 78/2015', 2 ],
		4  => [ 'VII 78/2016', 2 ],
		5  => [ 'VII 78/2017', 2 ],
		6  => [ 'VII 78/2018', 2 ],
		7  => [ 'VII 78/2019', 2 ],
		8  => [ 'VII 78/2020', 2 ],
		9  => [ 'VII 78/2021', 2 ],
		10 => [ 'VII 78/2022', 2 ],
		11 => [ 'VII 78/2023', 2 ],
		12 => [ 'VII 78/2024', 2 ],
		13 => [ 'VII 78/2025', 2 ],
		14 => [ 'VII 78/2026', 2 ],
		15 => [ 'VII 78/2027', 2 ],
		16 => [ 'VII 78/2028', 2 ],
		17 => [ 'VII 78/2029', 2 ],
		18 => [ 'VII 78/2030', 2 ],
	},
	107 => {
		1  => [ 'VII 78/2225', 2 ],
		2  => [ 'VII 78/2226', 2 ],
		3  => [ 'VII 78/2227', 2 ],
		4  => [ 'VII 78/2228', 2 ],
		5  => [ 'VII 78/2229', 2 ],
		6  => [ 'VII 78/2230', 2 ],
		7  => [ 'VII 78/2231', 2 ],
		8  => [ 'VII 78/2232', 2 ],
		9  => [ 'VII 78/2233', 2 ],
		10 => [ 'VII 78/2234', 2 ],
		11 => [ 'VII 78/2235', 2 ],
		12 => [ 'VII 78/2236', 2 ],
		13 => [ 'VII 78/2237', 2 ],
		14 => [ 'VII 78/2238', 2 ],
		15 => [ 'VII 78/2239', 2 ],
		16 => [ 'VII 78/2240', 2 ],
		17 => [ 'VII 78/2241', 2 ],
		18 => [ 'VII 78/2242', 2 ],
		19 => [ 'VII 78/2243', 2 ],
		20 => [ 'VII 78/2244', 2 ],
	},
	108 => {
		1 => [ 'VII 78/2245', 1 ],
		2 => [ 'VII 78/2246', 2 ],
	}
);

#DONT CHANGE

#
# DATA STRUCTURES
#

#1. FILE CACHE:
#DF: There is a cache for the file names found on disk.
#$filecache{$tape_no}{$track_no}=$filename;
#Known issues: It does not store root directory! This might cause problems

#2. FILE MAP:
#DF: Old name -> new name. This is almost the final result
#$file_map{$fn_new}=$fn_new

#3. ID CACHE
#DF: Keep the ids in mind.
#$id_cache{$tape_no}{$id}=$fn_old;

#my %warnings;    #warnings, don't load the stored warnings...

#load file map if exists
say "1. Load file map and file cache...";

my %file_map;
my $href = retrieve_me( $main::config{stored_map_fn} );
%file_map = %{$href} if $href;

my %id_cache;    #
$href     = retrieve_me( $main::config{stored_id_cache_fn} );
%id_cache = %{$href} if $href;

my %missing;     #where xml record appears to be missing
$href    = retrieve_me( $main::config{stored_missing_fn} );
%missing = %{$href} if $href;

#immediate sanity checks
die "Error: XML not found\n"              unless $main::config{xml};
die "Error: no destination dir specified" unless $dest_dir;
if ( !-d $main::config{tmp_dir} ) {
	mkdir $main::config{tmp_dir}
	  or die "Error: tmp_dir does not exist and I cannot create it";
}

#
# process commands
#

my $source = $ARGV[0];

my $start_tape = 0;
$start_tape = $ARGV[1] if $ARGV[1];

say "\tProcess Commands";
if ( $ARGV[0] ) {

	#	test_file_cache()           if $ARGV[0] =~ /test_file_cache/;
	#alphabetical order?
	check_titles() if $ARGV[0] =~ /check_titles/;
	no_titles()    if $ARGV[0] =~ /no_title/;
	clear_cache()  if $ARGV[0] =~ /clear_cache/;
	do_copy( \%file_map, $dest_dir ) if $ARGV[0] =~ /copy/;
	show_file_map($start_tape) if $ARGV[0] =~ /show_file_map/;
	show_last( \%file_map )    if $ARGV[0] =~ /show_last/;
	show_id_cache()            if $ARGV[0] =~ /show_id_cache/;
	show_missing( \%missing )  if $ARGV[0] =~ /show_missing/;
	show_warnings()            if $ARGV[0] =~ /show_warnings/;
	write_logs()               if $ARGV[0] =~ /write_logs/;
	help()                     if $ARGV[0] =~ /\-h/;
	show_file_cache($start_tape) if ( $ARGV[0] =~ /show_file_cache/ );

	if ( $ARGV[0] =~ /force_file_cache/ ) {
		say "FORCE FILE CACHE";

=head2 force_file_cache SOURCE_DIR

Delete old file cache and force the making of a new one and exit!

=cut

		if ( -e $main::config{stored_fc_fn} ) {
			say "\tAbout to delete file cache";
			unlink $main::config{stored_fc_fn}
			  or die "Cannot delete file cache\n";
		}
		my $source = $ARGV[1];
		die "Error: no source specified"        unless $source;
		die "Error: Source not found ($source)" unless -e $source;
		die "Error: Source no dir!"             unless -d $source;
		recreate_file_cache($source);
		exit;
	}

	if ( $ARGV[0] =~ /show_max/ ) {
		my $root = xml_init();
		show_max( $root, \%id_cache );
	}

	if ( $ARGV[0] =~ /check_gap/ ) {
		check_gaps( $main::config{stored_fc_fn} );
		exit 0;
	}
}

#if you reach here you need $source!
die "Error: no source specified"        unless $source;
die "Error: Source not found ($source)" unless -e $source;
die "Error: Source no dir!"             unless -d $source;

#
# FILE CACHE: if stored information available, do not scan again
#
recreate_file_cache($source);

#
# next step
#

my $root = xml_init( $main::config{xml} );

say "4.About to start reverse lookup...";

#loop over each tape
foreach my $tape_no ( sort { $a <=> $b } keys %main::filecache ) {
	if ( $tape_no >= $start_tape ) {

		#I want to sort tracks, so the highest track is the last
		my @tracks_sorted =
		  sort { $a <=> $b } keys %{ $main::filecache{$tape_no} };

	   #max is the current guess of how the highest id on this tape
	   #ids cannot be greater than tracks. For every 2-sides-disc, I substract 1
	   #For every "controlled track gap" I substract another one.
		my $max_id = $tracks_sorted[-1];

		#I do NOT need to loop over tracks, instead over hypothetical ids
		my $track_no = 1;    #track counter
		                     #2nd loop. Inside I loop over every hypothetical id
		for ( my $id = 1 ; $id <= $max_id ; $id++ ) {
			if ( $main::filecache{$tape_no}{$track_no} ) {
				while ( $main::filecache{$tape_no}{$track_no} =~ /^gap/ ) {
					say "Track gap. Ignore this tape/track combination "
					  . "($tape_no/$track_no)";

					#jump over those tracks which are marked as gap
					$track_no++;

					#why do I have to change max_id here?
					$max_id--;
				}
			}

			my $xpc = XML::LibXML::XPathContext->new;
			$xpc->registerNs( 'mpx' => 'http://www.mpx.org/mpx' );

			#debug tape and id info
			say "id:$tape_no/$id";

			my $xpath =
			  "//mpx:sammlungsobjekt[mpx:andereNr[\@art = 'ID' and . = '$id'] "
			  . "and mpx:andereNr[\@art ='DAT-Nr.' and . = '$tape_no' ]]";
			my @nodes = $xpc->findnodes( $xpath, $root );

			#
			# result is ONLY useful if I find exactly one
			# DEBUG/ TODO implement break for track counter ($track_no)
			if ( $#nodes eq 0 ) {

				# Determine the number of sides per disc
				my ( $tracks_per_id, $identNr ) =
				  number_of_sides( $nodes[0], $tape_no, $id );

				#if ( !( $tracks_per_id && $identNr ) ) {
				#
				#}

				# if a record has two tracks, then the max id has to smaller
				$max_id = $max_id - $tracks_per_id;

				#Debug
				# "\tF:$tracks_per_id\n";

				#
				# act on every side of disc
				#

				for (
					my $each_side = 0 ;
					$each_side <= $tracks_per_id ;
					$each_side++
				  )
				{
					my $fn_old;
					if ( $main::filecache{$tape_no}{$track_no} ) {
						while (
							$main::filecache{$tape_no}{$track_no} =~ /^gap/ )
						{

							# I dont get why I need this at all!
							say "\t\tHere is another track gap! "
							  . "($tape_no/$track_no)";
							$track_no++;

		   #TODO: I don't quite understand why I have to reduce the max_id here!
							$max_id--;
						}
						say $main::filecache{$tape_no}{$track_no};
						$fn_old = $main::filecache{$tape_no}{$track_no};
					}
					else {
						update_warnings( $tape_no, $id,
							    "Cannot find this track "
							  . "($tape_no/$track_no) in the file cache" );

					}

					my $side = "";
					$side = 'a' if $each_side eq 0;
					$side = 'b' if $each_side eq 1;

					$identNr =~ s/ /_/;    #replace spaces with underlines
					$identNr =~ s,/,_,;    #replace slash with underlines

					# new name VII_78_[nnnn][a|b].[tape]-[id].wav
					my $fn_new = "$identNr$side.$tape_no-$id.wav";

					if ( $id > $track_no ) {
						update_warnings( $tape_no, $id,
							"id > track ($track_no)!" );
					}

					#debug new
					if ($fn_old) {

						#$fn_old
						say "\t [$track_no]--> $fn_new";
						$file_map{$fn_old} = $fn_new;
						$id_cache{$tape_no}{$id} = $fn_old;
					}

					#make persistent after updating the hash
					store_file_map( \%file_map );

					store_id_cache( \%id_cache );

					#debug new
					# "\tD: " . $nodes[0]->textContent . "\n";
					$track_no++;
				}    # end of for for both sides

			}
			else {    #if not exactly 1 match in last xpath
				update_missing( \%missing, $tape_no, $id,
					"$main::filecache{$tape_no}{$track_no} ($#nodes results)" );

				#do i have to reset $track_no to 1?
				$track_no++;
				$id = $max_id;    #end loop here!
			}
		}    # end of for each id

		#check if there are ids that we did not yet care for

		my $xpc = XML::LibXML::XPathContext->new;
		$xpc->registerNs( 'mpx' => 'http://www.mpx.org/mpx' );

		my $xpath =
		  "//mpx:sammlungsobjekt[mpx:andereNr[\@art = 'ID' and . > '$max_id'] "
		  . "and mpx:andereNr[\@art ='DAT-Nr.' and . = '$tape_no' ]]";
		my @nodes = $xpc->findnodes( $xpath, $root );

		if ( $#nodes > 0 ) {
			update_warnings( $tape_no, $max_id,
				"NEW CHECK: Left-over id indicates that we guessed wrong" );
		}
		else {
			say "Check if found all ids:ok";
		}

	}
}

#
##
###
####
##### SUBS
####
###
##
#

sub analyze_filename {
	my $file_fn = shift;

	#take a filename, parse it and return no. of tape, track
	#(literal to filename) and take
	#
	#gets called by fn_parser()

	#skip the path
	my $base = basename($file_fn);

	#get tape_no (from beginning)
	my $tape_no;
	{
		$base =~ /\w+-\w+\s(\d+)/;
		$tape_no =
		  sprintf( "%d", $1 );    #without leading zeros, has the same result
		                          #in libxml's xpath
	}

	#take_no ( I cheat a little with the $2)
	my $take_no = 0;              # if need a numeric value here
	{
		$base =~ /\w+-\w+\s(\d+)#(\d+)\.\d+\./;
		$take_no = $2 if ($2);
	}

	#get track_no (from end)
	my $track_no;                 # preliminary track_no for this file

	{
		$base =~ /(\d+)\.wav$/;
		$track_no = sprintf( "%d", $1 ) if ($1);
	}

	#overwrite if wavelab form
	{
		$base =~ /(\d+)\)a*.wav$/;
		if ($1) {
			$track_no = sprintf( "%d", $1 );
			say "\tWavelab name form";

		}
		$track_no = sprintf( "%d", $1 ) if ($1);

		#		say "REACH HERE:$1 -- $track_no";
	}

	#DEBUG
	#	say	 "analyze_filename:base:tape/track/take:\n"
	#	."\t$base:$tape_no/$track_no/$take_no\n";

	return ( $tape_no, $track_no, $take_no, $base );
}

sub help {
	say "Loading help text ...";
	system "perldoc $0";

	exit;
}

sub no_titles {
	say "NO TITLES";
	say
"Show records that according to xml have no title AND that are not listed as exception";

	my $root = xml_init();
	my $xpc  = XML::LibXML::XPathContext->new;
	$xpc->registerNs( 'mpx' => 'http://www.mpx.org/mpx' );

	my $xpath = "//mpx:sammlungsobjekt[not (mpx:titel)]";
	my @nodes = $xpc->findnodes( $xpath, $root );

	my @identNrn;
	foreach my $objekt (@nodes) {

		# $objekt->toString()."\n\n\n";
		my $identNr = $objekt->findvalue("mpx:identNr");
		push @identNrn, $identNr if $identNr;
	}

	foreach ( sort @identNrn ) {
		say "$_";
	}

	say "\nTotal: $#identNrn without title and beyond exception.";

	exit;

	#	if ( $main::exceptions{$tape_no}{$id} ) {
	#		 "\t\t\tEXCEPTION OVERRIDE:$tape_no/$id\n";
	#
	#		$identNr       = $main::exceptions{$tape_no}{$id}[0];
	#		$tracks_per_id =
	#		  $main::exceptions{$tape_no}{$id}[1] - 1;  # convert to perl number 1=0
	#
	#	}

}

sub check_gaps {

=head2 check_gaps

This command is meant to be called internally mostly. It checks for gaps in the track
numbers, eg. 3 in the series 1,2,4 and writes a specific string to the missing number.
In the normal loop entries with this string are ignored. 

check_gaps is called after successfully reading in all the files in the file cache.

It works, but maybe I should have just created the track numbers, e.g. correct them in
1,2,3 instead of filling the gaps. 

=cut

	my $fc_fn = shift;
	die "Error: No filename for file cache\n" unless $fc_fn;
	my $new_gaps = 0;
	my $old_gaps = 0;

	say "CHECK IF FILES LOOK COMPLETE (check_gaps)";
	say "\tcheck if files in the file cache have gaps in between";

	#1st loop over tapes
	foreach my $tape_no ( sort { $a <=> $b } keys %main::filecache ) {

		#start with track 1 on every tape

		#sort the tracks from the filesystem numerically
		my @tracks_sorted =
		  sort { $a <=> $b } keys %{ $main::filecache{$tape_no} };

		#2nd loop

		for (
			my $track_check_counter = 1 ;
			$track_check_counter < $tracks_sorted[-1] ;
			$track_check_counter++
		  )
		{

			#Debug
			# "Looking for gaps ($tape_no/$track_check_counter)\n";
			if ( $main::filecache{$tape_no}{$track_check_counter} ) {

				#file exists in file cache
				if ( $main::filecache{$tape_no}{$track_check_counter} =~
					/^gap automatically identified/ )
				{
					$old_gaps++;

					# "track gap found:$tape_no/$track_no (old)\n";
				}
			}
			else {

				#file does not exist in file cache
				$main::filecache{$tape_no}{$track_check_counter} =
				  "gap automatically identified";
				print "track gap found:$tape_no/$track_check_counter (new)\n";
				$new_gaps++;
			}

		}
	}
	store \%main::filecache, $fc_fn
	  or die "Error: Cannot store file cache!\n";

	print "Total NEW track gaps:$new_gaps\n";
	print "Total OLD track gaps:$old_gaps\n";

	return $new_gaps;
}

sub check_titles {

=head2 check_titles

This command is meant to be when debugging the xml info. It lists you titles with
suspecious title information in mpx:titel.

Currently, the mpx:titel is used to determine the number of sides a disk has. 

=cut

	say "CHECK TITLES";
	say "I will show all mpx:titel\@art from xml. These used to determine "
	  . "the number of sides a 78 has. Currently zero or one of these titles are "
	  . "treated as one side and two or more are treated as two sides. Here, I "
	  . "will display the titles for debugging and display the (interesting) results.\n";

	say "show only records with more than two titles";

	#my @titles        = $nodes[0]->findnodes('mpx:titel[@art]');

	my $root = xml_init();
	my $xpc  = XML::LibXML::XPathContext->new;
	$xpc->registerNs( 'mpx' => 'http://www.mpx.org/mpx' );

	#	my $xpath = "//mpx:sammlungsobjekt[mpx:titel/\@art]";
	my $xpath = "//mpx:sammlungsobjekt[nmpx:titel/\@art]";
	my @nodes = $xpc->findnodes( $xpath, $root );

	foreach my $objekt (@nodes) {
		say $objekt->find("mpx:identNr");
		my @titles = $objekt->findnodes("mpx:titel[\@art]");
		if ( $#titles > 0 ) {
			foreach my $title (@titles) {
				say "\t" . $title->toString();
			}
		}
	}
	exit;
}

sub clear_cache {

=head2 clear_cache

Call this command when you want to delete the current caches. Usually I comment out to the 
deletion of the file cache, so I don't have to read it again and again. So make sure you
check the script, before you call this function!

=cut

	say "CLEAR CACHE";

	if ( -e $main::config{stored_map_fn} ) {
		say "\tAbout to clear file map";
		unlink $main::config{stored_map_fn}
		  or die "Cannot delete cache file map\n";
	}
	if ( -e $main::config{stored_warnings_fn} ) {
		say "\tAbout to clear warnings map";
		unlink $main::config{stored_warnings_fn}
		  or die "Cannot delete warnings file map\n";
	}
	if ( -e $main::config{stored_fc_fn} ) {

		# say		 "\tAbout to clear file cache";
		#		unlink $stored_fc_fn or die "Cannot delete file cache\n";
	}
	if ( -e $main::config{stored_missing_fn} ) {
		say "\tAbout to clear missing cache";
		unlink $main::config{stored_missing_fn}
		  or die "Cannot delete cache missing\n";
	}

	if ( -e $main::config{stored_id_cache_fn} ) {
		say "\tAbout to clear id cache";
		unlink $main::config{stored_id_cache_fn}
		  or die "Cannot delete id cache\n";
	}

	exit;
}

sub correct_track_no {

	#
	# correct track_no if one tape has more than one take
	#
	my $tape_no    = shift;
	my $p_track_no = shift;
	my $take_no    = shift;

	if ( $tape_no != $main::memory{last_tape_no} ) {

		#this is a new tape, so reset memory values
		$main::memory{'last_take_no'}  = 0;
		$main::memory{'last_track_no'} = 0;
		$main::memory{'last_take_no'}  = 0;
		$main::memory{'offset'}        = 0;

		#Debug
		# "DEBBUG: New tape\n";
	}
	else {

		#this is the same tape as before
		if ( $take_no != 0 ) {

			#there is a take_no defined
			#correction is neccesary only if take_no exists
			if ( $take_no != $main::memory{last_take_no} ) {

				#there is more than one take

				$main::memory{'offset'} = $main::memory{'last_track_no'};

				# "Debug: set new offset:$main::memory{'offset'}\n";
			}
		}
	}

	#correct track according to offset
	my $track_no = $p_track_no + $main::memory{'offset'};

	#update memory info
	$main::memory{last_track_no} = $track_no;
	$main::memory{last_take_no}  = $take_no;
	$main::memory{last_tape_no}  = $tape_no;

	return $track_no;
}

sub compare_max {

=head2 compare_max

TODO

=cut

	#compare file map with xml
	#check if same highest id per tape

	foreach my $tape_no ( sort { $a <=> $b } keys %main::filecache ) {

		my @tracks_sorted =
		  sort { $a <=> $b } keys %{ $main::filecache{$tape_no} };

		#2nd loop
		foreach my $track_no (@tracks_sorted) {

			#		max
		}

	}
}

sub do_copy {

=head2 copy

Call this command when after you double checked the file map and you want to commit 
the suggested changes. Copy will copy the original names to the new file names.

Dest_dir is not yet scripted. Command is not yet debugged.

=cut

	my $href     = shift @_;
	my $dest_dir = shift @_;
	my %file_map = %{$href};
	my $count    = 1;

	if ( !-d $dest_dir ) {
		mkdir $dest_dir
		  or die "Warn: \$dest_dir does not exist and I cannot create it";
	}

	#complete debug
	foreach my $fn_old ( sort keys %file_map ) {
		my $fn_new = $file_map{$fn_old};
		say "$fn_old --> $fn_new";
		if ( !-e "$dest_dir/$fn_new" ) {
			$count++;
			copy( $fn_old, "$dest_dir/$fn_new" );
		}
	}

	print "Total files copied: $count";
	exit;
}

sub fn_parser {

	#this is the filename parser
	#gets called by wanted
	#Get $tape_no and $track_no from filename
	#for each file that is selected in the wanted sub

	#I really should write this in a hash!
	#take corrects track when Martin needed several takes to record a single dat
	my $file_fn = shift @_;

	#my $href    = shift @_;
	#my %memory  = %{$href};    # contains state info on the file parsing.
	#
	# EXTRACT 3 PARTICLES FROM FILENAME
	# p_track_no is "preliminary track number", I might have to override it,
	# if one tape has more than one take

	my ( $tape_no, $p_track_no, $take_no, $base ) = analyze_filename($file_fn);

	my $track_no = correct_track_no( $tape_no, $p_track_no, $take_no );

	#first exception for tape 14. Ignore take no
	if ( $tape_no == 14 ) {
		$track_no = $p_track_no;

		# "FIRST EXCEPTION\n";
	}

	#another exception. Filenames in folder "DAT 021" are wrong
	#if ( $tape_no == 20 ) {
	#	my ( $name, $path, $suffix ) = fileparse($file_fn);
	#	$path =~ /\.\/DAT\s(\d+)\//;
	#	$tape_no =
	#	  sf( "%d", $1 );    #without leading zeros, has the same result
	#	 "DDDDD:$path --> $tape_no\n";
	#}

	#
	# OUTPUT INFO, DEBUG IT, STORE IS IN HASH AND CHECK IT
	#

	#Report warning messages if tape or track no missing
	say "Warning: No track no found.\nI will ignore this file ($file_fn)!\n"
	  if $track_no !~ /\d+/;
	say "Warning: No tape no found.\nI will ignore this file ($file_fn)!\n"
	  if $tape_no !~ /\d+/;

	#duplicate control
	if ( $main::filecache{$tape_no}{$track_no} ) {

		say "duplicate track: more than one file for one track (tape/track)";
		say "$tape_no/$track_no";
		say "\t$file_fn";
		say "\t$main::filecache{$tape_no}{$track_no}\n";

	}

	$main::filecache{$tape_no}{$track_no} = $file_fn;

	#DEBUG
	print "$base -> $tape_no/$p_track_no";
	print " --> $track_no ($take_no)" if ( $track_no != $p_track_no );
	print "\n";

}

sub number_of_sides {
	my $node    = shift;
	my $tape_no = shift;
	my $id      = shift;

	die "Error No node\n"    unless $node;
	die "Error No tape_no\n" unless $tape_no;
	die "Error No id\n"      unless $id;

	my $identNr = $node->find('mpx:identNr');

	#	my @titles        = $node->findnodes('mpx:titel[@art]');
	my @titles        = $node->findnodes('mpx:titel');
	my $tracks_per_id = $#titles;

	#if more than 2 titles, assume 2 sides
	if ( $tracks_per_id > 1 ) {
		$tracks_per_id = 1;
	}

	if ( $tracks_per_id < 0 ) {

		#if no title in the xml db, then assume default value of 2 sides!
		update_warnings( $tape_no, $id, "No title info. I guess two sides" );
		$tracks_per_id = 1;
	}

	foreach my $title (@titles) {
		if ( $title->toString =~ /nicht bespielt/i ) {
			$tracks_per_id = 0;
			update_warnings( $tape_no, $id,
				"'Nicht bespielt' im Titel. Doch nur eine Seite" );
		}
	}

	#overwrite default value when necessary
	if ( $main::exceptions{$tape_no}{$id} ) {
		say "\t\t\tAUTOSPECTION OVERRIDE:$tape_no/$id";

		$identNr       = $main::exceptions{$tape_no}{$id}[0];
		$tracks_per_id =
		  $main::exceptions{$tape_no}{$id}[1] - 1;  # convert to perl number 1=0

		update_warnings( $tape_no, $id,
			"Autoinspection override (use $main::exceptions{$tape_no}{$id}[1])"
		);

	}

	#no more warnings at this point, use no_titles instead for debugging
	#		update_warning( $tape_no, $id,
	#			"Apparently, no title ($tracks_per_id)" );

	return $tracks_per_id, $identNr;
}

sub read_file_cache {

	my $href = retrieve( $main::config{stored_fc_fn} );
	%main::filecache = %{$href};

}

sub recreate_file_cache {
	my $source = shift;
	say "2. (Re)create file cache...";
	if ( -e $main::config{stored_fc_fn} ) {
		say
		  "\tStored info exists, I do NOT attempt to scan the directory again.";
		say "\tInstead I proceed with stored info";
		say
"\tTo flush the cache, delete the tmp file:\n\t$main::config{stored_fc_fn}";
		say
"\tNB: Cache is relative to directory in which you execute the command.";
		read_file_cache();

		#return %main:filecache;
	}
	else {
		say "\tStored info does NOT exist. I will scan the directory again.\n";

		#initialize quick and dirty
		$main::memory{'offset'}        = 0;
		$main::memory{'last_take_no'}  = 0;
		$main::memory{'last_track_no'} = 0;
		$main::memory{'last_tape_no'}  = 0;

		#for each file in source path
		find( \&wanted, $source );

		#store info in Filename_Cache so that I can work on it
		#without having the actual files
		store_filecache();

		check_gaps( $main::config{stored_fc_fn} );
		say "Initial file caching finished.";
	}

	#returns filecache in main
	return \%main::filecache;
}

sub retrieve_me {
	my $file = shift;

	my $href;
	if ( -e $file ) {
		say "\tLoad cache. To flush cache delete\n\t$file";
		$href = retrieve($file);

	}
	return $href if $href;
}

sub show_file_cache {

=head2 show_file_cache
	
		Show all files in the file cache with their tape number and their track number.
		The track number is corrected if there were different takes, gaps are marked.
		
		show_file_cache adds a test if the file is found relative to pwd.
		
		show_file_cache start_tape let's you specify the tape from which to start display
		
=cut

	my $command = shift;    # either "exists" or start_tape

	read_file_cache();

	$command = "" unless $command;

	foreach my $tape_no ( sort { $a <=> $b } keys %main::filecache ) {
		if (   ( $command =~ /\d+/ && $tape_no >= $command )
			or $command =~ /exists/
			or !$command )
		{
			my @tracks_sorted =
			  sort { $a <=> $b } keys %{ $main::filecache{$tape_no} };
			foreach my $track_no (@tracks_sorted) {
				print "tape/track->fn_old:$tape_no/$track_no->";
				print $main::filecache{$tape_no}{$track_no};
				if ( $command =~ /exists/ ) {
					print " exists"
					  if -e $main::filecache{$tape_no}{$track_no};
				}
				print "\n";
			}
		}
	}
	exit 0;
}

sub show_file_map {
	my $start_tape = shift;    #todo

	my $href = retrieve_me( $main::config{stored_map_fn} );
	%file_map = %{$href} if $href;

	#$file_map{$fn_new}=$fn_new

	say "SHOW FILE MAP";
	say "old->new";
	foreach my $fn_old ( sort keys %file_map ) {
		say "$fn_old->" . $file_map{$fn_old};
	}
	exit;
}

sub show_gaps {

	#TODO
}

sub show_last {
	my $href     = shift @_;
	my %file_map = %{$href};

	say "SHOW LAST\n";
	say "show last two tracks from each tape like in file map\n";
	foreach my $tape_no ( sort { $a <=> $b } keys %main::filecache ) {
		my @tracks_sorted =
		  sort { $a <=> $b } keys %{ $main::filecache{$tape_no} };
		say "tape:$tape_no (track:fn_old->fn_new)";

		foreach my $track_no ( $tracks_sorted[-2], $tracks_sorted[-1] ) {
			my $fn_old = $main::filecache{$tape_no}{$track_no};
			print "\t$track_no:$main::filecache{$tape_no}{$track_no} ";
			if ($fn_old) {
				if ( $file_map{$fn_old} ) {
					say $file_map{$fn_old};
				}
				else {
					say "fn old missing in file map";
				}
			}
			else {
				say "fn old missing";
			}
		}
	}
	exit 0;

}

sub show_warnings {

	my $href     = retrieve_me( $main::config{stored_warnings_fn} );
	my %warnings = %{$href};

	say "SHOW WARNINGS";
	say "(Various suspicious cases)";

	my @results = sort { $a <=> $b } keys %warnings;
	say "Results: " . ( $#results + 1 );
	foreach my $tape_no (@results) {
		foreach my $id ( sort { $a <=> $b } keys %{ $warnings{$tape_no} } ) {
			say "tape/id:$tape_no/$id:$warnings{$tape_no}{$id}";
		}
	}
	exit;

}

sub show_id_cache {

	my $href     = retrieve_me( $main::config{stored_id_cache_fn} );
	my %id_cache = %{$href};

	say "SHOW ID CACHE";
	my @results = sort { $a <=> $b } keys %id_cache;
	say "Tapes: $#results";
	foreach my $tape_no (@results) {
		my @sorted_ids = sort { $a <=> $b } keys %{ $id_cache{$tape_no} };
		foreach my $id (@sorted_ids) {
			say "tape/id:$tape_no/$id:$id_cache{$tape_no}{$id}";
		}
	}
	exit;
}

sub show_missing {
	say "\tLoad stored missing. To flush cache delete"
	  . "\t$main::config{stored_missing_fn}\n";
	my $href = retrieve( $main::config{stored_missing_fn} );

	my %missing = %{$href};

	say "SHOW MISSING";
	my $i = 0;
	my $y = 0;

	say "\tShow cases where tape/id has no equivalent in the xml";
	foreach my $tape_no ( sort { $a <=> $b } keys %missing ) {
		$y++;

		foreach my $id ( sort { $a <=> $b } keys %{ $missing{$tape_no} } ) {
			$i++;
			if ( $missing{$tape_no}{$id} ) {
				say "tape/id:$tape_no/$id:" . $missing{$tape_no}{$id};
			}
		}
	}
	say
"TOTAL: For $i tracks on $y tapes, no ids could be associated (including gaps)";
	exit;
}

sub show_max {
	my $root     = shift;
	my $href     = shift @_;
	my %id_cache = %{$href};

	#show_max_id_per_tape_from_xml

	#for debug purposes
	#read xml
	#loop over tapes
	#query all nodes per tapes
	#sort according to id
	#return highest id

	say "SHOW MAX";
	say "Here is a list of the highest tracks or id for each tape "
	  . "according to file cache, id_cache and and xml file\n";
	foreach my $tape_no ( sort { $a <=> $b } keys %main::filecache ) {
		my @files_tracks_sorted =
		  sort { $a <=> $b } keys %{ $main::filecache{$tape_no} };
		my @ids_sorted =
		  sort { $a <=> $b } keys %{ $id_cache{$tape_no} };

		#strange!
		die "ids_sorted doesn't exist" unless (@ids_sorted);

		say "Tape/Max Track: $tape_no/$files_tracks_sorted[-1]";
		say "\tMax id from id cache:$ids_sorted[-1]";

		my $xpc = XML::LibXML::XPathContext->new;
		$xpc->registerNs( 'mpx' => 'http://www.mpx.org/mpx' );

		my $xpath =
"//mpx:sammlungsobjekt[mpx:andereNr[\@art = 'ID' ] and mpx:andereNr[\@art ='DAT-Nr.' and . = '$tape_no' ]]";

		my @nodes = $xpc->findnodes( $xpath, $root );
		my $max = 0;
		foreach my $node (@nodes) {
			my $new = $node->find("mpx:andereNr[\@art = 'ID']");
			die "ID no number" if ( $new !~ /\d+/ );
			$new = sf( "%d", $new );
			$max = $new if ( $new > $max );
		}
		say "\txml max id($#nodes):$max";

	}
	exit;
}

sub store_id_cache {
	my $href = shift;

	store $href, $main::config{stored_id_cache_fn}
	  or die "Cannot store id cache!\n";

}

sub store_filecache {

	#do not pass over file_cache, use a global variable
	die "$main::config{stored_fc_fn} nicht definiert\n"
	  unless ( $main::config{stored_fc_fn} );

	store \%main::filecache, $main::config{stored_fc_fn}
	  or die "Cannot store file cache!\n";
}

sub store_file_map {
	my $href = shift;

	store $href, $main::config{stored_map_fn}
	  or die "Cannot store file mapping!\n";
}

sub store_missing {
	my $href_missing = shift;
	my %missing      = %{$href_missing};

	store \%missing, $main::config{stored_missing_fn}
	  or die "Cannot store missing!\n";

}

sub store_warnings {

	store \%main::warnings, $main::config{stored_warnings_fn}
	  or die "Cannot store warnings mapping!\n";

}

sub update_missing {
	my $missing_href = shift;
	my $tape_no      = shift;
	my $id           = shift;
	my $text         = shift;
	my %missing      = %{$missing_href};

	say "\t MISSING $text";

	$main::missing{$tape_no}{$id} = $text;

	store_missing( \%main::missing );

}

sub update_warnings {
	my $tape_no = shift;
	my $id      = shift;
	my $text    = shift;

	say "Warning:$text";

	$main::warnings{$tape_no}{$id} = $text;

	store_warnings( \%main::warnings );

}

sub wanted {

	#look only at file with suffix wav
	#ignore .files
	#look only for files which start with "SL-DAT"
	#for those file which meet the criteria call fn_parser
	#gets called from main
	if ( $_ =~ /.wav$/ ) {
		if ( $_ =~ /^SL-DAT/ ) {

			#, \%main::memory
			fn_parser($File::Find::name);

			# contains state info for the fn_parser
			# last_track, last_take, offset
		}
	}
}

sub write_logs {
	my $warn_fn = "78er_warnings.txt";
	my $miss_fn = "78er_missing.txt";
	my $fm_fn   = "78er_file_map.txt";
	my $fc_fn   = "78er_file_cache.txt";
	my $id_fn   = "78er_id_cache.txt";

	"I will write,"
	  . "\n\t$warn_fn,"
	  . "\n\t$miss_fn,"
	  . "\n\t$fm_fn,"
	  . "\n\t$fc_fn,"
	  . "\n\t$id_fn"
	  . "to current directory ... ";

	#first seems not to work!? Why?
	system("$0 show_file_cache > $fc_fn ");
	system("$0 show_warnings > $warn_fn ");
	system("$0 show_missing > $miss_fn ");
	system("$0 show_file_map > $fm_fn ");
	system("$0 show_id_cache > $id_fn ");
	say " ok .";
	exit;
}

sub xml_init {
	say "About to parse xml data...\n";
	my $parser = XML::LibXML->new();
	my $tree   = $parser->parse_file( $main::config{xml} );    #tree is doc
	my $root   = $tree->getDocumentElement;

	return $root;
}

#__END__

=head1 SPECIFICS

=head2 Output name scheme

NAME SCHEME FOUR OUTPUT FILES
 VII_78_[nnnn][a|b].[DDD]-[ID].wav
where
[nnnn] is ident.nr component
[a|b] refers to side a or b
[DDD] is tape number (DAT-Nr.). With trailing zeros.
[ID] is id number. Without trailing zeros.
For the original track number see the filemap (internal command).


=head2 Loop details

Here I loop over ids not tracks. First I try to determine
if the disc has one or two sides and to calculate the tracks right. So mainly I try to
associate track_no with ids, but I also rename the file according to the VII 78 number.
Actually, the new name scheme is a little more difficult. Right now, I also save id and
track info. You never know when this is handy. But I might change that in the end.

=head1 FIX PROTOCOL

=over

=item Tape unknown

There was one tape which was missing. Instead it was copied twice. I had to 
cut that tape in chunks again. Which tape was it? In the 20s. 

=item Tape 2

In tape 2 there was one track more than necessary. We first autospected all disks for the 
number of sides and then listened to all wav tracks to discover that one take was wrong (incomplete).
We deleted the track (SL-DAT 002#035.wav) from the firewire harddisk.

=item Tape 35
SL-DAT 035#35.21.wav --> 19. Track auf DAT tatsächlich --> Seite B wir lassen es wie es ist 
SL-DAT 035#35.22.wav --> 20. Track auf DAT tatsächlich --> Seite A

=item Tape 36
Auf Tape 36 waren 2 Tracks mehr auf dem DAT als in der DB dokumentiert. 
SL-DAT 036#36.03.wav und SL-DAT 036#36.04.wav sind zwei verschiedene Digitalisate von dem 3. Track auf
diesem Band. SL-DAT 036#36.04.wav wird manuell umbenannt in VII 78/0638a-2.wav
SL-DAT 036#36.06.wav stimmt nicht Beschreibung in DB überein. Wird umbenannt in VII 78-0638b-2.wav   

VII 78/0626 hat laut DB und Autospektion zwei Seiten, aber nur eine Seite auf Harddisk. DAT noch zu 
checken.

=item Tape 44

SL-DAT 044#44.07.wav und SL-DAT 044#44.08.wav sind zwei anscheinend identische Digitalisate. Wir nennen
SL-DAT 044#44.08.wav manuell in VII 78-809a-2.wav um.

=item Tape 45

Tape 45 war von Martin nicht gut geschnitten, so dass ein File fehlte. Wir haben Seiten der Platten gepfürft 
und DAT-Band abgehört und dann Fehler bei Martin gefunden. Dann gesamtes Band Digitalisat von Martin neu 
gesplittet.

=item Tape 57 TODO

tape/id:57/28:NEW CHECK: Left-over id indicates that we guessed wrong
tape/id:57/29:Cannot find this track (57/38) in the file cache

=item Tape 58 TODO

tape/id:58/20:NEW CHECK: Left-over id indicates that we guessed wrong
tape/id:58/21:Cannot find this track (58/42) in the file cache


=item Tape 60

File DAT 060/SL-DAT 060#41.wav kann keinem xml Datensatz zugeordnet werden (missing), es gibt also einen Track 
mehr als Seiten in der DB erkannt. Problematisch scheint laut Fehlermeldung meines Programms tape/id:60/23 zu sein. 
Auf Tape 60 sind laut DB 22 Platten IDs (VII 78/1172-1194). Etliche dieser Platten haben keinen Titel. Aus der Produktions.Nr 
kann ich jedoch erkennen,dass die meisten 2 Seiten haben. Ich führe diejenigen 78-er Nummern auf, die 
laut DB nur eine Seite haben: 1191 (Titel richtig eingetragen), 1192 (Titel richtig eingetragen), 1193 (nicht bespielt),
1194 (nicht bespielt).  1188 ist scheinbar nicht abgespielt worden.

Laut DB unklar ist nur  VII 78/1172, weil Titel und Produktionsnummer fehlen, aber Autospektion bestätigt, dass sie 2 
Seiten hat. 


VII 78/1172-1194
(ID im Folgenden laut DB) 
ID1:1172:2S(Autospektion), T1,T2 
ID2:1173:2S, T3,T4
ID3:1174:2S, T5,T6
ID4:1175:2S, T7,T8
ID5:1176:2S, T9,T10
ID6:1177:2S, T11, T12
ID7:1178:2S, T13,T14
ID8:1179:2S, T15,T16
ID9:1180:2S, T17,T18
ID10:1181:2S, T19,T20
ID11:1182:2S, T21,T22
ID12:1183:2S, T23,T24
ID13:1184:2S, T25,T26
ID14:1185:2S, T27,T28
ID15:1186:2S, T29,T30
ID16:1187:2S, T31,T32
ID:1188:2S (ID missing in DB). Wurde sie überhaupt überspielt? Nein, Platte nicht abspielbar laut DB. Wenn ja, ist sie dann Teil von 
ID17:1189:2S, T33,T34
ID18:1190:2S, T35,T36
ID19:1191:1S (Titel richtig eingetragen), T37 
ID20:1192:1S (Titel richtig eingetragen), T38
ID21:1193:1S (nicht bespielt), T39
ID22:1194:1S (nicht bespielt), T40

Laut DB müsste es also 22*2-3 Tracks sein: 41 Tracks. Tatsächlich sind es auch 41 Tracks.

SL-DAT 060#41.wav und SL-DAT 060#42.wav sind zwei unterschiedliche Übertragungen der gleichen Platte.
Das zweite manuell umbenannt in VII 78-1994a-2.wav 

=item Tape 62 TODO
tape/id:62/19:NEW CHECK: Left-over id indicates that we guessed wrong


=item Tape 68

missing tape/id:68/21:./DAT 068/SL-DAT 068#73.03.wav (-1 results)

Hat auf HD 40 Dateien. Hat laut DB 20 Schallplatten (VII 78/1371-1392 ohne 1373 zerbrochen und 
1383 [gibt es in DB nicht]), sind von ID1-20 durchnummeriert.

1383 gibt es auch physikalisch nicht!.

ID1:1371:2S (DB):T1-2
ID2:1372:2S (DB):T3-4
1373 ZERBORCHEN
ID3:1374:2S (DB):T5-6
ID4:1375:2S (DB):T7-8
ID5:1376:2S (DB):T9-10
ID6:1377:2S (DB):T11-12
ID7:1378:2S (DB):T13-14
ID8:1379:2S (DB):T15-16
ID9:1380:2S (DB):T17-18
ID10:1381:2S (DB):T19-20
ID11:1382:2S (DB):T21-22
1383 EXISTIERT NICHT / LÜCKE
ID12:1384:2S laut A (1S laut DB):T23-T24
ID13:1385:2S (DB):T25-26
ID14:1386:2S (kein TItel eingetragen, A):T27-28
ID15:1387:2S laut A, DB eingetragen 1S :T29-30
ID16:1388:2S (kein Titel, A):T31-32
ID17:1389:2S (kein Titel, A):T33-34
ID18:1390:2S (kein Titel, A):T35-36
ID19:1391:2S (kein Titel, A):T37-38
ID20:1392:2S (kein Titel, A):T39-40

Zwei Platten hatten nur einen Titel in der DB, obwohl sie zwei Seiten hatten! Korrektur in der Ausnahme-
liste.

=item Tape 72

tape/id:72/21:./DAT 072/SL-DAT 072#72.1.35.wav (-1 results)

Laut FP 39 Files. Laut DB 20 Schallplatten mit 32 Seiten, d.h. mit nur einer Seite. VII 1455-1474 
Wir schneiden das gesamte DAT neu und finden den fehlenden Track

=item Tape 73

tape/id:73/22:./DAT 073/SL-DAT 073#74.03.wav (-1 results)

42 Files laut HD, 21 Schallplatten laut DB

=item 74

41 Tracks laut DB
42 Files laut HD


tape/id:74/22:./DAT 074/SL-DAT 074#74.42.wav (-1 results)

=item Tape 75
tape/id:75/22:./DAT 075/SL-DAT 075#75.1.41.wav (-1 results)

Laut FP 41, laut DB 39. Laut DB haben 1518, 1519 und 1538 nur eine Seite. Autopsie in diesen Fällen. 
1519 und 1938 haben tatsächlich zwei Seiten


=item Tape 76
tape/id:76/21:./DAT 076/SL-DAT 076#77.21.wav (-1 results)

40 Files auf HD. 20 Platten in DB
1544
1545

1539-1558

=item Tape 78

tape/id:7/21:./DAT 078/SL-DAT 078#78.51.wav (-1 results)

Hat 39 Files auf HD

Hat 20 Platten laut DB

Einseitig laut 1582, 

Zweifelhaft laut DB 1599

Autopsie? Start beschädigte Platte hat nur 1 Seite in Überspielung!

=item Tape 79
tape/id:79/20:./DAT 079/SL-DAT 079#80.29.wav (-1 results)

38 Files auf DB
19 Platten
Autopsie: alle haben 2 Seiten


=item Tape 80
tape/id:80/21:./DAT 080/SL-DAT 080#80.41.wav (-1 results)

39 Files auf HD
20 Platten laut DB

einseitig laut DB 1632, laut Autopsie aber 2 seitig
unklar laut DB 1629

=item Tape 81
tape/id:81/19:./DAT 081/SL-DAT 081#82.25.wav (-1 results)

36 Files auf HD

18 Platten

SL-DAT 081#82.02.wav ist der zweite Teil von VII 78/1643. Manuell umbenannt


=item Tape 82
tape/id:82/19:./DAT 082/SL-DAT 082#82.39.wav (-1 results)

36 Files on FP
18 Platten in der DB

Einseitig laut DB: 1662 und 1676, Autopsie 1662 hat zwei Seiten

letzter Track kurz und springt


=item Tape 83
tape/id:83/21:./DAT 083/SL-DAT 083#84.44.wav (-1 results)

Hat 40 Dateien laut FP

Hat 20 Schallplatten laut DB VII 78/1698 hat laut Autospie 2 seiten

=item Tape 84

tape/id:84/25:./DAT 084/SL-DAT 084.42.wav (-1 results)

Hat 42 Files laut hardisk,
24 Platten laut DB, d.h. es m[sste 6 mit einer Seite geben]


=item Tape 90
tape/id:90/21:./DAT 090/SL-DAT 090#93.31.wav (-1 results)

Hat 40 Files auf HD

20 Schallplatten

=item Tape 91
tape/id:91/20:./DAT 091/SL-DAT 091#38.wav (-1 results)

Hat 38 Files auf HD
19 Platten

=item Tape 92
tape/id:92/21:./DAT 092/SL-DAT 092#39.wav (-1 results)

hat 40 Files

20 Platten

laut DB einseitig92939 und 1940

=item Tape 95
tape/id:95/21:./DAT 010/SL-DAT 095#95.wav (-1 results)

40 Files

20 Platten

=item Tape 96
tape/id:96/19:./DAT 096/SL-DAT 096#97.09.wav (-1 results)

=item Tape 104
tape/id:104/1:./DAT 104/SL-DAT 104#105.01.wav (1 results)

40 Files
20 Platten laut DB


=item Tape 107

Hat 41 Tracks auf HD. Hat 20 Platten laut DB (VII 78/2225-2244). Letzter Track hört sich koreanisch an,
vielleicht VII 78/2245? Ist aber nicht mit diesem ID in der DB. Für Band 107 ignoriere ich den Track, indem
ich ihn umbenenne. 

2229 kein Titel in DB, 1 produktnummer. A: hat 2. Seite ohne Titel, aber unklar, ob abspielbar
2230 ist aber 107/06, also muss 2229 2 Seiten haben
2242 kein Titel in DB, 2 Produktnummeren
2243 kein Titel in DB, 2 Produktnummeren
2244 kein Titel in DB, 2 Produktnummeren

alle anderen haben 2 Titel.

d.h. Laut DB nur 39 Tracks

=item Tape 108

tape/id:108/1:./DAT 108/SL-DAT 108#1.wav (-1 results)

Band 108 ist komplett nicht in DB eingegeben. Ich kann Martins komplette Digitalisat von der Kassette 108 
nicht finden! Es ligen nur 2 Tracks vor, unklar, ob es nicht mehr auf dem DAT sind.

Nur 2 Tracks! Männliche Stimme, Asiatische Sprache. ISt bestimmt VII 78/2245

Mein XML-FIle scheint nicht komplett zu sein. Lösung: Ich habe kein Band 108. Als Ausnahme im Skript definieren!

Ich muss aber erst das DAT anhören!

=item TODO



=back

=head1 TODO

=over
 
=item document more commands

=back

=head1 DEPENDENCIES

=over

=item look at use in the beginning for use!

=back

For Libxml under windows it might be easier to get it by compiled from
ppm. I think I used http://theoryx5.uwinnipeg.ca/ppmpackages/XML-libXML.ppd


=head1 AUTHOR

Maurice Mengel

=head1 COPYRIGHT 2009

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

