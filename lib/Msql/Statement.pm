# -*- perl -*-

package Msql::Statement;

use strict;
use vars qw($OPTIMIZE $VERSION $AUTOLOAD);

$VERSION = '1.1825';

$OPTIMIZE = 0; # controls, which optimization we default to

sub numrows    { my $x = shift; $x->{'NUMROWS'} or $x->fetchinternal( 'NUMROWS'
  ) }
sub numfields  { shift->fetchinternal( 'NUMFIELDS' ) }
sub affectedrows { my $x = shift; $x->fetchinternal( 'AFFECTEDROWS') }
sub insertid  { my $x = shift; $x->fetchinternal( 'INSERTID') }
sub table      { return wantarray ? @{shift->fetchinternal('TABLE'    )}: shift->fetchinternal('TABLE'    )}
sub name       { return wantarray ? @{shift->fetchinternal('NAME'     )}: shift->fetchinternal('NAME'     )}
sub type       { return wantarray ? @{shift->fetchinternal('TYPE'     )}: shift->fetchinternal('TYPE'     )}
sub isnotnull  { return wantarray ? @{shift->fetchinternal('ISNOTNULL')}: shift->fetchinternal('ISNOTNULL')}
sub isprikey   { return wantarray ? @{shift->fetchinternal('ISPRIKEY' )}: shift->fetchinternal('ISPRIKEY' )}
sub isnum     { return wantarray ? @{shift->fetchinternal('ISNUM' )}: shift->fetchinternal('ISNUM' )}
sub isblob     { return wantarray ? @{shift->fetchinternal('ISBLOB' )}: shift->fetchinternal('ISBLOB' )}
sub length     { return wantarray ? @{shift->fetchinternal('LENGTH'   )}: shift->fetchinternal('LENGTH'   )}

sub maxlength  {
    my $sth = shift;
    my $result;
    if (!($result = $sth->{MAXLENGTH})) {
	$result = [];
	my ($l);
	for (0..$sth->numfields-1) {
	    $$result[$_] = 0;
	}
	$sth->dataseek(0);
	my($col, @row, $i);
	while (@row = $sth->fetchrow) {
	    for ($i = 0;  $i < @row;  $i++) {
		$col = $row[$i];
		my($s) = defined $col ? unctrl($col) : "NULL";
		# New in 2.0: a string is longer than it should be
		if (defined &Msql::TEXT_TYPE  &&
		    $sth->type->[$i] == &Msql::TEXT_TYPE &&
		    length($s) > $sth->length->[$i] + 5) {
		    my $l = length($col);
		    substr($s,$sth->length->[$i]) = "...($l)";
		}
		if (length($s) > $$result[$i]) {
		    $$result[$i] = length($s);
		}
	    }
	}
	$sth->{MAXLENGTH} = $result;
    }
    return wantarray ? @$result : $result;
}

sub listindices {
    my($sth) = shift;
    my(@result,$i);
    if (!&Msql::IDX_TYPE) {
	return ();
    }
    foreach $i (0..$sth->numfields-1) {
	next unless $sth->type->[$i] == &Msql::IDX_TYPE;
	push @result, $sth->name->[$i];
    }
    @result;
}

sub AUTOLOAD {
    my $meth = $AUTOLOAD;
    $meth =~ s/^.*:://;
    $meth =~ s/_//g;
    $meth = lc($meth);

    # Allow them to say fetch_row or FetchRow
    no strict;
    if (defined &$meth) {
	*$AUTOLOAD = \&{$meth};
	return &$AUTOLOAD(@_);
    }
    Carp::croak ("$AUTOLOAD not defined and not autoloadable");
}

sub unctrl {
    my($x) = @_;
    $x =~ s/\\/\\\\/g;
    $x =~ s/([\001-\037\177])/sprintf("\\%03o",unpack("C",$1))/eg;
    $x;
}

sub optimize {
    my($self,$arg) = @_;
    if (defined $arg) {
	return $self->{'OPTIMIZE'} = $arg;
    } else {
	return $self->{'OPTIMIZE'} ||= $OPTIMIZE;
    }
}

sub as_string {
    my($sth) = @_;
    my($plusline,$titline,$sprintf) = ('+','|','|');
    my($result,$s,$l);
    if ($sth->numfields == 0) {
	return '';
    }
    for (0..$sth->numfields-1) {
	$l=length($sth->name->[$_]);
	if ($sth->optimize  &&  $l < $sth->maxlength->[$_]) {
	    $l= $sth->maxlength->[$_];
	}
	if (!$sth->isnotnull  &&  $l < 4) {
	    $l = 4;
	}
	$plusline .= sprintf "%$ {l}s+", "-" x $l;
	$l= -$l  if (!$sth->isnum->[$_]);
	$titline .= sprintf "%$ {l}s|", $sth->name->[$_];
	$sprintf .= "%$ {l}s|";
    }
    $sprintf .= "\n";
    $result = "$plusline\n$titline\n$plusline\n";
    $sth->dataseek(0);
    my(@row);
    while (@row = $sth->fetchrow) {
	my ($col, $pcol, @prow, $i, $j);
	for ($i = 0;  $i < $sth->numfields;  $i++) {
	    $col = $row[$i];
	    $j = @prow;
	    $pcol = defined $col ? unctrl($col) : "NULL";
	    # New in 2.0: a string is longer than it should be
	    if (defined &Msql::TEXT_TYPE  &&
		$sth->optimize &&
		$sth->type->[$j] == &Msql::TEXT_TYPE &&
		length($pcol) > $sth->length->[$j] + 5) {
		my $l = length($col);
		substr($pcol,$sth->length->[$j])="...($l)";
	    }
	    push(@prow, $pcol);
	}
	$result .= sprintf $sprintf, @prow;
    }
    $result .= "$plusline\n";
    $s = $sth->numrows == 1 ? "" : "s";
    $result .= $sth->numrows . " row$s processed\n\n";
    return $result;
}

1;
