package Aquarium::Droid;
use strict;
use utf8;
use Moose;
use Time::Piece;
use Encode;
use DBI;

extends 'Aquarium::DB';

use Aquarium::Camera;
use Aquarium::TankMan;
use Aquarium::Common qw(:all);

$|=1;

has cmd_move     => (default => "/usr/local/bin/move_cam", is => 'ro');
has cmd_feed     => (default => "/usr/local/bin/feed", is => 'ro');
has cmd_exposure => (default => "/usr/local/bin/exposure_camwide", is => 'ro');

has tm           => (default => sub {Aquarium::TankMan->new();}, is => 'ro');
has CAMERA_CENTER_H => (default => 150, is => 'ro');
has CAMERA_CENTER_V => (default => 130, is => 'ro');

sub wait_operating {
    my $self = shift;

    my ($dstatus) = $self->note('droid_status'); #
    my $count = 0;
    while (defined($dstatus) && $dstatus eq "Operating") {
	lpf("Waiting...");
	sleep(3);    
	($dstatus) = $self->note('droid_status');
	last if ($count++ > 20);
    }
}

sub tank {
    my $self = shift;

    my $d_tp;
    if (@_) {
	$d_tp = shift;
	$self->move($d_tp,undef);
    } else {
	($d_tp) = $self->value('droid_tank_pos'); #
    }
    return $d_tp;
}

sub lift {
    my $self = shift;

    my $d_lp;
    if (@_) {
	$d_lp = shift;
	$self->move(undef,$d_lp);
    } else {
	($d_lp) = $self->value('droid_lift_pos'); #
    }
    return $d_lp;
}

sub set_tankpos {
    my $self = shift;
    my $tank = shift;
    my $lift = shift;
    if (defined($tank)) {
	if ($tank <= $self->tm->MAX_TANK_POS && $tank >= 0) {
	    $self->value('droid_tank_pos',$tank);
	    lpf("Set tank position to %d\n",$tank);
	}
    }
    if (defined($lift)) {
	if ($lift <= $self->tm->MAX_LIFT_POS && $lift >= 0) {
	    $self->value('droid_lift_pos',$lift);
	    lpf("Set lift position to %d\n",$lift);
	}
    }
}

sub init {
    my $self = shift;

    my $cmd = sprintf("%s -l %d -d %d",
		      $self->cmd_move,
		      $self->tm->MAX_TANK_POS,
		      $self->tm->MAX_LIFT_POS);
    lpf($cmd);
    my $ret = system($cmd);
    if (!$ret) {
	$self->value('droid_tank_pos',0);
	$self->value('droid_lift_pos',0);
	$self->change_status("Waiting",undef,undef);
    }

    system("echo 0=".$self->CAMERA_CENTER_H." > /dev/servoblaster");
    system("echo 1=".$self->CAMERA_CENTER_V." > /dev/servoblaster");

    if (!$ret) {
	$self->value('droid_swing_h',0);
	$self->value('droid_swing_v',0);
    }
    
    system("echo 2=150 > /dev/servoblaster");
    $self->change_status("Waiting",undef,undef);

    return $ret;
}

sub auto_feed {
    my $self= shift;
    
    my ($cp) = $self->value('droid_tank_pos');
    my $ec = 0;
    for (0..3) {
	$ec |= $self->move($self->tm->FEED_POS->[$_]); 
	$ec |= $self->feed($self->tm->FEED_TIME->[$_]);
    }
    $ec |= $self->move($cp); 
    return $ec;
}

sub move {
    my $self= shift;

    my $tankpos = shift;
    my $liftpos = shift;

    my $exit_code = 0;
    my @mopts;
    my @movediff = (0,0);
    if (defined($tankpos)) {
	my ($d_tp) = $self->value('droid_tank_pos');
	my $diff = $tankpos - $d_tp;
	if ($diff < 0) {
	    push(@mopts,sprintf("-l %d",abs($diff)));
	} elsif ($diff > 0) {
	    push(@mopts,sprintf("-r %d",abs($diff)));
	}
	$movediff[0]=$diff;
    }

    if (defined($liftpos)) {
	my ($d_lp) = $self->value('droid_lift_pos');
	my $diff = $liftpos - $d_lp;
	if ($diff < 0) {
	    push(@mopts,sprintf("-d %d",abs($diff)));
	} elsif ($diff > 0) {
	    push(@mopts,sprintf("-u %d",abs($diff)));
	}
	$movediff[1]=$diff;
    }

    if (@mopts) {
	$self->change_status("Operating",undef,undef);
	my $cmd = sprintf("%s %s",$self->cmd_move,join(" ",@mopts));

	$self->note('droid_movediff',join(",",@movediff));

	if ($movediff[0] < 0) {
	    $self->move_fuchiko("left");
	} elsif ($movediff[0] > 0) {
            $self->move_fuchiko("right");
	}

	my ($h,$v) = split(/\s/,`$cmd`);
	my $d_tp = 0;
	my $d_lp = 0;
	if (defined($h) && defined($v)) {
	    ($d_tp) = $self->value('droid_tank_pos');
	    ($d_lp) = $self->value('droid_lift_pos');
	    $self->move_fuchiko("center");
	} else {
	    $exit_code = 1;
	}

	$self->change_status("Waiting",$d_tp+$h,$d_lp+$v);
    }
    return $exit_code;
}

sub feed {
    my $self=shift;

    my $f = shift;
    my $ec = 0;
    my $t = localtime;
    my $today = $t->strftime('%m-%d');

    if ($f > 0 && $f < 6000) {
	my ($d_tp) =  $self->value('droid_tank_pos');

	$self->open;
	my $res = $self->dbh->selectall_arrayref("SELECT SUBSTR(timestamp,6,5),count(label),label FROM log WHERE label LIKE 'feed_tank%' AND SUBSTR(timestamp,6,5) = ".$self->dbh->quote($today)." GROUP BY label");
	$self->close;
	
	my %feedcount;
	foreach (@$res) {
	    $feedcount{$_->[2]} = $_->[1];
	}
	lpf("feed %d %d %d",$d_tp,$self->tm->tank_id($d_tp),$feedcount{"feed_tank_".$self->tm->tank_id($d_tp)});
	if ($feedcount{"feed_tank_".$self->tm->tank_id($d_tp)} < 2) {
	    my $ret = 0;
	    if ($d_tp != $self->tm->feed_pos($d_tp)) {
		lpf(sprintf("Move to tank_pos %d",
			    $self->tm->feed_pos($d_tp)));
		$ret |= $self->move($self->tm->feed_pos($d_tp));
	    }
	    lpf("Pos %2d",$self->tm->feed_pos($d_tp));
	    $self->move_fuchiko("feed");
	    $ret |= system(sprintf("%s -t %d",$self->cmd_feed,$f));
	    if(!$ret) {
		lpf("feed: success.");
		$self->value('feed_tank_'.$self->tm->tank_id($d_tp),$f);
	    } else {
		lpf("feed: failed.");
		$ec = 1;
	    }
	} else {
	    lpf("feed: no more feed for this tank!");
	}		
	return $ec;
    } else {
	lpf("feed: feed time should be less than 5 secs.");
	return 1;
    }	
}

sub move_fuchiko {
    my $self = shift;

    my $direction = shift;
    if ($direction eq "left") {
	system("echo 2=240 > /dev/servoblaster");
    } elsif ($direction eq "center") {
	system("echo 2=150 > /dev/servoblaster");
    } elsif ($direction eq "right") {
	system("echo 2=60 > /dev/servoblaster");
    } elsif ($direction eq "feed") {
	system("echo 2=105 > /dev/servoblaster");
	select(undef,undef,undef,0.6);
	system("echo 2=195 > /dev/servoblaster");
	select(undef,undef,undef,0.6);
	system("echo 2=150 > /dev/servoblaster");
    }
}

sub swing_camera {
    my $self = shift;

    my ($h,$v) = @_;
    if (($h > 25 && $h < -25) || ($v > 30 && $v < -40)) { 
	lpf("swing: valid ranges: h = -25 ~ 25, v = -40 ~ 30");
	return 1;
    }
    my $h_deg = $self->CAMERA_CENTER_H + $h;
    my $v_deg = $self->CAMERA_CENTER_V + $v;
    my $ret = 0;

    my ($c_h_deg) = $self->value('droid_swing_h');
    my ($c_v_deg) = $self->value('droid_swing_v');
    my $h_diff = $h_deg - $c_h_deg;
    my $v_diff = $v_deg - $c_v_deg;
    my $h_inc = $h_diff < 0 ? "-1" : "+1";
    my $v_inc = $v_diff < 0 ? "-1" : "+1";
    while ($c_h_deg != $h_deg || $c_v_deg != $v_deg) {
	if ($c_h_deg != $h_deg) {
	    $ret |= system("echo 0=$h_inc > /dev/servoblaster");
#	    print("echo 0=$h_inc > /dev/servoblaster\n");
	    $c_h_deg = $c_h_deg + ($h_diff < 0 ? -1: 1);
	    last if ($c_h_deg > 175 || $c_h_deg < 100);		
	}
	if ($c_v_deg != $v_deg) {
	    $ret |= system("echo 1=$v_inc > /dev/servoblaster");
#	    print("echo 1=$v_inc > /dev/servoblaster\n");
	    $c_v_deg = $c_v_deg + ($v_diff < 0 ? -1: 1);
	    last if ($c_v_deg > 180 || $c_v_deg < 90);
	}
	select(undef,undef,undef,0.08);
    }

    $ret |= system("echo 0=$h_deg > /dev/servoblaster");
    $ret |= system("echo 1=$v_deg > /dev/servoblaster");

    if (!$ret) {
	lpf("swing: %d %d",$h_deg,$v_deg);
	$self->value('droid_swing_h',$h_deg);
	$self->value('droid_swing_v',$v_deg);
    }
    return $ret;
}

sub change_status {
    my $self = shift;

    my ($s,$h,$v) = @_;
    $self->note('droid_status',$s);
    if (defined($h)) {
	$self->value('droid_tank_pos',$h);
    }
    if (defined($v)) {
	$self->value('droid_lift_pos',$v);
    }

    my $cam = Aquarium::Camera->new();
    $cam->set_exposure;
}

sub change_mode {
    my $self = shift;

    my ($m) = @_;
    $self->note('droid_mode',$m);
}

# ---------------------------------------------------
1;
