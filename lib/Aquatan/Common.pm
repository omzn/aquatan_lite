package Aquatan::Common;
use utf8;
use Moose;
use Sub::Exporter;
use Time::Piece;

Sub::Exporter::setup_exporter({ exports => [ qw(lpf timestamp ssleep unique) ]});

sub lpf {
    my $t = localtime;
    printf STDERR "[%s] ",$t->strftime('%Y-%m-%d %H:%M:%S');
    printf STDERR @_;
    print  STDERR "\n";
}

sub timestamp {
    my $t = localtime;
    return $t->strftime('%Y-%m-%d %H:%M:%S');
}

sub ssleep {
    my $wait = shift;
    select(undef,undef,undef,$wait);    
}

sub unique {
    my @array = @_;
    my %hash;
    @hash{@array} = ();
    return keys %hash;
}


1;
