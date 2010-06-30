#!/usr/bin/perl

#HISTORY
#2010-04-26
#-added STDERR to log file
#-added dir offset to make files in subdir samples
# now it needs to be run in ... Medienarchiv/Audio with the following command line
# mp3_samples2.pl -v -d samples Archiv/VII_78 Produktiv/VII_78

=head1 NAME

mp3_samples.pl

=head1 SYNOPSIS

	mp3_samples2.pl [-d dir] [-l n] [-v] source_dir target_dir

=head1 DESCRIPTION

This little script creates 30 sec samples from .wav files. It
will search source dir[ectory] recursively and create the samples relative to
target dir in the same directory structure.

MP3 cutting is handled by SoX. This script takes care of the filenames and
directories.

=head1 SWITCHES

-d dir	dir offset

-h		this short help text

-l n 	limit: stop after n files have been processed

-o		overwrite without warning

-v		be verbose

=cut

#pre-declare
sub verbose;
sub alternative;

use strict;
use warnings;
use Getopt::Std;
use Perl6::Say;
use File::Find;    #Rule?
use File::Spec;
use File::Path;

#initiate statistics
%main::count = (    #don't change these
	convert    => 0,
	identified => 0,
	file       => 0,
);

%main::config = (

	#change these if you will
	cmd => "/cygdrive/D/Programme/sox-14.3.0/sox",
	log => 'mp3_samples.log',
	search  => '.wav',           #act only files of this type (ending)
	replace => '.sample.mp3',    #rename files with this ending
	effects => "trim 10 34 fade 1 30 3 " . "remix - " . "riaa ",
);

#			$cmd .= "noisered /cygdrive/M/noise-profile"

getopts( 'd:hl:ov', \%main::opts );

help() if $main::opts{h};

if ( $main::opts{l} ) {

	#	die "Get here";
	if ( $main::opts{l} !~ /\A\d+\z/ ) {
		say "Error: Limit must be numeric!";
		exit 1;
	}

	#it doesn't get here with cygwin bash at least
	if ( $main::opts{l} < 1 ) {
		verbose "Warning: Limit must be at least 1.";
		$main::opts{l} = 1;
	}
}

#report on mode
verbose "Verbose mode on";
verbose "Limit is set to $main::opts{l}" if $main::opts{l};

#check input
die "Error: No source directory specified" if !$ARGV[0];
die "Error: No target directory specified" if !$ARGV[1];

#set initial values
$main::config{source} = $ARGV[0];
$main::config{target} = $ARGV[1];

#more checks
die "Error: Cannot find source directory"        if !-e $main::config{source};
die "Error: Source seems not to be a directory!" if !-d $main::config{source};
die "Error: Target exists, but is no directory"
  if -e $main::config{target} && !-d $main::config{target};

#make the target dir if necessary
if ( !-e $main::config{target} ) {
	mkdir $main::config{target} or die "Error: Cannot make target directory";
}

if ( $main::opts{d} ) {
	print "Dir offset: add this dir to target\n";
	print "\ttarget: $main::config{target}\n";
	print "\tdir offset: $main::opts{d}\n";
	$main::config{target} = "$main::config{target}/$main::opts{d}";
	if ( !-d "$main::config{target}" ) {
		mkdir $main::config{target}
		  or die "Error: Cannot make target directory";
	}
}

#Report initial values
verbose "Source dir: $main::config{source}";
verbose "Target dir: $main::config{target}";

#use absolute target, since File::Find change chdirs...
$main::config{target} = File::Spec->rel2abs( $main::config{target} );

#Loop over all files in $source_dir
verbose "Searching for *$main::config{search} files ...";

if ( -e $main::config{log} ) {
	unlink( $main::config{log} );
}
find( { wanted => \&each_file, no_chdir => 1 }, $main::config{source} );

#When done, report on what has been done
report();

#
# SUBS
#

#a_path/to/source_dir/trunk1/trunk2/file1.end
#another_path/to/target_dir
#

#split fully qualified filename in three parts
#source_dir/trunk/filename.end
#e.g. /path/to/source_dir/sub_dir/file1.end
#source_dir=/path/to/source_dir
#trunk=sub_dir
#filename=file1.end

sub each_file {

	#come here for every file (also dir) in source_dir
	++$main::count{file};

	#TODO:an optional status bar could be nice
	#verbose $_;

	#1st CHECK: only for files which end on the search pattern
	if ( $_ =~ /$main::config{search}$/i ) {

		verbose "\t$File::Find::name";

		my ( $trunk, $filename ) = truncate_path($File::Find::name);

		#mkdir in target if necessary
		my $target_dir_trunk =
		  File::Spec->canonpath(
			File::Spec->catfile( $main::config{target}, $trunk ) );
		die "Error: File exists where directory expected"
		  if ( -e $target_dir_trunk && !-d $target_dir_trunk );

		if ( !-e $target_dir_trunk ) {
			verbose
"directory in target does not exist, will make it:$target_dir_trunk";
			mkpath($target_dir_trunk);
		}

		#2nd CHECK: only for real files (not dirs)
		if ( !-d $File::Find::name ) {
			++$main::count{identified};

			#make new target filename (filename has no path here)
			my $new_fn = $filename;
			$new_fn =~ s/$main::config{search}$/$main::config{replace}/i;

			#verbose "\t$target_fn";

			#make target full path
			my $target_full_fn =
			  File::Spec->canonpath(
				File::Spec->catfile( $target_dir_trunk, $new_fn ) );

			#verbose "\t$target_path";

			#3rd CHECK: act only if file does not yet exist
			if ( ( !-e $target_full_fn ) or $main::opts{o} ) {
				work( $File::Find::name, $target_full_fn );
			}
			else {
				verbose "\t\texists already: $target_full_fn";
			}
		}
	}
	if ( $main::opts{l} ) {

		if ( $main::opts{l} == $main::count{identified} ) {
			verbose
			  "Stop here due limit option. $main::opts{l} file(s) processed";
			report();
		}
	}
}

sub help {
	system "perldoc $0";
	exit;
}

sub report {
	verbose "REPORT";
	verbose "$main::count{file} files found (including dirs).";
	verbose "$main::count{identified} $main::config{search} files identified.";
	verbose "$main::count{convert} attempted conversion during this run.";
	exit 0;
}

sub truncate_path {

	#return only that part of the path that is relative to source
	#this part of the path might have to created in target
	my $filepath = shift;

	my ( $volume, $directories, $file ) = File::Spec->splitpath($filepath);

	my $trunk = $directories;
	$trunk =~ s/$main::config{source}//;
	$trunk = File::Spec->canonpath($trunk);

	#DEBUG
	#say "\t$filepath (file name alone)";
	#say "\t\t$File::Find::name (full path)";

	#say "\t\t$directories | $file (dir | file)";
	#say "\t\t$trunk (trunk)";
	return $trunk, $file;
}

sub verbose {
	warn "Less parameters passed to verbose than expected" if $#_ < 0;
	warn "More parameters passed to verbose than expected" if $#_ > 0;

	my $text = shift;

	say $text if $main::opts{v};
}

sub work {

	#get here to execute the actual command
	my $item_a = shift;    # one specific file in source_dir
	my $item_b = shift;    # its analogon in target_dir

	#output diagnotic message on what you're doing
	#both with verbose on and off
	say "$item_a" if !$main::opts{v};
	open LOG, '>>', $main::config{log} or die $!;
	print LOG "$item_a\n";
	close LOG;
	verbose "\t\t-> $item_b";

	my $cmd = "$main::config{cmd} ";

	#$cmd .= "-V " if $main::opts{v};
	$cmd .= "'$item_a' '$item_b' " . $main::config{effects};
	$cmd .= " 2>>$main::config{log}";
	system($cmd);
	++$main::count{convert};

}
