package DiffExpressionCuffdiff;

use Utilities qw(:all);
use strict;
use Exporter;
my @EXPORT      = ();
my %EXPORT_TAGS = (CUFFDIFF => [qw(&CuffdiffRun)]);
use Cwd;
use Cwd 'abs_path';

# Description: Load the work instructions in the WORK_SHEET file
# Author: Cuncong Zhong
# Date: 02/23/2015
# Input: the WORK_SHEET file
# Output: the reference to a hash table
# Format: the keys are work instruction option tags and values are default values
# Sample usage: my $work_hash = CuffdiffLoadWorkSheet($work_sheet_file);
sub CuffdiffLoadWorkSheet($)	{
  my $work_sheet_file = shift;    # the WORK_SHEET file
  my %work;                       # the hash table contains working instructions
  # Cuffdiff needs 1: data_definition, 2: compare_definition, 3: num_threads, 4: run_mode
  open my $IN, "<$work_sheet_file" or die "Cannot open WORK_SHEET file. Please check setting.\n";
  while(<$IN>) {
    chomp;
    if(
      /^WORKSHEET\_DATA\_GROUP\d+\=/ ||       # data definition
      /^WORKSHEET\_COMPARE/ ||                # compare definition
      /^WORKSHEET\_NUM\_THREADS\=/  ||        # number of threads
      /^WORKSHEET\_DIFFEXPRESSION\_CUFFDIFF\_MODE\=/    # tophat running mode
    )  {
      my @decom = split /\=/, $_;
      $work{$decom[0]} = $decom[1];
    }
  }
  close $IN;
  return \%work;
}

# Description: Load the paths written in the PATH_CONFIG file
# Author: Cuncong Zhong
# Date: 02/23/2015
# Input: the PATH_CONFIG file
# Output: the reference to a hash table
# Format: the keys are path setting option tags and values are default values
# Sample usage: my $path_hash = CuffdiffLoadPaths($path_config_file);
sub CuffdiffLoadPaths($)	{
  my $path_config_file = shift;   # the PATH_CONFIG file
  my %path;                       # the hash table contains all the required paths
  # the only path we need to know is the Trimmomatic path
  open my $IN, "<$path_config_file" or die "Cannot open PATH_CONFIG file. Please check setting.\n";
  while(<$IN>)  {
    chomp;
    if(
      /^PATHCONF\_TRANSCRIPT\_GTF/ ||       # path to the gtf file for transcribed regions
      /^PATHCONF\_CUFFLINK\_HOME\=/         # path to cufflink
    )  {
      my @decom = split /\=/, $_;
      $path{$decom[0]} = $decom[1];
    }
  }
  close $IN;
  # returns the reference of the hash table
  return \%path;
}

# Description: check if all trimmomatic required paths have been set
# Author: Cuncong Zhong
# Date: 02/23/2015
# Input: the reference to the path hash table
# Output: N/A
# Format: N/A
# Sample usage: CuffdiffCheckPaths($path_hash);
sub CuffdiffCheckPaths($)	{
  my $hash = shift;               # the reference to the hash table containing the paths
  if(!(exists $hash->{"PATHCONF_CUFFLINK_HOME"}) || !(-e $hash->{"PATHCONF_CUFFLINK_HOME"}))  {
    die "Cannot find Cuffdiff path, required by diffential expression analysis...Exiting...\n";
  } elsif(!(exists $hash->{"PATHCONF_TRANSCRIPT_GTF"}) || !(-e $hash->{"PATHCONF_TRANSCRIPT_GTF"}))  {
    die "Cannot find transcript GTF file, required by diffential expression analysis...Exiting...\n";
  }
  return;
}

# Description: setup work directory
# Author: Cuncong Zhong
# Date: 02/23/2015
# Input: the working directory; the reference to the work sheet hash table
# Output: N/A
# Format: N/A
# Sample usage: CuffdiffSetupWorkDirectory($work_directory, $work_hash);
sub CuffdiffSetupWorkDirectory($$)  {
  print "=====CipherRSeq: Setting up working directory for Cuffdiff...=====\n";
  my $work_directory = shift;
  my $work_hash = shift;
  if(!(-e "$work_directory/DiffExpression"))  {
    mkdir "$work_directory/DiffExpression" or die "DiffExprssionCuffdiff::CuffdiffSetupWorkDirectory: Cannot create directory \"$work_directory/DiffExpression\"\n";
  }
  return;
}

# Description: run Cuffdiff with specified data and mode
# Author: Cuncong Zhong
# Date: 02/23/2015
# Input: the working directory, the reference to the path hash table; the reference to the work sheet hash table
# Output: N/A
# Format: N/A
# Sample usage: CuffdiffCompare($work_directory, $path_hash, $work_hash);
sub CuffdiffCompare($$$)	{
  my $work_directory = shift;
  my $path_hash = shift;
  my $work_hash = shift;
  # prepare running mode
  my $cdf_exe = $path_hash->{"PATHCONF_CUFFLINK_HOME"} . "/cuffdiff";
  if(!defined $cdf_exe)  {
    die "DiffExpressionCuffdiff::CuffdiffCompare: no executable is found for Cuffdiff...exiting...\n";
  }
  if($work_hash->{"WORKSHEET_DIFFEXPRESSION_CUFFDIFF_MODE"} eq "FAST")  {
    # TODO: determine proper setting for FAST mode
    #$run_mode = "";
  } elsif($work_hash->{"WORKSHEET_DIFFEXPRESSION_CUFFDIFF_MODE"} eq "SENSITIVE") {
    # TODO: determine proper setting for FAST mode
    #$run_mode = "";
  }
  my $gtf_file = $path_hash->{"PATHCONF_TRANSCRIPT_GTF"};
  my $num_threads = $work_hash->{"WORKSHEET_NUM_THREADS"};
  # check group definition  
  if(!exists $work_hash->{"WORKSHEET_COMPARE"})  {
    die "DiffExpressionCuffdiff::CuffdiffCompare: no compare group defined for differential expression analysis...exiting...\n";
  }
  
  # run mapping one-by-one
  print "=====CipherRSeq: Running Cuffdiff differential expression analysis...=====\n";
  my @compare = split /\;/, $work_hash->{"WORKSHEET_COMPARE"};  
  my $cmp_index = 0;
  foreach(@compare) {
    my @group = split /\:/, $_;
    if(!exists $work_hash->{"WORKSHEET_DATA_$group[0]"} || !exists $work_hash->{"WORKSHEET_DATA_$group[1]"})  {
      die "DiffExpressionCuffdiff::CuffdiffCompare: data group $group[0] or $group[1] undefined...exiting...\n";
    }
    my @expr0 = split /\;/, $work_hash->{"WORKSHEET_DATA_$group[0]"};
    my @expr1 = split /\;/, $work_hash->{"WORKSHEET_DATA_$group[1]"};
    my $data1 = "";
    my $expr_index = 0;
    foreach(@expr0) {
      if(-e "$work_directory/ReadMapping/$group[0]/expr_$expr_index/accepted_hits.bam")  {
        $data1 .= "$work_directory/ReadMapping/$group[0]/expr_$expr_index/accepted_hits.bam,"
      }
      ++ $expr_index;
    }
    my $data2 = "";
    $expr_index = 0;
    foreach(@expr1) {
      if(-e "$work_directory/ReadMapping/$group[1]/expr_$expr_index/accepted_hits.bam")  {
        $data2 .= "$work_directory/ReadMapping/$group[1]/expr_$expr_index/accepted_hits.bam,"
      }
      ++ $expr_index;
    }
    $data1 =~ s/\,$//g;
    $data2 =~ s/\,$//g;
    
    # prepare folder to hold results
    if(!(-e "$work_directory/DiffExpression/cmp_$cmp_index"))  {
      mkdir "$work_directory/DiffExpression/cmp_$cmp_index" or die "DiffExpressionCuffdiff::CuffdiffCompare: cannot create directory for compare analysis $cmp_index...exiting...\n";
    }
    print "=====Command: $cdf_exe $gtf_file $data1 $data2 -o $work_directory/DiffExpression/cmp_$cmp_index=====\n";
    system "$cdf_exe $gtf_file $data1 $data2 -o $work_directory/DiffExpression/cmp_$cmp_index";

    ++ $cmp_index;
  }
  
  return;
}

# Description: the Cuffdiff driver
# Author: Cuncong Zhong
# Date: 02/23/2015
# Input: the working directory
# Output: N/A
# Format: N/A
# Sample usage: CuffdiffRun($work_directory);
sub CuffdiffRun($)	{
  my $work_directory = shift;
  $work_directory = abs_path($work_directory);
  # loading the settings
  my $path_config_file = $work_directory . '/' . 'PATH_CONFIG';
  my $work_sheet_file = $work_directory . '/' . 'WORK_SHEET';
  my $path_hash = CuffdiffLoadPaths($path_config_file);
  my $work_hash = CuffdiffLoadWorkSheet($work_sheet_file);  
  # check path validity
  CuffdiffCheckPaths($path_hash);  
  # setup the work directory
  CuffdiffSetupWorkDirectory($work_directory, $work_hash);
  # run Trimmomatic
  CuffdiffCompare($work_directory, $path_hash, $work_hash);
  print "=====CipherRSeq: Cuffdiff run finished. Congratulations!=====\n";
  return;
}
