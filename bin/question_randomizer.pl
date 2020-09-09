#!/usr/bin/env perl

use v5.32;

use warnings;
use diagnostics;
use Getopt::Long;
use Try::Catch;
use lib "../lib/";
use Utility::Args;
use File::Slurp;
use Tie::File;
use List::Util 'shuffle';
use experimental 'signatures';
use Carp;

state $ascii_header = q(

    ____                  __                _                
   / __ \____ _____  ____/ /___  ____ ___  (_)___  ___  _____
  / /_/ / __ `/ __ \/ __  / __ \/ __ `__ \/ /_  / / _ \/ ___/
 / _, _/ /_/ / / / / /_/ / /_/ / / / / / / / / /_/  __/ /    
/_/ |_|\__,_/_/ /_/\__,_/\____/_/ /_/ /_/_/ /___/\___/_/     
                                                             
v0.1                                               09.09.2020
                                       
Created by Kevin Buman                                   
                                                             
);

state %args;

GetOptions( \%args, "master=s", "output=s", "help!" )
  or die( error_args() );

parse_args();
print_header();

my @input;
tie @input, 'Tie::File', $args{master} or die $!;

my $fn_output = $args{output}
  // get_processed_filename( extract_filename( $args{master} ) );

my @output;
tie @output, 'Tie::File', $fn_output or die $!;

# copy master file to the output file.
@output = @input;

# input is no longer needed;
untie @input;

shuffle_answers(@output);

sub shuffle_answers(@fh) {
    my @answers;

    for ( 0 .. $#fh ) {
        if ( $fh[$_] =~ /^\d+\./ ) {
            push @answers, { indices => [] };
        }
        elsif ( $fh[$_] =~ / \[ \s* /x ) {

            $fh[$_] = "adfs";
            if ( $#answers >= 0 ) {
                push $answers[-1]->{indices}->@*, $_;
            }
        }
    }

    for (@answers) {
        @fh[ $_->{indices}->@* ] = @fh[ shuffle $_->{indices}->@* ];
    }
}

sub parse_args() {
    if ( scalar( keys %args ) == 0 ) {
        usage();
        exit(1);
    }
    if ( $args{help} ) {
        usage();
        exit(0);
    }
    if ( !$args{master} ) {
        croak "No master file specified\n";
    }
    elsif ( !-f $args{master} || !-r $args{master} ) {
        croak "The file $args{master} cannot be read\n";
    }
}

sub print_header() {
    printf "%s", $ascii_header;
}

sub open_file($fn) {
    my $fh_output;
    open( $fh_output, ">", $fn )
      or die("Can't write to file '$fn' [$!]\n");
    return \$fh_output;
}
