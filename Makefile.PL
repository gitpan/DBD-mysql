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
require Config;
require ExtUtils::MakeMaker;
require File::Path;
require Config;
require Cwd;
use lib ".";

use vars qw($MyConfig $VERSION $DBD_VERSION);

$VERSION = "1.19_14";
$DBD_VERSION = "2.01_14";


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
		return (File::Basename::dirname($realfile), $dir);
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

    $gooddir = ExtUtils::MakeMaker::prompt($prompt, $gooddir)
	||  $gooddir;  # for 5.002;

    foreach $file (@$files) {
	if (-f ($realfile = "$gooddir/$file")) {
	    return (File::Basename::dirname($realfile), $gooddir);
	}
    }

    if (@$files == 1) {
	die "Cannot find " . $$files[0] . " in $gooddir.\n";
    }
    die "Cannot find one of " . join(", ", @$files) . " in $gooddir";
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
    if ($Config::Config{gccversion} eq '') {
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
        "-L$libgccdir -l$libgccfile";
    } else {
        $libgccfile;
    }
}


sub InitializeMysql () {
    my %X;
    my @mysqldirs = qw{/usr/local /usr/local/mysql /usr /usr/mysql /opt/mysql};
    my @gooddirs = ();
    if (exists($ENV{MYSQL_HOME})) {
	unshift @gooddirs, $ENV{MYSQL_HOME};
    }
    if (exists($ENV{MYSQL_BUILD})) {
	unshift @gooddirs, $ENV{MYSQL_BUILD};
    }

    my($headerdir, $gooddir) = Search(\@gooddirs, \@mysqldirs,
				      ["include/mysql/mysql.h",
				       "include/mysql.h"],
				      "Where is your mysql installed? Please"
				      . " tell me the directory that"
				      . " contains\n"
				      . "the subdir include/.");
    unshift(@gooddirs, $gooddir);
    my($libdir) = Search(\@gooddirs, \@mysqldirs,
			 ["lib/mysql/libmysqlclient.a",
			  "lib/libmysqlclient.a",
			  "client/libmysqlclient.a"],
			 "Where is your mysql installed? Please tell me the"
			 . " directory that contains\n"
			 . "the subdir lib/.");

    
    my $extralibs = "";
    my $linkwith = "";
    if ($Config::Config{osname} eq 'sco_sv') {
	# Some extra libraries need added for SCO
	$extralibs = "-lc";
    } elsif ($Config::Config{osname} eq 'solaris') {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
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
    $X{DEFINE}   = "-DDBD_MYSQL -DMyConnect=mysql_dr_connect -DMyLogin=mysql_dr_login";
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

sub InitializeMsql {
    my %X;
    my @msqldirs = qw{/usr/local/Hughes /usr/local/Minerva /usr/local
			  /usr/mSQL /opt/mSQL};
    my @gooddirs;
    if (exists($ENV{MSQL_HOME})) { push(@gooddirs, $ENV{MSQL_HOME}); }

    my($headerdir, $gooddir) = Search(\@gooddirs, \@msqldirs,
				      ["include/msql.h"],
				      "Where is your msql installed? Please"
				      . " tell me the directory that"
				      . " contains\n"
				      . " the subdir include/.");
    unshift(@gooddirs, $gooddir);
    my($libdir) = Search(\@gooddirs, \@msqldirs, ["lib/libmsql.a"],
			 "Where is your msql installed? Please tell me the"
			 . " directory that contains\n"
			 . " the subdir lib/.");

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
    
    my $extralibs = "";
    my $linkwith = "";
    if ( $Config::Config{osname} eq 'sco_sv' ) {
	# Some extra libraries need added for SCO
	$extralibs = "-lc";
    } elsif ( $Config::Config{osname} eq 'solaris' ) {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
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
    $X{DEFINE}   = "-DDBD_MSQL -D$version$getconf -DMyConnect=mSQL_dr_connect -DMyLogin=mSQL_dr_login";
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
		return (File::Basename::dirname($realfile), $dir);
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

    $gooddir = ExtUtils::MakeMaker::prompt($prompt, $gooddir)
	||  $gooddir;  # for 5.002;

    foreach $file (@$files) {
	if (-f ($realfile = "$gooddir/$file")) {
	    return (File::Basename::dirname($realfile), $gooddir);
	}
    }

    if (@$files == 1) {
	die "Cannot find " . $$files[0] . " in $gooddir.\n";
    }
    die "Cannot find one of " . join(", ", @$files) . " in $gooddir";
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
    if (-f ".status") {
	# Read settings from .status file
	require ".status";
	return;
    }

    if ($ENV{'IN_MYSQL_DISTRIBUTION'}) {
	$MyConfig->{'install_dbd_mysql'} = 1;
	$MyConfig->{'install_dbd_msql'} = 0;
	$MyConfig->{'install_mysqlperl'} = 1;
	$MyConfig->{'install_msqlperl'} = 0;
    } else {
	my($ok) = 2;
	$MyConfig = { 'VERSION' => $VERSION,
		      'DBD_VERSION' => $DBD_VERSION };

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

        my($reply);
        my($choice) = 0;
        if (exists $ENV{'IN_MYSQL_DISTRIBUTION'}) {
            $choice = 1;
        }
        while (!$choice) {
	     $reply = ExtUtils::MakeMaker::prompt(
	         "\n\nWhich DBMS do you want to use?\n\n" .
	         "  1) MySQL\n" .
	         "  2) mSQL\n" .
	         "  3) Both\n\n" .
	         "Enter your choice: ", "3");
            if ($reply =~ /(\d+)/) {
                $choice = $1;
                if ($choice < 1  ||  $choice > 3) {
                    $choice = 0;
                }
            }
        }

        if ($MyConfig->{'install_dbd_mysql'} = ($choice != 2)) {
	    $reply = ExtUtils::MakeMaker::prompt(qq{
Do you want to install the MysqlPerl emulation? This is highly experimental
and can break existing code!}, "y");
            if ($reply =~ /y/i) {
                $MyConfig->{'install_mysqlperl'} = 1;
            } else {
                $MyConfig->{'install_mysqlperl'} = 0;
            }
        }
        if ($MyConfig->{'install_dbd_msql'} = ($choice != 1)) {
	    $reply = ExtUtils::MakeMaker::prompt(qq{
Do you want to install the MsqlPerl emulation? This is highly experimental
and can break existing code!}, "y");
            if ($reply =~ /y/i) {
                $MyConfig->{'install_msqlperl'} = 1;
            } else {
                $MyConfig->{'install_msqlperl'} = 0;
            }
        }
    }

    $MyConfig->{'files_dbd_mysql'} =
        [ ["dbd/Makefile.PL.in", "Mysql/Makefile.PL"],
          ["dbd/dbdimp.c", "Mysql/dbdimp.c"],
          ["dbd/dbd.xs.in", "Mysql/mysql.xs"],
          ["dbd/dbd.pm.in", "Mysql/mysql.pm"],
          ["tests/00base.t", "Mysql/t/00base.t"],
          ["tests/10dsnlist.t", "Mysql/t/10dsnlist.t"],
          ["tests/20createdrop.t", "Mysql/t/20createdrop.t"],
          ["tests/30insertfetch.t", "Mysql/t/30insertfetch.t"],
          ["tests/40bindparam.t", "Mysql/t/40bindparam.t"],
          ["tests/40listfields.t", "Mysql/t/40listfields.t"],
          ["tests/40nulls.t", "Mysql/t/40nulls.t"],
          ["tests/40numrows.t", "Mysql/t/40numrows.t"],
          ["tests/50chopblanks.t", "Mysql/t/50chopblanks.t"],
          ["tests/50commit.t", "Mysql/t/50commit.t"],
          ["tests/ak-dbd.t", "Mysql/t/ak-dbd.t"],
          ["tests/lib.pl", "Mysql/t/lib.pl"] ];
    $MyConfig->{'files_mysqlperl'} =
        [ ["tests/akmisc.t", "Mysql/t/akmisc.t"],
          ["tests/mysql.t", "Mysql/t/mysql.t"],
          ["tests/mysql2.t", "Mysql/t/mysql2.t"],
          ["nodbd/bundle.pm.in", "Mysql/lib/Bundle/Mysql.pm"],
          ["nodbd/nodbd.pm.in", "Mysql/lib/Mysql.pm"],
          ["nodbd/statement.pm.in", "Mysql/lib/Mysql/Statement.pm"],
          ["nodbd/pmsql.in", "Mysql/pmysql", 1]];
    $MyConfig->{'files_dbd_msql'} =
        [ ["dbd/Makefile.PL.in", "Msql/Makefile.PL"],
          ["dbd/dbdimp.c", "Msql/dbdimp.c"],
          ["dbd/dbd.xs.in", "Msql/mSQL.xs"],
          ["dbd/dbd.pm.in", "Msql/mSQL.pm"],
          ["tests/00base.t", "Msql/t/00base.t"],
          ["tests/10dsnlist.t", "Msql/t/10dsnlist.t"],
          ["tests/20createdrop.t", "Msql/t/20createdrop.t"],
          ["tests/30insertfetch.t", "Msql/t/30insertfetch.t"],
          ["tests/40bindparam.t", "Msql/t/40bindparam.t"],
          ["tests/40listfields.t", "Msql/t/40listfields.t"],
          ["tests/40nulls.t", "Msql/t/40nulls.t"],
          ["tests/40numrows.t", "Msql/t/40numrows.t"],
          ["tests/50chopblanks.t", "Msql/t/50chopblanks.t"],
          ["tests/50commit.t", "Msql/t/50commit.t"],
          ["tests/ak-dbd.t", "Msql/t/ak-dbd.t"],
          ["tests/lib.pl", "Msql/t/lib.pl"] ];
    $MyConfig->{'files_msqlperl'} =
        [ ["tests/akmisc.t", "Msql/t/akmisc.t"],
          ["tests/msql1.t", "Msql/t/msql1.t"],
          ["tests/msql2.t", "Msql/t/msql2.t"],
          ["nodbd/bundle.pm.in", "Msql/lib/Bundle/Msql.pm"],
          ["nodbd/nodbd.pm.in", "Msql/lib/Msql.pm"],
          ["nodbd/statement.pm.in", "Msql/lib/Msql/Statement.pm"],
          ["nodbd/pmsql.in", "Mysql/pmsql", 1]];
    if ($MyConfig->{'install_dbd_mysql'}) {
        push(@{$MyConfig->{'files_dbd_mysql'}},
	     ["dbd/dbimon.in", "dbimon", 1]);
    } else {
        push(@{$MyConfig->{'files_dbd_msql'}},
	     ["dbd/dbimon.in", "dbimon", 1]);
    }

    if ($MyConfig->{'install_dbd_mysql'}  &&  !exists $MyConfig->{'X_mysql'}) {
        $MyConfig->{'X_mysql'} = InitializeMysql();
    }
    if ($MyConfig->{'install_dbd_msql'}  &&  !exists $MyConfig->{'X_msql'}) {
        $MyConfig->{'X_msql'} = InitializeMsql();
    }

    MakeDirs();
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
#    Purpose: Create the directories Msql and Mysql
#
#    Inputs:  None
#
#    Result:  Nothing; aborts in case of trouble
#
############################################################################

sub CreatePostamble($$$) {
    my($driver, $dbdDriver, $xtractFiles) = @_;
    my($ref);
    my($pa) = '';
    $| = 1;
    print "Creating $driver files ";
    foreach $ref (@$xtractFiles) {
	$pa .= XtractF($ref, $driver, $dbdDriver, "../xtract");
	Xtract($ref, $driver, $dbdDriver);
	print ".";
    }
    print "\n";
    $pa;
}

sub MakeDirs () {
    my (@createList);

    if ($MyConfig->{'install_dbd_mysql'}) {
	push(@createList, @{$MyConfig->{'files_dbd_mysql'}});
    }
    if ($MyConfig->{'install_mysqlperl'}) {
	push(@createList, @{$MyConfig->{'files_mysqlperl'}});
    }

    $MyConfig->{'postamble_mysql'} = CreatePostamble('Mysql', 'mysql',
						     \@createList);

    @createList = ();
    if ($MyConfig->{'install_dbd_msql'}) {
	push(@createList, @{$MyConfig->{'files_dbd_msql'}});
    }
    if ($MyConfig->{'install_msqlperl'}) {
	push(@createList, @{$MyConfig->{'files_msqlperl'}});
    }

    $MyConfig->{'postamble_msql'} = CreatePostamble('Msql', 'mSQL',
						    \@createList);
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

ExtUtils::MakeMaker::WriteMakefile
    ('NAME'         => 'Msql-Mysql-modules',
     'DIR'          => \@dirs,
     'EXE_FILES'    => [ 'dbimon' ],
     'dist'         => { 'SUFFIX'       => ".gz",
			 'DIST_DEFAULT' => 'all tardist',
			 'COMPRESS'     => "gzip -9f" },
     'VERSION'      => $MyConfig->{'VERSION'},
     'realclean'    => 'Mysql/Makefile.PL Msql/Makefile.PL'
     . ' DBD-mysql/Makefile.PL DBD-mSQL/Makefile.PL'
     . ' .status'
     );
