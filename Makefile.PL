#   Hej, Emacs, don't you see this is -*- perl -*- mode? :-)
#
#   Copyright (c) 1997  Andreas König, Jochen Wiedmann
#
#  You may distribute this under the terms of either the GNU General Public
#  License or the Artistic License, as specified in the Perl README file,
#  with the exception that it cannot be placed on a CD-ROM or similar media
#  for commercial distribution without the prior approval of the author.
#
#  $Id: Makefile.PL 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
#
BEGIN {require 5.004;}
use strict;
require ExtUtils::MakeMaker;
require File::Basename;
require File::Path;
require Config;
require Cwd;


my $VERSION = 1.1816;
my $DBD_VERSION = 2.006;


$| = 1;

print "Checking for DBI, 0.86 or later ... ";
$@ = '';
eval " use DBI 0.86 (); require DBI::DBD; ";
if ($@) {
    my $reply = ExtUtils::MakeMaker::prompt(
        "\n\n" .
        "You don't have installed the DBI module, version 0.86 or later." .
        " I cannot\n" .
        "continue installing the DBD modules. You have two options:\n\n" .
        "  1.) Abort now, install the DBI module (available at any CPAN" .
        " mirror,\n" .
        "      see 'perldoc CPAN') and rerun me. (Recommended)\n" .
        "  2.) Disable installation of the DBD modules and install the" .
        " non-DBD\n" .
        "      drivers only.\n\n" .
	"Do you want to abort now? ", "y");
    if ($reply =~ /y/i) {
	exit 10;
    }
    _MY::Config::disableDbd();
} else {
    print "ok\n";
    print "Checking for Data::ShowTable ... ";
    $@ = '';
    eval { require Data::ShowTable; };
    if ($@) {
	print "\n\n";
	print "You don't have installed the 'Data::ShowTable' module.\n";
	print "You won't be able to use 'dbimon', the DBI monitor until.\n";
	print "'Data::ShowTable' is installed. You get it at the CPAN.\n";
	print "See 'man CPAN' or 'perldoc CPAN' for more info.\n";
	print "I will install 'dbimon' anyways.\n\n";
    } else {
	print "ok\n";
    }
}


my $choosen = 0;
while (1) {
    my $reply = ExtUtils::MakeMaker::prompt(
        "\n\nWhich DBMS do you want to use?\n\n" .
	"  1) MySQL\n" .
        "  2) mSQL\n" .
        "  3) Both\n\n" .
	"Enter your choice: ", "3");
    if ($reply =~ /^1/) {
        _MY::Config::disableMsql();
	last;
    }
    if ($reply =~ /^2/) {
        _MY::Config::disableMysql();
	last;
    }
    if ($reply =~ /^3/) {
	last;
    }
}
	

_MY::Config::MakeDirs();


$::Verbose++ if $ENV{USER} eq "k";

ExtUtils::MakeMaker::WriteMakefile(
	      'NAME'         => 'Msql-Mysql-modules',
	      'dist'         => { 'SUFFIX'       => ".gz",
				  'DIST_DEFAULT' => 'all tardist',
				  'COMPRESS'     => "gzip -9f" },
	      'VERSION'      => $VERSION
);


package _MY::Config;

BEGIN {
    $_MY::Config::enableDbd = 1;
    $_MY::Config::enableMsql = 1;
    $_MY::Config::enableMysql = 1;
    $_MY::Config::X_Msql = undef;
    $_MY::Config::X_Mysql = undef;
};

sub disableDbd { $_MY::Config::enableDbd = 0; }
sub disableMsql { $_MY::Config::enableMsql = 0; }
sub disableMysql { $_MY::Config::enableMysql = 0; }

sub Extract ($$$$$$) {
    my($from, $to, $driver, $dbd_driver, $version, $dbd_version) = @_;
	
    my $dir = File::Basename::dirname($to);
    if (!(-d $dir)  &&  !File::Path::mkpath([$dir], 0, 0755)) {
	die "Cannot create directory $dir: $!";
    }

    if (!open(IN, "<$from")) {
	print STDERR "Cannot open $from for reading: $!\n";
	exit 10;
    }
    my ($line, $contents);
    $contents = '';
    while (defined($line = <IN>)) {
	$contents .= $line;
    }
    close IN;

    $contents =~ s/\~startperl\~/$Config::Config{startperl}/;
    $contents =~ s/\~DRIVER\~/$driver/g;
    $contents =~ s/\~DBD_DRIVER\~/$dbd_driver/g;
    $contents =~ s/\~NODBD_VERSION\~/$version/g;
    $contents =~ s/\~DBD_VERSION\~/$dbd_version/g;

    if (!open(OUT, ">$to")) {
	print STDERR "Cannot open $to for writing: $!\n";
	exit 10;
    }
    if (!print OUT $contents  ||  !close OUT) {
	print STDERR "Cannot write $to: $!\n";
	exit 10;
    }
}

sub MakeDirs () {
    if (-f "./.status") {
	do "./.status";
	if ($_MY::Config::enableDbd == $_MY::Config::Status::enableDbd  &&
	    $_MY::Config::enableMsql == $_MY::Config::Status::enableMsql  &&
	    $_MY::Config::enableMysql == $_MY::Config::Status::enableMysql) {
	    return;
	}
    }

    File::Path::rmtree(["lib"], 0, 0);
    File::Path::rmtree(["blib"], 0, 0);
    File::Path::rmtree(["DBD-mSQL"], 0, 0);
    File::Path::rmtree(["DBD-mysql"], 0, 0);
    File::Path::rmtree(["Mysql"], 0, 0);
    File::Path::rmtree(["Msql"], 0, 0);

    if ($_MY::Config::enableMysql) {
	my (@files) = (["nodbd/Makefile.PL.in", "Mysql/Makefile.PL"],
		       ["nodbd/bundle.pm.in", "lib/Bundle/Mysql.pm"],
		       ["nodbd/constants.c", "Mysql/constants.c"],
		       ["dbd/myMsql.c", "Mysql/myMsql.c"],
		       ["nodbd/nodbd.pm.in", "lib/Mysql.pm"],
		       ["nodbd/nodbd.xs.in", "Mysql/Mysql.xs"],
		       ["nodbd/pmsql.in", "Mysql/pmysql"],
		       ["nodbd/statement.pm.in", "lib/Mysql/Statement.pm"],
		       ["nodbd/typemap", "Mysql/typemap"],
		       ["tests/lib.pl", "Mysql/t/lib.pl"],
		       ["tests/mysql.t", "Mysql/t/mysql.t"],
		       ["tests/mysql2.t", "Mysql/t/mysql2.t"],
		       ["tests/akmisc.t", "Mysql/t/akmisc.t"]);

	if ($_MY::Config::enableDbd) {
	    push(@files,
		 ["dbd/Makefile.PL.in", "DBD-mysql/Makefile.PL"],
		 ["dbd/dbd.pm.in", "lib/DBD/mysql.pm"],
		 ["dbd/dbd.xs.in", "DBD-mysql/mysql.xs"],
		 ["dbd/dbdimp.c", "DBD-mysql/dbdimp.c"],
		 ["dbd/myMsql.c", "DBD-mysql/myMsql.c"],
		 ["dbd/dbimon.in", "DBD-mysql/dbimon"],
		 ["tests/lib.pl", "DBD-mysql/t/lib.pl"],
		 ["tests/00base.t", "DBD-mysql/t/00base.t"],
		 ["tests/10dsnlist.t", "DBD-mysql/t/10dsnlist.t"],
		 ["tests/20createdrop.t", "DBD-mysql/t/20createdrop.t"],
		 ["tests/30insertfetch.t", "DBD-mysql/t/30insertfetch.t"],
		 ["tests/40bindparam.t", "DBD-mysql/t/40bindparam.t"],
		 ["tests/40blobs.t", "DBD-mysql/t/40blobs.t"],
		 ["tests/40listfields.t", "DBD-mysql/t/40listfields.t"],
		 ["tests/40nulls.t", "DBD-mysql/t/40nulls.t"],
		 ["tests/40numrows.t", "DBD-mysql/t/40numrows.t"],
		 ["tests/50chopblanks.t", "DBD-mysql/t/50chopblanks.t"],
		 ["tests/50commit.t", "DBD-mysql/t/50commit.t"],
		 ["tests/ak-dbd.t", "DBD-mysql/t/ak-dbd.t"]);
	}
	my $ref;
	foreach $ref (@files) {
	    Extract($ref->[0], $ref->[1], "Mysql", "mysql", $VERSION,
		    $DBD_VERSION);
	}
    }
    if ($_MY::Config::enableMsql) {
	my (@files) = (["nodbd/Makefile.PL.in", "Msql/Makefile.PL"],
		       ["nodbd/bundle.pm.in", "lib/Bundle/Msql.pm"],
		       ["nodbd/constants.c", "Msql/constants.c"],
		       ["dbd/myMsql.c", "Msql/myMsql.c"],
		       ["nodbd/nodbd.pm.in", "lib/Msql.pm"],
		       ["nodbd/nodbd.xs.in", "Msql/Msql.xs"],
		       ["nodbd/pmsql.in", "Msql/pmsql"],
		       ["nodbd/statement.pm.in", "lib/Msql/Statement.pm"],
		       ["nodbd/typemap", "Msql/typemap"],
		       ["tests/lib.pl", "Msql/t/lib.pl"],
		       ["tests/msql1.t", "Msql/t/msql1.t"],
		       ["tests/msql2.t", "Msql/t/msql2.t"],
		       ["tests/akmisc.t", "Msql/t/akmisc.t"]);
	if ($_MY::Config::enableDbd) {
	    push(@files,
		 ["dbd/Makefile.PL.in", "DBD-mSQL/Makefile.PL"],
		 ["dbd/dbd.pm.in", "lib/DBD/mSQL.pm"],
		 ["dbd/dbd.xs.in", "DBD-mSQL/mSQL.xs"],
		 ["dbd/dbdimp.c", "DBD-mSQL/dbdimp.c"],
		 ["dbd/myMsql.c", "DBD-mSQL/myMsql.c"],
		 ["tests/lib.pl", "DBD-mSQL/t/lib.pl"],
		 ["tests/00base.t", "DBD-mSQL/t/00base.t"],
		 ["tests/10dsnlist.t", "DBD-mSQL/t/10dsnlist.t"],
		 ["tests/20createdrop.t", "DBD-mSQL/t/20createdrop.t"],
		 ["tests/30insertfetch.t", "DBD-mSQL/t/30insertfetch.t"],
		 ["tests/40bindparam.t", "DBD-mSQL/t/40bindparam.t"],
		 ["tests/40listfields.t", "DBD-mSQL/t/40listfields.t"],
		 ["tests/40nulls.t", "DBD-mSQL/t/40nulls.t"],
		 ["tests/40numrows.t", "DBD-mSQL/t/40numrows.t"],
		 ["tests/50chopblanks.t", "DBD-mSQL/t/50chopblanks.t"],
		 ["tests/50commit.t", "DBD-mSQL/t/50commit.t"],
		 ["tests/ak-dbd.t", "DBD-mSQL/t/ak-dbd.t"]);
	    if (!$_MY::Config::enableMysql) {
		push(@files,
		     ["dbd/dbimon.in", "DBD-mSQL/dbimon"]);
	    }
	}
	my $ref;
	foreach $ref (@files) {
	    Extract($ref->[0], $ref->[1], "Msql", "mSQL", $VERSION,
		    $DBD_VERSION);
	}
    }

    if (open(OUT, ">./.status")) {
	print OUT qq{
\$_MY::Config::Status::enableDbd = $_MY::Config::enableDbd;
\$_MY::Config::Status::enableMysql = $_MY::Config::enableMysql;
\$_MY::Config::Status::enableMsql = $_MY::Config::enableMsql;
};
    }
}
	

sub CheckForLibGcc() {
    # For reasons I don't understand the 'specs' file of some
    # gcc versions disable linking against libgcc.a in conjunction
    # with '-shared'. Unfortunately we need libgcc.a because of
    # some arithmetic functions.
    #
    # We check this by looking into gcc's "specs" file. If there
    # is a line saying
    #
    #    %{!shared:-lgcc}
    #
    # we assume a broken gcc.
    #
    if ($Config::Config{gccversion} eq '') {
	return '';
    }

    my $specs = `$Config::Config{cc} -v 2>&1`;
    if ($specs !~ /Reading specs from (\S+)/) {
	return;
    }

    $specs = $1;
    if (!open(FILE, "<$specs")) {
	return;
    }

    my $line;
    my $extralibs = '';
    while (defined($line = <FILE>)) {
	if ($line =~ /\%\{\!shared\:\-lgcc\}/) {
	    my $libgccdir = $specs;
	    $libgccdir =~ s/\/[^\/]+$//;
	    print("\nYou're building on ", $Config::Config{'osname'},
		  " with gcc.",
		  " According to your specs file\n    $specs\n",
		  "your gcc doesn't seem to link against libgcc.a when ",
		  " building shared libraries.\n",
		  "I assume that your libmysqlclient.a will need __moddi3",
		  " and __divdi3,\n",
		  "so lets be cautious and add a '-lgcc' to the linker",
		  " flags.\n\n");
	    $extralibs = "-L$libgccdir -lgcc";
	    last;
	}
    }
    close(FILE);

    return $extralibs;
}

sub InitializeMsql {
    if ($_MY::Config::X_Msql) {
	return $_MY::Config::X_Msql;
    }

    my %X;
    my @msqldir =
	qw{
	   /usr/local/Hughes
	   /usr/local/Minerva
	   /usr/local
	   /usr/mSQL
	   /opt/mSQL
	  };
    unshift @msqldir, $ENV{MSQL_HOME} if exists $ENV{MSQL_HOME};

    my($msqldir,$gooddir);

    for $msqldir (@msqldir) {
	if (-f "$msqldir/include/msql.h") {
	    $gooddir = $msqldir;
	    last;
	}
    }
    $gooddir ||= $msqldir[0];
    $gooddir = ExtUtils::MakeMaker::prompt("
Where is your msql installed? Please tell me the directory that contains
the subdirs lib/ and include/.",$gooddir) || $gooddir # || for 5.002
    unless exists $ENV{MSQL_HOME} && $gooddir eq $ENV{MSQL_HOME};

    my $headerdir="$gooddir/include";
    die "No msql.h file found\n" unless -f "$headerdir/msql.h";

    # the necessity to determine the version at this stage is legacy ADESC
    # the necessity to determine how many arguments are needed for
    # msqlget*conf is due to random changes in the API
    my $version = "MSQL1";
    my $getconf = "";
    open MSQL, "$headerdir/msql.h" 
	or die "Couldn't open $headerdir/msql.h: $!";
    local $/ = "\n";
    while (<MSQL>) {
	if (/IDX_TYPE/) {
	    $version = "MSQL2";
	}
	if (
	    m{
	      ^
	      (int|char)
	      \s+
	      \*?
	      msqlGet
	      (Int|Char)
	      Conf
	      \s+
	      __ANSI_PROTO
	      \(\(
	      char
	      \s*
	      \*\)\)
	     }x
	   ) {
	    $getconf = " -DMSQLGETXCONF1";
	}
    }

    my $libdir="$gooddir/lib";
    
    my $extralibs = "";
    my $linkwith = "";
    if ( $Config::Config{osname} eq 'sco_sv' ) {
	# Some extra libraries need added for SCO
	print q{Yuk! I see that you are a SCO Unix system. We\'ll add -lc to the list of
libraries to link with...
};
	$extralibs = "-lc";
    } elsif ( $Config::Config{osname} eq 'solaris' ) {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
	print q{Oh dear. Solaris? Let's add some more flags into the linker stage...
};
	$linkwith = "-L$libdir -R$libdir";
    } elsif ( $Config::Config{osname} eq 'hpux' ) {
	# We need to add +z to the list of CFLAGS if we're on HP-SUX, or -fPIC 
	# if we're on HP-SUX and using 'gcc'
	if ( $Config::Config{cccdlflags} eq '+z' ) {
	    print q{You\'re building on HP-UX with the HP compiler.
You might get a warning at the link stage of:

    ld: DP-Relative Code in file .../libmsql.a(libmsql.o)
    >  - Shared Library must be Position-Independent

You\'ll have to recompile libmsql.a from the mSQL distribution with the
    '+z' flag of your C compiler.
};
	  } elsif( $Config::Config{cccdlflags} eq '-fPIC' ) {
	    print q{You\'re building on HP-UX with the GNU C Compiler.
You might get a warning at the link stage like:

    ld: DP-Relative Code in file .../libmsql.a(libmsql.o)
    >  - Shared Library must be Position-Independent

You\'ll have to recompile libmsql.a from the mSQL distribution specifying
the '-fPIC' flag to produce Position-Independent code.
};
	  }
    }

    my $sysliblist = "-L$libdir -lmsql -lm $extralibs";

    my(@headerfiles) = ("$headerdir/msql.h");
    $X{macro} = {MSQL_HOME => $gooddir};
    $X{dynamic_lib} = { OTHERLDFLAGS => '-L$(MSQL_HOME)/lib ' . $linkwith } if $linkwith;
    $X{DEFINE}   = "-DDBD_MSQL -D$version$getconf";
    $X{LIBS}     = $sysliblist;
    $X{INC}      = "-I../dbd -I$headerdir -I\$(INSTALLSITEARCH)/auto/DBI"
	. " -I\$(INSTALLARCHLIB)";
    $X{H}        = \@headerfiles;
    $_MY::Config::X_Msql = \%X;
}


sub InitializeMysql {
    if ($_MY::Config::X_Mysql) {
	return $_MY::Config::X_Mysql;
    }

    my %X;
    my @mysqldir =
	qw{
	   /usr/local
	   /usr/local/mysql
	   /usr
	   /usr/mysql
	   /opt/mysql
	  };
    unshift @mysqldir, $ENV{MYSQL_HOME} if exists $ENV{MYSQL_HOME};

    my($mysqldir,$gooddir);

    for $mysqldir (@mysqldir) {
	if ((-f "$mysqldir/include/mysql/mysql.h"  ||
	     -f "$mysqldir/include/mysql.h")  &&
	    (-f "$mysqldir/lib/mysql/libmysqlclient.a"  ||
	     -f "$mysqldir/lib/libmysqlclient.a")) {
	    $gooddir = $mysqldir;
  	    last;
  	}
    }
    $gooddir ||= $mysqldir[0];
    $gooddir = ExtUtils::MakeMaker::prompt("
Where is your mysql installed? Please tell me the directory that contains
the subdirs lib/ and include/.",$gooddir) || $gooddir # || for 5.002
    unless exists $ENV{MYSQL_HOME} && $gooddir eq $ENV{MYSQL_HOME};

    my $headerdir;
    if (-f "$gooddir/include/mysql/mysql.h") {
	$headerdir = "$gooddir/include/mysql";
    } elsif (-f "$gooddir/include/mysql.h") {
	$headerdir = "$gooddir/include";
    } else {
	die "No mysql.h file found in $gooddir/include\n";
    }

    my $libdir;
    if (-f "$gooddir/lib/mysql/libmysqlclient.a") {
	$libdir = "$gooddir/lib/mysql";
    } elsif (-f "$gooddir/lib/libmysqlclient.a") {
	$libdir = "$gooddir/lib";
    } else {
	die "No libmysqlclient.a file found in $gooddir/lib\n";
    }
    
    my $extralibs = "";
    my $linkwith = "";
    if ($Config::Config{osname} eq 'sco_sv') {
	# Some extra libraries need added for SCO
	print("\nYuk! I see that you are a SCO Unix system. We\'ll add -lc",
	      " to the list of\n",
	      "libraries to link with...\n\n");
	$extralibs = "-lc";
    } elsif ($Config::Config{osname} eq 'solaris') {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
	print("\nOh dear. Solaris? Let's add some more flags into the",
	      " linker stage...\n\n");
	$linkwith = "-L$libdir -R$libdir";
    } elsif ($Config::Config{osname} eq 'hpux') {
	# We need to add +z to the list of CFLAGS if we're on HP-SUX, or -fPIC 
	# if we're on HP-SUX and using 'gcc'
	if ($Config::Config{cccdlflags} eq '+z') {
	    print("\nYou're building on HP-UX with the HP compiler.\n");
	} elsif ($Config::Config{cccdlflags} eq '-fPIC') {
	    print("\nYou're building on HP-UX with the GNU C Compiler.\n");
	} else {
	    print("\nYou're building on HP-UX with an unknown compiler.\n");
	}
	print("You might get a warning at the link stage of:\n\n",
	      "ld: DP-Relative Code in file .../libmysqlclient.a",
	      "(libmysql.o)\n",
	      ">  - Shared Library must be Position-Independent\n\n",
	      "You'll have to recompile libmysqlclient.a from the mysql",
	      " distribution specifying\n",
	      "the '", $Config::Config{cccdlflags}, "' flag",
	      " of your C compiler.\n");
    }

    $extralibs .= CheckForLibGcc();

    # List the libraries we're linking with (ADESC)
    my $sysliblist = ["-L$libdir -lmysqlclient -lm $extralibs"];

    my(@headerfiles) = ("$headerdir/mysql.h");
    $X{macro} = {MYSQL_HOME => $gooddir};
    $X{dynamic_lib} = { OTHERLDFLAGS => "-L$libdir/lib $linkwith" } if $linkwith;
    $X{DEFINE}   = "-DDBD_MYSQL";
    $X{LIBS}     = $sysliblist;
    $X{INC}      = "-I$headerdir -I../dbd -I\$(INSTALLSITEARCH)/auto/DBI"
	. " -I\$(INSTALLARCHLIB)";
    $X{H}        = \@headerfiles;
    if ($ENV{HOSTNAME} eq 'laptop.ispsoft.de'  &&  $ENV{'LOGNAME'} eq 'joe') {
	$X{'DEFINE'} .= ' -Wall -Wno-comment -Wpointer-arith'
            . ' -Wcast-align -Wconversion -Wtraditional -Wcast-qual';
    }
    $X{NAME} = "Mysql",
    $X{DISTNAME} = "Mysql-modules",
    $_MY::Config::X_Mysql = \%X;
}
