# -*- perl -*-
#
#
#   DBD::mysql::Install - Determine settings of installing DBD::mysql
#

use strict;

require Config;
require File::Basename;
require ExtUtils::MakeMaker;


package DBD::mysql::Install;


sub new {
    my($class, $dbd_version, $nodbd_version) = @_;
    my($old, $self);

    if (@_ != 3) {
	die 'Usage: new($dbd_version, $nodbd_version)';
    }
    if (ref($class)) {
	$old = $class;
	$class = ref($class);
    } else {
	$old = {};
    }

    my $self = {
	'install'       => exists($old->{'install'}) ? $old->{'install'} : 1,
	'install_nodbd' => exists($old->{'install_nodbd'}) ?
	    $old->{'install_nodbd'} : 1,
	'dbd_driver'    => $old->{'dbd_driver'}   ||  'mysql',
	'nodbd_driver'  => $old->{'nodbd_driver'} ||  'Mysql',
	'description'   => $old->{'description'}  ||  'MySQL',
	'dbd_version'   => $dbd_version,
	'nodbd_version' => $nodbd_version,
	'test_db'       => $old->{'test_db'}      ||  'test',
	'test_host'     => $old->{'test_host'}    ||  'localhost',
	'test_user'     => $old->{'test_user'}    ||  undef,
	'test_pass'     => $old->{'test_pass'}    ||  undef,
	'files'         => {
	    'dbd/dbdimp.c'          => 'mysql/dbdimp.c',
	    'dbd/dbd.xs.in'         => 'mysql/mysql.xs',
	    'dbd/dbd.pm.in'         => 'mysql/lib/DBD/mysql.pm',
	    'tests/00base.t'        => 'mysql/t/00base.t',
	    'tests/10dsnlist.t'     => 'mysql/t/10dsnlist.t',
	    'tests/20createdrop.t'  => 'mysql/t/20createdrop.t',
	    'tests/30insertfetch.t' => 'mysql/t/30insertfetch.t',
	    'tests/40bindparam.t'   => 'mysql/t/40bindparam.t',
	    'tests/40listfields.t'  => 'mysql/t/40listfields.t',
	    'tests/40blobs.t'  => 'mysql/t/40blobs.t',
	    'tests/40nulls.t'       => 'mysql/t/40nulls.t',
	    'tests/40numrows.t'     => 'mysql/t/40numrows.t',
	    'tests/50chopblanks.t'  => 'mysql/t/50chopblanks.t',
	    'tests/50commit.t'      => 'mysql/t/50commit.t',
	    'tests/60leaks.t'       => 'mysql/t/60leaks.t',
	    'tests/ak-dbd.t'        => 'mysql/t/ak-dbd.t',
	    'tests/dbdadmin.t'      => 'mysql/t/dbdadmin.t',
#	    'tests/dbisuite.t'      => 'mysql/t/dbisuite.t',
	    'tests/lib.pl'          => 'mysql/t/lib.pl'
	    },
	'files_nodbd' => {
	    'tests/akmisc.t'        => 'mysql/t/akmisc.t',
	    'tests/mysql.t'         => 'mysql/t/mysql.t',
	    'tests/mysql2.t'        => 'mysql/t/mysql2.t',
	    'nodbd/bundle.pm.in'    => 'mysql/lib/Bundle/Mysql.pm',
	    'nodbd/nodbd.pm.in'     => 'mysql/lib/Mysql.pm',
	    'nodbd/statement.pm.in' => 'mysql/lib/Mysql/Statement.pm',
	    'nodbd/pmsql.in'        => 'mysql/pmysql'
	    }
    };

    $self->{'lc_dbd_driver'} = lc $self->{'dbd_driver'};
    $self->{'uc_dbd_driver'} = uc $self->{'dbd_driver'};
    $self->{'lc_nodbd_driver'} = lc $self->{'nodbd_driver'};
    $self->{'uc_nodbd_driver'} = uc $self->{'nodbd_driver'};
    $self->{'test_dsn'} = sprintf("DBI:%s:database=%s%s",
				  $self->{'dbd_driver'},
				  $self->{'test_db'},
				  $self->{'test_host'} ?
				      (';host=' . $self->{'test_host'}) : '');

    bless($self, $class);
    $self;
}


############################################################################
#
#   Name:    Search
#
#   Purpose: Find a certain file
#
#   Inputs:  $self - Instance
#            $gooddirs - List of directories where to search; these
#                directories are accepted immediately if a file is
#                found there
#            $dirs - List of additional directories where to search;
#                these are accepted only if the user confirms them
#            $files - List of files to search for; any of these will
#                be sufficient
#            $prompt - Prompt for asking the user to confirm a
#                directory
#
#   Returns: List of two directories: The first directory is the basename
#       of "$dir/$file" where $dir is one of $gooddirs or $dirs and $file
#       is one of $files. (Note that the file name may contain preceding
#       directory names!) The second directory is the corresponding dir
#       of $gooddirs or $dirs.
#
############################################################################

sub Search ($$$$$) {
    my($self, $gooddirs, $dirs, $files, $prompt) = @_;

    my ($dir, $file, $realfile);
    foreach $dir (@$gooddirs) {
	foreach $file (@$files) {
	    if (-f ($realfile = "$dir/$file")) {
		if ($::options->{verbose}) {
		    print "Using $file in $dir.\n";
		}
		return (File::Basename::dirname($realfile), $dir);
	    }
	}
    }
    my $gooddir;
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
	    if ($::options->{verbose}) {
		print "Using $file in $gooddir.\n";
	    }
	    return (File::Basename::dirname($realfile), $gooddir);
	}
    }

    if (@$files == 1) {
	die "Cannot find " . $$files[0] . " in $gooddir.\n";
    }
    die "Cannot find one of " . join(", ", @$files) . " in $gooddir";
}


sub SearchHeaders ($$$$) {
    my($self, $gooddirs, $dirs, $files) = @_;
    my @d = @$dirs;
    if ($self->{'headerdir'}) {
	unshift(@d, $self->{'headerdir'});
    }

    my($headerdir, $gooddir) = $self->Search
	($gooddirs, \@d, $files,
	 "Where is your " . $self->{'description'}
	 . " installed? Please tell me the directory that\n"
	 . "contains the subdir 'include'.");
    $self->{'headerdir'} = $gooddir;
    unshift(@$gooddirs, $gooddir);
    ($headerdir, $gooddir);
}

sub SearchLibs ($$$$) {
    my($self, $gooddirs, $dirs, $files) = @_;
    my @d = @$dirs;
    if ($self->{'libdir'}) {
	unshift(@d, $self->{'libdir'});
    }

    my($libdir, $gooddir) = $self->Search
	($gooddirs, \@d, $files,
	 "Where is your " . $self->{'description'}
	 . " installed? Please tell me the directory that\n"
	 . "contains the subdir 'lib'.");

    $self->{'libdir'} = $gooddir;
    unshift(@$gooddirs, $gooddir);
    ($libdir, $gooddir);
}


############################################################################
#
#   Name:    Initialize
#
#   Purpose: Determine compiler settings
#
#   Inputs:  $self - Instance
#
#   Returns: Hash ref of MakeMaker variables
#
############################################################################

sub CheckForLibGcc {
    my($self, $libdir) = @_;

    # For reasons I don't understand the 'specs' files of some
    # gcc versions disable linking against libgcc.a in conjunction
    # with '-shared'. Unfortunately we need libgcc.a because of
    # some arithmetic functions.
    #
    # We try to fix this by always linking against libgcc.a. Unfortunately
    # it's somewhat hard to find out the path of this file ...
    #
    if ($Config::Config{'gccversion'} eq '') {
	# This isn't gcc. Question is, does libmysqlclient.a require gcc?
	require Symbol;
	my $fh = Symbol::gensym();
	if (open($fh, "<$libdir/libmysqlclient.a")  ||
	    open($fh, "<$libdir/libmysqlclient.so")) {
	    local($/) = undef;
	    my $lib = <$fh>;
	    if ($lib  &&  $lib =~ /umoddi3/) {
		printf(<<"MSG", $libdir);

Your Perl configuration says you are not using gcc, but it seems your
libmysqlclient.a in %s needs libgcc.a. You might receive an error
message like

    t/00base............install_driver(mysql) failed: Can't load
    '../blib/arch/auto/DBD/mysql/mysql.so' for module DBD::mysql:
    ../blib/arch/auto/DBD/mysql/mysql.so: undefined symbol: _umoddi3
    at /usr/local/perl-5.005/lib/5.005/i586-linux-thread/DynaLoader.pm
    line 168.

when running the tests. See the INSTALL file for working around such
problems.

MSG
            }
	}
	return '';
    }

    my($libgccfile) = `$Config::Config{'cc'} -print-libgcc-file-name 2>&1`;
    my($libgccdir);
    if ($libgccfile =~ /^\S+$/) {
	if ($libgccfile =~ /(.*)\/lib(\S+)\.a/) {
	    $libgccdir = $1;
	    $libgccfile = $2;
	}
    } else {
	my($specs) = `$Config::Config{'cc'} -v 2>&1`;
	if ($specs =~ /Reading specs from (\S+)/) {
	    $specs = $1;
	} else {
	    printf(<<"MSG", $Config::Config{'cc'});
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
	    printf(<<"MSG", $Config::Config{'cc'});
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


sub Initialize ($) {
    my($self) = @_;

    my @mysqldirs = ($^O =~ /mswin32/i) ? qw(C:/my/myodbc) :
	qw{/usr/local /usr/local/mysql /usr /usr/mysql /opt/mysql};
    my @gooddirs = ();
    my $gooddir;
    foreach $gooddir ('MYSQL_HOME', 'MYSQL_BUILD') {
	if (exists($ENV{$gooddir})) {
	    unshift @gooddirs, $ENV{MYSQL_HOME};
	}
    }

    my $headerdir;
    if (exists($ENV{'MYSQL_HEADERDIR'})) {
	$headerdir = $ENV{'MYSQL_HEADERDIR'};
    } else {
	($headerdir, $gooddir) = $self->SearchHeaders
	    (\@gooddirs, \@mysqldirs,
	     ["include/mysql/mysql.h", "include/mysql.h"]);
    }
    my $libdir;
    if (exists($ENV{'MYSQL_LIBDIR'})) {
	$libdir = $ENV{'MYSQL_LIBDIR'};
    } else {
	my @searchpath = ($^O =~ /mswin32/i) ?
	    qw(lib/mysqlclient.lib lib_release/mysqlclient.lib
	       lib_debug/mysqlclient.lib lib/lib.lib
	       lib_release/lib.lib lib_debug/lib.lib) :
	    qw(lib/mysql/libmysqlclient.a lib/mysql/libmysqlclient.so
	       lib/libmysqlclient.a lib/libmysqlclient.so
	       client/libmysqlclient.a client/libmysqlclient.so);
	($libdir) = $self->SearchLibs(\@gooddirs, \@mysqldirs, \@searchpath);
    }

    my $sysliblist = "-L$libdir -lmysqlclient -lm";
    my $defines = "-DDBD_MYSQL -DMyConnect=mysql_dr_connect"
	. " -DMyLogin=mysql_dr_login";
    my $linkwith = "";
    if ($Config::Config{'osname'} eq 'sco_sv') {
	# Some extra libraries need added for SCO
	$sysliblist .= " -lc";
    } elsif ($Config::Config{'osname'} eq 'solaris') {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
	$linkwith = "-R$libdir";
    } elsif ($Config::Config{'osname'} eq 'hpux') {
	# We need to add +z to the list of CFLAGS if we're on HP-SUX, or -fPIC 
	# if we're on HP-SUX and using 'gcc'
	if ($Config::Config{'cccdlflags'} eq '+z') {
	    print("\nYou're building on HP-UX with the HP compiler.\n");
	} elsif ($Config::Config{'cccdlflags'} eq '-fPIC') {
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
	      "the '", $Config::Config{'cccdlflags'}, "' flag",
	      " of your C compiler.\n");
    } elsif ($^O =~ /mswin32/i) {
	$defines .= " -D__WIN32__";

	if (! -f "$libdir/mysqlclient.lib"  &&  -f "$libdir/lib.lib") {
	    # Looks like we're using MyODBC.
	    $sysliblist =~ s/-lmysqlclient/-llib/;
	    $sysliblist .= " -lmysys -lstrings -lzlib";
	}

	# For some reasons libc.lib is not linked against msvcrt.lib
	# with VC++ ...
	if ($Config::Config{'libs'} =~ /\bmsvcrt\.lib\b/  &&
	    $Config::Config{'libs'} !~ /\blibc.lib\b/) {
	    $sysliblist .= " -lc";
	}
    }

    $sysliblist .= $self->CheckForLibGcc($libdir);

    my(@headerfiles) = ("$headerdir/mysql.h");

    if ($ENV{HOSTNAME} eq 'laptop.ispsoft.de'  &&  $ENV{'LOGNAME'} eq 'joe') {
	$defines .= ' -Wall -Wstrict-prototypes';
    }
    my $inc = "-I$headerdir -I../dbd -I\$(INSTALLSITEARCH)/auto/DBI"
	. " -I\$(INSTALLARCHLIB)";
    my $dir;
    foreach $dir (@INC) {
	if (-f "$dir/auto/DBI/DBIXS.h") {
	    $inc = "-I$dir/auto/DBI " . $inc;
	    last;
	}
    }

    $self->{'makemaker'} = {
	'macro'       => { MYSQL_HOME => $gooddir },
	'dynamic_lib' => { OTHERLDFLAGS => "-L$libdir $linkwith" },
	'DEFINE'      => $defines,
	'LIBS'        => $sysliblist,
	'H'           => \@headerfiles,
	'INC'         => $inc
    };
}

