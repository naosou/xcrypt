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
    # ����֤򥸥�֤��Ȥ˺��������ǥ��쥯�ȥ�ǽ���
    my $dir = $self->{id};
    mkdir $dir , 0755;
#    unless ($self->{input_arg_dirname} eq '') {
#	my $hoge = $self->{input_arg_dirname} . "/" . $self->{ifile};
    $self->{input} = &Data_Generation::CF($self->{ifile}, $dir);
#    }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    my $dir = $self->{id};
    unless (-e $dir) { mkdir $dir , 0755; }

    $self->before();

    # NQS ������ץȤ����������
    my $nqs_script = File::Spec->catfile($dir, 'nqs.sh');
    my $cmd = $self->{exe} . " $self->{arg1} $self->{arg2}";
    my $stdoutfile = File::Spec->catfile($dir, 'stdout');
    if ($self->{stdout_file}) { $stdoutfile = $self->{stdout_file}; }
    my $stderrfile = File::Spec->catfile($dir, 'stderr');
    if ($self->{stderr_file}) { $stderrfile = $self->{stderr_file}; }
    &jobsched::qsub($self->{id},
		    $cmd,
		    $self->{id},
		    $nqs_script,
		    $self->{queue},
		    $self->{option},
		    $stdoutfile,
		    $stderrfile);
    # ��̥ե����뤫���̤����
    # ��������桼���˽񤫤��ʤ��Ȥ����ʤ����ɤɤΤ褦�ˤ��롩
    &jobsched::wait_job_done($self->{id});
    my @stdlist = &pickup($stdoutfile, ',');
    $self->{stdout} = $stdlist[0];

    $self->after();
}

sub before {
    my $self = shift;
    $self->{input}->do();
    my $exe = $self->{exe};
    my $dir = $self->{id};
    if ( -e $exe ) { symlink File::Spec->catfile('..',  $exe), File::Spec->catfile($dir, $exe); }
}

sub after {
    my $self = shift;
    my $dir = $self->{id};
    unless ($self->{ofile}) {}
    else {
	my $outputfile = File::Spec->catfile($dir, $self->{ofile});
	my @list = &pickup($outputfile, $self->{odelimiter});
	$self->{output} = $list[$self->{ocolumn}];
	unshift (@{$self->{trace}} , $list[$self->{ocolumn}]);
    }
    # exit_cond �ˤ����������른��֤η�̤�ǥ��쥯�ȥ�ʲ�����¸
    my $tracelog_filename = 'trace.log';
    my $tracelog = File::Spec->catfile($dir, $tracelog_filename);
    open ( EXITOUTPUT , ">> $tracelog" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
}

1;
