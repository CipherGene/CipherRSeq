package Utilities;

use strict;
use Exporter;
my @EXPORT      = ();
my %EXPORT_TAGS = (all => [qw(&GetFileStem)]);

sub GetFileStem($) {
  my $p = shift;
  if(!(-f "$p"))  {
    # does not seem to be a file
    die "Utilities::GetFileStem: the input \"$p\" is unlikly to be a file...Exiting...\n";
  }
  if($p =~ /.*\/+(\S+)/)  {       # if the directory is not ended with back slash
    return $1;
  } else {                        # if no back slash exists, the stem is itself
    return $p;
  }
}

1;
