# Job scheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use threads;
use threads::shared;
use Cwd;
use File::Basename;
use Thread::Semaphore;

##################################################

# my $qsub_command="../kahanka/qsub";
# my $qdel_command="../kahanka/qdel";
# my $qstat_command="../kahanka/qstat";
my $qsub_command="qsub";
my $qdel_command="qdel";
my $qstat_command="qstat";

my $current_directory=Cwd::getcwd();

my $inventory_write_command="perl pjo_inventory_write.pl";
# my $inventory_write_opt="";

# pjo_inventory_watch.pl $B$O=PNO$r%P%C%U%!%j%s%0$7$J$$@_Dj(B ($|=1) 
# $B$K$7$F$*$/$3$H!J(Bfujitsu$B%*%j%8%J%k$O$=$&$J$C$F$J$$!K(B
my $inventory_watch_command="perl pjo_inventory_watch.pl";
my $inventory_watch_opt="-i summary -e end -t 86400 -s"; # -s
my $inventory_watch_path="$current_directory/inv_watch";
my $inventory_watch_thread=undef;

# $B%8%g%VL>"*>r7oJQ?t!J%;%^%U%)!K(B
my %jobthread_conds={};

##################################################
# $B%8%g%V%9%/%j%W%H$r@8@.$7!$I,MW$J(Binventory_writre$B$r9T$C$?8e!$%8%g%VEjF~(B
sub qsub {
    my ($job_name, # $B%8%g%VL>(B
        $command,  # $B<B9T$9$k%3%^%s%I$NJ8;zNs(B
        $dir,      # $B<B9T%U%!%$%kCV$->l!J%9%/%j%W%H<B9T>l=j$+$i$NAjBP%Q%9!K(B
        $scriptfile, # $B%9%/%j%W%H%U%!%$%kL>(B
        # $B0J2<$N0z?t$O(Boptional
        $stderr_file, $stdout_file, # $BI8=`!?%(%i!<=PNO$N=PNO@h!J(Bqsub$B$N%*%W%7%g%s!K(B
        # $B0J2<!$(BNQS$B$N%*%W%7%g%s(B
        $verbose, $verbose_node, $queue, $process, $cpu, $memory
        ) = @_;
    my $inventory_file = $dir/$job_name;
    my $jobspec = "\"spec: $job_name\"";
    open (SCRIPT, ">$scriptfile");
    if ($verbose == "") { print SCRIPT "# @\$-oi\n"; }
    if ($verbose_node)  { print SCRIPT "# @\$-OI\n"; }
    if ($queue)         { print SCRIPT "# @\$-q $queue\n"; }
    if ($process)       { print SCRIPT "# @\$-lP $process\n"; }
    if ($cpu)           { print SCRIPT "# @\$-lp $cpu\n"; }
    if ($memory)        { print SCRIPT "# @\$-lm $memory\n"; }
    print SCRIPT "cd \$QSUB_WORKDIR \n";
    print SCRIPT "$inventory_write_command $inventory_file \"start\" $jobspec\n";
    print SCRIPT "cd \$QSUB_WORKDIR/$dir \n";
    print SCRIPT "$command\n";
    print SCRIPT "cd \$QSUB_WORKDIR \n";
    # $B@5>o=*N;$G$J$1$l$P(B "abort" $B$r=q$-9~$`$Y$-(B
    print SCRIPT "$inventory_write_command $inventory_file \"done\" $jobspec\n";
    close (SCRIPT);
    my $stderr_option = ($stderr_file = "")?"":"-e $stderr_file";
    my $stdout_option = ($stdout_file = "")?"":"-o $stdout_file";
    system ("$inventory_write_command $inventory_file \"submit\" $jobspec");
    system ("$qsub_command $stderr_option $stdout_option $scriptfile");
}

##############################
# $B30It%W%m%0%i%`(Binventory_watch$B$r5/F0$7!$$=$NI8=`=PNO$r4F;k$9$k%9%l%C%I$r5/F0(B
sub invoke_inventory_watch {
    # $B%$%s%Y%s%H%j%U%!%$%k$NCV$->l=j%G%#%l%/%H%j$r:n@.(B
    if ( !(-d $inventory_watch_path) ) {
        mkdir $inventory_watch_path or
        die "Can't make $inventory_watch_path: $!.\n";
    }
    foreach (".tmp", ".lock") {
        if ( !(-d "$inventory_watch_path/$_") ) {
            mkdir "$inventory_watch_path/$_" or
                die "Can't make $inventory_watch_path/$_: $!.\n";
        }
    }
    # $B0J2<!$4F;k%9%l%C%I$N=hM}(B
    $inventory_watch_thread =  threads->new( sub {
        open (INVWATCH, "$inventory_watch_command $inventory_watch_path $inventory_watch_opt |");
        while (1) {
            while (<INVWATCH>){
                handle_inventory ($_);
            }
            close (INVWATCH);
            print "inventory_watch finished.\n";
            open (INVWATCH, "$inventory_watch_command $inventory_watch_path $inventory_watch_opt -c |");
        }
    });
}

# inventory_watch$B$N=PNO0l9T$r=hM}(B
my $last_jobname=undef; # $B:#=hM}Cf$N%8%g%V$NL>A0!J!a:G8e$K8+$?(B"spec: <name>"$B!K(B
sub handle_inventory {
    my ($line) = @_;
    if ($line =~ /^spec\:\s*(.+)/) {            # $B%8%g%VL>(B
        $last_jobname = $1;
    } elsif ($line =~ /^status\:\s*done/) {     # $B%8%g%V$N=*N;!J@5>o!K(B
        jobthread_signal ($last_jobname); # $B%8%g%V=*N;$rBT$C$F$$$k%9%l%C%I$r5/$3$9(B
    } elsif ($line =~ /^status\:\s*abort/) {    # $B%8%g%V$N=*N;!J@5>o0J30!K(B
        jobthread_signal ($last_jobname); # $B%8%g%V=*N;$rBT$C$F$$$k%9%l%C%I$r5/$3$9(B
    } elsif ($line =~ /^status\:\s*([a-z]*)/) { # $B=*N;0J30$N%8%g%V>uBVJQ2=(B
        # $B$H$j$"$($:2?$b$J$7(B
    } elsif (/^date\_.*\:\s*(.+)/){             # $B%8%g%V>uBVJQ2=$N;~9o(B
        # $B$H$j$"$($:2?$b$J$7(B
    } else {
        warn "unexpected inventory output: \"$line\"\n";
    }
}

##############################
# $BC/$+$,(B jobthread_signal($jobname) $B$G5/$3$7$F$/$l$k$^$G?2$k(B
sub jobthread_condwait {
    my ($jobname) = @_;
    if (!exists ($jobthread_conds{$jobname})) {
        $jobthread_conds{$jobname} = Thread::Semaphore->new(0);
    }
    $jobthread_conds{$jobname}->down;
}

# jobthread_condwait($jobname) $B$G?2$F$$$k%9%l%C%I$r5/$3$9(B
sub jobthread_signal {
    my ($jobname) = @_;
    if (!exists ($jobthread_conds{$jobname})) {
        # $B@5>o<B9T$G$b!$%?%$%_%s%0$K$h$C$F(B!exists$B$J$3$H$,$"$k$+$b(B
        # $B!J(Bbusy wait$B$GBT$F$P$h$$!)!K(B
        print STDERR "Conditional variable for $jobname thread does not exists.\n";
        exit 255;
    }
    $jobthread_conds{$jobname}->up;
}

# $B%9%l%C%I5/F0!JFI$_9~$`$@$1$G5/F0!$$O@5$7$$!)!K(B
invoke_inventory_watch ();
## $B%9%l%C%I=*N;BT$A!'%G%P%C%0!J(Bjobsched.pm$BC1BN<B9T!KMQ(B
# $inventory_watch_thread->join();

1;


## $B<+A0$G(Binventory_watch$B$r$d$m$&$H$7$?;D3<(B
#         my %timestamps = {};
#         my @updates = ();
#         foreach (glob "$inventory_watch_path/*") {
#             my $bname = fileparse($_);
#             my @filestat = stat $_;
#             my $tstamp = @filestat[9];
#             if ( !exists ($timestamps{$bname})
#                  || $timestamps{$bname} < $tstamp )
#             {
#                 push (@updates, $bname);
#                 $timestamps{$bname} = $tstamp;
#             }
#         }
