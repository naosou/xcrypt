package invalidate;

use strict;
use jobsched;
use builtin;

&add_key('allotted_time');

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

my $time_init = undef;
my $time_now = undef;
my $slp = 0;
my $cycle = 5;
sub start {
    my $self = shift;
    if (defined $self->{allotted_time}) {
	Coro::async {
	    &jobsched::wait_job_running($self);
	    $time_init = time();
	    my $stat = 'running';
	    until ($stat eq 'done') {
		Coro::AnyEvent::sleep $cycle;
		$stat = &jobsched::get_job_status($self);
		$time_now = time();
		my $elapsed = $time_now - $time_init;
		if ($self->{allotted_time} < $elapsed) {
                    print "Running time of $self->{id} exeeded $elapsed sec. Invalidates it.\n";
		    $self->invalidate();
		    $stat = 'done';
		}
	    }
	} $self;
	Coro::AnyEvent::sleep $slp;
    }
    $self->NEXT::start();
}

1;
