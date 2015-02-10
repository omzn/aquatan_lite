package Aquarium::DB;
use Moose;
use utf8;
use Time::Piece;
use DBI;
use Aquarium::Common qw(:all);

$|=1;

has db_name => (default => "aqualog", is => 'ro');
has db_host => (default => "192.168.68.15", is => 'ro');
has db_user => (default => "aquatan", is => 'ro');
has db_pass => (default => "akahire", is => 'ro');
has dbh     => (is => 'ro', default => undef);

sub BUILD {
    my $self = shift;
}

sub open {
    my $self = shift;

    eval {
	$self->{dbh} = DBI->connect("dbi:mysql:".$self->db_name.":".$self->db_host,
				$self->db_user, $self->db_pass,
				{
				    mysql_enable_utf8 => 1,
				    on_connect_do => ['SET NAMES utf8'],
				});
    };
    if ($@) {
	lpf("mysql:".$self->db_name.":".$self->db_host." is gone.");
    }
    return $self->dbh;
}

sub close {
    my $self = shift;
    eval {	
	$self->dbh->disconnect;
    };
    if ($@) {
    }
    $self->{dbh} = undef;
}

before qw(value note set_values set_notes) => sub {
    my $self = shift;
    if (!defined($self->{dbh})) {
	$self->open;
    }
};

after qw(value note set_values set_notes) => sub {
    my $self = shift;
    $self->close;
};

sub value {
    my $self = shift;
    my $label = shift;
    if (@_) {
	my $value = shift;
	if ($self->dbh) {
	    my $sth = $self->dbh->prepare("INSERT INTO log VALUES(null,?,?,?,null)");
	    $sth->execute($self->timestamp,$label,$value);
	} 
    } else {
	if ($self->dbh) {
	    my $res = $self->dbh->selectall_arrayref("SELECT timestamp,value FROM log WHERE label=".$self->dbh->quote($label)." ORDER BY timestamp DESC LIMIT 1");
	    return ($res->[0]->[1],$res->[0]->[0]);
	}
    }
}

sub set_values {
    my $self = shift;
    my $values = shift;
    my $ts = shift;
    if ($self->dbh) {
	if (%$values) {
	    my $sth = $self->dbh->prepare("INSERT INTO log VALUES(null,?,?,?,null)");
	    foreach (keys(%$values)) {	    
		$sth->execute(defined($ts)?$ts:$self->timestamp,$_,$values->{$_});
	    }
	}
    }
}

sub note {
    my $self = shift;
    my $label = shift;
    if (@_) {
	my $value = shift;
	if ($self->dbh) {
	    my $sth = $self->dbh->prepare("INSERT INTO log VALUES(null,?,?,null,?)");
	    $sth->execute($self->timestamp,$label,$value);
	}
    } else {
	if ($self->dbh) {
	    my $res = $self->dbh->selectall_arrayref("SELECT timestamp,note FROM log WHERE label=".$self->dbh->quote($label)." ORDER BY timestamp DESC LIMIT 1");
	    return ($res->[0]->[1],$res->[0]->[0]);
	}
    }
}

sub set_notes {
    my $self = shift;
    my $notes = shift;
    my $ts = shift;
    if ($self->dbh) {
	if (%$notes) {
	    my $sth = $self->dbh->prepare("INSERT INTO log VALUES(null,?,?,null,?)");
	    foreach (keys(%$notes)) {	    
		$sth->execute($self->timestamp,$_,$notes->{$_});
	    }
	}
    }
}

#sub timestamp {
#    my $t = localtime;
#    return $t->strftime('%Y-%m-%d %H:%M:%S');
#}


1;
