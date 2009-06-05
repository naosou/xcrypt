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
    my $id = qx/$qsub_command $scriptfile/;
    my $idfile = File::Spec->catfile($dirname, 'request_id');
    open (REQUESTID, ">> $idfile");
    print REQUESTID $id;
    close (REQUESTID);
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
    } elsif ($line =~ /^status\:\s*done/) {     # ����֤ν�λ�������
        set_job_done ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
    } elsif ($line =~ /^status\:\s*abort/) {    # ����֤ν�λ������ʳ���
        set_job_abort ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
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
# ����֤ξ��֤��ѹ�
sub set_job_done {
    my ($jobname) = @_;
    lock (%job_status);
    $job_status{$jobname} = "done";
    cond_broadcast (%job_status);
}
sub set_job_abort {
    my ($jobname) = @_;
    lock (%job_status);
    $job_status{$jobname} = "abort";
    cond_broadcast (%job_status);
}
## �ƤӽФ������ߥ󥰡ʤ��⤽��ɬ�פ��ˤ��狼��ʤ�
# sub set_job_submit  { ... }
# sub set_job_running { ... }

# �����"$jobname"�ξ��֤�done�ˤʤ�ޤ��Ԥ�
sub wait_job_done {
    my ($jobname) = @_;
    lock (%job_status);
#    while ($job_status{$jobname} != "done") {
    until ($job_status{$jobname} eq 'done') {
        cond_wait (%job_status);
    }
}

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
