#!/usr/bin/env perl

open(IN, "< $ARGV[0]");
foreach my $item (<IN>) {
    my $str = $item;
    if ($str =~ m/(param)/) {
	my @tmp = split(' ', $str);
	open(OUT, ">> output.dat" );
	sleep(2);
	print OUT (-0.5) * $tmp[2];
#	print OUT (0.5) * $tmp[2];
#	print OUT (0.5) * ($tmp[2] - 2);
	close(OUT);
    }
}
close(IN);
