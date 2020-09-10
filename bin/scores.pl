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


  /$$$$$$                                                   
 /$$__  $$                                                  
| $$  \__/  /$$$$$$$  /$$$$$$   /$$$$$$   /$$$$$$   /$$$$$$$
|  $$$$$$  /$$_____/ /$$__  $$ /$$__  $$ /$$__  $$ /$$_____/
 \____  $$| $$      | $$  \ $$| $$  \__/| $$$$$$$$|  $$$$$$ 
 /$$  \ $$| $$      | $$  | $$| $$      | $$_____/ \____  $$
|  $$$$$$/|  $$$$$$$|  $$$$$$/| $$      |  $$$$$$$ /$$$$$$$/
 \______/  \_______/ \______/ |__/       \_______/|_______/ 
                                                            
                                                            
v0.1                                               09.09.2020
                                       
Created by Kevin Buman                                   
                                                             
);

state %args;

Print::print_header($ascii_header);

# Read flags and store values in the hash
GetOptions( \%args, "master=s", "submissions=s{,}", "help!" )
  or die( Args::error_args() );

parse_args();

sub parse_args() {
    my $argc  = keys %args;
    my @paths = ();
    if ( $argc > 2 ) {
        warn "\nToo many arguments. See --help for more information.\n\n";
        die("too_many_args");
    }
    elsif ( $argc == 0 ) {
        warn "\nToo few arguments. See --help for more information.\n\n";
        die("too_few_args");
    }
    elsif ( $argc == 2 && $args->{"help"} ) {
        warn "\nWrong usage. See --help for more information.\n\n";
        die("wrong_args");
    }
    elsif ( $argc == 1 && $args->{"help"} ) {
        _usage();
        exit(0);
    }
    elsif ( $argc != 2 && !( $args->{"master"} && $args->{"submissions"} ) ) {
        error_args();
        die("error_args");
    }
    else {
        @paths[0] = $args->{"master"};
        @paths[1] = $args->{"submissions"};
    }
    return @paths;
}

sub usage {
    print
"Usage:\n\trandomizer command syntax:\n\n\t\t./randomizer [options] [arguments]\n\n\tGeneric command options:\n\n";
    print "\t\t-f, --file:\tSpecify the file to be processed.\n";
    print "\t\t-o, --output:\tSpecify the output file.\n";
    print "\t\t-h, --help:\tRead more detailed instructions.\n";
    print "\n";
}
