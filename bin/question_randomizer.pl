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
use Utility::Args;

# Ascii header
state $ascii_header = q(

    ____                  __                _                
   / __ \____ _____  ____/ /___  ____ ___  (_)___  ___  _____
  / /_/ / __ `/ __ \/ __  / __ \/ __ `__ \/ /_  / / _ \/ ___/
 / _, _/ /_/ / / / / /_/ / /_/ / / / / / / / / /_/  __/ /    
/_/ |_|\__,_/_/ /_/\__,_/\____/_/ /_/ /_/_/ /___/\___/_/     
                                                             
v0.2                                               09.09.2020
                                       
Created by Kevin Buman                                   
                                                             
);

# Holds command-line args
state %args;

# Read flags and store values in the hash
GetOptions( \%args, "master=s", "output=s", "help!" )
  or die( error_args() );

parse_args();
print_header();

my $fn_output = $args{output}
  // get_processed_filename( extract_filename( $args{master} ) );

my @input;
my @output;

print_progress("Opening master\t\t$args{master}");
# tie input file to @input
tie @input, 'Tie::File', $args{master} or die $!;

print_progress("Creating file\t\t$fn_output");
# tie output file to @output
tie @output, 'Tie::File', $fn_output or die $!;

print_progress("Copying content");
# copy master file content to the output file.
@output = @input;
# cleanup input tie;
untie @input;

shuffle_answers(\@output);

print_progress("Cleaning up");

# cleanup output tie;
untie @output;

print_progress("\nFinished execution.\tSee output file $fn_output\n\n");

#
# Shuffle answers and replace correct answers
sub shuffle_answers($fh) {
    # holds a hash for each question
    my @answers;

    print_progress("Removing indicators");

    # loop through all lines of $fh
    for ( 0 .. scalar($fh->@*)-1) {

        # check if the current line is the beginning of a question
        if ( $fh->[$_] =~ /^\d+\./ ) {
            # add new hash to @answers
            push @answers, { indices => [] };
        }

        # check if current line contains an answer
        elsif ( $fh->[$_] =~ / \[ \s* /x ) {

            # replace the marker X or x with a blank space
            $fh->[$_] =~ s/ \[ [X,x] /\[ /x;
            # check if we've seen a question before
            if ( $#answers >= 0 ) {

                # add line index to the array referenced by {indices}
                push $answers[-1]->{indices}->@*, $_;
            }
        }
    }
    
    print_progress("Shuffling lines");

    # loop through all indices of @answers
    for (@answers) {

        # shuffle answers of the current section
        $fh->@[ $_->{indices}->@* ] = $fh->@[ shuffle ($_->{indices}->@*) ];
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
# Print the ascii text at the beginning of the execution
sub print_header() {
    printf "%s", $ascii_header;
}

#
# Print the current state to STDOUT
sub print_progress($string) {
    printf "%s\n", $string;
}
