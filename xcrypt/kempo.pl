#!/usr/bin/perl

#sleep(1);
open ( PLASMA , "< plasma.inp");
foreach my $item (<PLASMA>) {
    my $str = $item;
    if ($str =~ m/^(param)/) {
	if ($str =~ m/(\d+)/) {
	    my $num = $1;
	    open ( PBODY , "> pbody" );
#	    print PBODY "foo," . ($num / $ARGV[0]) . ",bar";
	    print PBODY "foo," . $ARGV[0] . ",bar";
	    close ( PBODY );
	}
    }
}
close ( PLASMA );
