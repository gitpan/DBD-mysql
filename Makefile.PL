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
require File::Path;
require Config;
require Cwd;


my $VERSION = "1.1820";
my $DBD_VERSION = "2.006";


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
	      'EXE_FILES'    => [ 'dbimon' ],
	      'dist'         => { 'SUFFIX'       => ".gz",
				  'DIST_DEFAULT' => 'all tardist',
				  'COMPRESS'     => "gzip -9f" },
	      'VERSION'      => $VERSION,
	      'realclean'    => 'Mysql/Makefile.PL Msql/Makefile.PL'
			        . ' DBD-mysql/Makefile.PL DBD-mSQL/Makefile.PL'
);


package _MY::Config;

BEGIN {
    $_MY::Config::enableDbd = 1;
    $_MY::Config::enableMsql = 1;
    $_MY::Config::enableMysql = 1;
    $_MY::Config::X_Msql = undef;
    $_MY::Config::X_Mysql = undef;
    @_MY::Config::Files::Mysql = ();
    @_MY::Config::Files::Msql = ();
    @_MY::Config::Files::mysql = ();
    @_MY::Config::Files::mSQL = ();
};

sub disableDbd { $_MY::Config::enableDbd = 0; }
sub disableMsql { $_MY::Config::enableMsql = 0; }
sub disableMysql { $_MY::Config::enableMysql = 0; }


sub MakeDirs () {
    my (@removeList);

    if ($_MY::Config::enableMysql) {
	@_MY::Config::Files::Mysql =
	    (["nodbd/Makefile.PL.in", "Mysql/Makefile.PL"]);

	if ($_MY::Config::enableDbd) {
	    @_MY::Config::Files::mysql =
		(["dbd/Makefile.PL.in", "DBD-mysql/Makefile.PL"]);
	} else {
	    push(@removeList, "DBD-mysql/Makefile.PL");
	}
	my $ref;
	foreach $ref (@_MY::Config::Files::Mysql, @_MY::Config::Files::mysql) {
	    system sprintf("perl xtract %s %s %s %s %s %s",
			   $ref->[0], $ref->[1], "Mysql", "mysql", $VERSION,
			   $DBD_VERSION);
	}
    } else {
	push(@removeList, "Mysql/Makefile.PL", "DBD-mysql/Makefile.PL");
    }
    if ($_MY::Config::enableMsql) {
	@_MY::Config::Files::Msql =
	    (["nodbd/Makefile.PL.in", "Msql/Makefile.PL"]);
	if ($_MY::Config::enableDbd) {
	    @_MY::Config::Files::mSQL =
		(["dbd/Makefile.PL.in", "DBD-mSQL/Makefile.PL"]);
	    if (!$_MY::Config::enableMysql) {
		push(@_MY::Config::Files::mSQL,
		     ["dbd/dbimon.in", "DBD-mSQL/dbimon"]);
	    }
	} else {
	    push(@removeList, "DBD-mSQL/Makefile.PL");
	}
	my $ref;
	foreach $ref (@_MY::Config::Files::Msql, @_MY::Config::Files::mSQL) {
	    system sprintf("perl xtract %s %s %s %s %s %s",
			   $ref->[0], $ref->[1], "Msql", "mSQL", $VERSION,
			   $DBD_VERSION);
	}
    } else {
	push(@removeList, "Msql/Makefile.PL", "DBD-mSQL/Makefile.PL");
    }

    my $file;
    foreach $file (@removeList) {
	if (-f $file  &&  !unlink $file) {
	    print STDERR "Cannot remove $file: $!\n";
	    exit 10;
	}
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

sub MY::postamble {
    my ($ref, $pa, $from, $to);

    my @mysqlFiles = (["nodbd/bundle.pm.in", "lib/Bundle/Mysql.pm"],
		      ["nodbd/nodbd.pm.in", "lib/Mysql.pm"],
		      ["nodbd/statement.pm.in", "lib/Mysql/Statement.pm"],
		      ["dbd/dbd.pm.in", "lib/DBD/mysql.pm"]);
    if ($_MY::Config::enableMysql) {
	push(@mysqlFiles, @_MY::Config::Files::Mysql,
	     ["dbd/dbimon.in", "dbimon"]);
	if ($_MY::Config::enableDbd) {
	    push(@mysqlFiles, @_MY::Config::Files::mysql);
	}
    }
    foreach $ref (@mysqlFiles) {
	($from, $to) = @$ref;
	$pa .= sprintf("%s: %s Makefile.PL\n"
		       . "\tperl xtract %s %s %s %s %s %s\n\n",
		       $to, $from, $from, $to, "Mysql", "mysql",
		       $VERSION, $DBD_VERSION);
    }

    my @msqlFiles = (["nodbd/bundle.pm.in", "lib/Bundle/Msql.pm"],
		     ["nodbd/nodbd.pm.in", "lib/Msql.pm"],
		     ["nodbd/statement.pm.in", "lib/Msql/Statement.pm"],
		     ["dbd/dbd.pm.in", "lib/DBD/mSQL.pm"]);
    if ($_MY::Config::enableMsql) {
	push(@msqlFiles, @_MY::Config::Files::Msql);
	if (!$_MY::Config::enableMysql) {
	    push(@msqlFiles, ["dbd/dbimon.in", "dbimon"]);
	}
	if ($_MY::Config::enableDbd) {
	    push(@msqlFiles, @_MY::Config::Files::mSQL);
	}
    }
    foreach $ref (@msqlFiles) {
	($from, $to) = @$ref;
	$pa .= sprintf("%s: %s Makefile.PL\n"
		       . "\tperl xtract %s %s %s %s %s %s\n\n",
		       $to, $from, $from, $to, "Msql", "mSQL",
		       $VERSION, $DBD_VERSION);
    }
    $pa;
}
