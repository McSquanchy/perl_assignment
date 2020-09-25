#!/usr/bin/env perl

use v5.32;

use warnings;
use diagnostics;
use experimental 'signatures';
use Carp;
use Getopt::Long;
use List::Util 'shuffle';
use Tie::File;

use lib "../lib/";
use Utility;

# Ascii header
state $ascii_header = q(

    ____                  __                _                
   / __ \____ _____  ____/ /___  ____ ___  (_)___  ___  _____
  / /_/ / __ `/ __ \/ __  / __ \/ __ `__ \/ /_  / / _ \/ ___/
 / _, _/ /_/ / / / / /_/ / /_/ / / / / / / / / /_/  __/ /    
/_/ |_|\__,_/_/ /_/\__,_/\____/_/ /_/ /_/_/ /___/\___/_/     
                                                             
v1.0                                               25.09.2020
                                       
Created by Kevin Buman                                   
                                                             
);

# Holds command-line args
state %args;

# Read flags and store values in the hash
GetOptions( \%args, "master=s", "output=s", "help!", "silent!" )
  or die( Args::error_args() );

Print::print_header($ascii_header);
parse_args();

# default value if not provided by the user
my $fn_output = $args{output}
  // Args::get_processed_filename( Args::extract_filename( $args{master} ) );

# arrays to tie both files to
my @input;
my @output;

Print::print_progress("Opening master\t\t$args{master}");

# tie input file to @input
tie @input, 'Tie::File', $args{master} or die $!;

Print::print_progress("Creating file\t\t$fn_output");

# tie output file to @output
tie @output, 'Tie::File', $fn_output or die $!;

Print::print_progress("Copying content");

# copy master file content to the output file.
@output = @input;

# cleanup input tie;
untie @input;

shuffle_answers( \@output );

# cleanup output tie;
untie @output;

Print::print_progress("\nFinished execution.\tSee output file $fn_output\n\n");

#
# Shuffle answers and replace correct answers
sub shuffle_answers($fh) {

    # holds a hash for each question
    my @answers;

    Print::print_progress("Removing indicators");

    # loop through all lines of $fh
    for ( 0 .. scalar( $fh->@* ) - 1 ) {

        # check if the current line is the beginning of a question
        if ( $fh->[$_] =~ /^\d+ \. /x ) {

            # add new hash to @answers
            push @answers, { indices => [] };
        }

        # check if current line contains an answer
        elsif ( $fh->[$_] =~ / \[ \s* /x ) {

            # check if we've seen a question before
            if ( scalar @answers > 0 ) {

                # replace the marker X or x with a blank space
                $fh->[$_] =~ s/ \[ \s* \S \s* \] /\[ \]/x;

                # add line index to the array referenced by {indices}
                push $answers[-1]->{indices}->@*, $_;
            }
        }
    }

    Print::print_progress("Shuffling lines");

    # loop through all indices of @answers
    for (@answers) {

        # shuffle answers of the current section
        $fh->@[ $_->{indices}->@* ] = $fh->@[ shuffle( $_->{indices}->@* ) ];
    }
}

#
# Parse arguments
sub parse_args() {

    # display usage if no arguments supplied
    if ( scalar( keys %args ) == 0 ) {
        usage();
        exit(1);
    }

    # display help if -h/--help present
    if ( $args{help} ) {
        usage();
        exit(0);
    }

    # set silent flag to true to disable console logs
    if ( $args{silent} ) {
        Print::set_silent();
    }

    # display error if no master file specified
    if ( !$args{master} ) {
        croak "No master file specified\n";
    }

    # check if master file doesn't exist or cannot be read
    elsif ( !-f $args{master} || !-r $args{master} ) {
        croak "The file $args{master} cannot be read\n";
    }
}

#
# Print help to STDOUT
sub usage() {
    print
"\nUsage:\n\trandomizer command syntax:\n\n\t./randomizer [options] [arguments] [optional arguments]\n\n\tGeneric command options:\n\n";
    print "\t\t-m, --master:\tSpecify the file to be processed.\n";
    print "\t\t-h, --help:\tRead more detailed instructions.\n";
    print "\t\t-s, --silent:\tDisable progress output to STDOUT.\n";
    print "\n\tOptional parameters:\n\n";
    print "\t\t-o, --output:\tSpecify the output file.\n";
    print "\n";
}
