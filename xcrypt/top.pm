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
    # ����֤򥸥�֤��Ȥ˺��������ǥ��쥯�ȥ�ǽ���
    my $dir = $self->{id};
    my $dotdir = '.' . $dir;
    unless (-e $dotdir) { mkdir $dotdir , 0755; }
    else { die "Can't make $dotdir or $dir since they have already existed."; }

    my $hoge;
    for ( my $i = 0; $i < $MAX; $i++ ) {
	my $copied;
	if ($self->{"envdir$i"}) {
	    $copied = $self->{"envdir$i"};
	    opendir(DIR, $copied);
	    my @params = grep { !m/^(\.|\.\.)/g } readdir(DIR);
	    closedir(DIR);
	    foreach (@params) {
		my $tmp = File::Spec->catfile($copied, $_);
		my $temp = File::Spec->catfile($dotdir, $_);
		rcopy $tmp, $temp;
	    }
	}
	if ($self->{"envfile$i"}) {
	    $copied = $self->{"envfile$i"};
	    fcopy $copied, $dotdir;
	}
	if ($self->{"ifile$i"}) {
	    $copied = $self->{"ifile$i"};
	    $self->{"input$i"} = &Data_Generation::CF($copied, $dotdir);
	}
    }
    return bless $self, $class;
}

sub start {
    my $self = shift;

    my $dir = $self->{id};
    my $dotdir = '.' . $dir;
    unless (-e $dir) { rename $dotdir, $dir; }

    $self->before();

    # NQS ������ץȤ����������
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
    # ��̥ե����뤫���̤����
    &jobsched::wait_job_done($self->{id});
    until (-e $stdofile) {
	sleep 2;
    }
    my @stdlist = &pickup($stdofile, ',');
    $self->{stdout} = $stdlist[0];


    $self->after();
}

sub before {
    my $self = shift;

    for ( my $i = 0; $i < $MAX; $i++ ) {
	if ($self->{"ifile$i"}) { $self->{"input$i"}->do(); }
    }

    my $exe = $self->{exe};
    my $dir = $self->{id};
#    if ( -e $exe ) {
#	my $direxe = File::Spec->catfile($dir, $exe);
#	system("cp $exe $direxe");
#    }
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
    # exit_cond �ˤ����������른��֤η�̤�ǥ��쥯�ȥ�ʲ�����¸
    my $tracelog_filename = 'trace.log';
    my $tracelog = File::Spec->catfile($dir, $tracelog_filename);
    open ( EXITOUTPUT , ">> $tracelog" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
}

1;
