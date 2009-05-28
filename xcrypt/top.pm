package top;

use File::Copy;
use UI;
use function;
use jobsched;

my $tracelog_file = 'trace.log';

sub new {
    my $class = shift;
=comment
    my $self = {
    'id' => '',
    'predecessors' => [],
    'exe' => '',
    'arg1' => [],
    'arg2' => [],
    'input_file' => '',
    'output_file' => '',
    'output_column' => 0,
    'delimiter' => ',',
    'trace' => [],
    'exit_cond' => sub { &function::tautology; },
    'successors' => []
    };
=cut
    my $self = shift;
    return bless $self, $class;
}

sub start {
    my $self = shift;

    $self->before();

    my $dir = $self->{id} . '/';

    # ����֤򥸥�֤��Ȥ˺��������ǥ��쥯�ȥ�ǽ���
    mkdir $dir , 0755;
    my $inputfile = $self->{input_file};
    if ( -e $inputfile ) { copy( $inputfile , $dir . $inputfile ); }
    my $exe = $self->{exe};
    if ( -e $exe ) { symlink '../' . $exe , $dir . $exe; }

    # NQS ������ץȤ����������
    my $nqs_script = $dir . 'nqs.sh';
    my $cmd = $self->{exe} . " $self->{arg1} $self->{arg2}";
    my $stdoutfile = "stdout";
    if ($self->{stdout_file}) { $stdoutfile = $self->{stdout_file}; }
    my $stderrfile = "stderr";
    if ($self->{stderr_file}) { $stderrfile = $self->{stderr_file}; }
    &jobsched::qsub($self->{id}, $cmd, $self->{id}, $nqs_script, $self->{queue}, $self->{option}, $stdoutfile, $stderrfile);

    # ��̥ե����뤫���̤����
    # ��������桼���˽񤫤��ʤ��Ȥ����ʤ����ɤɤΤ褦�ˤ��롩
    &jobsched::wait_job_done($self->{id});
    my @stdlist = &pickup($stdoutfile, ',');
    $self->{stdout} = $stdlist[0];

    unless ($self->{output_file}) {}
    else {
	my $outputfile = $dir . $self->{output_file};
	my @list = &pickup($outputfile, $self->{delimiter});
	$self->{output} = $list[$self->{output_column}];
	unshift (@{$self->{trace}} , $list[$self->{output_column}]);
    }

    $self->after();

    # exit_cond �ˤ����������른��֤η�̤�ǥ��쥯�ȥ�ʲ�����¸
    my $hoge = $dir . $tracelog_file;
    open ( EXITOUTPUT , ">> $hoge" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
}

sub before {}

sub after {}

1;
