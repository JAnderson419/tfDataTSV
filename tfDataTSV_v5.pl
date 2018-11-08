#!/usr/local/bin/perl

# Jackson Anderson
# v1 - Spring 2015 - Senior Design
# Microelectronic Engineering - Rochester Institute of Technology
# 
# For use parsing dynamic hysteresis measurements made on the TF Analyzer 1000
# Reads .dat files and outputs a folder named after the .dat file 
# with seperate .tsv files for each measurement table
#
# v2 Release Notes:
# Removes []+-/ from headers since matlab confuses them on tdfread
#
# v3 Release Notes:
# Karine: Added table number as unique measurement identifier
#
# v4
# Added initial support for fatigue & PUND measurements 
# Removed $number - same thing as $table
#
# v5 (2017):
# Added initial support for leakage current measurements
#

use strict;
use warnings;
use Cwd;


my $fileName = '';
my $summaryTableRead = 0;
my $isDataTable = 0;
my $isDataTableHeader = 1;
my $firstline = 1;
my ($table, $sampleName, $frequency, $amplitude, $average, $cycles, $type, $stepDur);

my $workingDir = getcwd;
opendir(DIR, $workingDir) or die;
my @dir = readdir DIR;
foreach my $item (@dir) {
   print "$item\n";
}
closedir DIR;

print "Enter the .dat filename (with extension) you would like to parse\n";
$fileName = <STDIN>;
chomp $fileName;
unless (-e $fileName) {
    print "File not found. Exiting.\n";
    exit;
}

my $dirName = substr ($fileName,0,length($fileName)-4);

unless(-e $dirName or mkdir $dirName) {
        die "Unable to create $fileName\n";
    }

open DATA, "<", $fileName;

while (<DATA>) {
    chomp;
	# Determine which type of measurement this is. Later file syntax is determined by measurement type.
    if ($firstline){
        $type = 0 if /DynamicHysteresisResult/;
        $type = 1 if /Fatigue/;
        $type = 2 if /PulseResult/;
        $type = 3 if /LeakageResult/;
        $firstline = 0;
    }
    s/\t$//;
    #Skip reading lines until end of measurement summary table detected
    $summaryTableRead = 1 if /^DynamicHysteresis$/ or /^Data Table/ or /^Pulse$/ or /^Leakage$/;
    next unless $summaryTableRead;

	# Store relavant sample information from table header. Available information depends on measurement type
    $table = $1 if /Table (\[*\d*.*\d*\]*)/;
    $sampleName = $1 if /SampleName: (.*)/;
    if ($type == 0 or $type == 1) {
        $frequency = $1 if /Hysteresis Frequency \[Hz\]: (\d*)/;
        $amplitude = $1 if /Hysteresis Amplitude \[V\]: (\d*)/;
    }
    elsif ($type == 2) {
        $frequency = $1 if /Pund Frequency \[Hz\]: (\d*)/;
        $amplitude = $1 if /Pund Amplitude \[V\]: (\d*)/;
    }
    elsif ($type == 3){
        $stepDur = $1 if /Step Duration \[s\]: (\d*)/;
    }
    $average = $1 if /Averages: (.*)/;
    $cycles = $1 if /Total Cycles: (\d*)/;
    if ($type !=3) {
        $isDataTable = 1 if /^Time \[s\]/;
    }
    elsif ($type == 3) {
        $isDataTable = 1 if /^Voltage \[V\]/;
    }
	# Data table has been reached
    if ($isDataTable){
		# Define unique save file name based on header info and measurement type
        my $datapath;
        $datapath = "$dirName\\$sampleName $frequency".'Hz '."$amplitude".'V '."$average".'Average Table'."$table".'.tsv' if $type == 0;
        $datapath = "$dirName\\$sampleName $frequency".'Hz '."$amplitude".'V '."$average".'Average Table'."$table $cycles".'Cycles.tsv' if $type == 1;
        $datapath = "$dirName\\$sampleName $frequency".'Hz '."$amplitude".'V Table'."$table".'.tsv' if $type == 2;
        $datapath = "$dirName\\$sampleName $stepDur".'s step '.'Table'."$table".'.tsv' if $type == 3;
        # If path is not defined, code did not recognize measurement type. Print error and close
		unless(defined $datapath) {
            die "Measurement type not recognized";
        }
		# First line of data table is header. Substitutions made for some symbols.
        $isDataTableHeader ? (open DATAFILE, ">" , $datapath) : (open DATAFILE, ">>",$datapath);
        if ($isDataTableHeader) {
            $isDataTableHeader = 0;
            s/\[//g;
            s/\]//g;
            s/\//_per_/g;
            s/\+/plus/g;
            s/-/minus/g;
        }
		# Information printed to file
        print DATAFILE;
        print DATAFILE "\n";
        if (/^$/) {
			# End of table reached, close file and reset data table and data table header flags.
            $isDataTable = 0;
            $isDataTableHeader = 1;
            close DATAFILE;
        }
    }
}
close DATA;
exit;


