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

# pjo_inventory_watch.pl は出力をバッファリングしない設定 ($|=1)
# にしておくこと（fujitsuオリジナルはそうなってない）
my $watch_command=File::Spec->catfile($ENV{'XCRYPT'}, 'pjo_inventory_watch.pl');
my $watch_opt="-i summary -e all -t 86400 -s"; # -s: signal end mode
my $watch_path=File::Spec->catfile($current_directory, 'inv_watch');
#my $watch_thread=undef;
our $watch_thread=undef;

# ジョブ名→ジョブのrequest_id
my %job_request_id : shared;
# ジョブ名→ジョブの状態
my %job_status : shared;
# ジョブ名→最後のジョブ変化時刻
my %job_last_update : shared;
# ジョブの状態→ランレベル
my %status_level = ("active"=>0, "submit"=>1, "qsub"=>2, "start"=>3, "done"=>4, "abort"=>5);
# "start"状態のジョブが登録されているハッシュ (key,value)=(req_id,jobname)
my %running_jobs : shared;
our $abort_check_thread=undef;

##################################################
# ジョブスクリプトを生成し，必要なwriteを行った後，ジョブ投入
sub qsub {
    my ($job_name, # ジョブ名
        $command,  # 実行するコマンドの文字列
        $dirname,      # 実行ファイル置き場（スクリプト実行場所からの相対パス）
        $scriptfile, # スクリプトファイル名
        # 以下の引数はoptional
	$queue,
        $option,
        $stdofile, $stdefile, # 標準／エラー出力先（qsubのオプション）
        # 以下，NQSのオプション
        $proc, $cpu, $memory, $verbose, $verbose_node,
        ) = @_;
    open (SCRIPT, ">$scriptfile");
    print SCRIPT "#!/bin/sh\n";
    # NQS も SGE も，オプション中の環境変数を展開しないので注意！
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
    print SCRIPT inventory_write_cmdline($job_name, "start") . " || exit 1\n";
    print SCRIPT "cd $ENV{'PWD'}/$dirname\n";
#    print SCRIPT "cd \$QSUB_WORKDIR/$dirname\n";
    print SCRIPT "$command\n";
    # 正常終了でなければ "abort" を書き込むべき
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
# 外部プログラムinventory_writeを起動し，
# インベントリファイルに$jobnameの状態が$statに変化したことを書き込む
sub inventory_write {
    my ($jobname, $stat) = @_;
    system (inventory_write_cmdline($jobname,$stat));
}
sub inventory_write_cmdline {
    my ($jobname, $stat) = @_;
    my $file = File::Spec->catfile($watch_path, $jobname);
    my $jobspec = "\"spec: $jobname\"";
    status_name_to_level ($stat); # 有効な名前かチェック
    return "$write_command $file \"$stat\" $jobspec";
    
}


##############################
# 外部プログラムwatchを起動し，その標準出力を監視するスレッドを起動
sub invoke_watch {
    # inventory_watchが，監視準備ができたことを通知するために設置するファイル
    my $invwatch_ok_file = "$watch_path/.tmp/.pjo_invwatch_ok";
    # インベントリファイルの置き場所ディレクトリを作成
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
    # 起動前にもしあれば消しておく
    if ( -f $invwatch_ok_file ) { unlink $invwatch_ok_file; }
    # 以下，監視スレッドの処理
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
    # inventory_watchの準備ができるまで待つ
    until ( -f $invwatch_ok_file ) { sleep 1; }
}

# watchの出力一行を処理
my $last_jobname=undef; # 今処理中のジョブの名前（＝最後に見た"spec: <name>"）
sub handle_inventory {
    my ($line) = @_;
    if ($line =~ /^spec\:\s*(.+)/) {            # ジョブ名
        $last_jobname = $1;
#     } elsif ($line =~ /^status\:\s*active/) {   # ジョブ実行予定
#         set_job_active ($last_jobname); # ジョブ状態ハッシュを更新（＆通知）
#     } elsif ($line =~ /^status\:\s*submit/) {   # ジョブ投入直前
#         set_job_submit ($last_jobname); # ジョブ状態ハッシュを更新（＆通知）
# #     } elsif ($line =~ /^status\:\s*qsub/) {     # qsub成功
# #         set_job_qsub ($last_jobname);   # ジョブ状態ハッシュを更新（＆通知）
#     } elsif ($line =~ /^status\:\s*start/) {    # プログラム開始
#         set_job_start ($last_jobname); # ジョブ状態ハッシュを更新（＆通知）
#     } elsif ($line =~ /^status\:\s*done/) {     # プログラムの終了（正常）
#         set_job_done ($last_jobname); # ジョブ状態ハッシュを更新（＆通知）
#     } elsif ($line =~ /^status\:\s*abort/) {    # ジョブの終了（正常以外）
#         set_job_abort ($last_jobname); # ジョブ状態ハッシュを更新（＆通知）
    ## ↑から変更： "time_submit: <更新時刻>"  の行を見るようにした
    ## inventory_watch は同じ更新情報を何度も出力するので，
    ## 最後の更新より古い情報は無視する
    ## 同じ時刻の更新の場合→「意図する順序」の更新なら受け入れる (ref. set_job_*)
    } elsif ($line =~ /^time_active\:\s*([0-9]*)/) {   # ジョブ実行予定
        set_job_active ($last_jobname, $1);
    } elsif ($line =~ /^time_submit\:\s*([0-9]*)/) {   # ジョブ投入直前
        set_job_submit ($last_jobname, $1);
    } elsif ($line =~ /^time_qsub\:\s*([0-9]*)/) {   # qsub成功
        set_job_qsub ($last_jobname, $1);
    } elsif ($line =~ /^time_start\:\s*([0-9]*)/) {   # プログラム開始
        set_job_start ($last_jobname, $1);
    } elsif ($line =~ /^time_done\:\s*([0-9]*)/) {   # プログラムの終了（正常） 
        set_job_done ($last_jobname, $1);
    } elsif ($line =~ /^time_abort\:\s*([0-9]*)/) {   # プログラムの終了（正常以外）
        set_job_abort ($last_jobname, $1);
    } elsif ($line =~ /^status\:\s*([a-z]*)/) { # 終了以外のジョブ状態変化
        # とりあえず何もなし
    } elsif (/^date\_.*\:\s*(.+)/){             # ジョブ状態変化の時刻
        # とりあえず何もなし
    } elsif (/^time\_.*\:\s*(.+)/){             # ジョブ状態変化の時刻
        # とりあえず何もなし
    } else {
        warn "unexpected inventory output: \"$line\"\n";
    }
}

##############################
# ジョブ名→request_id
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
    if ( $req_id_line =~ /([0-9]*)\.nqs/ ) {
        $req_id = $1;
    } else {
        die "set_job_request_id: unexpected req_id_line.\n";
    }
    # print "$jobname id <= $req_id\n";
    lock (%job_request_id);
    $job_request_id{$jobname} = $req_id;
}

##############################
# ジョブ状態名→状態レベル数
sub status_name_to_level {
    my ($name) = @_;
    if ( exists ($status_level{$name}) ) {
        return $status_level{$name};
    } else {
        die "status_name_to_runlevel: unexpected status name \"$name\"\n";
    }
}

# ジョブ名→状態
sub get_job_status {
    my ($jobname) = @_;
    if ( exists ($job_status{$jobname}) ) {
        return $job_status{$jobname};
    } else {
        return "active";
    }
}
# ジョブ名→最後の状態変化時刻
sub get_job_last_update {
    my ($jobname) = @_;
    if ( exists ($job_last_update{$jobname}) ) {
        return $job_last_update{$jobname};
    } else {
        return -1;
    }
}

# ジョブの状態を変更
sub set_job_status {
    my ($jobname, $stat, $tim) = @_;
    status_name_to_level ($stat); # 有効な名前かチェック
    print "$jobname <= $stat\n";
    {
        lock (%job_status);
        $job_status{$jobname} = $stat;
        $job_last_update{$jobname} = $tim;
        cond_broadcast (%job_status);
    }
    # startなジョブ一覧に登録／削除
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
# 更新時刻情報や状態遷移の順序をもとにsetを実行してよいかを判定
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
# $jobnameの状態が，$whoによる状態遷移の期待するもの（@e_statsのどれか）であるかをチェック
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

# ジョブ"$jobname"の状態が$stat以上になるまで待つ
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

# すべてのジョブの状態を出力（デバッグ用）
sub print_all_job_status {
    foreach my $jn (keys %job_status) {
        print "$jn:" . get_job_status ($jn) . " ";
    }
    print "\n";
}

##################################################
# "start"なジョブ一覧の更新
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

# running_jobsのジョブがabortになってないかチェック
# 状態が"start"にもかかわらず，qstatで当該ジョブが出力されないものを
# abortとみなす．
# abortと思われるものはinventory_write("abort")する
### Note:
# ジョブ終了後（done書き込みはスクリプト内なので終わっているはず．
# ただし，NFSのコンシステンシ戦略によっては危ないかも）
# linventory_watchからdone書き込みの通知がXcryptに届くまでの間に
# abort_checkが入ると，abortを書き込んでしまう．
# ただし，書き込みはdone→abortの順であり，set_job_statusもその順
# なのでおそらく問題ない．
# doneなジョブの状態はabortに変更できないようにすべき？
# →とりあえずそうしている（ref. set_job_abort）
sub check_and_write_abort {
    lock (%running_jobs);
    print "check_and_write_abort:\n";
    # foreach my $j ( keys %running_jobs ) { print " " . $running_jobs{$j} . "($j)"; }
    # print "\n";
    my %unchecked = %running_jobs;
    open (QSTATOUT, "$qstat_command |");
    while (<QSTATOUT>) {
        chomp;
        # depend on outputs of NQS's qstat
        if ( $_ =~ /([0-9]*)\.nqs/ ) {
            my $req_id = $1;
            print "$_ --- " . $unchecked{$req_id} . "\n";
            delete ($unchecked{$req_id});
        }
    }
    close (QSTATOUT);
    # "abort"をインベントリファイルに書き込み
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

# スレッド起動（読み込むだけで起動，は正しい？）
invoke_watch ();
invoke_abort_check ();
## スレッド終了待ち：デバッグ（jobsched.pm単体実行）用
# $watch_thread->join();

1;


## 自前でwatchをやろうとした残骸
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
