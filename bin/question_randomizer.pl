#!/usr/bin/env perl

use v5.32;

use warnings;
use diagnostics;
use Getopt::Long;
use Try::Catch;
use lib "../lib/";
use Utility::Args;
use File::Slurp;
use List::Util 'shuffle';
use experimental 'signatures';
use Carp;


state $ascii_header = 
q(

    ____                  __                _                
   / __ \____ _____  ____/ /___  ____ ___  (_)___  ___  _____
  / /_/ / __ `/ __ \/ __  / __ \/ __ `__ \/ /_  / / _ \/ ___/
 / _, _/ /_/ / / / / /_/ / /_/ / / / / / / / / /_/  __/ /    
/_/ |_|\__,_/_/ /_/\__,_/\____/_/ /_/ /_/_/ /___/\___/_/     
                                                             
v0.1                                               09.09.2020
                                       
Created by Kevin Buman                                   
                                                             
);
state %args;


GetOptions( \%args, 
            "master=s", 
            "output=s", 
            "help!" )
or die("Error in command line arguments\n");


parse_args();
print_header();


sub parse_args() {
    if (scalar(keys %args) == 0) {
        usage();   
        exit(1);
    }
    if ( $args{help}) {
        usage();   
        exit(0);
    }
    if (! $args{master}) {
        croak "No master file specified\n";
    }
    elsif ( !-f $args{master} || !-r $args{master} ) {
        croak "The file $args{master} cannot be read\n";
    }
}

sub print_header() {  
    printf "%s", $ascii_header;
}