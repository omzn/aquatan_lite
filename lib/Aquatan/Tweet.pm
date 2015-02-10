package Aquatan::Tweet;
use utf8;
use Moose;
use Encode;
use List::Util qw(shuffle);
use Data::Dumper;
use Time::Piece;

use Aquatan::Photo;

has text                  => (is=>'rw');
has reply_to              => (is=>'rw');
has dot_reply             => (is=>'rw',default=>0);
has dm_to                 => (is=>'rw');
has in_reply_to_status_id => (is=>'rw');
has media_url             => (is=>'rw');
has media_type            => (is=>'rw');
has tms                   => (is=>'rw');
has hashtag               => (is=>'rw');

sub ts {
    my $self = shift;
    my $format = shift;

    my $t = localtime;

    my $tsp = {
	full  => $t->strftime('%Y-%m-%d %H:%M:%S'),
	day   => $t->strftime('%m-%d'),
	time  => $t->strftime('%H:%M'),
	jfull => decode_utf8($t->strftime('%Y年%m月%d日%H時%M分')),
	jshort => decode_utf8($t->strftime('%m月%d日%H時%M分')),
	jday  => decode_utf8($t->strftime('%m月%d日')),
	jtime => decode_utf8($t->strftime('%H時%M分'))
    };

    return $tsp->{$format};
}

sub append_text {
    my $self = shift;
    my $txt  = shift;

    $self->text($self->text . $txt);
}

sub tweet {
    my $self = shift;
    my $tweet;

    # text 
    my $text = sprintf("%s%s %s",
		       $self->tms ? 
		         $self->ts($self->tms)."、": '',
		       $self->text ? 
		         $self->text : '',
		       $self->hashtag ?
		         "#".$self->hashtag : ""
	);
    $text=~s/(^\s*|\s*$)//g;
    $text=~s/[\@＠][\w\d_]+//g;

    if ($self->reply_to) {
	$text = join(" ",map {"\@".$_} split(/,/,$self->reply_to))." ".$text;
	if ($self->dot_reply) {
	    $text = ".".$text;
	}
    }
    
    $tweet->{status}= substr($text,0,140);

    if ($self->in_reply_to_status_id) {
	$tweet->{in_reply_to_status_id} = $self->in_reply_to_status_id;
    }

    my $fname;
    my $ftype;
    if ($self->media_type) {
	$tweet->{status} = substr($tweet->{status},0,120);	
	if ($self->media_type =~/(graph|png)/i ) {
	    $fname = 'live.png';
	    $ftype = "Image/Png";
	} else {
	    $fname = 'live.jpg';
	    $ftype = "Image/Jpeg";
	} 

	sleep(2);
	my $media;
	if ($self->media_url) {
	    $media = Aquarium::Photo->new(url => $self->media_url);
	    #lpf("Photo url: %s",$self->media_url);
	} else {
	    $media = Aquarium::Photo->new;
	}	
	$tweet->{media} = [undef,$fname, Content_Type => $ftype, Content => $media->get_image];
    }
    
    return $tweet;
}

1;
__END__
