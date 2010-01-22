export XCRYPT=$HOME/xcrypt
export PATH=$XCRYPT/bin:$PATH
export XCRJOBSCHED="sh"
export PERL5LIB=$XCRYPT/lib:$XCRYPT/lib/algo/lib:$PERL5LIB
export XCR_CPAN_BASE=$XCRYPT/lib/cpan
for i in usr usr/local usr/local/share; do
  for j in lib lib64 perl; do
      for k in perl5 perl5/site_perl 5.10.0; do
          export PERL5LIB=$XCR_CPAN_BASE/$i/$j/$k:$PERL5LIB
      done
  done
done