#!/usr/bin/perl
use strict;
use warnings;
#use File::Basename;
use File::Copy;

my $left="/cygdrive/S/MIMO/Fotos/Scans";
my $right="/cygdrive/M/MuseumPlus/Produktiv/Multimedia/EM/Musikethnologie/Fotos/Daniela";


#compare every file in left folder with right folder
#I assume that files with equal names exist in both folders (e.g. after copying)
#act only if files are different size
#rename file and move it to the right

die "Problem with left $left" unless -d $left;
die "Problem with right $right" unless -d $right; 

opendir(my $dh, $left ) || die "can't opendir left: $!";
#my @files  = grep { /^\./ && -f "$left/$_" } readdir($dh);
my @files  = grep { (!/^\./) && -f "$left/$_" && $_ =~ /.tif$/} readdir($dh);
my $count=0;
foreach (@files) {
	#my ($name,$path,$suffix) = fileparse($_);
	#print "$_\n";
	my $left_fn="$left/$_";
	my $right_fn="$right/$_";
	
	if (-f $right_fn) {
		#print "\tFile exists on the right\n";
		if (-s $left_fn != -s $right_fn) {
			print "$_\n";
			#print "\t\tSize not equal\n"; 
			my $base=$_;
			$base=~s/.tif$//i;
			my $i=2;
			my $new_fn=$base."_$i.tif";
			if (!-e "$right/$new_fn") {
				print "\t!$new_fn\n";			
				 copy($left_fn,"$right/$new_fn") or die "Copy failed: $!";
			} else {
				warn "_2 exists already!!!!!!!!!!!!!!!!!";
			}
			$count++;
		}
	}
}

print "Total $count\n";
#   3. closedir $dh;