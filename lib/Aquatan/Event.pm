package Aquatan::Event;
use utf8;
use strict;
use warnings;
use Moose;

extends 'Aquatan::Config';

use AnyEvent;
#use AnyEvent::Twitter;
use AnyEvent::Twitter::Stream;
use Data::Dumper;
use Net::Twitter;
use Encode;
use Time::Piece;

use Aquatan::Common qw(:all);

use Aquatan::Tweet;

has nt      => (is=>'rw');
has username => (is=>'rw');

sub BUILD {
    my $self = shift;

    $self->{nt} = Net::Twitter->new(
	traits   => [qw/API::RESTv1_1 OAuth/],
	consumer_key    => $self->p('consumer_key'),
	consumer_secret => $self->p('consumer_secret'),
	access_token    => $self->p('access_token'),
	access_token_secret => $self->p('access_token_secret'),
	ssl => 1
	);

    $self->{username} = $self->nt->account_settings->{screen_name};
    lpf("========================================================");
    lpf("Net::Twitter init: done.");
    lpf("Username %s",$self->username);
}

sub post_tweet {
    my $self=shift;
}
sub got_message {
    my $self=shift;
}
sub got_event {
    my $self=shift;
}

sub got_tweet {
    my ($self,$tweet) = @_;

    my $USERNAME = $self->username;

    return if (!defined($tweet));
    return if (!exists($tweet->{user}->{id}));
    return if (!exists($tweet->{text}));

    my $txt = $tweet->{text};
    my $m_id = $tweet->{id};
    my $sname = $tweet->{user}->{screen_name};

    my $t = localtime;

    my $reply = Aquatan::Tweet->new(
	reply_to  => $sname,
	in_reply_to_status_id => $m_id
	);

    my $opcmd = '';
    if ($tweet->{text} =~/移動/) {
	if ($tweet->{text} =~/右/) {
	    $opcmd = "gr";
	} elsif ($tweet->{text} =~/左/) {
	    $opcmd = "gl";
	}
    } elsif ($tweet->{text} =~/撮影|写真|映像/) {
	$opcmd = "ph";
    }
    lpf("Command: %s",$opcmd);
    
    ### 写真撮影 ###
    # 条件
    if ($opcmd eq "ph") {	    
	$reply->text("ライブ画像を送信します。");
	$reply->tms('jtime');
	$reply->media_type('camera');
	$self->do_tweet($reply);
	return;
    }      

    ### 移動命令 (left, rightのみ) ###
    # カメラ移動
    if ($opcmd eq "gr" || $opcmd eq "gl") {
	my $num = 1;
	if ($tweet->{text}=~/(\d+)/) {
	    $num = $1;
	    if ($num > 16) {
		$num = 16;
	    } elsif ($num < 1) {
		$num = 1;
	    }
	}	
	$self->move_h($opcmd,$reply,$num);
	return;
    }   
}

sub delete_tweet {
    my $self=shift;
}
sub int_15min {
    my $self=shift;
}
sub int_120min {
    my $self=shift;
}

sub eventloop {
    my $self=shift;

    my $cv = AE::cv;
    
    my $set_timer;
    my $listener_twitter;
    my $listener_timer;

    my $set_userstream = sub {
	$listener_twitter = AnyEvent::Twitter::Stream->new(
	    consumer_key    => $self->p('consumer_key'),
	    consumer_secret => $self->p('consumer_secret'),
	    token    => $self->p('access_token'),
	    token_secret => $self->p('access_token_secret'),
	    method => 'userstream',
	    
	    on_tweet => sub {
		my $tweet = shift;
		$self->got_tweet($tweet);
	    },    
	    
	    on_delete => sub {
	    },

	    on_direct_message => sub {
	    },

	    on_event => sub {
	    },
	    
	    on_error => sub {
		my $message = shift;
		lpf("ERROR: %s",$message);
		#$cv->send;
		undef $listener_twitter;
		undef $listener_timer;
		$set_timer->(5);
	    },
	    
	    );
    };    

    my $timer1 = AnyEvent->timer(
	after    => 60,
	interval => 60,
	cb       => sub {
	    $self->post_tweet;
	},
	);

    my $timer2 = AnyEvent->timer(
	after    => 0,
	interval => 900,
	cb       => sub {
	    $self->int_15min;
	},
	);

    my $timer3 = AnyEvent->timer(
	after    => 1800,
	interval => 7200,
	cb       => sub {
	    $self->int_120min;
	},
	);
    
    $set_timer = sub {
	my $after = shift || 0;
	$listener_timer = AnyEvent->timer(
	    after    => $after,
	    interval => 10,
	    cb => sub {
		unless ( $listener_twitter ) {
		    $set_userstream->();
		    lpf("AnyEvent_Timer:(re)connecting");
		}
	    },
	    );
    };
    
    $set_timer->();
    
    $cv->recv;
}

sub move_h {
    my $self = shift;
    my ($direction,$reply,$num) = @_;

    my $jdir;
    my $cmd;
    if ($direction eq 'gl') {	    
	$cmd = "-l $num";
	$jdir = '左';
    } elsif ($direction eq 'gr') {	    
	$cmd = "-r $num";
	$jdir = '右';
    }  
    my $ret = system("/usr/local/bin/motor $cmd");
    if ($ret != 0) {
	$reply->text(sprintf("移動コマンドが応答しませんでした。"));
	$reply->tms('jtime');
	
	$self->do_tweet($reply);
	return;
    } else {
	$reply->tms('jtime');
	$reply->text(sprintf("%sへ%d歩移動完了しました。",
			     $jdir,$num
		     ));
	$reply->media_type('camera');
	
	$self->do_tweet($reply);
	return;
    }
}

sub do_tweet {
    my ($self,$tw) = @_;
    my $content = $tw->tweet;
    {
	no utf8;
	eval {
	    my $res;
	    if (defined($content) && %$content) {
		if (exists($content->{media})) {
		    $res = $self->nt->update_with_media( $content );
		} else {
		    $res = $self->nt->update( $content );
		}
		lpf("Tweeted.");
	    }
	};
	if ($@) {
	    print STDERR $@;
	}
    }
}

1;
