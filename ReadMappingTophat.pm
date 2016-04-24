package ReadMappingTophat;

use Utilities qw(:all);
use strict;
use Exporter;
my @EXPORT      = ();
my %EXPORT_TAGS = (TOPHAT => [qw(&TophatRun)]);
use Cwd;
use Cwd 'abs_path';

# Description: Load the work instructions in the WORK_SHEET file
# Author: Cuncong Zhong
# Date: 02/03/2015
# Input: the WORK_SHEET file
# Output: the reference to a hash table
# Format: the keys are work instruction option tags and values are default values
# Sample usage: my $work_hash = TophatLoadWorkSheet($work_sheet_file);
sub TophatLoadWorkSheet($)	{
  my $work_sheet_file = shift;    # the WORK_SHEET file
  my %work;                       # the hash table contains working instructions
  # Tophat needs 1: data_definition, 2: num_threads, 3: run_mode
  open my $IN, "<$work_sheet_file" or die "Cannot open WORK_SHEET file. Please check setting.\n";
  while(<$IN>) {
    chomp;
    if(
      /^WORKSHEET\_DATA\_GROUP\d+\=/ ||       # data definition
      /^WORKSHEET\_NUM\_THREADS\=/  ||        # number of threads
      /^WORKSHEET\_READMAPPING\_TOPHAT2\_MODE\=/    # tophat running mode
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
# Date: 02/03/2015
# Input: the PATH_CONFIG file
# Output: the reference to a hash table
# Format: the keys are path setting option tags and values are default values
# Sample usage: my $path_hash = TophatLoadPaths($path_config_file);
sub TophatLoadPaths($)	{
  my $path_config_file = shift;   # the PATH_CONFIG file
  my %path;                       # the hash table contains all the required paths
  # we need to load the following paths: 
  # reference_fasta, index_path, samtool_path, bowtie2_path, tophat2_path
  # load one by one
  open my $IN, "<$path_config_file" or die "Cannot open PATH_CONFIG file. Please check setting.\n";
  while(<$IN>)  {
    chomp;
    if(
      /^PATHCONF\_REFGENOME\_PATH\=/ ||         # reference fasta path
      /^PATHCONF\_BOWTIE2\_INDEX\_PATH\=/ ||    # bowtie2 indexing path
      /^PATHCONF\_SAMTOOLS\_HOME\=/ ||          # samtools HOME path
      /^PATHCONF\_BOWTIE2\_HOME\=/ ||           # BOWTIE2 HOME path
      /^PATHCONF\_TOPHAT2\_HOME\=/              # TOPHAT HOME path
    )  {
      my @decom = split /\=/, $_;
      $path{$decom[0]} = $decom[1];
    }
  }
  close $IN;
  # returns the reference of the hash table
  return \%path;
}

# Description: check if all tophat2 required paths have been set
# Author: Cuncong Zhong
# Date: 02/03/2015
# Input: the reference to the path hash table
# Output: N/A
# Format: N/A
# Sample usage: TophatCheckPaths($path_hash);
sub TophatCheckPaths($)	{
  my $hash = shift;               # the reference to the hash table containing the paths
  if(!(exists $hash->{"PATHCONF_REFGENOME_PATH"}) || !(-e $hash->{"PATHCONF_REFGENOME_PATH"}))  {
    die "Cannot find reference genome file, which is required by Tophat2...Exiting...\n";
  } 
  if(!(exists $hash->{"PATHCONF_SAMTOOLS_HOME"}) || !(-e $hash->{"PATHCONF_SAMTOOLS_HOME"})) {
    die "Cannot find Samtools program, which is required by Tophat2...Exiting...\n";
  } 
  if(!(exists $hash->{"PATHCONF_BOWTIE2_HOME"}) || !(-e $hash->{"PATHCONF_BOWTIE2_HOME"})) {
    die "Cannot find Bowtie2 program, which is required by Tophat2...Exiting...\n";
  } 
  if(!(exists $hash->{"PATHCONF_TOPHAT2_HOME"}) || !(-e $hash->{"PATHCONF_TOPHAT2_HOME"})) {
    die "Cannot find Tophat2 program, which is required by Tophat2...Exiting...\n";
  }
  if(!(exists $hash->{"PATHCONF_BOWTIE2_INDEX_PATH"})) {
    die "Cannot find Bowtie2 indexing setting...Please specify the directory in PATH_CONF file...Exiting...\n";
  } 
  return;
}

# Description: soft link bowtie2, samtools, and tophat2 executables into a temporary directory,
#              and add the directory to $PATH
# Author: Cuncong Zhong
# Date: 02/03/2015
# Input: the working directory; the reference to the path hash table
# Output: N/A
# Format: N/A
# Sample usage: TophatPrepareRunEnvironment($work_directory, $path_hash);
sub TophatPrepareRunEnvironment($$)	{
  print "=====CipherRSeq: Preparing run environment for Tophat2...=====\n";
  my $work_directory = shift;
  my $path_hash = shift;
  $work_directory = abs_path($work_directory);
  # create directory for temporary executable links
  if(!(-e "$work_directory/TophatBin"))  {
    #print "ReadMappingTophat::TophatPrepareRunEnvironment: Creating directory \"$work_directory\/TophatBin\"...\n";
    mkdir "$work_directory/TophatBin" or die "ReadMappingTophat::TophatPrepareRunEnvironment: Cannot create directory \"$work_directory\/TophatBin\"...Exiting...\n";
  }
  # link executables
  my $current_path = getcwd();
  chdir "$work_directory\/TophatBin" or die "ReadMappingTophat::TophatPrepareRunEnvironment: Cannot enter directory \"$work_directory\/TophatBin\"...Exiting...";
  # link samtools executables  
  my $samtools_path = $path_hash->{"PATHCONF_SAMTOOLS_HOME"};  
  foreach(<$samtools_path/*>) {
    if(-f "$_" and -X "$_")  {
      my $fstem = Utilities::GetFileStem($_);
      if(!(-e $fstem))  {
        #print "ReadMappingTophat::TophatPrepareRunEnvironment: Soft-linking Samtools executable $fstem...\n";
        system "ln -s $_ ./$fstem";
      }
    }
  }
  # link bowtie2 executables  
  my $bowtie2_path = $path_hash->{"PATHCONF_BOWTIE2_HOME"};  
  foreach(<$bowtie2_path/*>) {
    if(-f "$_" and -X "$_")  {
      my $fstem = Utilities::GetFileStem($_);
      if(!(-e $fstem))  {
        #print "ReadMappingTophat::TophatPrepareRunEnvironment: Soft-linking Bowtie2 executable $fstem...\n";
        system "ln -s $_ ./$fstem";
      }
    }
  }
  # link samtools executables  
  my $tophat2_path = $path_hash->{"PATHCONF_TOPHAT2_HOME"};  
  foreach(<$tophat2_path/*>) {
    if(-f "$_" and -X "$_")  {
      my $fstem = Utilities::GetFileStem($_);
      if(!(-e $fstem))  {
        #print "ReadMappingTophat::TophatPrepareRunEnvironment: Soft-linking Tophat2 executable $fstem...\n";
        system "ln -s $_ ./$fstem";
      }
    }
  }
  # switching back to the current directory
  chdir "$current_path" or die "ReadMappingTophat::TophatPrepareRunEnvironment: Cannot enter directory \"$current_path\"...Exiting...";
  # add the temporary executable directory to PATH
  $ENV{PATH} = $ENV{PATH} . ':' . "$work_directory\/TophatBin";
  return;
}

# Description: setup work directory
# Author: Cuncong Zhong
# Date: 02/03/2015
# Input: the working directory; the reference to the work sheet hash table
# Output: N/A
# Format: N/A
# Sample usage: TophatSetupWorkDirectory($work_directory, $work_hash);
sub TophatSetupWorkDirectory($$)  {
  print "=====CipherRSeq: Setting up working directory for Tophat2...=====\n";
  my $work_directory = shift;
  my $work_hash = shift;
  if(!(-e "$work_directory/ReadMapping"))  {
    mkdir "$work_directory/ReadMapping" or die "ReadMappingTophat::TophatSetupWorkDirectory: Cannot create directory \"$work_directory/ReadMapping\"\n";
  }
  # create folder for each data group
  foreach(keys %{$work_hash}) {
    if(/^WORKSHEET_DATA_(GROUP\d+)/)  {
      if(!(-e "$work_directory/ReadMapping/$1"))  {
        mkdir "$work_directory/ReadMapping/$1" or die "ReadMappingTophat::TophatSetupWorkDirectory: Cannot create directory $1\n";
      }
    }
  }
  return;
}

# Description: check if we need to run bowtie indexing, if yes, run it
#              currently assuming human genome as reference
# Author: Cuncong Zhong
# Date: 02/03/2015
# Input: the reference to the path hash table
# Output: N/A
# Format: N/A
# Sample usage: TophatCheckIndexing($path_hash);
sub TophatCheckIndexing($)	{
  my $hash = shift;
  if(!exists $hash->{"PATHCONF_BOWTIE2_INDEX_PATH"})  {
    die "Cannot find Bowtie2 indexing setting...Please specify the directory in PATH_CONF file...Exiting...\n";
  }
  my $bw2_index_path = $hash->{"PATHCONF_BOWTIE2_INDEX_PATH"};
  my $ref_file = Utilities::GetFileStem($hash->{"PATHCONF_REFGENOME_PATH"});
  # check if directory exists
  if(!(-e "$bw2_index_path"))  {
    # if the path is not present, create the directory
    #print "ReadMappingTophat::TophatCheckIndexing: Bowtie2 indexing directory is not found...\n";
    #print "ReadMappingTophat::TophatCheckIndexing: Creating indexing directory...\n";
    mkdir "$bw2_index_path" or die "Cannot create bowtie2 indexing directory: \"$bw2_index_path\"\n";
  }
  # check if reference genome file exists in the indexing directory
  # try to handle trailing .fa extension 
  # (as tophat2 requires .fa extension for the reference fasta file)
  $ref_file =~ s/\.fa$//g;
  if(!(-e "$bw2_index_path/$ref_file\.fa"))  {
    # copy the file to the indexing directory
    #print "ReadMappingTophat::TophatCheckIndexing: Reference sequence file is not found in the indexing directory...\n";
    #print "ReadMappingTophat::TophatCheckIndexing: Copying reference sequence file...\n";
    my $full_ref_file = $hash->{"PATHCONF_REFGENOME_PATH"};    
    system "cp $full_ref_file $bw2_index_path/$ref_file\.fa";
  }
  # check if the indexing directory contains bowtie index
  if(!(-e "$bw2_index_path/$ref_file.1.bt2"))  {
    # build indexing from scratch
    #print "ReadMappingTophat::TophatCheckIndexing: No bowtie2 index is detected from the indexing directory...\n";
    #print "ReadMappingTophat::TophatCheckIndexing: Building indexing from scratch, may take a long time...\n";
    my $bw2_path = $hash->{"PATHCONF_BOWTIE2_HOME"};    
    if(!(-e "$bw2_path/bowtie2-build"))  {
      die "ReadMappingTophat::TophatCheckIndexing: Cannot find executable \"bowtie2-build\" from the Bowtie2 HOME directory \"$bw2_path\"...Exiting...\n";
    }
    # build bowtie2 index with default parameter (good for human genome)
    print "=====CipherRSeq: Bowtie2 index not found...Building bowtie2 index...=====\n";
    print "=====Command: $bw2_path/bowtie2-build $bw2_index_path/$ref_file\.fa $bw2_index_path/$ref_file=====\n";
    system "$bw2_path/bowtie2-build $bw2_index_path/$ref_file\.fa $bw2_index_path/$ref_file";
  }
  return;
}

# Description: run tophat2 with specified data and mode
# Author: Cuncong Zhong
# Date: 02/03/2015
# Input: the working directory, the reference to the path hash table; the reference to the work sheet hash table
# Output: N/A
# Format: N/A
# Sample usage: TophatMapping($work_directory, $path_hash, $work_hash);
sub TophatMapping($$$)	{
  my $work_directory = shift;
  my $path_hash = shift;
  my $work_hash = shift;
  # prepare indexing stem
  my $ref_file = Utilities::GetFileStem($path_hash->{"PATHCONF_REFGENOME_PATH"});
  $ref_file =~ s/\.fa$//g;
  my $index_stem = $path_hash->{"PATHCONF_BOWTIE2_INDEX_PATH"};
  $index_stem .= '/' . $ref_file;
  # prepare running mode
  my $run_mode = "--b2-sensitive";  # bowtie2 default
  if($work_hash->{"WORKSHEET_READMAPPING_TOPHAT2_MODE"} eq "FAST")  {
    $run_mode = "--b2-very-fast";
  } elsif($work_hash->{"WORKSHEET_READMAPPING_TOPHAT2_MODE"} eq "SENSITIVE") {
    $run_mode = "--b2-very-sensitive";
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
        my $data_to_map;
        if(scalar @decom == 1)  {   # single-end case
          if(-e "$work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed.fastq")  {
            $data_to_map = "$work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed.fastq";
          } else  {
            die "ReadMappingTophat::TophatMapping: $decom[0] is not quality trimmed...Exiting...\n";          
            #$data_to_map = $decom[0];    # if you want to map reads without quality trimming
          }
        } elsif(scalar @decom == 2)  {  # pair-end case
          if(-e "$work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_1P.fastq" &&
             -e "$work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_2P.fastq"
          )  {
            $data_to_map = "$work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_1P.fastq" . " " . "$work_directory/Preprocessing/$group/expr_$exp_index/$group\_expr$exp_index\_trimmed_2P.fastq";
          } else  {
            die "ReadMappingTophat::TophatMapping: $decom[0] or $decom[1] is not quality trimmed...Exiting...\n";          
            #$data_to_map = $decom[0] . " " . $decom[1];    # if you want to map reads withou qulity trimming
          }
        } else  {
          die "ReadMappingTophat::TophatMapping: Warning: Illy defined read group: $group_all...Exiting...\n";
        }
        if(!(-e "$work_directory/ReadMapping/$group/expr_$exp_index"))  {
          mkdir "$work_directory/ReadMapping/$group/expr_$exp_index" or die "Cannot create Tophat2 output directory\n";
        }
        print "=====CipherRSeq: Running Tophat2 mapping...=====\n";
        print "=====Command: tophat $run_mode -p $num_threads -o $work_directory/ReadMapping/$group/expr_$exp_index $index_stem $data_to_map=====\n";
        system "tophat2 $run_mode -p $num_threads -o $work_directory/ReadMapping/$group/expr_$exp_index $index_stem $data_to_map";
        ++ $exp_index;
      }
    }
  }
  return;
}

sub TophatCheckResults()	{
  # TODO: check integrity of the tophat2 output results
}

sub TophatCleanUp()	{
  # TODO: remove unwanted temporary files, if any
}

sub TophatFormatOutput()  {
  # TODO: provide interface for the consecutive analysis (rename/move output files)
}

# Description: the tophat2 driver
# Author: Cuncong Zhong
# Date: 02/03/2015
# Input: the working directory
# Output: N/A
# Format: N/A
# Sample usage: TophatRun($work_directory);
sub TophatRun($)	{
  my $work_directory = shift;
  $work_directory = abs_path($work_directory);
  # loading the settings
  my $path_config_file = $work_directory . '/' . 'PATH_CONFIG';
  my $work_sheet_file = $work_directory . '/' . 'WORK_SHEET';
  my $path_hash = TophatLoadPaths($path_config_file);
  my $work_hash = TophatLoadWorkSheet($work_sheet_file);  
  # copy the executables and create soft-links
  TophatPrepareRunEnvironment($work_directory, $path_hash);
  # setup the work directory
  TophatSetupWorkDirectory($work_directory, $work_hash);
  # check path validity
  TophatCheckPaths($path_hash);
  # prepare bowtie2 indexing, if necessary
  TophatCheckIndexing($path_hash);
  # run tophat2
  TophatMapping($work_directory, $path_hash, $work_hash);
  print "=====CipherRSeq: Tophat2 run finished. Congratulations!=====\n";
  return;
}

1;
