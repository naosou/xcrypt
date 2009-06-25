package top;

use Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use UI;
use function;
use jobsched;
use Data_Generation;

my $MAX = 255;

sub new {
    my $class = shift;
    my $self = shift;
    # ジョブをジョブごとに作成されるディレクトリで処理
    my $dir = $self->{id};
    my $dotdir = '.' . $dir;
    unless (-e $dotdir) { mkdir $dotdir , 0755; }
    else { die "Can't make $dotdir since it has already existed."; }

    for ( my $i = 0; $i < $MAX; $i++ ) {
	if ($self->{"copieddir$i"}) {
	    my $copied = $self->{"copieddir$i"};
	    opendir(DIR, $copied);
	    my @params = grep { !m/^(\.|\.\.)/g } readdir(DIR);
	    closedir(DIR);
	    foreach (@params) {
		my $tmp = File::Spec->catfile($copied, $_);
		my $temp = File::Spec->catfile($dotdir, $_);
		rcopy $tmp, $temp;
	    }
	}
	if ($self->{"linkedfile$i"}) {
	    my $hoge = File::Spec->catfile($dotdir, $self->{"linkedfile$i"});
	    my $nya = File::Spec->catfile('..', $self->{"linkedfile$i"});
	    symlink $nya , $hoge;
	}
	if ($self->{"copiedfile$i"}) {
#	    $self->{"input$i"} = &Data_Generation::CF($self->{"copiedfile$i"}, $dotdir);
	    fcopy $self->{"copiedfile$i"}, $dotdir;
	}
    }
    unless (-e $dir) { rename $dotdir, $dir; }
    else { die "Can't make $dir since it has already existed."; }

    return bless $self, $class;
}

sub start {
    my $self = shift;

    my $dir = $self->{id};

    $self->before();

    # NQS スクリプトを作成・投入
    my $nqs_script = File::Spec->catfile($dir, 'nqs.sh');
    my @args = ();
    for ( my $i = 0; $i <= 255; $i++ ) { push(@args, $self->{"arg$i"}); }
    my $cmd = $self->{exe} . ' ' . join(' ', @args);
    my $proc = 1;
    my $cpu = 1;
    if ($self->{proc}) { $proc = $self->{proc}; }
    if ($self->{cpu}) { $cpu = $self->{cpu}; }
    $self->{request_id} = &jobsched::qsub($self->{id},
					  $cmd,
					  $self->{id},
					  $nqs_script,
					  $self->{queue},
					  $self->{option},
					  $self->{stdofile},
					  $self->{stdefile},
					  $proc,
					  $cpu);
    jobsched::set_job_request_id ($self->{id}, $self->{request_id});
#    print $self->{id} . " is submitted.\n";

    # 結果ファイルから結果を取得
    &jobsched::wait_job_done($self->{id});
#    print $self->{id} . " is done.\n";
    until (-e $stdofile) { sleep 2; }
    my @stdlist = &pickup($stdofile, ',');
    $self->{stdout} = $stdlist[0];

    $self->after();
}

sub before {
    my $self = shift;

    for ( my $i = 0; $i < $MAX; $i++ ) {
#	if ($self->{"copiedfile$i"}) { $self->{"input$i"}->do(); }
    }
}

sub after {
    my $self = shift;
    my $dir = $self->{id};
    unless ($self->{ofile}) {}
    else {
	my $outputfile = File::Spec->catfile($dir, $self->{ofile});
	my @list = &pickup($outputfile, $self->{odlmtr});
	$self->{output} = $list[$self->{oclmn}];
	unshift (@{$self->{trace}} , $list[$self->{oclmn}]);
    }
    # exit_cond により生成されるジョブの結果もディレクトリ以下に保存
    my $tracelog_filename = 'trace.log';
    my $tracelog = File::Spec->catfile($dir, $tracelog_filename);
    open ( EXITOUTPUT , ">> $tracelog" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
}

1;
