#   Our beloved Emacs will give us -*- perl -*- mode :-)
#
#   $Id: mysql.pm 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
#
#   Copyright (c) 1994,1995,1996,1997 Alligator Descartes, Tim Bunce
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

package DBD::mysql;
use strict;
use vars qw(@ISA $VERSION $err $errstr $drh);

use DBI ();
use DynaLoader();
use Carp ();
@ISA = qw(DynaLoader);

$VERSION = '2.01_10';

bootstrap DBD::mysql $VERSION;


$err = 0;	# holds error code   for DBI::err
$errstr = "";	# holds error string for DBI::errstr
$drh = undef;	# holds driver handle once initialised

sub driver{
    return $drh if $drh;
    my($class, $attr) = @_;

    $class .= "::dr";

    # not a 'my' since we use it above to prevent multiple drivers
    $drh = DBI::_new_drh($class, { 'Name' => 'mysql',
				   'Version' => $VERSION,
				   'Err'    => \$DBD::mysql::err,
				   'Errstr' => \$DBD::mysql::errstr,
				   'Attribution' => 'DBD::mysql by Jochen Wiedmann'
				 });

    $drh;
}

sub _OdbcParse($$$) {
    my($class, $dsn, $hash, $args) = @_;
    my($var, $val);
    if (!defined($dsn)) {
	return;
    }
    while (length($dsn)) {
	if ($dsn =~ /([^:;]*)[:;](.*)/) {
	    $val = $1;
	    $dsn = $2;
	} else {
	    $val = $dsn;
	    $dsn = '';
	}
	if ($val =~ /([^=]*)=(.*)/) {
	    $var = $1;
	    $val = $2;
	    if ($var eq 'hostname') {
		$hash->{'host'} = $val;
	    } elsif ($var eq 'db'  ||  $var eq 'dbname') {
		$hash->{'database'} = $val;
	    } else {
		$hash->{$var} = $val;
	    }
	} else {
	    foreach $var (@$args) {
		if (!defined($hash->{$var})) {
		    $hash->{$var} = $val;
		}
		last;
	    }
	}
    }
}

sub _OdbcParseHost ($$) {
    my($class, $dsn) = @_;
    my($hash) = {};
    $class->_OdbcParse($dsn, $hash, ['host', 'port']);
    ($hash->{'host'}, $hash->{'port'});
}

sub AUTOLOAD {
    my ($meth) = $DBD::mysql::AUTOLOAD;
    my ($smeth) = $meth;
    $smeth =~ s/(.*)\:\://;

    my $val = constant($smeth, @_ ? $_[0] : 0);
    if ($! == 0) { eval "sub $meth { $val }"; return $val; }

    Carp::croak "$meth: Not defined";
}

1;


package DBD::mysql::dr; # ====== DRIVER ======
use strict;

sub connect {
    my($drh, $dsn, $username, $password, $attrhash) = @_;
    my($port);
    my($cWarn);

    # Avoid warnings for undefined values
    $username ||= '';
    $password ||= '';

    # create a 'blank' dbh
    my($this, $privateAttrHash);
    $privateAttrHash = {
	'dsn' => $dsn,
	'user' => $username,
	'password' => $password
    };

    DBD::mysql->_OdbcParse($dsn, $privateAttrHash,
				  ['database', 'host', 'port']);

    if (!defined($this = DBI::_new_dbh($drh, {}, $privateAttrHash))) {
	return undef;
    }

    $this->{'private_DBD_mysql_attr'} = $privateAttrHash;

    # Call msqlConnect func in mSQL.xs file
    # and populate internal handle data.
    DBD::mysql::db::_login($this, $dsn, $username, $password)
	  or $this = undef;
    $this;
}

sub data_sources {
    my($self) = shift;
    my(@dsn) = $self->func('', '_ListDBs');
    my($i);
    for ($i = 0;  $i < @dsn;  $i++) {
	$dsn[$i] = "DBI:mysql:$dsn[$i]";
    }
    @dsn;
}

sub admin {
    my($drh) = shift;
    my($command) = shift;
    my($dbname) = ($command eq 'createdb'  ||  $command eq 'dropdb') ?
	shift : '';
    my($host, $port) = DBD::mysql->_OdbcParseHost(shift(@_) || '');
    my($user) = shift || '';
    my($password) = shift || '';

    $drh->func(undef, $command,
	       $dbname || '',
	       $host || '',
	       $port || '',
	       $user, $password, '_admin_internal');
}

sub _CreateDB {
    my($drh) = shift;
    my($host) = (@_ > 1) ? shift : undef;
    my($dbname) = shift;
    if (!$DBD::mysql::QUIET) {
	warn "'_CreateDB' is deprecated, use 'admin' instead";
    }
    $drh->func('createdb', $dbname, $host, 'admin');
}

sub _DropDB {
    my($drh) = shift;
    my($host) = (@_ > 1) ? shift : undef;
    my($dbname) = shift;
    if (!$DBD::mysql::QUIET) {
	warn "'DropDB' is deprecated, use 'admin' instead";
    }
    $drh->func('dropdb', $dbname, $host, 'admin');
}


package DBD::mysql::db; # ====== DATABASE ======
use strict;

%DBD::mysql::db::db2ANSI = ("INT"   =>  "INTEGER",
			   "CHAR"  =>  "CHAR",
			   "REAL"  =>  "REAL",
			   "IDENT" =>  "DECIMAL"
                          );

### ANSI datatype mapping to mSQL datatypes
%DBD::mysql::db::ANSI2db = ("CHAR"          => "CHAR",
			   "VARCHAR"       => "CHAR",
			   "LONGVARCHAR"   => "CHAR",
			   "NUMERIC"       => "INTEGER",
			   "DECIMAL"       => "INTEGER",
			   "BIT"           => "INTEGER",
			   "TINYINT"       => "INTEGER",
			   "SMALLINT"      => "INTEGER",
			   "INTEGER"       => "INTEGER",
			   "BIGINT"        => "INTEGER",
			   "REAL"          => "REAL",
			   "FLOAT"         => "REAL",
			   "DOUBLE"        => "REAL",
			   "BINARY"        => "CHAR",
			   "VARBINARY"     => "CHAR",
			   "LONGVARBINARY" => "CHAR",
			   "DATE"          => "CHAR",
			   "TIME"          => "CHAR",
			   "TIMESTAMP"     => "CHAR"
			  );

sub prepare {
    my($dbh, $statement)= @_;

    # create a 'blank' dbh
    my $sth = DBI::_new_sth($dbh, {
	'Statement' => $statement,
    });

    # Populate internal handle data.
    if (!DBD::mysql::st::_prepare($sth, $statement)) {
	$sth = undef;
    }

    $sth;
}

sub db2ANSI {
    my $self = shift;
    my $type = shift;
    return $DBD::mysql::db::db2ANSI{"$type"};
}

sub ANSI2db {
    my $self = shift;
    my $type = shift;
    return $DBD::mysql::db::ANSI2db{"$type"};
}

sub _ListFields($$) {
    my($self, $table) = @_;
    if (!$DBD::mysql::QUIET) {
	warn "'_ListFields' is deprecated, use the SQL query 'LISTFIELDS \$table' instead.";
    }
    my($sth) = $self->prepare("LISTFIELDS $table");
    if ($sth  &&  !$sth->execute()) {
	undef $sth;
    }
    $sth;
}

sub admin {
    my($dbh) = shift;
    my($command) = shift;
    my($dbname) = ($command eq 'createdb'  ||  $command eq 'dropdb') ?
	shift : '';
    $dbh->{'Driver'}->func($dbh, $command, $dbname, '', '', '',
			   '_admin_internal');
}


package DBD::mysql::st; # ====== STATEMENT ======
use strict;

# Just a stub for backward compatibility; use is deprecated
sub _ListSelectedFields ($) {
    if (!$DBD::mysql::QUIET) {
	warn "_ListSelectedFields is deprecated and superfluos";
    }
    shift;
}

sub _NumRows ($) {
    if (!$DBD::mysql::QUIET) {
	warn "_NumRows is deprecated, use \$sth->rows instead.";
    }
    shift->rows;
}

1;


__END__

=head1 NAME

DBD::mSQL / DBD::mysql - mSQL and mysql drivers for the Perl5 Database
Interface (DBI)

=head1 SYNOPSIS

    use DBI;

    $dbh = DBI->connect("DBI:mSQL:$database:$hostname:$port",
			undef, undef);

        or

    $dbh = DBI->connect("DBI:mysql:$database:$hostname:$port",
			$user, $password);

    @databases = DBD::mysql::dr->func($host, $port, '_ListDBs');
    @tables = $dbh->func( '_ListTables' );

    $sth = $dbh->prepare("SELECT * FROM foo WHERE bla");
       or
    $sth = $dbh->prepare("LISTFIELDS $table");
       or
    $sth = $dbh->prepare("LISTINDEX $table $index");
    $sth->execute;
    $numRows = $sth->rows;
    $numFields = $sth->{'NUM_OF_FIELDS'};
    $sth->finish;

    $rc = $drh->func('createdb', $database, $host, $user, $password, 'admin');
    $rc = $drh->func('dropdb', $database, $host, $user, $password, 'admin');
    $rc = $drh->func('shutdown', $host, $user, $password, 'admin');
    $rc = $drh->func('reload', $host, $user, $password, 'admin');

    $rc = $dbh->func('createdb', $database, 'admin');
    $rc = $dbh->func('dropdb', $database, 'admin');
    $rc = $dbh->func('shutdown', 'admin');
    $rc = $dbh->func('reload', 'admin');


=head1 EXPERIMENTAL SOFTWARE

This package contains experimental software and should *not* be used
in a production environment. We are following the Linux convention and
treat the "even" releases (1.18xx as of this writing, perhaps 1.20xx,
1.22xx, ... in the future) as stable. Only bug or portability fixes
will go into these releases.

The "odd" releases (1.19xx as of this writing, perhaps 1.21xx, 1.23xx
in the future) will be used for testing new features or other serious
code changes.


=head1 DESCRIPTION

<DBD::mysql> and <DBD::mSQL> are the Perl5 Database Interface drivers for
the mysql, mSQL 1.I<x> and mSQL 2.I<x> databases. The drivers are part
of the I<Msql-Mysql-modules> package.


=head2 Class Methods

=over 4

=item B<connect>

    use DBI;

    $dsn = "DBI:mSQL:$database";
    $dsn = "DBI:mSQL:database=$database;host=$hostname";
    $dsn = "DBI:mSQL:database=$database;host=$hostname;port=$port";

    $dbh = DBI->connect($dsn, undef, undef);

        or

    $dsn = "DBI:mysql:$database";
    $dsn = "DBI:mysql:database=$database;host=$hostname";
    $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";

    $dbh = DBI->connect($dsn, $user, $password);

A C<database> must always be specified.

The hostname, if not specified or specified as '', will default to an
mysql or mSQL daemon running on the local machine on the default port
for the UNIX socket.

Should the mysql or mSQL daemon be running on a non-standard port number,
you may explicitly state the port number to connect to in the C<hostname>
argument, by concatenating the I<hostname> and I<port number> together
separated by a colon ( C<:> ) character.

=back

=head2 Private MetaData Methods

=over 4

=item B<ListDBs>

    @dbs = $dbh->func("$hostname:$port", '_ListDBs');

Returns a list of all databases managed by the mysql daemon or
mSQL daemon running on C<$hostname>, port C<$port>. This method
is rarely needed for databases running on C<localhost>: You should
use the portable method

    @dbs = DBI->data_sources("mysql");

        or

    @dbs = DBI->data_sources("mSQL");

whenever possible. It is a design problem of this method, that there's
no way of supplying a host name or port number to C<data_sources>, that's
the only reason why we still support C<ListDBs>. :-(


=item B<ListTables>

    @tables = $dbh->func('_ListTables');

Once connected to the desired database on the desired mysql or mSQL
mSQL daemon with the C<DBI->connect()> method, we may extract a list
of the tables that have been created within that database.

C<ListTables> returns an array containing the names of all the tables
present within the selected database. If no tables have been created,
an empty list is returned.

    @tables = $dbh->func( '_ListTables' );
    foreach $table ( @tables ) {
        print "Table: $table\n";
      }


=item B<ListFields>

Deprecated, see L</COMPATIBILITY ALERT> below. Used to be equivalent
to

    $sth = $dbh->prepare("LISTFIELDS $table");
    $sth->execute;

See L</SQL EXTENSIONS> below.


=item B<ListSelectedFields>

Deprecated, see L</COMPATIBILITY ALERT> below.

=back


=head2 Server Administration

=over 4

=item admin

    $rc = $drh->func("createdb", $dbname, [host, user, password,], 'admin');
    $rc = $drh->func("dropdb", $dbname, [host, user, password,], 'admin');
    $rc = $drh->func("shutdown", [host, user, password,], 'admin');
    $rc = $drh->func("reload", [host, user, password,], 'admin');

      or

    $rc = $dbh->func("createdb", $dbname, 'admin');
    $rc = $dbh->func("dropdb", $dbname, 'admin');
    $rc = $dbh->func("shutdown", 'admin');
    $rc = $dbh->func("reload", 'admin');

For server administration you need a server connection. For obtaining
this connection you have two options: Either use a driver handle (drh)
and supply the appropriate arguments (host, defaults localhost, user,
defaults to '' and password, defaults to ''). A driver handle can be
obtained with

    $drh = DBI->install_driver('mysql');

Otherwise reuse the existing connection of a database handle (dbh).

There's only one function available for administrative purposes, comparable
to the m(y)sqladmin programs. The command being execute depends on the
first argument:

=over 8

=item createdb

Creates the database $dbname. Equivalent to "m(y)sqladmin create $dbname".

=item dropdb

Drops the database $dbname. Equivalent to "m(y)sqladmin drop $dbname".

It should be noted that database deletion is
I<not prompted for> in any way.  Nor is it undo-able from DBI.

    Once you issue the dropDB() method, the database will be gone!

These method should be used at your own risk.

=item shutdown

Silently shuts down the database engine. (Without prompting!)
Equivalent to "m(y)sqladmin shutdown".

=item reload

Reloads the servers configuration files and/or tables. This can be particularly
important if you modify access privileges or create new users.

=back


=item B<_CreateDB>

=item B<_DropDB>


These methods are deprecated, see L</COMPATIBILITY ALERT> below.!

    $rc = $drh->func( $database, '_CreateDB' );
    $rc = $drh->func( $database, '_DropDB' );

      or

    $rc = $drh->func( $host, $database, '_CreateDB' );
    $rc = $drh->func( $host, $database, '_DropDB' );

These methods are equivalent to the admin method with "createdb" or
"dropdb" commands, respectively. In particular note the warnings
concerning the missing prompt for dropping a database!

=back


=head1 DATABASE HANDLES

The DBD::mysql driver supports the following attributes of database
handles (read only):

    $infoString = $dbh->{'info'};
    $threadId = $dbh->{'thread_id'};

These correspond to mysql_info() and mysql_tread_id(), respectively.


=head1 STATEMENT HANDLES

The statement handles of DBD::mysql and DBD::mSQL support a number
of attributes. You access these by using, for example,

  my $numFields = $sth->{'NUM_OF_FIELDS'};

Note, that most attributes are valid only after a successfull I<execute>.
An C<undef> value will returned in that case. The most important exception
is the C<mysql_use_result> attribute: This forces the driver to use
mysql_use_result rather than mysql_store_result. The former is faster
and less memory consuming, but tends to block other processes. (That's why
mysql_store_result is the default.)

To set the C<mysql_use_result> attribute, use either of the following:

  my $sth = $dbh->prepare("QUERY", { "mysql_use_result" => 1});

or

  my $sth = $dbh->prepare("QUERY");
  $sth->{"mysql_use_result"} = 1;

Of course it doesn't make sense to set this attribute before calling the
C<execute> method.

Column dependent attributes, for example I<NAME>, the column names,
are returned as a reference to an array. The array indices are
corresponding to the indices of the arrays returned by I<fetchrow>
and similar methods. For example the following code will print a
header of table names together with all rows:

  my $sth = $dbh->prepare("SELECT * FROM $table");
  if (!$sth) {
      die "Error:" . $dbh->errstr . "\n";
  }
  if (!$sth->execute) {
      die "Error:" . $sth->errstr . "\n";
  }
  my $names = $sth->{'NAME'};
  my $numFields = $sth->{'NUM_OF_FIELDS'};
  for (my $i = 0;  $i < $numFields;  $i++) {
      printf("%s%s", $$names[$i], $i ? "," : "");
  }
  print "\n";
  while (my $ref = $sth->fetchrow_arrayref) {
      for (my $i = 0;  $i < $numFields;  $i++) {
	  printf("%s%s", $$ref[$i], $i ? "," : "");
      }
      print "\n";
  }

For portable applications you should restrict yourself to attributes with
capitalized or mixed case names. Lower case attribute names are private
to DBD::mSQL and DBD::mysql. The attribute list includes:

=over 4

=item ChopBlanks

this attribute determines whether a I<fetchrow> will chop preceding
and trailing blanks off the column values. Chopping blanks does not
have impact on the I<max_length> attribute.

=item insertid

MySQL has the ability to choose unique key values automatically. If this
happened, the new ID will be stored in this attribute. This attribute
is not valid for DBD::mSQL.

=item is_blob

Reference to an array of boolean values; TRUE indicates, that the
respective column is a blob. This attribute is valid for MySQL only.

=item is_key

Reference to an array of boolean values; TRUE indicates, that the
respective column is a key. This is valid for MySQL only.

=item is_num

Reference to an array of boolean values; TRUE indicates, that the
respective column contains numeric values.

=item is_pri_key

Reference to an array of boolean values; TRUE indicates, that the
respective column is a primary key. This is only valid for MySQL
and mSQL 1.0.x: mSQL 2.x uses indices.

=item is_not_null

A reference to an array of boolean values; FALSE indicates that this
column may contain NULL's. You should better use the I<NULLABLE>
attribute above which is a DBI standard.

=item length

=item max_length

A reference to an array of maximum column sizes. The I<max_length> is
the maximum physically present in the result table, I<length> gives
the theoretically possible maximum. I<max_length> is valid for MySQL
only.

=item NAME

A reference to an array of column names.

=item NULLABLE

A reference to an array of boolean values; TRUE indicates that this column
may contain NULL's.

=item NUM_OF_FIELDS

Number of fields returned by a I<SELECT> or I<LISTFIELDS> statement.
You may use this for checking whether a statement returned a result:
A zero value indicates a non-SELECT statement like I<INSERT>,
I<DELETE> or I<UPDATE>.

=item table

A reference to an array of table names, useful in a I<JOIN> result.

=item type

A reference to an array of column types. It depends on the DBMS,
which values are returned, even for identical types. mSQL will
return types like &DBD::mSQL::INT_TYPE, &DBD::msql::TEXT_TYPE etc.,
MySQL uses &DBD::mysql::FIELD_TYPE_SHORT, &DBD::mysql::FIELD_TYPE_STRING etc.

=back


=head1 SQL EXTENSIONS

Certain metadata functions of mSQL and mysql that are available on the
C API level, haven't been implemented here. Instead they are implemented
as "SQL extensions" because they return in fact nothing else but the
equivalent of a statement handle. These are:

=over 4

=item LISTFIELDS $table

Returns a statement handle that describes the columns of $table.
Ses the docs of msqlListFields or mysql_list_fields for details.

=item LISTINDEX $table $index

mSQL only; returns a statement handle that describes the index $index
of table $table. See the docs of msqlListIndex for details.

=back

=head1 COMPATIBILITY ALERT

Certain attributes methods have been declared obsolete or deprecated,
partially because there names are agains DBI's naming conventions,
partially because they are just superfluous or obsoleted by other methods.

Obsoleted attributes and methods will be explicitly listed below. You cannot
expect them to work in future versions, but they have not yet been scheduled
for removal and currently they should be usable without any code modifications.

Deprecated attributes and methods will currently issue a warning unless
you set the variable $DBD::mysql::QUIET to a true value. This will
be the same for Msql-Mysql-modules 1.19xx and 1.20xx. They will be silently
removed in 1.21xx.

Here is a list of obsoleted attributes and/or methods:

=over 4

=item _CreateDB

=item _DropDB

deprecated, use

    $drh->func("createdb", $dbname, $host, "admin")
    $drh->func("dropdb", $dbname, $host, "admin")

=item _ListFields

deprecated, use

    $sth = $dbh->prepare("LISTFIELDS $table")
    $sth->execute;

=item _ListSelectedFields

deprecated, just use the statement handles for accessing the same attributes.

=item _NumRows

deprecated, use

    $numRows = $sth->rows;

=item IS_PRI_KEY

=item IS_NOT_NULL

=item IS_KEY

=item IS_BLOB

=item IS_NUM

=item LENGTH

=item MAXLENGTH

=item NUMROWS

=item NUMFIELDS

=item RESULT

=item TABLE

=item TYPE

All these statement handle attributes are obsolete. They can be simply
replaced by just downcasing the attribute names. You should expect them
to be deprecated as of Msql-Mysql-modules 1.1821. (Whenever that will
be.)

=back


=head1 BUGS

The I<port> part of the first argument to the connect call is
implemented in an unsafe way when using mSQL. In fact it is just
stting the environment variable MSQL_TCP_PORT during the connect
call. If another connect call uses another port and the handles
are used simultaneously, they will interfere. I doubt that this
will ever change.

Please speak up now (June 1997) if you encounter additional bugs. I'm
still learning about the DBI API and can neither judge the quality of
the code presented here nor the DBI compliancy. But I'm intending to
resolve things quickly as I'd really like to get rid of the multitude
of implementations ASAP.

When running "make test", you will notice that some test scripts fail.
This is due to bugs in the respective databases, not in the DBI drivers:

=over 4

=item Nulls

mSQL seems to have problems with NULL's: The following fails with
mSQL 2.0.1 running on a Linux 2.0.30 machine:

    [joe@laptop Msql-modules-1.18]$ msql test
    Welcome to the miniSQL monitor.  Type \h for help.
    mSQL > CREATE TABLE foo (id INTEGER, name CHAR(6))\g
    Query OK.  1 row(s) modified or retrieved.
    mSQL > INSERT INTO foo VALUES (NULL, 'joe')\g
    Query OK.  1 row(s) modified or retrieved.
    mSQL > SELECT * FROM foo WHERE id = NULL\g
    Query OK.  0 row(s) modified or retrieved.
    +----------+------+
    | id       | name |
    +----------+------+
    +----------+------+
    mSQL > 

=item Blanks

mysql has problems with Blanks on the right side of string fields: They
get chopped of. (Tested with mysql 3.20.25 on a Linux 2.0.30 machine.)

    [joe@laptop Msql-modules-1.18]$ mysql test
    Welcome to the mysql monitor.  Commands ends with ; or \g.
    Type 'help' for help.
    mysql> CREATE TABLE foo (id INTEGER, bar CHAR(8));
    Query OK, 0 rows affected (0.10 sec)
    mysql> INSERT INTO foo VALUES (1, ' a b c ');
    Query OK, 1 rows affected (0.00 sec)
    mysql> SELECT * FROM foo;
    1 rows in set (0.19 sec)
    +------+--------+
    | id   | bar    |
    +------+--------+
    |    1 |  a b c |
    +------+--------+
    mysql> quit;
    [joe@laptop Msql-modules-1.18]$ mysqldump test foo

    [deleted]

    INSERT INTO foo VALUES (1,' a b c');

=back

=head1 AUTHOR

B<DBD::mSQL> has been primarily written by Alligator Descartes
(I<descarte@hermetica.com>), who has been aided and abetted by Gary
Shea, Andreas Koenig and Tim Bunce amongst others. Apologies if your
name isn't listed, it probably is in the file called
'Acknowledgments'. As of version 0.80 the maintainer is Andreas König.
Version 2.00 is an almost complete rewrite by Jochen Wiedmann.


=head1 COPYRIGHT

This module is Copyright (c)1997 Jochen Wiedmann, with code portions
Copyright (c)1994-1997 their original authors. This module is
released under the 'Artistic' license which you can find in the perl
distribution.

This document is Copyright (c)1997 Alligator Descartes. All rights
reserved.  Permission to distribute this document, in full or in part,
via email, Usenet, ftp archives or http is granted providing that no
charges are involved, reasonable attempt is made to use the most
current version and all credits and copyright notices are retained (
the I<AUTHOR> and I<COPYRIGHT> sections ).  Requests for other
distribution rights, including incorporation into commercial products,
such as books, magazine articles or CD-ROMs should be made to
Alligator Descartes <I<descarte@hermetica.com>>.


=head1 MAILING LIST SUPPORT

This module is maintained and supported on a mailing list,

    msql-mysql-modules@tcx.se

To subscribe to this list, send a mail with the words

    subscribe msql-mysql-modules

or

    subscribe msql-mysql-modules-digest

in the first line of the body to mdomo@tcx.se. A mailing list archive is
in preparation.

Additionally you might try the dbi-user mailing list for questions about
DBI and its modules in general. Subscribe via

    http://www.fugue.com/dbi

Mailing list archives are at

     http://www.rosat.mpe-garching.mpg.de/mailing-lists/PerlDB-Interest/
     http://outside.organic.com/mail-archives/dbi-users/
     http://www.coe.missouri.edu/~faq/lists/dbi.html


=head1 ADDITIONAL DBI INFORMATION

Additional information on the DBI project can be found on the World
Wide Web at the following URL:

    http://www.hermetica.com/technologia/perl/DBI

where documentation, pointers to the mailing lists and mailing list
archives and pointers to the most current versions of the modules can
be used.

Information on the DBI interface itself can be gained by typing:

    perldoc DBI

right now!

=cut
