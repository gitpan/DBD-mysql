#   Hej, Emacs, don't you see this is -*- perl -*- mode? :-)
#
#   Copyright (c) 1997,1998  Andreas König, Jochen Wiedmann
#
#  You may distribute this under the terms of either the GNU General Public
#  License or the Artistic License, as specified in the Perl README file.
#
#  $Id: Makefile.PL 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
#
BEGIN {require 5.004;}
use strict;
require Config;
use ExtUtils::MakeMaker qw(prompt WriteMakefile);
require File::Path;
require Config;
require Cwd;
use lib "lib";

use vars qw($VERSION $DBD_VERSION);

$VERSION = "1.21_02";
$DBD_VERSION = "2.03_02";

my $options = {};


############################################################################
#
#   General hints:
#
#   This Makefile.PL can install several modules: DBD::mysql, DBD::mSQL
#   and/or DBD::mSQL1.
#
#   This is done by creating a hash ref $config with keys 'mysql', 'mSQL'
#   and 'mSQL1'. Each key has another hash ref as value with keys like
#
#       install (0 or 1)
#       install_nodbd (0 or 1)
#       files   (hash ref ready for using as MakeMakers PL_FILES)
#       dbd_driver  (drivers name, same as the top level key)
#       nodbd_driver (Mysql, Msql or Msql1)
#       lc_dbd_driver (lowercased driver name)
#       dbd_version
#       nodbd_version
#       test_dsn (DSN for running tests)
#       test_user (User for running tests)
#       test_pass (Password for running tests)
#       test_db (Database for running tests; DSN is derived from this and
#                test_host)
#       test_host (Host for running tests)
#
############################################################################


############################################################################
#
#   Name:    QueryDb
#
#   Purpose: Query settings for running the test suite
#
#   Inputs:  $cfg - Config hash ref
#
#   Returns: Nothing; creates
#            $cfg->{$driver}->{test_(db|host|dsn|user|pass)}
#
############################################################################

sub QueryDb ($) {
    my($cfg) = @_;
    my $db = $cfg->{'description'};
    my $driver = $cfg->{'dbd_driver'};

    my $test_db = prompt
	("Which database should I use for testing the $db drivers?",
	 ($cfg->{'test_db'} || 'test'));
    my $test_host = prompt
	("On which host is database $test_db running (hostname, ip address\n" .
	 "or host:port)",
	 ($cfg->{'test_host'} || 'localhost'));

    my($test_user, $test_pass);
    if ($driver eq 'mysql') {
	$test_user = prompt
	    ("User name for connecting to database $test_db?",
	     ($cfg->{'test_user'} || "undef"));
	if ($test_user eq "undef") {
	    $test_user = undef;
	}
	$test_pass = prompt
	    ("Password for connecting to database $test_db?",
	     ($cfg->{'test_pass'} || "undef"));
	if ($test_pass eq "undef") {
	    $test_pass = undef;
	}
    }

    $cfg->{$driver}->{'test_db'} = $test_db;
    $cfg->{$driver}->{'test_host'} = $test_host;
    if ($test_host eq 'undef'  ||  $test_host eq 'localhost') {
	$test_host = '';
    }
    my $test_dsn = "DBI:$driver:database=$test_db";
    if ($test_host) {
	$cfg->{$driver}->{'test_dsn'} .= ";host=$test_host";
    }

    $cfg->{'test_dsn'} = $test_dsn;
    $cfg->{'test_db'} = $test_db;
    $cfg->{'test_host'} = $test_host;
    $cfg->{'test_user'} = $test_user;
    $cfg->{'test_pass'} = $test_pass;

    if ($options->{'verbose'}) {
	print("Driver $driver is using the following settings for tests:\n",
	      "    Database $test_db\n",
	      "    Host     $test_host\n",
	      "    DSN      $test_dsn\n",
	      "    User     $test_user\n",
	      "    Password $test_pass\n");
    }
}


############################################################################
#
#   This is main()
#
############################################################################

sub CheckModule ($;$) {
    my($module, $version) = @_;
    if ($version) {
	print "Checking for $module, $version or later ...";
	eval "use $module $version ()";
	if ($@) {
	    print("\nYou don't have installed the $module module, version"
		  . " $version or later.\n");
	    return 1;
	}
    } else {
	print "Checking for $module ...";
	eval "use $module ()";
	if ($@) {
	    print("\nYou don't have installed the $module module.\n");
	    return 1;
	}
    }
    print "Ok\n";
    return 0;
}


sub SelectDrivers ($$) {
    my($config, $old) = @_;

    my $choice;
    if (!$old->{'mysql'}  ||
	($old->{'mysql'} && $old->{'mysql'}->{'install'})) {
	if (!$old->{'mSQL'}  ||
	    ($old->{'mSQL'} && $old->{'mSQL'}->{'install'})) {
	    if (($old->{'mSQL1'} && $old->{'mSQL1'}->{'install'})) {
		$choice = 5;
	    } else {
		$choice = 3;
	    }
	} else {
	    $choice = 1;
	}
    } else {
	if (!$old->{'mSQL'}  ||
	    ($old->{'mSQL'} && $old->{'mSQL'}->{'install'})) {
	    if (($old->{'mSQL1'} && $old->{'mSQL1'}->{'install'})) {
		$choice = 4;
	    } else {
		$choice = 2;
	    }
	} else {
	    $choice = 3;
	}
    }

    $choice = prompt
	("Which drivers do you want to install?\n\n"
	 . "    1)	MySQL only\n"
	 . "    2)	mSQL only (either of mSQL 1 or mSQL 2)\n"
	 . "    3)  MySQL and mSQL (either of mSQL 1 or mSQL 2)\n\n"
	 . "    4)  mSQL 1 and mSQL 2\n"
	 . "    5)  MySQL, mSQL 1 and mSQL 2\n\n"
	 . "Enter the appropriate number: ", $choice);

    my $reply;
    if ($choice == 1  ||  $choice == 3  ||  $choice == 5) {
	$config->{'mysql'}->{'install'} = 1;
	$reply = prompt
	    ("Do you want to install the MysqlPerl emulation? This is highly"
	     . " experimental\n"
	     . "and can break existing code! ",
	     (!$old->{'mysql'} ||
	      ($old->{'mysql'} && $old->{'mysql'}->{'install_nodbd'})) ?
	     "y" : "n");
	$config->{'mysql'}->{'install_nodbd'} = ($reply =~ /y/i) ? 1 : 0;
    } else {
	$config->{'mysql'}->{'install'} = 0;
	$config->{'mysql'}->{'install_nodbd'} = 0;
    }
    if ($choice > 1) {
	$config->{'mSQL'}->{'install'} = 1;
	if ($choice == 4  ||  $choice == 5) {
	    $config->{'mSQL'}->{'description'} = 'mSQL 2';
	}
	$reply = prompt
	    ("Do you want to install the MsqlPerl emulation? This is highly"
	     . " experimental\n"
	     . " and can break existing code! ",
	     (!$old->{'mSQL'} ||
	      ($old->{'mSQL'} && $old->{'mSQL'}->{'install_nodbd'})) ?
	     "y" : "n");
	$config->{'mSQL'}->{'install_nodbd'} = ($reply =~ /y/i) ? 1 : 0;
    } else {
	$config->{'mSQL'}->{'install'} = 0;
	$config->{'mSQL'}->{'install_nodbd'} = 0;
    }
    if ($choice == 4  ||  $choice == 5) {
	$config->{'mSQL1'}->{'install'} = 1;
	$reply = prompt
	    ("Do you want to install the Msql1Perl emulation? This is highly"
	     . " experimental\n"
	     . " and can break existing code! ",
	     (!$old->{'mSQL1'} ||
	      ($old->{'mSQL1'} && $old->{'mSQL1'}->{'install_nodbd'})) ?
	     "y" : "n");
	$config->{'mSQL1'}->{'install_nodbd'} = ($reply =~ /y/i) ? 1 : 0;
    } else {
	$config->{'mSQL1'}->{'install'} = 0;
	$config->{'mSQL1'}->{'install_nodbd'} = 0;
    }
}


{
    require Getopt::Long;
    Getopt::Long::GetOptions($options, "verbose", "debug");

    # Checking for existing installations
    my $package;
    my $old = {};
    my $config = {};
    foreach $package ('mysql', 'mSQL', 'mSQL1') {
	my $class = "DBD::${package}::Install";
	# Try to find an existing configuration
	eval qq{
	    require $class;
	    \$old->{\$package} = require $class\::Config;
	};
	if ($old->{$package}) {
	    $config->{$package} = $old->{$package};
	} else {
	    $config->{$package} = $class->new($DBD_VERSION, $VERSION);
	}
    }

    # Checking for prerequisites
    if (!$ENV{'IN_MYSQL_DISTRIBUTION'}  &&
	!$old->{'mysql'}  &&  !$old->{'mSQL'}  &&  !$old->{'mSQL1'}) {
	my($missing_required, $missing_recommended) = (0,0);

	$missing_required ||= CheckModule('DBI', 0.93);
	$missing_required ||= CheckModule('Data::Dumper');
	$missing_required ||= CheckModule('ExtUtils::PerlPP');
	$missing_recommended ||= CheckModule('Data::ShowTable');

        if ($missing_required  ||  $missing_recommended) {
            print q{
Missing modules are available from any CPAN mirror, for example

   ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module

};
	    if ($missing_required) { exit 1 } else { sleep 5 };
	}
    } else {
	require DBI;
	require Data::Dumper;
	require ExtUtils::PerlPP;
	require Data::ShowTable;
    }


    if ($ENV{'IN_MYSQL_DISTRIBUTION'}) {
	$config->{'mysql'}->{'install'} = 1;
	$config->{'mysql'}->{'install_nodbd'} = 1;
	$config->{'mSQL'}->{'install'} = 0;
	$config->{'mSQL1'}->{'install'} = 0;
    } else {
	if (!$old->{'mysql'}  ||  !$old->{'mSQL'}  ||  !$old->{'mSQL1'}) {
	    SelectDrivers($config, $old);
	}
    }

    my(@installdirs, @pl_files, @delete_files, $dbimon_done);
    $| = 1;
    foreach $package ('mysql', 'mSQL', 'mSQL1') {
	my $cfg = $config->{$package};
	# Create the config file
	my $dir = $cfg->{'dbd_driver'};

	if ($cfg->{'install'}) {
	    my $description = $cfg->{'description'};
	    push(@installdirs, $dir);
	    push(@pl_files, 'dbd/Makefile.PL.in', "$dir/Makefile.PL",
		 "lib/DBD/$dir/Install/Config.pm");
	    if (!$dbimon_done) {
		$dbimon_done = 1;
		push(@pl_files, 'dbd/dbimon.in', 'dbimon',
		     "lib/DBD/$dir/Install/Config.pm");
	    }
	    if (!$old->{$package}) {
		$cfg->Initialize();
		QueryDb($cfg);
		# Create the Makefile.PL
		print "Creating files for $description ";
	        ExtUtils::PerlPP::ppp('dbd/Makefile.PL.in',
				      "$dir/Makefile.PL",
				      $cfg);
		print ".";
		# Create other files.
		my($var, $val);
		while (($var, $val) = each %{$cfg->{'files'}}) {
		    ExtUtils::PerlPP::ppp($var, $val, $cfg);
		      print ".";
		}
		if ($cfg->{'install_nodbd'}) {
		    while (($var, $val) = each %{$cfg->{'files_nodbd'}}) {
		        ExtUtils::PerlPP::ppp($var, $val, $cfg);
			print ".";
		    }
		} else {
		    push(@delete_files, values %{$cfg->{'files_nodbd'}});
		}
		print "\n";
	    }

	    $Data::Dumper::Indent = 1;
	    my $cf = Data::Dumper->Dump
		([$cfg], ["\$DBD::${dir}::Install::Config::configuration"]);
	    my $time = localtime();
	    my $cfg_file = <<"CFG_FILE";
# -*- perl -*-
#
#    This file was automatically generated at $time
#    by Makefile.PL. Do not edit, instead do a "make realclean" in
#    the toplevel directory and rerun "perl makefile.PL".
#
package DBD::${dir}::Install::Config;

$cf
CFG_FILE
            my $d = "lib/DBD/$dir/Install";
	    if (! -d $d  &&  !mkdir $d, 0755) {
		die "Error while creating $d: $!";
	    }
	    if (!open(CFG, ">$d/Config.pm")
		|| !(printf CFG $cfg_file)  || !close(CFG)) {
		die "Cannot create config file $d/Config.pm: $!";
	    }
        } else {
	    push(@delete_files, "$dir/Makefile.PL",
		 values %{$cfg->{'files'}},
		 values %{$cfg->{'files_nodbd'}});
	}
    }

#     my $f;
#     foreach $f (@delete_files) {
# 	if (-f $f) {
# 	    if ($options->{'verbose'}) {
# 		print "Removing file: $f\n";
# 	    }
# 	    if (!unlink $f) {
# 		die "Error while removing $f: $!";
# 	    }
# 	}
#     }

    ExtUtils::MakeMaker::WriteMakefile
        ('NAME'         => 'Msql-Mysql-modules',
         'DIR'          => \@installdirs,
         'EXE_FILES'    => [ 'dbimon' ],
         'dist'         => { 'SUFFIX'       => ".gz",
			     'DIST_DEFAULT' => 'all tardist',
			     'COMPRESS'     => "gzip -9f" },
         'VERSION'      => $VERSION,
         'realclean'    => {
	     FILES => 'Mysql/Makefile.PL Msql/Makefile.PL Msql1/Makefile.PL'
		 . ' lib/DBD/mysql/Install/Config.pm'
		 . ' lib/DBD/mSQL/Install/Config.pm'
		 . ' lib/DBD/mSQL1/Install/Config.pm'
	     },
         'PL_FILES'     => \@pl_files
     );
}


package MY;

sub libscan {
    my($self, $path) = @_;
    if ($path =~ /(PerlPP\.pm|Config\.pm|Install\.pm|,v|~)$/) { return undef; }
    $path;
}

sub processPL {
    my($self) = shift;
    my @output;
    my @files = @{$self->{'PL_FILES'}};
    while (@files) {
	my $from = shift @files;
	my $to = shift @files;
	my $cfg = shift @files;
	push(@output, <<"PART");
pm_to_blib: $to

$to :: $from
	\$(PERL) -I\$(INST_ARCHLIB) -I\$(INST_LIB) -I\$(PERL_ARCHLIB) \\
		-I\$(PERL_LIB) -Ilib -MExtUtils::PerlPP \\
		-e "ppp('$from', '$to', '$cfg')"

PART
    }
    join "", @output;
}
