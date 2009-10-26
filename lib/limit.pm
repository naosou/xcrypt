package limit;

#warn "Now limit.pm is obsoleted!";

use strict;
use NEXT;
use Thread::Semaphore;

#our $smph;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {
    my $self = shift;
    if (defined $user::smph) {
	$user::smph->down;
    } else {
	warn "Not given \$limit.  Not using limit.pm.\n";
    }
    $self->NEXT::before();
}

sub after {
    my $self = shift;
    $self->NEXT::after();
    if (defined $user::smph) {
	$user::smph->up;
    } else {
	warn "Not given \$limit.  Not using limit.pm.\n";
    }

}

1;