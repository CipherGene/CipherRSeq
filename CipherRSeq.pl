#!/usr/bin/perl -w
use strict;
use PreprocessingTrimmomatic qw(:TRIMMOMATIC);
use ReadMappingTophat qw(:TOPHAT);
use DiffExpressionCuffdiff qw(:CUFFDIFF);

my $work_directory = shift;

PreprocessingTrimmomatic::TrimmomaticRun($work_directory);
ReadMappingTophat::TophatRun($work_directory);
DiffExpressionCuffdiff::CuffdiffRun($work_directory);
