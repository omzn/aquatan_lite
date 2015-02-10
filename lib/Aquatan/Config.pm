package Aquatan::Config;
use utf8;
use Moose;
use Time::Piece;
use Data::Dumper;
use Config::Pit;

has config => (is => 'rw');
has config_name => (is => 'rw', default=> 'aqua');    

sub BUILD {
    my $self = shift;
    $self->{config} = Config::Pit::get($self->{config_name});
}

sub p {
    my $self = shift;
    my $param = shift;
    
    return $self->config->{$param};
}

1;

__END__
