# Job scheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use threads;
use threads::shared;
use Cwd;
use File::Basename;
use File::Spec;
use threads::shared;
# use Thread::Semaphore;

##################################################

# my $qsub_command="../kahanka/qsub";
# my $qdel_command="../kahanka/qdel";
# my $qstat_command="../kahanka/qstat";
my $qsub_command="qsub";
my $qdel_command="qdel";
my $qstat_command="qstat";

my $current_directory=Cwd::getcwd();

my $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'pjo_inventory_write.pl');
# my $write_opt="";

# pjo_watch.pl �Ͻ��Ϥ�Хåե���󥰤��ʤ����� ($|=1)
# �ˤ��Ƥ������ȡ�fujitsu���ꥸ�ʥ�Ϥ����ʤäƤʤ���
#
my $watch_command="pjo_inventory_watch.pl";
my $watch_opt="-i summary -e end -t 86400 -s"; # -s
my $watch_path=File::Spec->catfile($current_directory, 'inv_watch');
#my $watch_thread=undef;
our $watch_thread=undef;

# �����̾������֤ξ���
my %job_status : shared;
# ����֤ξ��֢�����٥�
my %status_level = ("undef"=>0, "submit"=>1, "start"=>2, "abort"=>3, "done"=>4);

##################################################
# ����֥�����ץȤ���������ɬ�פ�write��Ԥä��塤���������
sub qsub {
    my ($job_name, # �����̾
        $command,  # �¹Ԥ��륳�ޥ�ɤ�ʸ����
        $dirname,      # �¹ԥե������֤���ʥ�����ץȼ¹Ծ�꤫������Хѥ���
        $scriptfile, # ������ץȥե�����̾
        # �ʲ��ΰ�����optional
	$queue,
        $option,
        $stdofile, $stdefile, # ɸ�ࡿ���顼�������qsub�Υ��ץ�����
        # �ʲ���NQS�Υ��ץ����
        $proc, $cpu, $memory, $verbose, $verbose_node,
        ) = @_;
    my $file = File::Spec->catfile($watch_path, $dirname);
    my $jobspec = "\"spec: $job_name\"";
    open (SCRIPT, ">$scriptfile");
    print SCRIPT "#!/bin/sh\n";
    # NQS �� SGE �⡤���ץ������δĶ��ѿ���Ÿ�����ʤ��Τ���ա�
    print SCRIPT "#\$ -S /bin/sh\n";
    if ($queue) {
	print SCRIPT "# @\$-q $queue\n";
    }
    print SCRIPT "$option\n";
    if ($stdofile) {
	print SCRIPT "#\$ -o $ENV{'PWD'}/$stdofile\n";
	print SCRIPT "# @\$-o $ENV{'PWD'}/$stdofile\n";
    }
    if ($stdefile) {
	print SCRIPT "#\$ -e $ENV{'PWD'}/$stdefile\n";
	print SCRIPT "# @\$-e $ENV{'PWD'}/$stdefile\n";
    }
    if ($proc) {
	print SCRIPT "# @\$-lP $proc\n";
    }
    if ($cpu) {
	print SCRIPT "# @\$-lp $cpu\n";
    }
    if ($memory) {
	print SCRIPT "# @\$-lm $memory\n";
    }
    if ($verbose) {
	print SCRIPT "# @\$-oi\n";
    }
    if ($verbose_node) {
	print SCRIPT "# @\$-OI\n";
    }

#    print SCRIPT "PATH=$ENV{'PATH'}\n";
#    print SCRIPT "set -x\n";
    print SCRIPT "$write_command $file \"start\" $jobspec\n";
    print SCRIPT "cd $ENV{'PWD'}/$dirname\n";
#    print SCRIPT "cd \$QSUB_WORKDIR/$dirname\n";
    print SCRIPT "$command\n";
    # ���ｪλ�Ǥʤ���� "abort" ��񤭹���٤�
    print SCRIPT "$write_command $file \"done\" $jobspec\n";
    close (SCRIPT);
    system ("$write_command $file \"submit\" $jobspec");
    my $existence = qx/which $qsub_command \> \/dev\/null; echo \$\?/;
    if ($existence == 0) {
	my $id = qx/$qsub_command $scriptfile/;
	my $idfile = File::Spec->catfile($dirname, 'request_id');
	open (REQUESTID, ">> $idfile");
	print REQUESTID $id;
	close (REQUESTID);
	return $id;
    } else {
	die "qsub not found\n";
    }
}

##############################
# �����ץ����watch��ư��������ɸ����Ϥ�ƻ뤹�륹��åɤ�ư
sub invoke_watch {
    # ����٥�ȥ�ե�������֤����ǥ��쥯�ȥ�����
    if ( !(-d $watch_path) ) {
        mkdir $watch_path or
        die "Can't make $watch_path: $!.\n";
    }
    foreach (".tmp", ".lock") {
        if ( !(-d "$watch_path/$_") ) {
            mkdir "$watch_path/$_" or
                die "Can't make $watch_path/$_: $!.\n";
        }
    }
    # �ʲ����ƻ륹��åɤν���
    $watch_thread =  threads->new( sub {
        open (INVWATCH, "$watch_command $watch_path $watch_opt |");
        while (1) {
            while (<INVWATCH>){
                handle_inventory ($_);
            }
            close (INVWATCH);
            print "watch finished.\n";
            open (INVWATCH, "$watch_command $watch_path $watch_opt -c |");
        }
    });
}

# watch�ν��ϰ�Ԥ����
my $last_jobname=undef; # ��������Υ���֤�̾���ʡ�Ǹ�˸���"spec: <name>"��
sub handle_inventory {
    my ($line) = @_;
    if ($line =~ /^spec\:\s*(.+)/) {            # �����̾
        $last_jobname = $1;
    } elsif ($line =~ /^status\:\s*submit/) {   # ����֤ν�λ������ʳ���
        set_job_submit ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
    } elsif ($line =~ /^status\:\s*start/) {    # ����֤ν�λ������ʳ���
        set_job_start ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
    } elsif ($line =~ /^status\:\s*abort/) {    # ����֤ν�λ������ʳ���
        set_job_abort ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
    } elsif ($line =~ /^status\:\s*done/) {     # ����֤ν�λ�������
        set_job_done ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
    } elsif ($line =~ /^status\:\s*([a-z]*)/) { # ��λ�ʳ��Υ���־����Ѳ�
        # �Ȥꤢ��������ʤ�
    } elsif (/^date\_.*\:\s*(.+)/){             # ����־����Ѳ��λ���
        # �Ȥꤢ��������ʤ�
    } elsif (/^time\_.*\:\s*(.+)/){             # ����־����Ѳ��λ���
        # �Ȥꤢ��������ʤ�
    } else {
        warn "unexpected inventory output: \"$line\"\n";
    }
}

##############################
# ����־���̾�����֥�٥��
sub status_name_to_level {
    my ($name) = @_;
    if ( exists ($status_level{$name}) ) {
        return $status_level{$name};
    } else {
        die "status_name_to_runlevel: unexpected status name \"$name\"\n";
    }
}

# ����֢�����
sub get_job_status {
    my ($jobname) = @_;
    if ( exists ($job_status{$jobname}) ) {
        return $job_status{$jobname};
    } else {
        return "undef";
    }
}

# ����֤ξ��֤��ѹ�
sub set_job_status {
    my ($jobname, $stat) = @_;
    status_name_to_level ($stat); # ͭ����̾���������å�
    print "$jobname: $stat\n";
    lock (%job_status);
    $job_status{$jobname} = $stat;
    cond_broadcast (%job_status);
}
sub set_job_undef  { set_job_status ($_[0], "undef"); }
sub set_job_submit { set_job_status ($_[0], "submit"); }
sub set_job_start  { set_job_status ($_[0], "start"); }
sub set_job_abort  { set_job_status ($_[0], "abort"); }
sub set_job_done   { set_job_status ($_[0], "done"); }

# �����"$jobname"�ξ��֤�$stat�ʾ�ˤʤ�ޤ��Ԥ�
sub wait_job_status {
    my ($jobname, $stat) = @_;
    my $stat_lv = status_name_to_level ($stat);
    # print "wait for status of $jobname changed to $stat($stat_lv)\n";
    lock (%job_status);
    until ( &status_name_to_level (&get_job_status ($jobname))
            >= $stat_lv) {
        cond_wait (%job_status);
    }
    # print "wait: $stat($stat_lv)...done\n";
}
sub wait_job_undef  { wait_job_status ($_[0], "undef"); }
sub wait_job_submit { wait_job_status ($_[0], "submit"); }
sub wait_job_start  { wait_job_status ($_[0], "start"); }
sub wait_job_abort  { wait_job_status ($_[0], "abort"); }
sub wait_job_done   { wait_job_status ($_[0], "done"); }

# ����åɵ�ư���ɤ߹�������ǵ�ư��������������
invoke_watch ();
## ����åɽ�λ�Ԥ����ǥХå���jobsched.pmñ�μ¹ԡ���
# $watch_thread->join();

1;


## ������watch�����Ȥ����ĳ�
#         my %timestamps = {};
#         my @updates = ();
#         foreach (glob "$watch_path/*") {
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
