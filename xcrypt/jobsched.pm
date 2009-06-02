# Job scheduler I/F  (written by Tasuku HIRAISHI)
# ���: 23 ���ܤ˥ե�ѥ���ľ�ܵ��Ҥ��Ƥ��롥���Τ���ľ����
package jobsched;

use threads;
use threads::shared;
use Cwd;
use File::Basename;
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

my $write_command="\$XCRYPT/pjo_inventory_write.pl";
# my $write_opt="";

# pjo_watch.pl �Ͻ��Ϥ�Хåե���󥰤��ʤ����� ($|=1)
# �ˤ��Ƥ������ȡ�fujitsu���ꥸ�ʥ�Ϥ����ʤäƤʤ���
#
my $watch_command="pjo_inventory_watch.pl";
my $watch_opt="-i summary -e end -t 86400 -s"; # -s
my $watch_path="$current_directory/inv_watch";
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
        $stdout_file, $stderr_file, # ɸ�ࡿ���顼�������qsub�Υ��ץ�����
        # �ʲ���NQS�Υ��ץ����
        $verbose, $verbose_node, $process, $cpu, $memory
        ) = @_;
    my $file = $watch_path . '/' . $dirname;
    my $jobspec = "\"spec: $job_name\"";
    open (SCRIPT, ">$scriptfile");
    print SCRIPT "$option\n";
#    if ($verbose eq '') { print SCRIPT "# @\$-oi\n"; }
    if ($verbose_node)  { print SCRIPT "# @\$-OI\n"; }
    if ($queue)         { print SCRIPT "# @\$-q $queue\n"; }
    if ($process)       { print SCRIPT "# @\$-lP $process\n"; }
    if ($cpu)           { print SCRIPT "# @\$-lp $cpu\n"; }
    if ($memory)        { print SCRIPT "# @\$-lm $memory\n"; }
    if ($stdout_file)   { print SCRIPT "# @\$-o $stdout_file\n"; }
    if ($stderr_file)   { print SCRIPT "# @\$-e $stderr_file\n"; }
    print SCRIPT "set -x\n";
    print SCRIPT "XCRYPT=$ENV{'XCRYPT'}\n";
    print SCRIPT "cd \$QSUB_WORKDIR\n";
    print SCRIPT "$write_command $file \"start\" $jobspec\n";
    print SCRIPT "cd \$QSUB_WORKDIR/$dirname\n";
    print SCRIPT "$command\n";
    print SCRIPT "cd \$QSUB_WORKDIR\n";
    # ���ｪλ�Ǥʤ���� "abort" ��񤭹���٤�
    print SCRIPT "$write_command $file \"done\" $jobspec\n";
    close (SCRIPT);
#    my $stderr_option = ($stderr_file = "")?"":"-e $stderr_file";
#    my $stdout_option = ($stdout_file = "")?"":"-o $stdout_file";
    system ("$write_command $file \"submit\" $jobspec");
#    system ("$qsub_command $stderr_option $stdout_option $scriptfile");
    my $hoge = qx/$qsub_command $scriptfile/;
#    system ("$qsub_command $scriptfile");
    my $hogefile = $dirname . "/request_id";
    open (HOGE, ">> $hogefile");
    print HOGE $hoge;
    close (HOGE);
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
