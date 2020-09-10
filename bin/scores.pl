#!/usr/bin/env perl

use v5.32;

use warnings;
use diagnostics;
use experimental 'signatures';
use Carp;

use Getopt::Long;
use Try::Catch;
use List::Util 'shuffle';
use Tie::File;

use lib "../lib/";
use Utility;

# Ascii header
state $ascii_header = q(


  /$$$$$$                                                   
 /$$__  $$                                                  
| $$  \__/  /$$$$$$$  /$$$$$$   /$$$$$$   /$$$$$$   /$$$$$$$
|  $$$$$$  /$$_____/ /$$__  $$ /$$__  $$ /$$__  $$ /$$_____/
 \____  $$| $$      | $$  \ $$| $$  \__/| $$$$$$$$|  $$$$$$ 
 /$$  \ $$| $$      | $$  | $$| $$      | $$_____/ \____  $$
|  $$$$$$/|  $$$$$$$|  $$$$$$/| $$      |  $$$$$$$ /$$$$$$$/
 \______/  \_______/ \______/ |__/       \_______/|_______/ 
                                                            
                                                            
v0.1                                               10.09.2020
                                       
Created by Kevin Buman                                   
                                                             
);

state %args;
state @submission_filenames;


Print::print_header($ascii_header);

# Read flags and store values in the hash
GetOptions( \%args, "master=s", "submissions=s{,}" => \@submission_filenames, "help!" )
  or die( Args::error_args() );

parse_args();

Print::print_progress("Opening master\t\t$args{master}");

parse_master();


sub parse_master() {
    Print::print_progress("Processing master");
    my $fh;
    try {
        open ($fh, $args{master});
    } catch {
        
    };

    my @questions; 

    foreach my $line (<$fh>)  {
        my $previous_line_was_question = 0;
        # check if the current line is the beginning of a question
        if ( $line =~ /^\d+\./ ) {

            # add new hash to @questions
            push @questions, { question => $line, answers => [] };
            $previous_line_was_question = 1;
        }
        elsif ( $line =~ /\w+/ ) {
            say $line;
            # say $previous_line_was_question;
            if ( $previous_line_was_question == 1 ) {
                # say $line;
                $questions[-1]->{question} .= $line;
            }
        }
        else {
            $previous_line_was_question = 0;
        }
    }
    close($fh);
    # for (@questions) {
    #     say $_->{question};
    # }
}

sub usage {
    print
"Usage:\n\trandomizer command syntax:\n\n\t\t./randomizer [options] [arguments]\n\n\tGeneric command options:\n\n";
    print "\t\t-f, --file:\tSpecify the file to be processed.\n";
    print "\t\t-o, --output:\tSpecify the output file.\n";
    print "\t\t-h, --help:\tRead more detailed instructions.\n";
    print "\n";
}

sub parse_args() {

    if ( scalar( keys %args ) == 0 ) {
        usage();
        exit(0);
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
