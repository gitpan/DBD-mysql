#!/usr/local/bin/perl
#
#   $Id: 40bindparam.t 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
#
#   This is a skeleton test. For writing new tests, take this file
#   and modify/extend it.
#


#
#   Make -w happy
#
$test_dsn = '';
$test_user = '';
$test_password = '';


#
#   Include lib.pl
#
require DBI;
use vars qw($COL_NULLABLE);
$mdriver = "";
foreach $file ("lib.pl", "t/lib.pl") {
    do $file; if ($@) { print STDERR "Error while executing lib.pl: $@\n";
			   exit 10;
		      }
    if ($mdriver ne '') {
	last;
    }
}
if ($mdriver eq 'pNET') {
    print "1..0\n";
    exit 0;
}

sub ServerError() {
    my $err = $DBI::errstr;  # Hate -w ...
    print STDERR ("Cannot connect: ", $DBI::errstr, "\n",
	"\tEither your server is not up and running or you have no\n",
	"\tpermissions for acessing the DSN $test_dsn.\n",
	"\tThis test requires a running server and write permissions.\n",
	"\tPlease make sure your server is running and you have\n",
	"\tpermissions, then retry.\n");
    exit 10;
}

if (!defined(&SQL_VARCHAR)) {
    eval "sub SQL_VARCHAR { 12 }";
}
if (!defined(&SQL_INTEGER)) {
    eval "sub SQL_INTEGER { 4 }";
}

#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
while (Testing()) {
    #
    #   Connect to the database
    Test($state or $dbh = DBI->connect($test_dsn, $test_user, $test_password))
	or ServerError();

    #
    #   Find a possible new table name
    #
    Test($state or $table = FindNewTable($dbh))
	   or DbiError($dbh->err, $dbh->errstr);

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($def = TableDefinition($table,
					   ["id",   "INTEGER",  4, 0],
					   ["name", "CHAR",    64, $COL_NULLABLE]),
		    $dbh->do($def)))
	   or DbiError($dbh->err, $dbh->errstr);


    Test($state or $cursor = $dbh->prepare("INSERT INTO $table"
	                                   . " VALUES (?, ?)"))
	   or DbiError($dbh->err, $dbh->errstr);

    #
    #   Insert some values using bind_param
    #
    Test($state or $cursor->bind_param(1, 1, SQL_INTEGER()))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->bind_param(2, "Alligator Descartes",
				       {TEST => SQL_VARCHAR()}))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->execute)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->bind_param(1, 2, SQL_INTEGER()))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->bind_param(2, "Tim Bunce",
				       {TEST => SQL_VARCHAR()}))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->execute)
	or DbiError($dbh->err, $dbh->errstr);
  
    Test($state or $cursor->bind_param(1, 3, SQL_INTEGER()))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->bind_param(2, "Jochen Wiedmann",
				       SQL_VARCHAR()))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->execute)
	or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->bind_param(1, 4, SQL_INTEGER()))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->bind_param(2, undef))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->execute)
 	or DbiError($dbh->err, $dbh->errstr);
  


    Test($state or undef $cursor  ||  1);

    #
    #   And now retreive them using bind_columns
    #
    Test($state or $cursor = $dbh->prepare("SELECT * FROM $table"
					   . " ORDER BY id"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->bind_columns(undef, \$id, \$name))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($ref = $cursor->fetch)  &&  $id == 1  &&
		   $name eq 'Alligator Descartes')
	   or DbiError($dbh->err, $dbh->errstr);
    if (!$state && $verbose) {
	print "Query returned id = $id, name = $name, ref = $ref, @$ref\n";
    }

    Test($state or (($ref = $cursor->fetch)  &&  $id == 2  &&
		    $name eq 'Tim Bunce'))
	   or DbiError($dbh->err, $dbh->errstr);
    if (!$state && $verbose) {
	print "Query returned id = $id, name = $name, ref = $ref, @$ref\n";
    }

    Test($state or (($ref = $cursor->fetch)  &&  $id == 3  &&
		    $name eq 'Jochen Wiedmann'))
	or DbiError($dbh->err, $dbh->errstr);
    if (!$state && $verbose) {
 	print "Query returned id = $id, name = $name, ref = $ref, @$ref\n";
    }
 
    Test($state or (($ref = $cursor->fetch)  &&  $id == 4  &&
 		    !defined($name)))
	   or DbiError($dbh->err, $dbh->errstr);
    if (!$state && $verbose) {
	print "Query returned id = $id, name = $name, ref = $ref, @$ref\n";
    }

    Test($state or undef $cursor  or  1);

    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or DbiError($dbh->err, $dbh->errstr);
}
