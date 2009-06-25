# Job scheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use strict;
use threads;
use threads::shared;
use Cwd;
use File::Basename;
use File::Spec;
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

# pjo_inventory_watch.pl �Ͻ��Ϥ�Хåե���󥰤��ʤ����� ($|=1)
# �ˤ��Ƥ������ȡ�fujitsu���ꥸ�ʥ�Ϥ����ʤäƤʤ���
my $watch_command=File::Spec->catfile($ENV{'XCRYPT'}, 'pjo_inventory_watch.pl');
my $watch_opt="-i summary -e all -t 86400 -s"; # -s: signal end mode
my $watch_path=File::Spec->catfile($current_directory, 'inv_watch');
#my $watch_thread=undef;
our $watch_thread=undef;

# �����̾������֤�request_id
my %job_request_id : shared;
# �����̾������֤ξ���
my %job_status : shared;
# �����̾���Ǹ�Υ�����Ѳ�����
my %job_last_update : shared;
# ����֤ξ��֢�����٥�
my %status_level = ("active"=>0, "submit"=>1, "qsub"=>2, "start"=>3, "done"=>4, "abort"=>5);
# "start"���֤Υ���֤���Ͽ����Ƥ���ϥå��� (key,value)=(req_id,jobname)
my %running_jobs : shared;
our $abort_check_thread=undef;

##################################################
# ����֥�����ץȤ���������ɬ�פ�write��Ԥä��塤���������
sub qsub {
    my $self = shift;

=comment
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
=cut

    my $job_name = $self->{id};
    my $dir = $self->{id};
    my $dirname = $self->{id};
    my $scriptfile = File::Spec->catfile($dir, 'nqs.sh');

    open (SCRIPT, ">$scriptfile");
    print SCRIPT "#!/bin/sh\n";
    # NQS �� SGE �⡤���ץ������δĶ��ѿ���Ÿ�����ʤ��Τ���ա�
    print SCRIPT "#\$ -S /bin/sh\n";
    my $queue = $self->{queue};
    print SCRIPT "# @\$-q $queue\n";
    my $option = $self->{option};
    print SCRIPT "$option\n";

    my $stdofile;
    if ($self->{stdofile}) {
	$stdofile = File::Spec->catfile($dir, $self->{stdofile});
    } else {
	$stdofile = File::Spec->catfile($dir, 'stdout');
    }
    print SCRIPT "#\$ -o $ENV{'PWD'}/$stdofile\n";
    print SCRIPT "# @\$-o $ENV{'PWD'}/$stdofile\n";
    my $stdefile;
    if ($self->{stdefile}) {
	$stdefile = File::Spec->catfile($dir, $self->{stdefile});
    } else {
	$stdefile = File::Spec->catfile($dir, 'stderr');
    }
    print SCRIPT "#\$ -e $ENV{'PWD'}/$stdefile\n";
    print SCRIPT "# @\$-e $ENV{'PWD'}/$stdefile\n";

    my $proc = $self->{proc};
    unless ($proc eq '') {
	print SCRIPT "# @\$-lP $proc\n";
    }
    my $cpu = $self->{cpu};
    unless ($cpu eq '') {
	print SCRIPT "# @\$-lp $cpu\n";
    }
    my $memory = $self->{memory};
    unless ($memory eq '') {
	print SCRIPT "# @\$-lm $memory\n";
    }
    my $verbose = $self->{verbose};
    unless ($verbose eq '') {
	print SCRIPT "# @\$-oi\n";
    }
    my $verbose_node = $self->{verbose_node};
    unless ($verbose_node eq '') {
	print SCRIPT "# @\$-OI\n";
    }

#    print SCRIPT "PATH=$ENV{'PATH'}\n";
#    print SCRIPT "set -x\n";
    print SCRIPT inventory_write_cmdline($job_name, "start") . " || exit 1\n";
    print SCRIPT "cd $ENV{'PWD'}/$dirname\n";
#    print SCRIPT "cd \$QSUB_WORKDIR/$dirname\n";

#    print SCRIPT "$command\n";
    my @args = ();
    for ( my $i = 0; $i <= 255; $i++ ) { push(@args, $self->{"arg$i"}); }
    my $cmd = $self->{exe} . ' ' . join(' ', @args);
    print SCRIPT "$cmd\n";
    # ���ｪλ�Ǥʤ���� "abort" ��񤭹���٤�
    print SCRIPT inventory_write_cmdline($job_name, "done") . " || exit 1\n";
    close (SCRIPT);
    inventory_write ($job_name, "submit");
    my $existence = qx/which $qsub_command \> \/dev\/null; echo \$\?/;
    if ($existence == 0) {
	my $id = qx/$qsub_command $scriptfile/;
	my $idfile = File::Spec->catfile($dirname, 'request_id');
	open (REQUESTID, ">> $idfile");
	print REQUESTID $id;
	close (REQUESTID);
        inventory_write ($job_name, "qsub");
	return $id;
    } else {
	die "qsub not found\n";
    }
}

##############################
# �����ץ����inventory_write��ư����
# ����٥�ȥ�ե������$jobname�ξ��֤�$stat���Ѳ��������Ȥ�񤭹���
sub inventory_write {
    my ($jobname, $stat) = @_;
    system (inventory_write_cmdline($jobname,$stat));
}
sub inventory_write_cmdline {
    my ($jobname, $stat) = @_;
    my $file = File::Spec->catfile($watch_path, $jobname);
    my $jobspec = "\"spec: $jobname\"";
    status_name_to_level ($stat); # ͭ����̾���������å�
    return "$write_command $file \"$stat\" $jobspec";
    
}


##############################
# �����ץ����watch��ư��������ɸ����Ϥ�ƻ뤹�륹��åɤ�ư
sub invoke_watch {
    # inventory_watch�����ƻ�������Ǥ������Ȥ����Τ��뤿������֤���ե�����
    my $invwatch_ok_file = "$watch_path/.tmp/.pjo_invwatch_ok";
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
    # ��ư���ˤ⤷����оä��Ƥ���
    if ( -f $invwatch_ok_file ) { unlink $invwatch_ok_file; }
    # �ʲ����ƻ륹��åɤν���
    $watch_thread =  threads->new( sub {
        # open (INVWATCH_LOG, ">", "$watch_path/log");
        open (INVWATCH, "$watch_command $watch_path $watch_opt |")
            or die "Failed to execute inventory_watch.";
        while (1) {
            while (<INVWATCH>){
                # print INVWATCH_LOG "$_";
                handle_inventory ($_);
            }
            close (INVWATCH);
            # print "watch finished.\n";
            open (INVWATCH, "$watch_command $watch_path $watch_opt -c |");
        }
        # close (INVWATCH_LOG);
    });
    # inventory_watch�ν������Ǥ���ޤ��Ԥ�
    until ( -f $invwatch_ok_file ) { sleep 1; }
}

# watch�ν��ϰ�Ԥ����
my $last_jobname=undef; # ��������Υ���֤�̾���ʡ�Ǹ�˸���"spec: <name>"��
sub handle_inventory {
    my ($line) = @_;
    if ($line =~ /^spec\:\s*(.+)/) {            # �����̾
        $last_jobname = $1;
#     } elsif ($line =~ /^status\:\s*active/) {   # ����ּ¹�ͽ��
#         set_job_active ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
#     } elsif ($line =~ /^status\:\s*submit/) {   # ���������ľ��
#         set_job_submit ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
# #     } elsif ($line =~ /^status\:\s*qsub/) {     # qsub����
# #         set_job_qsub ($last_jobname);   # ����־��֥ϥå���򹹿��ʡ����Ρ�
#     } elsif ($line =~ /^status\:\s*start/) {    # �ץ���೫��
#         set_job_start ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
#     } elsif ($line =~ /^status\:\s*done/) {     # �ץ����ν�λ�������
#         set_job_done ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
#     } elsif ($line =~ /^status\:\s*abort/) {    # ����֤ν�λ������ʳ���
#         set_job_abort ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
    ## �������ѹ��� "time_submit: <��������>"  �ιԤ򸫤�褦�ˤ���
    ## inventory_watch ��Ʊ������������٤���Ϥ���Τǡ�
    ## �Ǹ�ι������Ť������̵�뤹��
    ## Ʊ������ι����ξ�碪�ְտޤ������פι����ʤ��������� (ref. set_job_*)
    } elsif ($line =~ /^time_active\:\s*([0-9]*)/) {   # ����ּ¹�ͽ��
        set_job_active ($last_jobname, $1);
    } elsif ($line =~ /^time_submit\:\s*([0-9]*)/) {   # ���������ľ��
        set_job_submit ($last_jobname, $1);
    } elsif ($line =~ /^time_qsub\:\s*([0-9]*)/) {   # qsub����
        set_job_qsub ($last_jobname, $1);
    } elsif ($line =~ /^time_start\:\s*([0-9]*)/) {   # �ץ���೫��
        set_job_start ($last_jobname, $1);
    } elsif ($line =~ /^time_done\:\s*([0-9]*)/) {   # �ץ����ν�λ������� 
        set_job_done ($last_jobname, $1);
    } elsif ($line =~ /^time_abort\:\s*([0-9]*)/) {   # �ץ����ν�λ������ʳ���
        set_job_abort ($last_jobname, $1);
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
# �����̾��request_id
sub get_job_request_id {
    my ($jobname) = @_;
    if ( exists ($job_request_id{$jobname}) ) {
        return $job_request_id{$jobname};
    } else {
        return "active";
    }
}
sub set_job_request_id {
    my ($jobname, $req_id_line) = @_;
    my $req_id;
    # depend on outputs of NQS's qsub
#    if ( $req_id_line =~ /([0-9]*)\.nqs/ ) {
#        $req_id = $1;
#    } else {
#        die "set_job_request_id: unexpected req_id_line.\n";
#    }

    # SGE�Ǥ�ư���褦�ˤ����Ĥ��
    my @list = split(/ /, $req_id_line);
    my $req_id;
    foreach (@list) {
	if ($_ =~ /^([0-9]+)/) {
	    $req_id = $1;
	}
    }
    print "$jobname id <= $req_id\n";
    lock (%job_request_id);
    $job_request_id{$jobname} = $req_id;
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

# �����̾������
sub get_job_status {
    my ($jobname) = @_;
    if ( exists ($job_status{$jobname}) ) {
        return $job_status{$jobname};
    } else {
        return "active";
    }
}
# �����̾���Ǹ�ξ����Ѳ�����
sub get_job_last_update {
    my ($jobname) = @_;
    if ( exists ($job_last_update{$jobname}) ) {
        return $job_last_update{$jobname};
    } else {
        return -1;
    }
}

# ����֤ξ��֤��ѹ�
sub set_job_status {
    my ($jobname, $stat, $tim) = @_;
    status_name_to_level ($stat); # ͭ����̾���������å�
    print "$jobname <= $stat\n";
    {
        lock (%job_status);
        $job_status{$jobname} = $stat;
        $job_last_update{$jobname} = $tim;
        cond_broadcast (%job_status);
    }
    # start�ʥ���ְ�������Ͽ�����
    if ( $stat eq "start" ) {
        entry_running_job ($jobname);
    } else {
        delete_running_job ($jobname);
    }
}
sub set_job_active  {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "active", "done", "abort") ) {
        set_job_status ($jobname, "active", $tim);
    }
}
sub set_job_submit {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "submit", "active", "done", "abort") ) {
        set_job_status ($jobname, "submit", $tim);
    }
}
# sub set_job_qsub {
#     expect_job_stat ("qsub", $_[0], "submit");
#     set_job_status ($_[0], "submit");
# }
sub set_job_start  {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "start", "submit" ) ) {
        set_job_status ($jobname, "start", $tim);
    }
}
sub set_job_done   {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "done", "start" ) ) {
        set_job_status ($jobname, "done", $tim);
    }
}
sub set_job_abort  {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "abort", "submit", "start" )
         && get_job_status ($jobname) ne "done" ) {
        set_job_status ($jobname, "abort", $tim);
    }
}
# ������������������ܤν�����Ȥ�set��¹Ԥ��Ƥ褤����Ƚ��
sub do_set_p {
  my ($jobname, $tim, $stat, @e_stats) = @_;
  my $who = "set_job_$stat";
  my $last_update = get_job_last_update ($jobname);
  # print "$jobname: cur=$tim, last=$last_update\n";
  if ( $tim > $last_update ) {
      expect_job_stat ($who, $jobname, 1, @e_stats);
      return 1;
  } elsif ( $tim == $last_update ) {
      if ( $stat eq get_job_status($jobname) ) {
          return 0;
      } else {
          return expect_job_stat ($who, $jobname, 0, @e_stats);
      }
  } else {
      return 0;
  }
}
# $jobname�ξ��֤���$who�ˤ��������ܤδ��Ԥ����Ρ�@e_stats�Τɤ줫�ˤǤ��뤫������å�
sub expect_job_stat {
    my ($who, $jobname, $do_warn, @e_stats) = @_;
    my $stat = get_job_status($jobname);
    foreach my $es (@e_stats) {
        if ( $stat eq $es ) {
            return 1;
        }
    }
    if ( $do_warn ) {
        print "$who expects $jobname is (or @e_stats), but $stat.\n";
    }
    return 0;
}

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
}
sub wait_job_active { wait_job_status ($_[0], "active"); }
sub wait_job_submit { wait_job_status ($_[0], "submit"); }
# sub wait_job_qsub   { wait_job_status ($_[0], "qsub"); }
sub wait_job_start  { wait_job_status ($_[0], "start"); }
sub wait_job_done   { wait_job_status ($_[0], "done"); }
sub wait_job_abort  { wait_job_status ($_[0], "abort"); }

# ���٤ƤΥ���֤ξ��֤���ϡʥǥХå��ѡ�
sub print_all_job_status {
    foreach my $jn (keys %job_status) {
        print "$jn:" . get_job_status ($jn) . " ";
    }
    print "\n";
}

##################################################
# "start"�ʥ���ְ����ι���
sub entry_running_job {
    my ($jobname) = @_;
    lock (%running_jobs);
    $running_jobs{get_job_request_id ($jobname)} = $jobname;
    # print "entry_running_job: " . (keys %running_jobs) . "\n";
}
sub delete_running_job {
    my ($jobname) = @_;
    lock (%running_jobs);
    delete ($running_jobs{get_job_request_id ($jobname)});
}

# running_jobs�Υ���֤�abort�ˤʤäƤʤ��������å�
# ���֤�"start"�ˤ⤫����餺��qstat����������֤����Ϥ���ʤ���Τ�
# abort�Ȥߤʤ���
# abort�Ȼפ����Τ�inventory_write("abort")����
### Note:
# ����ֽ�λ���done�񤭹��ߤϥ�����ץ���ʤΤǽ���äƤ���Ϥ���
# ��������NFS�Υ��󥷥��ƥ���ά�ˤ�äƤϴ�ʤ������
# linventory_watch����done�񤭹��ߤ����Τ�Xcrypt���Ϥ��ޤǤδ֤�
# abort_check������ȡ�abort��񤭹���Ǥ��ޤ���
# ���������񤭹��ߤ�done��abort�ν�Ǥ��ꡤset_job_status�⤽�ν�
# �ʤΤǤ����餯����ʤ���
# done�ʥ���֤ξ��֤�abort���ѹ��Ǥ��ʤ��褦�ˤ��٤���
# ���Ȥꤢ�����������Ƥ����ref. set_job_abort��
sub check_and_write_abort {
    lock (%running_jobs);
    print "check_and_write_abort:\n";
    # foreach my $j ( keys %running_jobs ) { print " " . $running_jobs{$j} . "($j)"; }
    # print "\n";
    my %unchecked = %running_jobs;
    open (QSTATOUT, "$qstat_command |");
    while (<QSTATOUT>) {
        chomp;
        # # depend on outputs of NQS's qstat
        # if ( $_ =~ /([0-9]*)\.nqs/ ) {
        #   my $req_id = $1;
        #   delete ($unchecked{$req_id});
        # }

        # SGE�Ǥ�ư���褦�ˤ����Ĥ��
        my @list = split(/ /, $_);
        my $req_id;
        foreach (@list) {
            if ($_ =~ /^([0-9]+)/) {
                $req_id = $1;
                print "$_ --- " . $unchecked{$req_id} . "\n";
                delete ($unchecked{$req_id});
            }
        }
    }
    close (QSTATOUT);
    # "abort"�򥤥�٥�ȥ�ե�����˽񤭹���
    foreach my $req_id ( keys %unchecked ){
        inventory_write ($unchecked{$req_id}, "abort");
    }
}
sub invoke_abort_check {
    $abort_check_thread = threads->new( sub {
        while (1) {
            sleep 10;
            check_and_write_abort();
            # print_all_job_status();
        }
    });
}

# ����åɵ�ư���ɤ߹�������ǵ�ư��������������
invoke_watch ();
invoke_abort_check ();
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
