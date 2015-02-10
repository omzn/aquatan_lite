package Aquarium::Camera;
use utf8;

$|=1;

use Moose;
use Aquarium::DB;

has cmd_wide => (default => '/usr/local/bin/enable_camwide', is => 'ro');
has cmd_ir   => (default => '/usr/local/bin/enable_camir', is => 'ro');
has cmd_expo => (default => '/usr/local/bin/exposure_camwide', is => 'ro');
has ssh_host => (default => '', is => 'ro');
has ssh_user => (default => '', is => 'ro');

has url      => (default => 'http://192.168.68.92:8080/?action=snapshot', is => 'ro');

sub mode {
    my $self = shift;
    if (@_) {
	my $mode = shift;
	if ($mode =~ /^(wide|ir)$/) {
	    my $ssh_cmd = "";
	    if ($self->ssh_host && $self->ssh_user) { 
		$ssh_cmd = sprintf("ssh -l %s %s",
				   $self->ssh_user,
				   $self->ssh_host);
	    }
	    system($ssh_cmd." ".$self->{"cmd_".$mode});
	    my $db = Aquarium::DB->new;
	    $db->note("droid_camera",$mode);
	} else {
	    warn "Invalid mode for camera.";
	}
    }
}

sub set_exposure {
    my $self = shift;

    my $ssh_cmd = "";
    if ($self->ssh_host && $self->ssh_user) { 
	$ssh_cmd = sprintf("ssh -l %s %s",
			   $self->ssh_user,
			   $self->ssh_host);
    }
    system($ssh_cmd." ".$self->cmd_expo);
}


1;
