package DC;

use strict;
use NEXT;
use builtin;
use Coro;
use Coro::AnyEvent;

&add_key('ofname', 'mergeFunc','divideFunc','canDivideFunc');

sub start
{
	my $self = shift;
	
	if( &{$self->{canDivideFunc}}($self) )
	{
            my @children = &{$self->{divideFunc}}($self);
            submit_sync (@children);
            &{$self->{mergeFunc}}($self, @children);
            jobsched::set_job_submitted ($self);
            system (jobsched::inventory_write_cmdline($self,'running'));
            system (jobsched::inventory_write_cmdline($self,'done'));
	} else {
            $self->NEXT::start();
        }
}

1;
