# Config file for sh
use config_common;

$jsconfig::jobsched_config{"muramasa"} = {
    # commands
    qsub_command => "/home/spara/abet/xcrypt/lib/config/run-output-pid.sh",
    qdel_command => "kill -9",
    qstat_command => "ps",
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
    jobscript_workdir => sub { $_[0]->{id}; },
    qsub_option_stdout => workdir_file_option('-o ', 'stdout'),
    qsub_option_stderr => workdir_file_option('-e ', 'stderr'),
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /([0-9]*)/) {
            return $1;
        } else {
            return -1;
        }
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /^\s*([0-9]+)/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};