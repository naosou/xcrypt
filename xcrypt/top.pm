package top;

use File::Copy;
use File::Spec;
use UI;
use function;
use jobsched;
use Data_Generation;

sub new {
    my $class = shift;
    my $self = shift;
    # ジョブをジョブごとに作成されるディレクトリで処理
    my $dir = $self->{id};
    unless (-e $dir) {
	mkdir $dir , 0755;
    } else {
	die "Can't make a directory $dir since $dir has already existed.  Rename the id of a job or the directory.";
    }
    my $copied;
    if ($self->{dir}) {
	$copied = File::Spec->catfile($self->{dir}, $self->{ifile});
#	$self->{input} = &Data_Generation::CF($copied, $dir);
	copy $copied, $dir;
#	system("cp -f $copied $dir");
    } else {
	if ($self->{ifile}) {
	    $copied = $self->{ifile};
#	    $self->{input} = &Data_Generation::CF($copied, $dir);
	copy $copied, $dir;
#	system("cp -f $copied $dir");

	}
    }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    my $dir = $self->{id};
    unless (-e $dir) { mkdir $dir , 0755; }

    $self->before();

    # NQS スクリプトを作成・投入
    my $nqs_script = File::Spec->catfile($dir, 'nqs.sh');
    my @args = ();
    for ( my $i = 0; $i <= 255; $i++ ) {
	my $arg = 'arg' . $i;
	push(@args, $self->{$arg});
    }
    my $cmd = $self->{exe} . ' ' . join(' ', @args);
    my $stdofile = File::Spec->catfile($dir, 'stdout');
    if ($self->{stdofile}) { $stdofile = $self->{stdofile}; }
    my $stdefile = File::Spec->catfile($dir, 'stderr');
    if ($self->{stdefile}) { $stdefile = $self->{stdefile}; }
    my $proc = 1;
    if ($self->{proc}) { $proc = $self->{proc}; }
    my $cpu = 1;
    if ($self->{cpu}) { $cpu = $self->{cpu}; }
    &jobsched::qsub($self->{id},
		    $cmd,
		    $self->{id},
		    $nqs_script,
		    $self->{queue},
		    $self->{option},
		    $stdofile,
		    $stdefile,
		    $proc,
		    $cpu);
    # 結果ファイルから結果を取得
    &jobsched::wait_job_done($self->{id});
    my @stdlist = &pickup($stdofile, ',');
    $self->{stdout} = $stdlist[0];

    $self->after();
}

sub before {
    my $self = shift;
    unless ($self->{dir}) {
#	if ($self->{ifile}) { $self->{input}->do(); }
    }
    my $exe = $self->{exe};
    my $dir = $self->{id};
#    if ( -e $exe ) { copy($exe, File::Spec->catfile($dir, $exe)); }
    if ( -e $exe ) {
	my $direxe = File::Spec->catfile($dir, $exe);
	copy($exe, $direxe);
	chmod 0755, $direxe;
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
