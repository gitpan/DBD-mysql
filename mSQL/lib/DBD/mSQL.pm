#   Our beloved Emacs will give us -*- perl -*- mode :-)
#
#   $Id: mysql.pm 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
#
#   Copyright (c) 1994,1995,1996,1997 Alligator Descartes, Tim Bunce
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

package DBD::mSQL;
use strict;
use vars qw(@ISA $VERSION $err $errstr $drh);

use DBI ();
use DynaLoader();
use Carp ();
@ISA = qw(DynaLoader);

$VERSION = '2.03_08';

bootstrap DBD::mSQL $VERSION;


$err = 0;	# holds error code   for DBI::err
$errstr = "";	# holds error string for DBI::errstr
$drh = undef;	# holds driver handle once initialised

sub driver{
    return $drh if $drh;
    my($class, $attr) = @_;

    $class .= "::dr";

    # not a 'my' since we use it above to prevent multiple drivers
    $drh = DBI::_new_drh($class, { 'Name' => 'mSQL',
				   'Version' => $VERSION,
				   'Err'    => \$DBD::mSQL::err,
				   'Errstr' => \$DBD::mSQL::errstr,
				   'Attribution' => 'DBD::mSQL by Jochen Wiedmann'
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
	    if ($var eq 'hostname'  ||  $var eq 'host') {
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
		    last;
		}
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
    my ($meth) = $DBD::mSQL::AUTOLOAD;
    my ($smeth) = $meth;
    $smeth =~ s/(.*)\:\://;

    my $val = constant($smeth, @_ ? $_[0] : 0);
    if ($! == 0) { eval "sub $meth { $val }"; return $val; }

    Carp::croak "$meth: Not defined";
}

1;


package DBD::mSQL::dr; # ====== DRIVER ======
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
	'Name' => $dsn,
	'user' => $username,
	'password' => $password
    };

    DBD::mSQL->_OdbcParse($dsn, $privateAttrHash,
				  ['database', 'host', 'port']);

    if (!defined($this = DBI::_new_dbh($drh, {}, $privateAttrHash))) {
	return undef;
    }

    # Call msqlConnect func in mSQL.xs file
    # and populate internal handle data.
    DBD::mSQL::db::_login($this, $dsn, $username, $password)
	  or $this = undef;
    $this;
}

sub data_sources {
    my($self) = shift;
    my(@dsn) = $self->func('', '_ListDBs');
    my($i);
    for ($i = 0;  $i < @dsn;  $i++) {
	$dsn[$i] = "DBI:mSQL:$dsn[$i]";
    }
    @dsn;
}

sub admin {
    my($drh) = shift;
    my($command) = shift;
    my($dbname) = ($command eq 'createdb'  ||  $command eq 'dropdb') ?
	shift : '';
    my($host, $port) = DBD::mSQL->_OdbcParseHost(shift(@_) || '');
    my($user) = shift || '';
    my($password) = shift || '';

    $drh->func(undef, $command,
	       $dbname || '',
	       $host || '',
	       $port || '',
	       $user, $password, '_admin_internal');
}

package DBD::mSQL::db; # ====== DATABASE ======
use strict;

%DBD::mSQL::db::db2ANSI = ("INT"   =>  "INTEGER",
			   "CHAR"  =>  "CHAR",
			   "REAL"  =>  "REAL",
			   "IDENT" =>  "DECIMAL"
                          );

### ANSI datatype mapping to mSQL datatypes
%DBD::mSQL::db::ANSI2db = ("CHAR"          => "CHAR",
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
    my $sth = DBI::_new_sth($dbh, {'Statement' => $statement});

    # Populate internal handle data.
    if (!DBD::mSQL::st::_prepare($sth, $statement)) {
	$sth = undef;
    }

    $sth;
}

sub db2ANSI {
    my $self = shift;
    my $type = shift;
    return $DBD::mSQL::db::db2ANSI{"$type"};
}

sub ANSI2db {
    my $self = shift;
    my $type = shift;
    return $DBD::mSQL::db::ANSI2db{"$type"};
}

sub admin {
    my($dbh) = shift;
    my($command) = shift;
    my($dbname) = ($command eq 'createdb'  ||  $command eq 'dropdb') ?
	shift : '';
    $dbh->{'Driver'}->func($dbh, $command, $dbname, '', '', '',
			   '_admin_internal');
}

sub _SelectDB ($$) {
    die "_SelectDB is removed from this module; use DBI->connect instead.";
}

{
    my $names = ['TABLE_QUALIFIER', 'TABLE_OWNER', 'TABLE_NAME',
		 'TABLE_TYPE', 'REMARKS'];

    sub table_info ($) {
	my $dbh = shift;
	my @tables = map { [ undef, undef, $_, 'TABLE', undef ]
			 } $dbh->func('_ListTables');
	my $dbh2;
	if (!($dbh2 = $dbh->{'~dbd_driver~_sponge_dbh'})) {
	    $dbh2 = $dbh->{'~dbd_driver~_sponge_dbh'} =
		DBI->connect("DBI:Sponge:");
	    if (!$dbh2) {
	        DBI::set_err($dbh, 1, $DBI::errstr);
		return undef;
	    }
	}
	my $sth = $dbh2->prepare("LISTTABLES", { 'rows' => \@tables,
						 'NAMES' => $names });
	if (!$sth) {
	    DBI::set_err($sth, $dbh2->err(), $dbh2->errstr());
	}
	$sth;
    }
}

package DBD::mSQL::st; # ====== STATEMENT ======
use strict;

1;


__END__

=head1 NAME

DBD::mSQL / DBD::mysql - mSQL and mysql drivers for the Perl5 Database
Interface (DBI)

=head1 SYNOPSIS

    use DBI;

    $driver = "mSQL"; # or "mSQL1";
    $dsn = "DBI:$driver:database=$database;host=$hostname";

    $dbh = DBI->connect($dsn, undef, undef);

        or

    $driver = "mysql";
    $dsn = "DBI:$driver:database=$database;host=$hostname;port=$port";

    $dbh = DBI->connect($dsn, $user, $password);


    $drh = DBI->install_driver("mSQL");
    @databases = $drh->func($host, $port, '_ListDBs');
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

    $driver = "mSQL";  #  or "mSQL1"
    $dsn = "DBI:$driver:$database";
    $dsn = "DBI:$driver:database=$database;host=$hostname";

    $dbh = DBI->connect($dsn, undef, undef);

        or

    $dsn = "DBI:mysql:$database";
    $dsn = "DBI:mysql:database=$database;host=$hostname";
    $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";

    $dbh = DBI->connect($dsn, $user, $password);

A C<database> must always be specified.

=over 8

=item host

=item port

The hostname, if not specified or specified as '', will default to an
mysql or mSQL daemon running on the local machine on the default port
for the UNIX socket.

Should the mysql or mSQL daemon be running on a non-standard port number,
you may explicitly state the port number to connect to in the C<hostname>
argument, by concatenating the I<hostname> and I<port number> together
separated by a colon ( C<:> ) character or by using the  C<port> argument.
This doesn't work for mSQL 2: You have to create an alternative config
file and load it using the msql_configfile attribute, see below.


=item msql_configfile

By default mSQL 2 loads its port settings and similar things from the
file InstDir/msql.conf. This option allows you to specify another
attribute, as in

    DBI->connect("DBI:mSQL:test;msql_configfile=msql_test.conf");

If the filename is not absolute, mSQL will search in certain other
locations, see the documentation of the msqlLoadConfigFile() function
in the mSQL manual for details.

=item mysql_compression

As of MySQL 3.22.3, a new feature is supported: If your DSN contains
the option "mysql_compression=1", then the communication between client
and server will be compressed.

=item mysql_read_default_file

=item mysql_read_default_group

These options can be used to read a config file like /etc/my.cnf or
~/.my.cnf. By default MySQL's C client library doesn't use any config
files unlike the client programs (mysql, mysqladmin, ...) that do, but
outside of the C client library. Thus you need to explicitly request
reading a config file, as in

    $dsn = "DBI:mysql:test;mysql_read_default_file=/home/joe/my.cnf";
    $dbh = DBI->connect($dsn, $user, $password)

The option mysql_read_default_group can be used to specify the default
group in the config file: Usually this is the I<client> group, but
see the following example:

    [perl]
    host=perlhost

    [client]
    host=localhost

If you read this config file, then you'll be typically connected to
I<localhost>. However, by using

    $dsn = "DBI:mysql:test;mysql_read_default_group=perl;"
        . "mysql_read_default_file=/home/joe/my.cnf";
    $dbh = DBI->connect($dsn, $user, $password);

you'll be connected to I<perlhost>. See the (missing :-) documentation
of the C function mysql_options() for details.

=item mysql_socket

As of MySQL 3.21.15, it is possible to choose the Unix socket that is
used for connecting to the server. This is done, for example, with

    mysql_socket=/dev/mysql

Usually there's no need for this option, unless you are using another
location for the socket than that built into the client.

=back

=back


=head2 Private MetaData Methods

=over 4

=item B<ListDBs>

    my $drh = DBI->install_driver("mSQL");
    @dbs = $drh->func("$hostname:$port", '_ListDBs');
    @dbs = $drh->func($hostname, $port, '_ListDBs');
    @dbs = $dbh->func('_ListDBs');

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

*WARNING*: This method is obsolete due to DBI's $dbh->table_info().

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

    $drh = DBI->install_driver('mSQL');

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


=back


=head1 DATABASE HANDLES

The DBD::mysql driver supports the following attributes of database
handles (read only):

    $infoString = $dbh->{'info'};
    $threadId = $dbh->{'thread_id'};
    $insertId = $dbh->{'mysql_insertid'}

These correspond to mysql_info(), mysql_thread_id() and mysql_insertid(),
respectively.


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
is not valid for DBD::mSQL. An alternative way for accessing this attribute
is via $dbh->{'mysql_insertid'}. (Note we are using the $dbh in this case!)

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

=item TYPE

A reference to an array of column types. The engine's native column
types are mapped to portable types like DBI::SQL_INTEGER() or
DBI::SQL_VARCHAR(), as good as possible. Not all native types have
a meaningfull equivalent, for example DBD::mSQL::IDX_TYPE() or
DBD::mysql::FIELD_TYPE_INTERVAL are mapped to DBI::SQL_VARCHAR().
If you need the native column types, use I<mysql_type> or I<msql_type>,
respectively. See below.


=item msql_type

A reference to an array of mSQL's native column types, for example
DBD::mSQL::INT_TYPE() or DBD::mSQL::CHAR_TYPE().
Use the I<TYPE> attribute, if you want portable types like
DBI::SQL_INTEGER() or DBI::SQL_VARCHAR().


=item msql_type_name

Similar to msql, but type names and not numbers are returned.
Whenever possible, the ANSI SQL name is preferred.

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

The statement attribute I<TYPE> has changed its meaning, as of
Msql-Mysql-modules 1.19_19. Formerly it used to be the an array
of native engine's column types, but it is now an array of
portable SQL column types. The old attribute is still available
as I<mysql_type> or I<msql_type>, respectively.

The Msql-Mysql-modules are a moving target, due to a number of reasons:

=over 8

=item -

Of course they have to conform the DBI guidelines and developments.

=item -

They have to keep track with the latest MySQL developments.

=item -

And, surprisingly, they have to be as close to ODBC as possible: This is
due to the current direction of DBI.

=item -

And, last not least, as any tool they have a little bit of own life.

=back

This means that a lot of things had to and have to be changed. As I am not
interested in maintaining a lot of compatibility kludges, which only
increase the drivers code without being really usefull, I did and will
remove some features, methods or attributes.

To ensure a smooth upgrade, the following policy will be applied:

=over 8

=item Obsolete features

The first step is to declare something obsolete. This means, that no code
is changed, but the feature appears in the list of obsolete features. See
L<Obsolete Features> below.

=item Deprecated features

If the feature has been obsolete for quite some time, typically in the
next major stable release, warnings will be inserted in the code. You
can suppress these warnings by setting

    $DBD::mSQL = 1;

In the docs the feature will be moved from the list of obsolete features
to the list of deprecated features. See L<Deprecated Features> below.

=item Removing features

Finally features will be removed silently in the next major stable
release. The feature will be shown in the list of historic features.
See L<Historic Features> below.

=back

Example: The statement handle attribute

    $sth->{'LENGTH'}

was declared obsolete in Msql-Mysql-modules 1.18xy. It is considered
deprecated in Msql-Mysql-modules 1.20xy (current as of this writing)
and will finally be removed in Msql-Mysql-modules 1.22xy.

=back


=head2 Obsolete Features

=over 8

=item _ListTables

This method is obsoleted by DBI's new method

    $dbh->tables()

See also $dbh->table_info(). Portable applications will prefer

    @tables = map { $_ =~ s/.*\.//; $_ } $dbh->tables()

because, depending on the engine, the string "user.table" will be
returned, user being the table owner. The method will be deprecated
in 1.23_xy and 1.24xy and removed in 1.25_xy and 1.26xy.

=back


=head2 Deprecated Features

=over 8

=item _InsertID

The method

    $dbh->func('_InsertID');

can be replaced with

    $dbh->{'mysql_insertid'};

The method is deprecated as of 1.21_xy, thus it will be removed in
1.23_xy and 1.24xy.

=item Statement handle attributes:

=over 12

=item affected_rows

=item IS_PRI_KEY

=item is_pri_key

=item IS_NOT_NULL

=item is_not_null

=item IS_KEY

=item is_key

=item IS_BLOB

=item is_blob

=item IS_NUM

=item is_num

=item LENGTH

=item length

=item MAXLENGTH

=item maxlength

=item NUMROWS

=item numrows

=item NUMFIELDS

=item numfields

=item RESULT

=item result

=item TABLE

=item table

=item format_max_size

=item format_default_size

=item format_type_name

=back

All of the above statement handle attributes are not conforming to DBI's
naming conventions, thus they have been declared deprecated in 1.20xy.
However, I forgot to insert warnings in the driver. These warnings have
been inserted in 1.21_07, thus the attributes will be removed in 1.23_xy
and 1.24xy.

In most of the above cases the driver name has been added and the resulting
name was lowercased. For example, you use

    $sth->{'msql_is_num'};

now. IS_NOT_NULL can be replaced with NULLABLE (note you need to invert
the logical value!), LENGTH, format_max_size and format_default_size will
be dropped in favour of PRECISION, affected_rows and NUMROWS are identical
with

    $sth->rows();

and NUMFIELDS is the same as NUM_OF_FIELDS. Finally format_right_justify
is the same as msql_type_name.

=back



=head2 Historic Features

=over 8

=item _CreateDB

=item _DropDB

The methods

    $dbh->func($db, '_CreateDB');
    $dbh->func($db, '_DropDB');

have been used for creating or dropping databases. They have been removed
in 1.21_07 in favour of

    $drh->func("createdb", $dbname, $host, "admin")
    $drh->func("dropdb", $dbname, $host, "admin")

=item _ListFields

The method

    $sth = $dbh->func($table, '_ListFields');

has been used to list a tables columns names, types and other attributes.
This method has been removed in 1.21_07 in favour of

    $sth = $dbh->prepare("LISTFIELDS $table");

=item _ListSelectedFields

The method

    $sth->func('_ListSelectedFields');

use to return a hash ref of attributes like 'IS_NUM', 'IS_KEY' and so
on. These attributes are now accessible via

    $sth->{'msql_is_num'};
    $sth->{'msql_is_key'};

and so on. Thus the method has been removed in 1.21_07.

=item _NumRows

The method

    $sth->func('_NumRows');

used to be equivalent to

    $sth->rows();

and has been removed in 1.21_07.

=back


=head1 MULTITHREADING

The multithreading capabilities of the Msql-Mysql-modules depend completely
on the underlying C libraries: The modules are working with handle data
only, no global variables are accessed or (to the best of my knowledge)
thread unsafe functions are called. Thus DBD::mSQL and DBD::mysql are
completely thread safe, if the C libraries thread safe and you don't
share handles among threads.

The obvious questions is: Are the C libraries thread safe? In the case of
mSQL the answer is definitely "no". The C library has a concept of one
single active connection at a time and that is not what threads like.

In the case of MySQL the answer is "mostly" and, in theory, you should
be able to get a "yes", if the C library is compiled for being thread
safe (By default it isn't.) by passing the option -with-thread-safe-client
to configure. See the section on I<How to make a threadsafe client> in
the manual.


=head1 BUGS

The I<port> part of the first argument to the connect call is
implemented in an unsafe way when using mSQL. In fact it is just
setting the environment variable MSQL_TCP_PORT during the connect
call. If another connect call uses another port and the handles
are used simultaneously, they will interfere. I doubt that this
will ever change.

Msql-2.0.4 and 2.0.4.1 contain a bug that makes ORDER BY and hence
the test script C<t/40bindparam> fail. To verify, if this is the
case for you, do a

	cd Msql
	perl -w -I../blib/lib -I../blib/arch t/40bindparam.t

If something is wrong, the script ought to print a number of id's and
names. If the id's aren't in order, it is likely, that your mSQL has
a bug. See the INSTALL file for a patch.


=head1 AUTHORS

B<DBD::mSQL> has been primarily written by Alligator Descartes
(I<descarte@arcana.co.uk>), who has been aided and abetted by Gary
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
Alligator Descartes <I<descarte@arcana.so.uk>>.


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

    http://www.arcana.co.uk/technologia/perl/DBI

where documentation, pointers to the mailing lists and mailing list
archives and pointers to the most current versions of the modules can
be used.

Information on the DBI interface itself can be gained by typing:

    perldoc DBI

right now!

=cut
