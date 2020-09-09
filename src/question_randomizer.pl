#!/usr/bin/env perl

use v5.32;

use warnings;
use diagnostics;
use Getopt::Long;
use Try::Catch;
use File::Slurp;
use List::Util 'shuffle';
use experimental 'signatures';


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
            "file=s", 
            "output=s", 
            "help!" )
or die("Error in command line arguments\n");


print_header();

say $args{"file"};



sub print_header() {  
    printf "%s", $ascii_header;
}