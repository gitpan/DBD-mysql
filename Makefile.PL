#   Hej, Emacs, don't you see this is -*- perl -*- mode? :-)
#
#   Copyright (c) 1997  Andreas König, Jochen Wiedmann
#
#  You may distribute this under the terms of either the GNU General Public
#  License or the Artistic License, as specified in the Perl README file,
#  with the exception that it cannot be placed on a CD-ROM or similar media
#  for commercial distribution without the prior approval of the author.
#
#  $Id: Makefile.PL,v 1.8 1999/01/26 20:22:04 joe Exp $
#
BEGIN {require 5.004;}
use strict;
require Config;
require Getopt::Long;
use ExtUtils::MakeMaker qw(prompt WriteMakefile);
require File::Path;
require Config;
require Cwd;
use lib ".";

use vars qw($MyConfig $VERSION $DBD_VERSION);

$VERSION = "1.2017";
$DBD_VERSION = "2.0217";


my %options;
Getopt::Long::GetOptions(\%options, "static", "config");


############################################################################
#
#   Name:    Search
#
#   Purpose: Find installed files (headers or libraries)
#
#   Inputs:  $gooddirs - List of directories where to search; these
#                directories are accepted immediately if a file is
#                found there
#            $dirs - List of additional directories where to search;
#                these are accepted only if the users confirms them
#            $files - List of files to search for; any of these will
#                be sufficient
#            $prompt - Prompt for asking the user to confirm a
#                directory
#
#   Returns: List of two directories: The first directory is the basename
#       of "$dir/$file" where $dir is one of $gooddirs or $dirs and $file
#       is one of $files. (Note that the file name may contain preceding
#       directory names!) The second directory is the corresponding dir
#       od $gooddirs or $dirs.
#
############################################################################

sub Search ($$$$) {
    my ($gooddirs, $dirs, $files, $prompt) = @_;
    my ($dir, $file, $realfile);
    foreach $dir (@$gooddirs) {
	foreach $file (@$files) {
	    if (-f ($realfile = "$dir/$file")) {
		return (File::Basename::dirname($realfile), $dir, $realfile);
	    }
	}
    }
    my ($gooddir);
    foreach $dir (@$dirs) {
	foreach $file (@$files) {
	    if (-f "$dir/$file") {
		$gooddir = $dir;
		last;
	    }
	}
	if ($gooddir) {
	    last;
	}
    }
    $gooddir ||= $$gooddirs[0] || $$dirs[0];

    $gooddir = prompt($prompt, $gooddir)  ||  $gooddir;  # for 5.002;

    foreach $file (@$files) {
	if (-f ($realfile = "$gooddir/$file")) {
	    return (File::Basename::dirname($realfile), $gooddir, $realfile);
	}
    }

    if (@$files == 1) {
	die "Cannot find " . $$files[0] . " in $gooddir.\n";
    }
    die "Cannot find one of " . join(", ", @$files) . " in $gooddir";
}


############################################################################
#
#   Name:    QueryDb
#
#   Purpose: Query settings for running the test suite
#
#   Inputs:  $cfg - Config hash ref
#            $db - Database name
#            $driver - Driver name
#
#   Returns: Nothing; creates
#            $cfg->{$driver}->{test_(db|host|dsn|user|pass)}
#
############################################################################

sub QueryDb ($$$) {
    my($cfg, $db, $driver) = @_;
    my $db_lc = lc $driver;

    my $dbname = prompt("Which database should I use for testing the $db"
			. " drivers?", "test");
    my $host = prompt("On which host is database $dbname running (hostname, "
		      . " ip address or host:port)\n", "localhost");
    my($user, $pass);
    if ($driver eq 'mysql') {
	$user = prompt("User name for connecting to database $dbname?",
		       "undef");
	$pass = prompt("Password for connecting to database $dbname?",
		       "undef");
    }

    $cfg->{$driver}->{"test_db"} = $dbname;
    $cfg->{$driver}->{"test_host"} = $host;
    if ($host eq 'undef'  ||  $host eq 'localhost') {
	$host = '';
    }
    $cfg->{$driver}->{"test_dsn"} = "DBI:$driver:database=$dbname";
    if ($host) {
	$cfg->{$driver}->{"test_dsn"} .= ";host=$host";
    }
    $cfg->{$driver}->{"test_user"} =
	($user && $user ne 'undef') ? $user : "";
    $cfg->{$driver}->{"test_pass"} =
	($pass && $pass ne 'undef') ? $pass : "";
}


############################################################################
#
#   Name:    Xtract
#
#   Purpose: Create files from the distribution directories dbd and nodbd
#            using the "xtract" utility.
#
#   Inputs:  $ref - Array ref representing one file; the elements are
#
#                      $ref->[0]  Source file
#                      $ref->[1]  Destination file
#                      $ref->[2]  TRUE for executable (Mode 0755),
#                                 FALSE otherwise
#            $driver - Either "Msql" or "Mysql"
#            $dbdDriver - Either "mSQL" or "mysql"
#            $path - Path of the utility, defaults to "./xtract"
#
#   Returns: Nothing, aborts in case of trouble.
#
############################################################################

sub Xtract($$$;$) {
    my ($ref, $driver, $dbdDriver, $path) = @_;
    if (!$path) {
	$path = "xtract";
    }
    $ENV{'XTRACT_NOT_RUNNING'} = 1;
    require "xtract";
    Extract($ref->[0], $ref->[1], $driver, $dbdDriver,
	    $MyConfig->{'VERSION'}, $MyConfig->{'DBD_VERSION'});
    delete $ENV{'XTRACT_NOT_RUNNING'};
    chmod $ref->[2] ? 0755 : 0644, $ref->[1];
}


############################################################################
#
#   Name:    XtractF
#
#   Purpose: Create Makefile rules for updating files from the distribution
#            directories dbd and nodbd using the "xtract" utility.
#
#   Inputs:  $ref - Array ref representing one file; the elements are
#
#                      $ref->[0]  Source file
#                      $ref->[1]  Destination file
#                      $ref->[2]  TRUE for executable (Mode 0755),
#                                 FALSE otherwise
#            $driver - Either "Msql" or "Mysql"
#            $dbdDriver - Either "mSQL" or "mysql"
#            $path - Path of the utility, defaults to "./xtract"
#
#   Returns: String being inserted in the postamble.
#
############################################################################

sub XtractF($$$;$) {
    my ($ref, $driver, $dbdDriver, $path) = @_;
    if (!$path) {
	$path = "xtract";
    }
    sprintf("pm_to_blib: ../%s\n\n"
	    . "../%s: ../%s\n"
	    . "\t%s %s ../%s ../%s %s %s %s %s\n\tchmod %s ../%s\n\n",
	    $ref->[1],
	    $ref->[1], $ref->[0], $^X, $path,
	    $ref->[0], $ref->[1], $driver, $dbdDriver,
	    $MyConfig->{'VERSION'}, $MyConfig->{'DBD_VERSION'},
	    $ref->[2] ? "0755" : "0644", $ref->[1]);
}


############################################################################
#
#   Name:    InitializeMysql
#
#   Purpose: Setup mysql dependent variables
#
#   Inputs:  None
#
#   Returns: Hash ref of MakeMaker variables
#
############################################################################

sub CheckForLibGcc() {
    # For reasons I don't understand the 'specs' files of some
    # gcc versions disable linking against libgcc.a in conjunction
    # with '-shared'. Unfortunately we need libgcc.a because of
    # some arithmetic functions.
    #
    # We try to fix this by always linking against libgcc.a. Unfortunately
    # it's somewhat hard to find out the path of this file ...
    #
    # However, this must not happen under NetBSD, because it duplicates
    # libc functions. These get pulled in instead of the libc functions,
    # but since the library is static only, they're not PIC and thus render
    # mysql.so unsharable.
    #
    if ($Config::Config{gccversion} eq ''  ||
	$Config::Config{osname} eq 'netbsd') {
	return '';
    }

    my($libgccfile) = `$Config::Config{cc} -print-libgcc-file-name 2>&1`;
    my($libgccdir);
    if ($libgccfile =~ /^\S+$/) {
	if ($libgccfile =~ /(.*)\/lib(\S+)\.a/) {
	    $libgccdir = $1;
	    $libgccfile = $2;
	}
    } else {
	my($specs) = `$Config::Config{cc} -v 2>&1`;
	if ($specs =~ /Reading specs from (\S+)/) {
	    $specs = $1;
	} else {
	    printf(<<"MSG", $Config::Config{cc});
Your Perl configuration says you are using gcc, but your compiler (%s) doesn't
look like gcc. There might be missing symbols in libmysqlclient.a, typically
'umoddi3' or something similar, if you have precompiled mysql binaries. If so,
try to compile your own binaries, perhaps the '--without-server' option
might help in the configure stage.
MSG
	    return '';
	}

	$specs = $1;
	if ($specs =~ /(.*)\//) {
	    $libgccdir = $1;
	    $libgccfile = "gcc";
	} else {
	    printf(<<"MSG", $Config::Config{cc});
Your Perl configuration says you are using gcc (%s), but I cannot determine the
path of your libgcc.a file. There might be missing symbols in
libmysqlclient.a, typically 'umoddi3' or something similar, if you have
precompiled mysql binaries. If so, try to compile your own binaries, perhaps
the '--without-server' option might help in the configure stage.
MSG
	    return '';
	}
    }

    if ($libgccdir) {
        " -L$libgccdir -l$libgccfile";
    } else {
        " $libgccfile";
    }
}


sub InitializeMysql ($) {
    my $cfg = shift;

    my %X;
    my @mysqldirs = ($^O =~ /mswin32/i) ?  qw(C:/mysql C:/my/myodbc)  :
	qw{/usr/local /usr/local/mysql /usr /usr/mysql /opt/mysql};
    my @gooddirs = ();
    if (exists($ENV{MYSQL_HOME})) {
	unshift @gooddirs, $ENV{MYSQL_HOME};
    }
    if (exists($ENV{MYSQL_BUILD})) {
	unshift @gooddirs, $ENV{MYSQL_BUILD};
    }

    my($headerdir, $gooddir);
    if (exists($ENV{'MYSQL_HEADERDIR'})) {
	$headerdir = $ENV{'MYSQL_HEADERDIR'};
    } else {
	($headerdir, $gooddir) = Search(\@gooddirs, \@mysqldirs,
					["include/mysql/mysql.h",
					 "include/mysql.h"],
					"Where is your mysql installed? Please"
					. " tell me the directory that"
					. " contains\n"
					. "the subdir include/.");
	unshift(@gooddirs, $gooddir);
    }

    my($libdir, $libfilename);
    if (exists($ENV{'MYSQL_LIBDIR'})) {
	$libdir = $ENV{'MYSQL_LIBDIR'};
    } else {
	my @searchpath;
	if ($^O =~ /mswin32/i) {
	    @searchpath = qw(lib/opt/mysqlclient.lib
			     lib_release/mysqlclient.lib
			     lib/mysqlclient.lib
			     lib/debug/mysqlclient.lib
			     lib_debug/mysqlclient.lib
			     lib/opt/lib.lib
			     lib_release/lib.lib 
			     lib/lib.lib
			     lib/debug/lib.lib
			     lib_debug/lib.lib);
	} else {
	    @searchpath = qw(lib/mysql/libmysqlclient.a
			     lib/libmysqlclient.a
			     client/libmysqlclient.a
			     lib/mysql/libmysqlclient.so
			     lib/libmysqlclient.so
			     client/libmysqlclient.so);
	}
	($libdir, $gooddir, $libfilename) =
	    Search(\@gooddirs, \@mysqldirs, \@searchpath,
		   "Where is your mysql installed? Please tell me the"
		   . " directory that contains\n"
		   . "the subdir lib/.");
    }

    # List the libraries we're linking with (ADESC)
    my $sysliblist;
    my $extra_libs = '';
    my $final_libs = '';
    if ($options{'static'}) {
	if ($libfilename !~ /\.a/) {
	    die "Option -static given, but no static libmysqlclient.a found";
	}
	$extra_libs .= " $libfilename";
	$MY::LIBS = $libfilename;
    } else {
	$sysliblist = "-L$libdir -lmysqlclient";
    }
    $sysliblist .= " -lm";
    my $linkwith = "";
    my $defines = "-DDBD_MYSQL -DMyConnect=mysql_dr_connect"
	. " -DMyLogin=mysql_dr_login";
    if ($Config::Config{osname} eq 'sco_sv'  ||
	$Config::Config{osname} eq 'svr4') {
	# Some extra libraries need added for SCO and Unixware
	$sysliblist .= " -lc";
    } elsif ($Config::Config{osname} eq 'solaris') {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
	$linkwith = "-R$libdir";
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
    } elsif ($Config::Config{osname} eq 'MSWin32') {
	$defines .= " -DWIN32";

	if (! -f "$libdir/mysqlclient.lib"  &&
	    -f "$libdir/lib.lib") {
	    # Looks like we're using MyODBC ...
	    $defines .= " -D__WIN32__";
	    $sysliblist =~ s/-lmysqlclient/-llib/;
	    $sysliblist .= " -lmysys -lstrings";
	}
	if (-f "$libdir/zlib.lib") {
	    $sysliblist .= " -lzlib";
	}
	# For some reasons libs.lib is not linked against msvcrt.lib
	# with VC++ ...
	if ($Config::Config{libs} =~ /\bmsvcrt\.lib\b/ &&
	    $Config::Config{libs} !~ /\blibc.lib\b/) {
	    $sysliblist .= " -lmsvcrt -lc";
	  } elsif ($Config::Config{libs} =~ /\bPerlCRT\.lib\b/) {
	    $final_libs .= " libc.lib";
	}
    }

    $sysliblist .= CheckForLibGcc();
    $cfg->{'Mysql'}->{'EXTRA_LIBS'} = $extra_libs;
    $cfg->{'Mysql'}->{'FINAL_LIBS'} = $final_libs;

    my(@headerfiles) = ("$headerdir/mysql.h");
    $X{dynamic_lib} = { OTHERLDFLAGS => "-L$libdir $linkwith" };
    $X{DEFINE}   = $defines;
    $X{LIBS}     = $sysliblist;
    $X{INC}      = "-I$headerdir -I../dbd  -I\$(INSTALLSITEARCH)/auto/DBI"
	. " -I\$(INSTALLARCHLIB)";
    $X{H}        = \@headerfiles;
    if ($ENV{HOSTNAME} eq 'laptop.ispsoft.de'  &&  $ENV{'LOGNAME'} eq 'joe') {
	$X{'DEFINE'} .= ' -Wall -Wstrict-prototypes';
    }

    my $dir;
    foreach $dir (@INC) {
	if (-f "$dir/auto/DBI/DBIXS.h") {
	    $X{INC} = "-I$dir/auto/DBI " . $X{INC};
	    last;
	}
    }

    \%X;
}


############################################################################
#
#   Name:    InitializeMsql
#
#   Purpose: Setup msql dependent variables
#
#   Inputs:  None
#
#   Returns: Hash ref of MakeMaker variables
#
############################################################################

sub InitializeMsql ($) {
    my($ver) = @_;
    my($homeVar, $dbVar, $dbiDriver);
    my($queryVar) = $ver ? "mSQL $ver" : "mSQL";
    if ($ver && $ver == 1) {
	$homeVar = "MSQL1_HOME";
	$dbVar = "-DDBD_MSQL -DDBD_MSQL1";
	$dbiDriver = "mSQL1";
    } else {
	$homeVar = "MSQL_HOME";
	$dbVar = "-DDBD_MSQL";
	$dbiDriver = "mSQL";
	$ver = 2;
    }

    my %X;
    my @msqldirs = qw{/usr/local/Hughes /usr/local/Minerva /usr/local
			  /usr/mSQL /opt/mSQL /usr};
    my @gooddirs;
    if (exists($ENV{$homeVar})) { push(@gooddirs, $ENV{$homeVar}); }

    my($headerdir, $gooddir) = Search(\@gooddirs, \@msqldirs,
				      ["include/msql.h"],
				      "Where is your $queryVar installed? Please"
				      . " tell me the directory that"
				      . " contains\n"
				      . " the subdir include/.");
    unshift(@gooddirs, $gooddir);
    my($libdir) = Search(\@gooddirs, \@msqldirs, ["lib/libmsql.a"],
			 "Where is your $queryVar installed? Please tell me the"
			 . " directory that contains\n"
			 . " the subdir lib/.");

    # the necessity to determine how many arguments are needed for
    # msqlget*conf is due to random changes in the API
    my($getconf) = '';
    open MSQL, "$headerdir/msql.h" 
	or die "Couldn't open $headerdir/msql.h: $!";
    local $/ = "\n";
    while (<MSQL>) {
	if (m{
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
	    }x) {
	    $getconf = " -DMSQLGETXCONF1";
	}
    }

    my $extralibs = "";
    my $linkwith = "";
    if ( $Config::Config{osname} eq 'sco_sv' ) {
	# Some extra libraries need added for SCO
	$extralibs = "-lc";
    } elsif ( $Config::Config{osname} eq 'solaris' ) {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
	$linkwith = "-R$libdir";
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

    my($sysliblist) = "-L$libdir -lmsql -lm $extralibs";

    my(@headerfiles) = ("$headerdir/msql.h");
    $X{macro} = {$homeVar => $gooddir};
    $X{dynamic_lib} = { OTHERLDFLAGS => "-L$libdir $linkwith" };
    $X{DEFINE}   = "$dbVar $getconf -DMyConnect=${dbiDriver}_dr_connect"
	. " -DMyLogin=${dbiDriver}_dr_login";
    if ($ENV{HOSTNAME} eq 'laptop.ispsoft.de'  &&  $ENV{'LOGNAME'} eq 'joe') {
	$X{'DEFINE'} .= ' -Wall -Wstrict-prototypes';
    }
    $X{LIBS}     = $sysliblist;
    $X{INC}      = "-I../dbd -I$headerdir  -I\$(INSTALLSITEARCH)/auto/DBI"
	. " -I\$(INSTALLARCHLIB)";
    $X{H}        = \@headerfiles;

    my $dir;
    foreach $dir (@INC) {
	if (-f "$dir/auto/DBI/DBIXS.h") {
	    $X{INC} .= " -I$dir/auto/DBI";
	    last;
	}
    }

    \%X;
}


############################################################################
#
#    Name:    Init
#
#    Purpose: Setup variables that are manually configurable
#
#    Inputs:  None
#
#    Result:  Nothing; the $MyConfig hash will be modified
#
############################################################################

sub Init () {
    my($reply);

    if (-f ".status"  and  !$options{'config'}) {
	# Read settings from .status file
	require ".status";
	return;
    }

    $MyConfig = { 'VERSION' => $VERSION,
		  'DBD_VERSION' => $DBD_VERSION };

    if ($ENV{'IN_MYSQL_DISTRIBUTION'}) {
	require Data::Dumper;
	$MyConfig->{'install_dbd_mysql'} = 1;
	$MyConfig->{'install_dbd_msql'} = 0;
	$MyConfig->{'install_dbd_msql1'} = 0;
	$MyConfig->{'install_msqlperl'} = 0;
	$MyConfig->{'install_msql1perl'} = 0;
    } else {
	my($ok) = 2;

	print "Checking for DBI, 0.93 or later ... ";
	$@ = '';
	eval "use DBI 0.93 (); require DBI::DBD;";
	if ($@) {
	    $ok = 0;
	    print qq{
You don't have installed the DBI module, version 0.93 or later. I cannot
continue installing the Msql-Mysql modules.
};
        } else {
            print "ok\n";
        }

        print "Checking for Data::Dumper ... ";
        $@ = '';
        eval "require Data::Dumper";
        if ($@) {
	    $ok = 0;
	    print qq{
You don't have installed the Data::Dumper module. I cannot continue
installing the Msql-Mysql modules.
};
        } else {
	    print "ok\n";
        }

        print "Checking for Data::ShowTable ... ";
        $@ = '';
        eval "require Data::ShowTable";
        if ($@) {
	    print qq{
You don't have installed the Data::ShowTable module. You won't be able
to use 'dbimon' the DBI shell.};
            if ($ok == 2) {
	        $ok = 1;
	        print qq{I'll continue installing the Msql-Mysql modules
anyways so that you can install Data::ShowTable at a later time.
};
            }
        } else {
	    print "ok\n";
        }

        if ($ok < 2) {
            print qq{
Missing modules are available from any CPAN mirror, for example

   ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module
};
	}
        if (!$ok) {
            exit 1;
        }

        my($choice) = 0;
        if (exists $ENV{'IN_MYSQL_DISTRIBUTION'}) {
            $choice = 1;
        }
        while (!$choice) {
	     $reply = prompt(
	         "\n\nWhich DBMS do you want to use?\n\n" .
	         "  1) MySQL\n" .
	         "  2) mSQL (1 or 2)\n" .
	         "  3) Both MySQL and mSQL\n\n" .
                 "  4) mSQL1 and mSQL2\n" .
                 "  5) Everything (MySQL, mSQL1 and mSQL2)\n\n" .
	         "Enter your choice: ", "3");
            if ($reply =~ /(\d+)/) {
                $choice = $1;
                if ($choice < 1  ||  $choice > 5) {
                    $choice = 0;
                }
            }
        }

        $MyConfig->{'install_dbd_mysql'} =
            ($choice == 1 || $choice == 3 || $choice == 5);
        $MyConfig->{'install_dbd_msql'} =
            ($choice == 2 || $choice == 3 || $choice == 4 || $choice == 5);
        $MyConfig->{'install_dbd_msql1'} = ($choice == 4 || $choice == 5);
    }

    if ($MyConfig->{'install_dbd_mysql'}) {
        if ($ENV{'IN_MYSQL_DISTRIBUTION'}) {
	    $MyConfig->{'install_mysqlperl'} = 1;
        } else {
	    eval { require Mysql };
	    my $default =
		(defined($Mysql::VERSION) and $Mysql::VERSION >= 1.19) ?
		    "y" : "n";

	    $reply = prompt(qq{

Do you want to install the MysqlPerl emulation? You might keep your old
Mysql module (to be distinguished from DBD::mysql!) if you are concerned
about compatibility to existing applications!}, $default);
            $MyConfig->{'install_mysqlperl'} = ($reply =~ /y/i) ? 1 : 0;
            QueryDb($MyConfig, 'Mysql', 'mysql');
        }
        if (!exists $MyConfig->{'X_mysql'}) {
            $MyConfig->{'X_mysql'} = InitializeMysql($MyConfig);
        }
    }

    $MyConfig->{'files_dbd_mysql'} =
        [ ["dbd/Makefile.PL.in", "Mysql/Makefile.PL"],
          ["dbd/bundle.pm.in", "Mysql/lib/Bundle/DBD/mysql.pm"],
          ["dbd/dbdimp.c", "Mysql/dbdimp.c"],
          ["dbd/dbd.xs.in", "Mysql/mysql.xs"],
          ["dbd/dbd.pm.in", "Mysql/mysql.pm"],
          ["tests/00base.t", "Mysql/t/00base.t"],
          ["tests/10dsnlist.t", "Mysql/t/10dsnlist.t"],
          ["tests/20createdrop.t", "Mysql/t/20createdrop.t"],
          ["tests/30insertfetch.t", "Mysql/t/30insertfetch.t"],
          ["tests/40bindparam.t", "Mysql/t/40bindparam.t"],
          ["tests/40blobs.t", "Mysql/t/40blobs.t"],
          ["tests/40listfields.t", "Mysql/t/40listfields.t"],
          ["tests/40nulls.t", "Mysql/t/40nulls.t"],
          ["tests/40numrows.t", "Mysql/t/40numrows.t"],
          ["tests/50chopblanks.t", "Mysql/t/50chopblanks.t"],
          ["tests/50commit.t", "Mysql/t/50commit.t"],
          ["tests/60leaks.t", "Mysql/t/60leaks.t"],
          ["tests/ak-dbd.t", "Mysql/t/ak-dbd.t"],
          ["tests/dbdadmin.t", "Mysql/t/dbdadmin.t"],
          ["tests/lib.pl", "Mysql/t/lib.pl"] ];
    $MyConfig->{'files_mysqlperl'} =
        [ ["tests/akmisc.t", "Mysql/t/akmisc.t"],
          ["tests/mysql.t", "Mysql/t/mysql.t"],
          ["tests/mysql2.t", "Mysql/t/mysql2.t"],
          ["nodbd/nodbd.pm.in", "Mysql/lib/Mysql.pm"],
          ["nodbd/statement.pm.in", "Mysql/lib/Mysql/Statement.pm"],
          ["nodbd/pmsql.in", "Mysql/pmysql", 1]];


    if ($MyConfig->{'install_dbd_msql'}) {
	eval { require Msql };
	my $default =
	    (defined($Msql::VERSION) and $Msql::VERSION >= 1.19) ?
		"y" : "n";

	$reply = prompt(qq{

Do you want to install the MsqlPerl emulation? You might keep your old
Msql module (to be distinguished from DBD::mSQL!) if you are concerned
about compatibility to existing applications!}, $default);
        $MyConfig->{'install_msqlperl'} = ($reply =~ /y/i) ? 1 : 0;
        QueryDb($MyConfig,
                $MyConfig->{'install_dbd_msql1'} ? 'mSQL 2' : 'mSQL',
                'mSQL');
        if (!exists($MyConfig->{X_msql})) {
            $MyConfig->{'X_msql'} =
               InitializeMsql($MyConfig->{'install_dbd_msql1'} ? 2 : 0);
        }
    }

    $MyConfig->{'files_dbd_msql'} =
        [ ["dbd/Makefile.PL.in", "Msql/Makefile.PL"],
          ["dbd/bundle.pm.in", "Msql/lib/Bundle/DBD/mSQL.pm"],
          ["dbd/dbdimp.c", "Msql/dbdimp.c"],
          ["dbd/dbd.xs.in", "Msql/mSQL.xs"],
          ["dbd/dbd.pm.in", "Msql/mSQL.pm"],
          ["tests/00base.t", "Msql/t/00base.t"],
          ["tests/10dsnlist.t", "Msql/t/10dsnlist.t"],
          ["tests/20createdrop.t", "Msql/t/20createdrop.t"],
          ["tests/30insertfetch.t", "Msql/t/30insertfetch.t"],
          ["tests/40bindparam.t", "Msql/t/40bindparam.t"],
          ["tests/40blobs.t", "Msql/t/40blobs.t"],
          ["tests/40listfields.t", "Msql/t/40listfields.t"],
          ["tests/40nulls.t", "Msql/t/40nulls.t"],
          ["tests/40numrows.t", "Msql/t/40numrows.t"],
          ["tests/50chopblanks.t", "Msql/t/50chopblanks.t"],
          ["tests/50commit.t", "Msql/t/50commit.t"],
          ["tests/60leaks.t", "Msql/t/60leaks.t"],
          ["tests/ak-dbd.t", "Msql/t/ak-dbd.t"],
          ["tests/dbdadmin.t", "Msql/t/dbdadmin.t"],
          ["tests/lib.pl", "Msql/t/lib.pl"] ];
    $MyConfig->{'files_msqlperl'} =
        [ ["tests/akmisc.t", "Msql/t/akmisc.t"],
          ["tests/msql1.t", "Msql/t/msql1.t"],
          ["tests/msql2.t", "Msql/t/msql2.t"],
          ["nodbd/nodbd.pm.in", "Msql/lib/Msql.pm"],
          ["nodbd/statement.pm.in", "Msql/lib/Msql/Statement.pm"],
          ["nodbd/pmsql.in", "Msql/pmsql", 1]];


    if ($MyConfig->{'install_dbd_msql1'}) {
	eval { require Msql1 };
	my $default =
	    (defined($Msql1::VERSION) and $Msql1::VERSION >= 1.19) ?
		"y" : "n";

	$reply = prompt(qq{

Do you want to install the Msql1Perl emulation? You might keep your old
Mysql module (to be distinguished from DBD::mSQL1!) if you are concerned
about compatibility to existing applications!}, $default);
        $MyConfig->{'install_msql1perl'} = ($reply =~ /y/i) ? 1 : 0;
        QueryDb($MyConfig, 'mSQL 1', 'mSQL1');
        if (!exists $MyConfig->{'X_msql1'}) {
            $MyConfig->{'X_msql1'} = InitializeMsql(1);
        }
    }

    $MyConfig->{'files_dbd_msql1'} =
        [ ["dbd/Makefile.PL.in", "Msql1/Makefile.PL"],
          ["dbd/bundle.pm.in", "Msql1/lib/Bundle/DBD/mSQL1.pm"],
          ["dbd/dbdimp.c", "Msql1/dbdimp.c"],
          ["dbd/dbd.xs.in", "Msql1/mSQL1.xs"],
          ["dbd/dbd.pm.in", "Msql1/mSQL1.pm"],
          ["tests/00base.t", "Msql1/t/00base.t"],
          ["tests/10dsnlist.t", "Msql1/t/10dsnlist.t"],
          ["tests/20createdrop.t", "Msql1/t/20createdrop.t"],
          ["tests/30insertfetch.t", "Msql1/t/30insertfetch.t"],
          ["tests/40bindparam.t", "Msql1/t/40bindparam.t"],
          ["tests/40blobs.t", "Msql1/t/40blobs.t"],
          ["tests/40listfields.t", "Msql1/t/40listfields.t"],
          ["tests/40nulls.t", "Msql1/t/40nulls.t"],
          ["tests/40numrows.t", "Msql1/t/40numrows.t"],
          ["tests/50chopblanks.t", "Msql1/t/50chopblanks.t"],
          ["tests/50commit.t", "Msql1/t/50commit.t"],
          ["tests/60leaks.t", "Msql1/t/60leaks.t"],
          ["tests/ak-dbd.t", "Msql1/t/ak-dbd.t"],
          ["tests/dbdadmin.t", "Msql1/t/dbdadmin.t"],
          ["tests/lib.pl", "Msql1/t/lib.pl"] ];
    $MyConfig->{'files_msql1perl'} =
        [ ["tests/akmisc.t", "Msql1/t/akmisc.t"],
          ["tests/msql1.t", "Msql1/t/msql1.t"],
          ["tests/msql2.t", "Msql1/t/msql2.t"],
          ["nodbd/nodbd.pm.in", "Msql1/lib/Msql1.pm"],
          ["nodbd/statement.pm.in", "Msql1/lib/Msql1/Statement.pm"],
          ["nodbd/pmsql.in", "Msql1/pmsql1", 1]];

    if ($MyConfig->{'install_dbd_mysql'}) {
        push(@{$MyConfig->{'files_dbd_mysql'}},
	     ["dbd/dbimon.in", "dbimon", 1]);
    } else {
        push(@{$MyConfig->{'files_dbd_msql'}},
	     ["dbd/dbimon.in", "dbimon", 1]);
    }

    MakeDirs();
    $Data::Dumper::Indent = 1;
    if (!open(STATUS, ">.status")
        || !print STATUS Data::Dumper->Dump([$MyConfig], [qw($MyConfig)])
        || !close(STATUS)) {
        die "Cannot create .status file: $!\n";
    }
}


############################################################################
#
#    Name:    MakeDirs
#
#    Purpose: Create the directories Msql, Msql1 and Mysql
#
#    Inputs:  None
#
#    Result:  Nothing; aborts in case of trouble
#
############################################################################

sub CreatePostamble($$$$) {
    my($driver, $dbdDriver, $xtractFiles, $unlinkFiles) = @_;
    my($ref);
    my($pa) = '';
    $| = 1;
    if (@$xtractFiles) {
	print "Creating $driver files ";
	foreach $ref (@$xtractFiles) {
	    $pa .= XtractF($ref, $driver, $dbdDriver, "../xtract");
	    Xtract($ref, $driver, $dbdDriver);
	    print ".";
	}
	print "\n";
    }
    if (@$unlinkFiles) {
	unlink map {
	    my $f = $_->[1]; $f =~ /\.pm$/ ? () : ($f)
	} @$unlinkFiles;
    }
    $pa;
}

sub MakeDirs () {
    my (@createList, @deleteList);

    if ($MyConfig->{'install_dbd_mysql'}) {
	push(@createList, @{$MyConfig->{'files_dbd_mysql'}});
    } else {
	push(@deleteList, @{$MyConfig->{'files_dbd_mysql'}});
    }
    if ($MyConfig->{'install_mysqlperl'}) {
	push(@createList, @{$MyConfig->{'files_mysqlperl'}});
    } else {
	push(@deleteList, @{$MyConfig->{'files_mysqlperl'}});
    }

    $MyConfig->{'postamble_mysql'} = CreatePostamble('Mysql', 'mysql',
						     \@createList,
						     \@deleteList);

    @createList = ();
    @deleteList = ();
    if ($MyConfig->{'install_dbd_msql'}) {
	push(@createList, @{$MyConfig->{'files_dbd_msql'}});
    } else {
	push(@deleteList, @{$MyConfig->{'files_dbd_msql'}});
    }
    if ($MyConfig->{'install_msqlperl'}) {
	push(@createList, @{$MyConfig->{'files_msqlperl'}});
    } else {
	push(@deleteList, @{$MyConfig->{'files_msqlperl'}});
    }

    $MyConfig->{'postamble_msql'} = CreatePostamble('Msql', 'mSQL',
						    \@createList,
						    \@deleteList);

    @createList = ();
    @deleteList = ();
    if ($MyConfig->{'install_dbd_msql1'}) {
	push(@createList, @{$MyConfig->{'files_dbd_msql1'}});
    } else {
	push(@deleteList, @{$MyConfig->{'files_dbd_msql1'}});	
    }
    if ($MyConfig->{'install_msql1perl'}) {
	push(@createList, @{$MyConfig->{'files_msql1perl'}});
    } else {
	push(@deleteList, @{$MyConfig->{'files_msql1perl'}});	
    }

    $MyConfig->{'postamble_msql1'} = CreatePostamble('Msql1', 'mSQL1',
						    \@createList,
						    \@deleteList);
}


############################################################################
#
#   This is main()
#
############################################################################

Init();

my(@dirs);
if ($MyConfig->{'install_dbd_msql'}) {
    push(@dirs, "Msql");
}
if ($MyConfig->{'install_dbd_mysql'}) {
    push(@dirs, "Mysql");
}
if ($MyConfig->{'install_dbd_msql1'}) {
    push(@dirs, "Msql1");
}

my %opts =
    ('NAME'         => 'Msql-Mysql-modules',
     'DIR'          => \@dirs,
     'EXE_FILES'    => [ 'dbimon' ],
     'dist'         => { 'SUFFIX'       => ".gz",
			 'DIST_DEFAULT' => 'all tardist',
			 'COMPRESS'     => "gzip -9f" },
     'VERSION'      => $MyConfig->{'VERSION'},
     'realclean'    => { FILES => 'Mysql/Makefile.PL Msql/Makefile.PL'
			     . ' Msql1/Makefile.PL .status' }
     );

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{ABSTRACT} =
	'mSQL and MySQL drivers for the Perl5 Database Interface (DBI)';
    $opts{AUTHOR} = 'Jochen Wiedmann (joe@ispsoft.de)';
    $opts{CAPI} = 'TRUE' if $Config::Config{archname} =~ /-object\b/i;
    $opts{PREREQ_PM} = { 'DBI' => 1.02 };
}

ExtUtils::MakeMaker::WriteMakefile(%opts);
