# -*- perl -*-

package Msql::Statement;

@Msql::Statement::ISA = qw(DBI::st);

use strict;
use vars qw($OPTIMIZE $VERSION $AUTOLOAD);

$VERSION = '1.21_07';

$OPTIMIZE = 0; # controls, which optimization we default to

sub fetchrow ($) {
    my($self) = shift;
    my($ref) = $self->fetchrow_arrayref;
    if ($ref) {
	@$ref;
    } else {
	();
    }
}
sub fetchhash ($) {
    my($self) = shift;
    my($ref) = $self->fetchrow_hashref;
    if ($ref) {
	%$ref;
    } else {
	();
    }
}
sub fetchcol ($$) {
    my($self, $colNum) = @_;
    my(@col);
    $self->dataseek(0);
    my($ref);
    while ($ref = $self->fetchrow_arrayref) {
	push(@col, $ref->[$colNum]);
    }
    @col;
}
sub dataseek ($$) {
    my($self, $pos) = @_;
    $self->func($pos, 'dataseek');
}

sub numrows { my($self) = shift; $self->rows() }
sub numfields { my($self) = shift; $self->{'NUM_OF_FIELDS'} }
sub arrAttr ($$) {
    my($self, $attr) = @_;
    my $arr = $self->{$attr};
    wantarray ? @$arr : $arr
}
sub table ($) { shift->arrAttr('msql_table') }
sub name ($) { shift->arrAttr('NAME') }
sub type ($) { shift->arrAttr('msql_type') }
sub isnotnull ($) {
    my $arr = [map {!$_} @{shift()->{'NULLABLE'}}];
    wantarray ? @$arr : $arr;
}
sub isprikey ($) { shift->arrAttr('msql_is_pri_key') }
sub isnum ($) { shift->arrAttr('msql_is_num') }
sub isblob ($) { shift->arrAttr('msql_is_blob') }
sub length ($) { shift->arrAttr('PRECISION') }

sub maxlength  {
    my $sth = shift;
    my $result;
    if (!($result = $sth->{'msql_maxlength'})) {
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
		    CORE::length($s) > $sth->length->[$i] + 5) {
		    my $l = CORE::length($col);
		    substr($s,$sth->length->[$i]) = "...($l)";
		}
		if (CORE::length($s) > $$result[$i]) {
		    $$result[$i] = CORE::length($s);
		}
	    }
	}
    }
    return wantarray ? @$result : $result;
}

sub listindices {
    my($sth) = shift;
    my(@result,$i);
    if (!&Msql::IDX_TYPE()) {
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
	$OPTIMIZE = $arg;
    }
    $OPTIMIZE;
}

sub as_string {
    my($sth) = @_;
    my($plusline,$titline,$sprintf) = ('+','|','|');
    my($result,$s,$l);
    if ($sth->numfields == 0) {
	return '';
    }
    for (0..$sth->numfields-1) {
	$l=CORE::length($sth->name->[$_]);
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
		CORE::length($pcol) > $sth->length->[$j] + 5) {
		my $l = CORE::length($col);
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