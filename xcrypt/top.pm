package top;

use File::Copy;
use UI;
use function;
use jobsched;
use Data_Generation;

sub new {
    my $class = shift;
    my $self = shift;
    # ����֤򥸥�֤��Ȥ˺��������ǥ��쥯�ȥ�ǽ���
    my $dir = $self->{id} . '/';
    mkdir $dir , 0755;
    if ( -e $self->{input_filename} ) {
	$self->{input} = &Data_Generation::CF($self->{input_filename}, $dir);
    }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    my $dir = $self->{id} . '/';

    $self->before();

    # NQS ������ץȤ����������
    my $nqs_script = $dir . 'nqs.sh';
    my $cmd = $self->{exe} . " $self->{arg1} $self->{arg2}";
    my $stdoutfile = "stdout";
    if ($self->{stdout_file}) { $stdoutfile = $self->{stdout_file}; }
    my $stderrfile = "stderr";
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
    if ( -e $self->{input_filename} ) { $self->{input}->do(); }
    my $exe = $self->{exe};
    my $dir = $self->{id} . '/';
    if ( -e $exe ) { symlink '../' . $exe, $dir . $exe; }
}

sub after {
    my $self = shift;
    unless ($self->{output_filename}) {}
    else {
	my $dir = $self->{id} . '/';
	my $outputfile = $dir . $self->{output_filename};
	my @list = &pickup($outputfile, $self->{delimiter});
	$self->{output} = $list[$self->{output_column}];
	unshift (@{$self->{trace}} , $list[$self->{output_column}]);
    }
    # exit_cond �ˤ����������른��֤η�̤�ǥ��쥯�ȥ�ʲ�����¸
    my $tracelog_filename = 'trace.log';
    my $hoge = $dir . $tracelog_filename;
    open ( EXITOUTPUT , ">> $hoge" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
}

1;
