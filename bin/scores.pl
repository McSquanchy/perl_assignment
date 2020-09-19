#!/usr/bin/env perl

use v5.32;

use warnings;
use diagnostics;
use experimental 'signatures';
use experimental 'smartmatch';
use Carp;

use Getopt::Long;
use Try::Catch;
use String::Util "trim";
use List::Util 'shuffle';
use List::MoreUtils qw(firstidx);
use List::MoreUtils qw(uniq);
use Regexp::Grammars;

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
                                                            
                                                            
v0.3                                               16.09.2020
                                       
Created by Kevin Buman                                   
                                                             
);

my $master_parser = qr {

    <master>

    <nocontext:>

    <rule: master>
        <[master_component]>*

    <rule: master_component>
        <question_and_answers> | <decoration>

    <rule: question_and_answers>
        <question>
        <[answer]>+
        <.empty_line>
    
    <token: question>
        \s* <q_nr> <text>

    <token: answer>
        \s* <checkbox> <text>

    <token: q_nr>
        \d+ \.
    
    <token: text>
        \N* \n
        (?: \N* \S \N \n*)*?
    
    <token: checkbox>
        \[ . \]

    <token: decoration>
        \N* \n
    
    <token: empty_line>
        \s* \n

};

my $submission_parser = qr{

    <exam_submission>

    <nocontext:>

    <rule: exam_submission>
        <[exam_component]>*

    <rule: exam_component>
        <question_and_answers> | <decoration>

    <rule: question_and_answers>
        <question>
        <[answer]>+
        <.empty_line>
    
    <token: question>
        \s* <q_nr> <text>

    <token: answer>
        \s* <checkbox> <text>

    <token: q_nr>
        \d+ \.
    
    <token: text>
        \N* \n
        (?: \N* \S \N \n*)*?
    
    <token: checkbox>
        \[ . \]

    <token: decoration>
        \N* \n
    
    <token: empty_line>
        \s* \n

};

state %args;
state @master_parse;
state %submissions;
state @submission_filenames;

Print::print_header($ascii_header);

# Read flags and store values in the hash
GetOptions(
    \%args, "master=s",
    "submissions=s{,}" => \@submission_filenames,
    "help!"
) or die( Args::error_args() );

parse_args();

Print::print_progress("Opening master\t\t$args{master}");

parse_master();
parse_submissions();
validate_completeness();
grade_submissions();
use Data::Show;

# my $test = trim(qq(perl's          three main types of call context (or "amount context") are:));
# $test =~ s/\s* {2,} / /;
# show lc($test);

# my $test2 = 'If the array @x contains four elements,
#     how many elements will be in the list (1, @x, 2)?';
# $test2 =~ s/\s* {2,} / /;
# show lc($test2);



sub parse_master() {
    Print::print_progress("Parsing master");

    my $fh;

    open( $fh, $args{master} ) or die "error accessing file";

    my $exam_text = do { local $/; readline($fh) };
    if ( $exam_text =~ $master_parser ) {
        @master_parse = grep( $_->{question_and_answers},
            $/{master}->{master_component}->@* );
    }
    else {
        die "not valid!!";
    }
    close($fh);
}

sub parse_submissions() {
    Print::print_progress("Parsing submissions");
    for my $submission (@submission_filenames) {
        my $fh;

        open( $fh, $submission ) or die "error accessing file";

        my $exam_text = do { local $/; readline($fh) };
        if ( $exam_text =~ $submission_parser ) {
            my @questions_and_answers = grep( $_->{question_and_answers},
                $/{exam_submission}->{exam_component}->@* );
            $submissions{$submission} = \@questions_and_answers;
        }
        else {
            warn "not valid!!";
        }
        close($fh);
    }
}

sub validate_completeness() {
    Print::print_progress("Checking for completeness");   

    my @master_questions =
      map { $_->{question_and_answers}{question}{text} =~ s/^\s+|\s+$//gr }
      @master_parse;
    my @master_answers =
      ( map { $_->{question_and_answers}{answer}->@* } @master_parse );
    @master_answers = map { $_->{text} =~ s/^\s+|\s+$//gr } @master_answers;


    for my $sub ( keys %submissions ) {
        printf "\n%s:\n", FilePaths::get_filename($sub);
        check_missing_q_a( $submissions{$sub} );

    }
}

sub check_missing_q_a($submission) {
    my @submission_questions =
      map { $_->{question_and_answers}{question}{text} } $submission->@*;

    for ( 0 .. $#master_parse ) {
        my $cnt            = $_;
        my @master_answers = map { $_->{text} }
          $master_parse[$cnt]->{question_and_answers}{answer}->@*;
        my ($missing_question) =
          $master_parse[$cnt]->{question_and_answers}{question}{text} =~
          s/^\s+|\s+$//gr;
        my $i = firstidx {
            $_ eq $master_parse[$cnt]->{question_and_answers}{question}{text}
        }
        @submission_questions;
        if ( $i < 0 ) {
            printf "\tmissing question: %s %s\n",
            $master_parse[$cnt]->{question_and_answers}{question}{q_nr},
              $missing_question =~ s/\s{2,}/ /gr;

        }
        else {
            my $missing       = undef;
            my @given_answers = map { $_->{text} }
              $submission->[$i]->{question_and_answers}{answer}->@*;

            for my $answer (@master_answers) {
                if ( !( $answer ~~ @given_answers ) ) {
                    if ( !$missing ) {
                        printf "\tquestion: %s %s\n",
                        $submission->[$i]->{question_and_answers}{question}{q_nr},
                          $missing_question =~ s/\s{2,}/ /gr;
                        $missing = 1;
                    }
                    printf "\t\tmissing answer: %s\n",
                      $answer =~ s/^\s+|\s+$//gr;
                }
            }
        }
    }
}

sub grade_submissions() {
    use Data::Show;
    Print::print_progress("\n\nComputing scores\n");
    for my $sub ( keys %submissions ) {
        printf "%s", pad(Args::extract_filename($sub), 60, "r", ".", 1);
        my $nr_of_questions = uniq map { $_->{question_and_answers}{question}{text} } $submissions{$sub}->@*;
        my $correct_count = 0;
        my @sub_array = uniq $submissions{$sub}->@*;
        for my $entry(@sub_array) {
  
            my @correct_answer = grep $_->{checkbox} =~ / \[ [X,x] /x, $entry->{question_and_answers}{answer}->@*;
 
            next if(scalar @correct_answer != 1);
    
            my $match = (grep {lc(trim($_->{question_and_answers}{question}{text} =~ s/\s* {2,} / /)) eq lc(trim($entry->{question_and_answers}{question}{text} =~ s/\s* {2,} / /))} @master_parse)[0];

            show $match;
   
            my $master_answer =  (grep $_->{checkbox} =~ / \[ [X,x] /x, $match->{question_and_answers}{answer}->@*)[0];

            if (trim($correct_answer[0]->{text}) eq trim($master_answer->{text})) {
                $correct_count++;
            }

        }
        printf " %s/%s\n", pad($correct_count, 2, "l", "0", 1), pad($nr_of_questions, 2, "l", "0", 1);
    }
}


sub pad {
    my ($text, $width, $which, $padchar, $is_trunc) = @_;
    if ($which) {
        $which = substr($which, 0, 1);
    } else {
        $which = "r";
    }
    $padchar //= " ";

    my $w = length($text);
    if ($is_trunc && $w > $width) {
        $text = substr($text, 0, $width, 1);
    } else {
        if ($which eq 'l') {
            $text = ($padchar x ($width-$w)) . $text;
        } elsif ($which eq 'c') {
            my $n = int(($width-$w)/2);
            $text = ($padchar x $n) . $text . ($padchar x ($width-$w-$n));
        } else {
            $text .= ($padchar x ($width-$w));
        }
    }
    $text;
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
