package config_common;

use base qw(Exporter);
our @EXPORT = qw(workdir_file_option boolean_option);
use strict;
use File::Spec;

sub workdir_file_option {
    my $prefix = shift;
    my $default = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        my $file = $self->{$mb_name} || $default;
	return $file?($prefix . $file):();
    }
}

sub boolean_option {
    my $opt_string = shift;
    my $default = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        my $val = (defined $self->{$mb_name})?($self->{$mb_name}):$default;
        return $val ? ($opt_string) : ();
    }
}

1;
