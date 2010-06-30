#!/usr/bin/perl

=head1 NAME

mk_mp3s.pl

=head1 SYNOPSIS

	mk_mp3_dir.pl [-i] source_dir target_dir

=head1 DESCRIPTION

This little script converts wav-files in the source directory recursively
to mp3 files in target. Sub directories in source are re-created in target.

WAV to MP3 is handled by SoX. This script takes care of the filenames and
directories.

=head1 SWITCHES

-i	interactive (does not ask as much as it could, TODO)
-h	this short help text
-v	be verbose

=head1 ISSUES / TODO

=over1

=item counterpart

Should I also deal with "false positives" with mp3s that have no wavs anymore?
I could check that they have a counterpart and suggest to delete them.

=item module

I could write a module that checks for better integrety. I would define source/target pairs
in a config file. I would make the samples from the originals if possible and convert from preferably from wav to mp3.

=item check_orphaned

check_orphaned:loop over target and check which mp3s have no equivalent in source anymore, report them back, delete them

=back


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
#use IO::Prompt;

#initiate statistics
$main::config{wavfile_count} = 0;
$main::config{convert_count} = 0;
$main::config{file_count}    = 0;

my $sox = "/cygdrive/C/oracle/ora92/bin/sox";

getopts( 'hiv', \%main::opts );

help() if $main::opts{h};

#report on mode
verbose "Verbose mode on";

die "Interactive mode not available on this machine" if $main::opts{i};

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
	if ( $main::opts{i} ) {
		my $ret = 0;
		while ( $ret !~ /y|n/ ) {
			$ret = prompt(
				"Target directory does not exist. Want me to create it? (y/n) ",
				-yn
			);
		}
		if ( $ret eq "n" ) {
			say "No target directory. Quit here.";
			exit;
		}
	}
	mkdir $main::config{target} or die "Error: Cannot make target directory";
}

#Report initial values
verbose "Source dir: $main::config{source}";
verbose "Target dir: $main::config{target}";

if ( $main::opts{i} ) {
	my $ret;
	while ( $ret !~ /y|n/ ) {
		$ret = prompt( "Continue? (y/n) ", -yn );
	}
	if ( $ret eq "n" ) {
		say "Okay, exit here.";
		exit;
	}
}

#todo
if ($main::opts{c}) {
	check_orphans();
}


#use absolute target, since File::Find change chdirs...
#alternative would be to save the current path
#or to not to change dir
$main::config{target} = File::Spec->rel2abs( $main::config{target} );
#todo
#$main::config{source} = File::Spec->rel2abs( $main::config{source} );

#
# Let's start
#

verbose "Searching for *.wav files ...";
find( { wanted => \&each_source_file, no_chdir => 1 }, $main::config{source} );

#
# Report on what has been done
#
verbose "REPORT";
verbose "$main::config{file_count} files encountered.";
verbose "$main::config{wavfile_count} *.wav files encountered.";
verbose "$main::config{convert_count} attempted conversion during this run.";

#
# SUBS
#
sub check_orphans{
	#TODO
	say "CHECK ORPHANS\n";
	sub each_mp3 {
		verbose $_;
		my $new=target2source_path ($_);
		verbose "\t->$new";


	}
	sub each_target_file {
		each_mp3() if ( $_ =~ /.mp3$|.MP3$/ && $_ !~ /.sample.mp3$/);
	}

	find( { wanted => \&each_target_file, no_chdir => 1 }, $main::config{target} );


	exit;

}


sub each_source_file {
	#TODO
	++$main::config{file_count};

	#come here for every file in source
	#TODO:an optional status bar could be nice
	#verbose $_;

	each_wav() if ( $_ =~ /.wav$/i );
}

sub source2target_path {
	#expect a file path inside source
	#return the equivalent target
	my $source_path= shift;

	my ( $trunk, $filename ) = truncate_path($File::Find::name);

	my $new_target_dir =
	  File::Spec->canonpath(
		File::Spec->catfile( $main::config{target}, $trunk ) );

	die "Error: File exists where directory expected"
	  if ( -e $new_target_dir && !-d $new_target_dir );

	if ( !-e $new_target_dir ) {
		verbose
		  "directory in target does not exist, will make it:$new_target_dir";
		mkpath( $new_target_dir);
	}

	my $target_fn = $filename;
	$target_fn =~ s/.wav$/.mp3/i;

	my $target_path =
	  File::Spec->canonpath(
		File::Spec->catfile( $new_target_dir, $target_fn ) );

	return $target_path;
}

sub target2source_path {
	#expects a file path in target and returns the equivalent in source
	my $target_path=shift;

	my ( $trunk, $filename ) = truncate_path($File::Find::name);

	my $source_dir =
	  File::Spec->canonpath(
		File::Spec->catfile( $main::config{source}, $trunk ) );

	die "Error: File exists where directory expected"
	  if ( -e $source_dir && !-d $source_dir );

	if ( !-e $source_dir ) {
		verbose
		  "directory in source does not exist, will make it:$source_dir";
		mkpath( $source_dir);
	}

	my $source_fn = $filename;
	$source_fn =~ s/.mp3$/.wav/i;

	my $source_path =
	  File::Spec->canonpath(
		File::Spec->catfile( $source_dir, $source_fn ) );

	return $source_path;
}

sub each_wav {

	#get here for every *.wav file in source
	verbose "\t$File::Find::name";
	++$main::config{wavfile_count};

	my $target_path=source2target_path($File::Find::name);
	verbose "\t$target_path";

	if ( !-e $target_path ) {
		say "$File::Find::name" if ! $main::opts{v};
		#only make new mp3 if not yet already there
		verbose "\t\t-> $target_path";
		my $cmd = "$sox ";

		#$cmd .= "-V " if $main::opts{v};
		$cmd .= "$File::Find::name $target_path";
		system($cmd);
		++$main::config{convert_count};
	}
	else {
		verbose "\t\texists already: $target_path";
	}

	my $sample_fn=$target_path;
	$sample_fn=~s/\.mp3$/\.sample\.mp3/i;

	if ( !-e $sample_fn ) {
		#only make new mp3 if not yet already there
		verbose "\t\t-> $sample_fn";
		my $cmd = "$sox ";
		$cmd .= "$File::Find::name $sample_fn trim 0 30";
		system($cmd);
#		++$main::config{sample_count};
	}
	
	
	


}

sub help {
	system "perldoc $0";
	exit;
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
