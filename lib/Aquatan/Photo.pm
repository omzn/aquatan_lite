package Aquarium::Photo;
use Moose;
use utf8;
use LWP::UserAgent;

#use Aquarium::Common qw(:all);

has url => (default=>"http://localhost:8080/?action=snapshot",is=>'ro');

sub get_image {
    my $self = shift;

    my $browser = LWP::UserAgent->new;
    my $response = $browser->get($self->url,'User-Agent' => 'Mozilla/5.0 (Windows; U; Win98; en-US; rv:1.5) Gecko/20031007');
    my $img_file = $response->content;
    return $img_file;
}

1;
