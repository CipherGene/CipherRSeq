package PreprocessingTrimmomatic;

use Utilities qw(:all);
use strict;
use Exporter;
my @EXPORT      = ();
my %EXPORT_TAGS = (TRIMMOMATIC => [qw(&TrimmomaticRun)]);
use Cwd;
use Cwd 'abs_path';

# Description: Load the work instructions in the WORK_SHEET file
# Author: Cuncong Zhong
# Date: 02/21/2015
# Input: the WORK_SHEET file
# Output: the reference to a hash table
# Format: the keys are work instruction option tags and values are default values
# Sample usage: my $work_hash = TrimmomaticLoadWorkSheet($work_sheet_file);
sub TrimmomaticLoadWorkSheet($)	{
  my $work_sheet_file = shift;    # the WORK_SHEET file
  my %work;                       # the hash table contains working instructions
  # Trimmomatic needs 1: data_definition, 2: num_threads, 3: run_mode
  open my $IN, "<$work_sheet_file" or die "Cannot open WORK_SHEET file. Please check setting.\n";
  while(<$IN>) {
    chomp;
    if(
      /^WORKSHEET\_DATA\_GROUP\d+\=/ ||       # data definition
      /^WORKSHEET\_NUM\_THREADS\=/  ||        # number of threads
      /^WORKSHEET\_PREPROCESSING\_TRIMMOMATIC\_MODE\=/    # tophat running mode
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
# Date: 02/21/2015
# Input: the PATH_CONFIG file
# Output: the reference to a hash table
# Format: the keys are path setting option tags and values are default values
# Sample usage: my $path_hash = TrimmomaticLoadPaths($path_config_file);
sub TrimmomaticLoadPaths($)	{
  my $path_config_file = shift;   # the PATH_CONFIG file
  my %path;                       # the hash table contains all the required paths
  # the only path we need to know is the Trimmomatic path
  open my $IN, "<$path_config_file" or die "Cannot open PATH_CONFIG file. Please check setting.\n";
  while(<$IN>)  {
    chomp;
    if(
      /^PATHCONF\_TRIMMOMATIC\_HOME\=/         # path to trimmomatic
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
# Date: 02/21/2015
# Input: the reference to the path hash table
# Output: N/A
# Format: N/A
# Sample usage: TrimmomaticCheckPaths($path_hash);
sub TrimmomaticCheckPaths($)	{
  my $hash = shift;               # the reference to the hash table containing the paths
  if(!(exists $hash->{"PATHCONF_TRIMMOMATIC_HOME"}) || !(-e $hash->{"PATHCONF_TRIMMOMATIC_HOME"}))  {
    die "Cannot find Trimmomatic path, required by quality trimming...Exiting...\n";
  } else  {
    # check adapter sequence folder, which is required for the run
    my $a_dir = $hash->{"PATHCONF_TRIMMOMATIC_HOME"} . '/adapters';
    # Illumina HiSeq uses TruSeq3 adapters, so only check TruSeq3-SE and TruSeq3-PE    
    if(!(-e "$a_dir/TruSeq3-PE.fa") || !(-e "$a_dir/TruSeq3-SE.fa"))  {
      die "Cannot find Trimmomatic adapter sequence template, required by quality trimming...Exiting...\n";
    }
  }
  return;
}

# Description: setup work directory
# Author: Cuncong Zhong
# Date: 02/21/2015
# Input: the working directory; the reference to the work sheet hash table
# Output: N/A
# Format: N/A
# Sample usage: TrimmomaticSetupWorkDirectory($work_directory, $work_hash);
sub TrimmomaticSetupWorkDirectory($$)  {
  print "=====CipherRSeq: Setting up working directory for Trimmomatic...=====\n";
  my $work_directory = shift;
  my $work_hash = shift;
  if(!(-e "$work_directory/Preprocessing"))  {
    mkdir "$work_directory/Preprocessing" or die "PreprocessingTrimmomatic::TrimmomaticSetupWorkDirectory: Cannot create directory \"$work_directory/Preprocessing\"\n";
  }
  # create folder for each data group
  foreach(keys %{$work_hash}) {
    if(/^WORKSHEET_DATA_(GROUP\d+)/)  {
      if(!(-e "$work_directory/Preprocessing/$1"))  {
        mkdir "$work_directory/Preprocessing/$1" or die "PreprocessingTrimmomatic::TrimmomaticSetupWorkDirectory: Cannot create directory $1\n";
      }
    }
  }
  return;
}

# Description: run Trimmomatic with specified data and mode
# Author: Cuncong Zhong
# Date: 02/21/2015
# Input: the working directory, the reference to the path hash table; the reference to the work sheet hash table
# Output: N/A
# Format: N/A
# Sample usage: TrimmomaticTrim($work_directory, $path_hash, $work_hash);
sub TrimmomaticTrimming($$$)	{
  my $work_directory = shift;
  my $path_hash = shift;
  my $work_hash = shift;
  # prepare running mode
  my $trm_path = $path_hash->{"PATHCONF_TRIMMOMATIC_HOME"};
  my $trm_exe;
  foreach(<$trm_path/*.jar>) {
    $trm_exe = $_;
  }
  if(!defined $trm_exe)  {
    die "PreprocessingTrimmomatic::TrimmomaticTrim: no executable is found for Trimmomatic...exiting...\n";
  }
  my $run_mode_PE = "ILLUMINACLIP:$trm_path/adapters/TruSeq3-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36";  
  my $run_mode_SE = "ILLUMINACLIP:$trm_path/adapters/TruSeq3-SE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36"; 
  if($work_hash->{"WORKSHEET_PREPROCESSING_TRIMMOMATIC_MODE"} eq "FAST")  {
    # TODO: determine proper setting for FAST mode
    #$run_mode_PE = "";
    #$run_mode_SE = "";
  } elsif($work_hash->{"WORKSHEET_PREPROCESSING_TRIMMOMATIC_MODE"} eq "SENSITIVE") {
    # TODO: determine proper setting for FAST mode
    #$run_mode_PE = "";
    #$run_mode_SE = "";
  }
  # run mapping one-by-one
  my $num_threads = $work_hash->{"WORKSHEET_NUM_THREADS"};
  foreach(sort keys %{$work_hash}) {    
    my $name_key = $_;    
    if($name_key =~ /^WORKSHEET_DATA_(GROUP\d+)/)  {
      my $group = $1;
      my @expr = split /\;/, $work_hash->{$name_key};
      my $exp_index = 0;      
      foreach(@expr) {
        my $group_all = $_;
        my @decom = split /\:/, $group_all;
        if(!(-e "$work_directory/Preprocessing/$group/expr_$exp_index"))  {
          mkdir "$work_directory/Preprocessing/$group/expr_$exp_index" or die "Cannot create Trimmomatic output directory\n";
        }
        print "=====CipherRSeq: Running Trimmomatic quality trimming...=====\n";
        if(scalar @decom == 1)  {   # single-end case
          print "=====Command: java -jar $trm_exe SE -threads $num_threads $decom[0] $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed.fastq $run_mode_SE =====\n";
          system "java -jar $trm_exe SE -threads $num_threads $decom[0] $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed.fastq $run_mode_SE";
        } elsif(scalar @decom == 2)  {  # pair-end case
          print "=====Command: java -jar $trm_exe PE -threads $num_threads $decom[0] $decom[1] $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_1P.fastq $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_1U.fastq $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_2P.fastq $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_2U.fastq $run_mode_PE =====\n";
          system "java -jar $trm_exe PE -threads $num_threads $decom[0] $decom[1] $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_1P.fastq $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_1U.fastq $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_2P.fastq $work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_2U.fastq $run_mode_PE";
        } else  {
          die "PreprocessingTrimmomatic::Trimmomatic: Warning: Illy defined read group: $group_all...Exiting...\n";
        }
        ++ $exp_index;
      }
    }
  }
  return;
}

# Description: the trimmomatic driver
# Author: Cuncong Zhong
# Date: 02/21/2015
# Input: the working directory
# Output: N/A
# Format: N/A
# Sample usage: TrimmomaticRun($work_directory);
sub TrimmomaticRun($)	{
  my $work_directory = shift;
  $work_directory = abs_path($work_directory);
  # loading the settings
  my $path_config_file = $work_directory . '/' . 'PATH_CONFIG';
  my $work_sheet_file = $work_directory . '/' . 'WORK_SHEET';
  my $path_hash = TrimmomaticLoadPaths($path_config_file);
  my $work_hash = TrimmomaticLoadWorkSheet($work_sheet_file);  
  # check path validity
  TrimmomaticCheckPaths($path_hash);  
  # setup the work directory
  TrimmomaticSetupWorkDirectory($work_directory, $work_hash);
  # run Trimmomatic
  TrimmomaticTrimming($work_directory, $path_hash, $work_hash);
  print "=====CipherRSeq: Trimmomatic run finished. Congratulations!=====\n";
  return;
}
