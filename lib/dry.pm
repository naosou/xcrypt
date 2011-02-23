package dry;

use strict;
use NEXT;
use builtin;
use core;

&add_key('dry','dry_qsub');
&add_prefix_of_key('dry_exe');

my %default_options = (                  # dryのデフォルト設定値
    'dry'  => '0',
    'dry_qsub' => 'host',
);

our %options = %default_options;   # dryの設定値 (dry, dry_qsub, dry_exe0, dry_exe1...)

###############################################
#     << 初期設定 >>                                                                               #
###############################################
sub initialize {
    my %add_options = @_;
    foreach my $key (keys %add_options) {
        if ($add_options{$key} ne '') {
            &check_dry_value($key, $add_options{$key});
            $options{$key} = $add_options{$key};
        } else {
            $options{$key} = $default_options{$key};
        }
    }
}

###############################################
#     << 設定値検証 >>                                                                            #
###############################################
sub check_dry_value {
    my ($key, $value) = @_;
    
    if ($key eq 'dry' and $value !~ /\A[0-3]\Z/) {
        die "error $key";
    } elsif ($key eq 'dry_qsub' and ($value ne 'host' and $value ne 'local')) {
        die "error $key";
    }
}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

###############################################
#     << 設定をジョブに反映 >>                                                                 #
###############################################
sub start {
    my $self = shift;
    if ($self->{dry} >= 1) {
        foreach my $key (keys(%$self)) {
            if ($key =~ /\Aexe([0-9]+)\Z/) {
                my $bkup = 'Bkup_exe'.$1;
                $self->{$bkup} = $self->{$key};
                $self->{$key} = "\#\# dry_run \#\#\n";
                if (defined $self->{"dry_exe$1"} and ($self->{dry} == 1 or $self->{dry} == 2)) {
                    no strict 'refs';
                    if (ref($self->{"dry_exe$1"}) eq 'CODE') {
                        $self->{$key} .= "perl $self->{id}_dry_exe${1}.pl $self->{$bkup}";
                        $self->make_in_job_script($self, "dry_exe{$1}_script", "dry_exe$1");
                        $self->update_script_file ("$self->{id}_dry_exe${1}.pl", @{$self->{"dry_exe{$1}_script"}});
                    } elsif (*{$self->{"dry_exe$1"}}{SCALAR}) {
                        $self->{$key} .= $self->{"dry_exe$1"} . "\n";
                        $self->{$key} .= "\#".$self->{$bkup};
                    } else {
                        die "error dry_exe";
                    }
                } else {
                    $self->{$key} .= "\#".$self->{$bkup};
                }
            }
        }
    }
    $self->NEXT::start();
}

sub initially {
    my $self = shift;
    
    if (defined $self->{dry}) {
        &check_dry_value('dry', $self->{dry});
    } elsif (exists $self->{dry}) {
        $self->{dry} = $default_options{dry};
    } else {
        $self->{dry} = $options{dry};
    }
    
    if (defined $self->{dry_qsub}) {
        &check_dry_value('dry_qsub', $self->{dry_qsub});
    } elsif (exists $self->{dry_qsub}) {
        $self->{dry_qsub} = $default_options{dry_qsub};
    } else{
        $self->{dry_qsub} = $options{dry_qsub};
    }
    
    if ($self->{dry_qsub} eq 'local') {
        $self->{env}->{sched} = 'sh';
        $self->{jobscript_file} = "$self->{id}_$self->{env}->{sched}.sh";
    }
    
    
    if (defined $self->{dry_exe}) {
        $self->{dry_exe0} = $self->{dry_exe};
    }
    
    foreach my $dry_exe (grep {$_ =~ /\Adry_exe[0-9]+\Z/} keys(%options)) {
        unless (exists $self->{$dry_exe}) {
            $self->{$dry_exe} = $options{$dry_exe};
        }
    }
    
    if ($self->{dry} >= 2) {
        &redefine_sub('before_in_job', 'after_in_job');
        &delete_sub($self, 'before_in_job', 'after_in_job');
        if ($self->{before_to_job} == 1) {
            &delete_sub($self, 'before');
            delete $self->{before_to_job};
        } 
        if ($self->{after_to_job} == 1) {
            &delete_sub($self, 'after');
            delete $self->{before_to_job};
        }
    }
    if ($self->{dry} == 3) {
        &redefine_sub('before_in_xcrypt', 'after_in_xcrypt', 'before', 'after');
        &delete_sub($self, 'before', 'after', 'before_in_xcrypt', 'after_in_xcrypt');
    }
    
    if ($self->{dry} >= 1) {
        foreach my $key (keys(%$self)) {
            if ($key =~ /\Aexe([0-9]+)\Z/) {
                my $bkup = 'Bkup_exe'.$1;
                $self->{$bkup} = $self->{$key};
                $self->{$key} = "\#\# dry_run \#\#\n";
                if (defined $self->{"dry_exe$1"} and ($self->{dry} == 1 or $self->{dry} == 2)) {
                    no strict 'refs';
                    
                    if (ref($self->{"dry_exe$1"}) eq 'CODE') {
                        $self->{"dry_exe${1}_sub"} = &get_dry_exe_sub;
                        $self->{$key} .= "perl $self->{id}_dry_exe${1}.pl\n";
                        $self->make_in_job_script("dry_exe${1}_sub", "dry_exe${1}_script");
                        $self->update_script_file ("$self->{id}_dry_exe${1}.pl", @{$self->{"dry_exe${1}_script"}});    
                    } elsif (ref($self->{"dry_exe$1"}) eq 'ARRAY' or ref($self->{"dry_exe$1"}) eq 'HASH' or ref($self->{"dry_exe$1"}) eq 'REF') {
                        die "error dry_exe";
                    } else {
                        $self->{$key} .= $self->{"dry_exe$1"} . "\n";
                    }
                }
                $self->{$key} .= "\#".$self->{$bkup};
            }
        }
    }
    
}

###############################################
#     << 関数再定義 >>                                                                            #
###############################################
sub redefine_sub {
    my @redefine_subs = @_;
    
    foreach my $key ('user', @user::ISA) {
        foreach my $redefine_sub (@redefine_subs) {
            my $sub_redefine = "*" . "$key" . "::$redefine_sub = sub {}";
            no warnings 'redefine';
            eval $sub_redefine;
        }
    } 
}

###############################################
#     << サブルーチン削除 >>                                                                   #
###############################################
sub delete_sub {
    my $self = shift;
    my @delete_subs = @_;
    
    foreach my $delete_sub (@delete_subs) {
        if (defined ($self->{$delete_sub})) {
            delete $self->{$delete_sub};
        }
    }
}

<<<<<<< /share/home-spara/tasuku/xcrypt-909/xcrypt/lib/dry.pm.orig
sub before_in_xcrypt {}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub after_in_xcrypt {}
||||||| /tmp/dry.pm~base.fZvTU9
sub before_in_xcrypt {}
sub after_in_xcrypt {}
=======
sub before {}
sub after {}
>>>>>>> /tmp/dry.pm~other.4n7ANN

###############################################
#     << dry_exe引数抽出 >>                                                                   #
###############################################
sub get_dry_exe_sub {
    return sub{
        my $self = $main::self;
        
        $0 =~ /.+([0-9]+)\.pl\Z/;
        my @args = ();
        foreach my $arg_key (sort { $a cmp $b } (grep {$_ =~ /arg$1_[0-9]+/} keys (%$self))) {
            if ($self->{"$arg_key"}) {
                push(@args, $self->{"$arg_key"});
            }
        }
        &{$self->{"dry_exe$1"}}($self,$self->{'Bkup_exe' . $1}, @args); 
    }
}

1;
