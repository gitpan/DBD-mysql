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
use lib ".";
require "Makefile.lib";


_MY::Config::Init(1);
_MY::Config::MakeDirs();


$::Verbose++ if $ENV{USER} eq "k";

ExtUtils::MakeMaker::WriteMakefile(
	      'NAME'         => 'Msql-Mysql-modules',
	      'EXE_FILES'    => [ 'dbimon' ],
	      'dist'         => { 'SUFFIX'       => ".gz",
				  'DIST_DEFAULT' => 'all tardist',
				  'COMPRESS'     => "gzip -9f" },
	      'VERSION'      => $_MY::Config::VERSION,
	      'realclean'    => 'Mysql/Makefile.PL Msql/Makefile.PL'
			        . ' DBD-mysql/Makefile.PL DBD-mSQL/Makefile.PL'
				. ' status.lib'
);
