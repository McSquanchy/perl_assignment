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

# say scalar ($submissions{$submission_filenames[0]}->@*); -> Nr. of Questions

# my @submission_questions = map {$_->{question_and_answers}{question}{text}} $submissions{$submission_filenames[0]}->@*; -> get all questions of a submission

# show $submissions{$submission_filenames[0]}[0]{question_and_answers}{question}{text};
# show $submissions{$submission_filenames[0]}->@*;

# show $submissions{$submission_filenames[0]};
# foreach ($submissions{$submission_filenames[0]}->@*) {
#     # show $_;
#     say $_->{question_and_answers}{question}{text};
# }

validate_completeness();

grade_submissions();


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
    # show @master_parse;
    my @master_questions =
      map { $_->{question_and_answers}{question}{text} =~ s/^\s+|\s+$//gr }
      @master_parse;
    my @master_answers =
      ( map { $_->{question_and_answers}{answer}->@* } @master_parse );
    @master_answers = map { $_->{text} =~ s/^\s+|\s+$//gr } @master_answers;

    # show @master_parse[0]->{question_and_answers}{question}{text};
    for my $sub ( keys %submissions ) {
        printf "\n%s:\n", FilePaths::get_filename($sub);
        check_missing_q_a( $submissions{$sub} );

       # my $nr_of_questions = $submissions{$sub}->@*;
       # my @submission_questions =
       #   map { $_->{question_and_answers}{question}{text} =~ s/^\s+|\s+$//gr }
       #   $submissions{$sub}->@*;
       # my @submission_answers =
       #   ( map { $_->{question_and_answers}{answer}->@* }
       #       $submissions{$sub}->@* );
       # @submission_answers =
       #   map { $_->{text} =~ s/^\s+|\s+$//gr } @submission_answers;

        # foreach (@master_questions) {
        #     if ( !( $_ ~~ @submission_questions ) ) {
        #         printf "\tmissing question: %s\n", $_ =~ s/\s{2,}/ /gr;
        #     }
        # }

        # foreach (@master_answers) {
        #     if ( !( $_ ~~ @submission_answers ) ) {
        #         printf "\tmissing answer: %s\n", $_;
        #     }
        # }
        # printf "\n";
    }

# my @test = $master{master}{master_component}->@*;
# show @test;
# foreach($master{master}{master_component}->@*) {
#     next if($_->{decoration});
#     print $_->{question_and_answers}{question}{text};
# }
# my @questions =  grep($_->{question_and_answers}, $master{master}{master_component}->@*);
# print join "\n", $_->{question_and_answers}{question}{text} foreach (grep($_->{question_and_answers}, $master{master}{master_component}->@*));

# show $submissions{$submission_filenames[0]}{exam_submission}{exam_component}->@*;
# show $submissions{$submission_filenames[0]}{exam_submission}{exam_component};
# use Hash::Diff qw(diff);
# for my $sub(@submission_filenames) {
#     my %diff = %{ diff (\$master{master}{master_component}, \$submissions{$sub}{exam_submission}{exam_component})};
# # print join "n", grep($_->{question_and_answers}, $submissions{$sub}{exam_submission}{exam_component}->@*);
# foreach (grep($_->{question_and_answers}, $submissions{$sub}{exam_submission}{exam_component}->@* )) {

    #     # print $_->{question_and_answers}{question}{text};
    #     push @questions, $_->{question_and_answers}{question}{text};

#     if (scalar (grep($_->{checkbox} =~ /\[ [x,X] \]/x , $_->{question_and_answers}{answer}->@*)) == 1 && scalar ($_->{question_and_answers}{answer}->@*) == 5) {
#         my $given_answer = (grep($_->{checkbox} =~ /\[ [x,X] \]/x, $_->{question_and_answers}{answer}->@*))[0]->{text};
#         # my @master_questoin = (grep($_->{q_nr} eq ))
#         my $qnr = $_->{question_and_answers}{question}{q_nr};
#         my @correct_answer = grep($_->{question}{q_nr} eq $qnr, {$master{master}{master_component}{question_and_answers}{question}->@*);

    #         # if
    #         # for my $answer ($_->{question_and_answers}{answer}->@*) {
    #         #     if ($answer->{checkbox} =~ /\[ [x,X] \]/x) {
    #         #         say "correct";
    #         #     }
    #         # }
    #     }

    #     # say scalar ($_->{question_and_answers}{answer}->@*);
    #     # show $_->{question_and_answers}{answer}->@*;
    #     # say join "\n", @submission_questions;
    # }
    # say join "\n", @questions;

    # };

    # for my $el ($master{master}{master_component}->@*) {
    #     # my @tst = keys $el->%*;
    #     # say $tst[0];
    #     if (! ((keys $el->%*)[0] eq "decoration")) {
    #         while(my ($key, $value) = each $el->{question_and_answers}->%*) {
    #             show $value;
    #         }
    #     };

    # }
    # foreach ($master{master}{master_component}->@*) {
    #    use Data::Show;
    #    print $_->{question_and_answers}{question}{q_nr};
    # }
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

           # for my $answer(@master_answers) {
           #     printf "\t\tmissing answer: %s\n", $answer =~ s/^\s+|\s+$//gr ;
           # }
           # printf "\n";
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
            # if ($missing) {
            #     # printf "\n";
            # }

        }
    }
}

sub grade_submissions() {
    use Data::Show;
    Print::print_progress("\n\nComputing scores");
    for my $sub ( keys %submissions ) {
        my $nr_of_questions = uniq map { $_->{question_and_answers}{question}{text} } $submissions{$sub}->@*;
        
    }
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
