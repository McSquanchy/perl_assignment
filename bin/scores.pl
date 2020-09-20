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
use List::Util qw( min max ); 
use List::MoreUtils qw(firstidx);
use Text::Levenshtein::Damerau;
use Text::Levenshtein::Damerau qw/edistance/;
use List::MoreUtils qw(uniq);
use Regexp::Grammars;
use Statistics::Basic qw(:all);
use Data::Show;
use Array::Diff qw(diff);

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
                                                            
                                                            
v0.8                                               16.09.2020
                                       
Created by Kevin Buman                                   
                                                             
);

# grammer for parsing the master file
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
        \[  \s* .* \s* \]

    <token: decoration>
        \N* \n
    
    <token: empty_line>
        \s* \n

};

state %args;
state @master_parse;
state %submissions;
state @submission_filenames;

state %statistics;

# Print the ascii art to the console
Print::print_header($ascii_header);

# Read flags and store values in the hash
GetOptions(
    \%args, "master=s",
    "submissions=s{,}" => \@submission_filenames,
    "help!"
) or die( Args::error_args() );

# Validate the arguments
validate_args();

Print::print_progress("Opening master\t\t$args{master}");

parse_master();
parse_submissions();
validate_completeness();

# show %statistics;
print_results();
gather_statistics();
find_cheaters();


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

    sanitize_questions( \@master_parse );
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
            sanitize_questions( \@questions_and_answers );
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
    for my $sub ( keys %submissions ) {
        printf "\n%s:\n", FilePaths::get_filename($sub);
        check_validity( $sub );
    }
}

sub check_validity($submission) {
    # create array with all questions
    my @submission_questions = map { $_->{question_and_answers}{question}{text} } $submissions{$submission}->@*;

    # create statistics entry for current submission
    $statistics{$submission} = {nr_answers => 0, nr_correct_answers => 0, nr_total_answers => 0, nr_of_questions => 0, given_answers_pattern => [], missing_answers_pattern => [], missing_questions_pattern => []};

    for ( 0 .. $#master_parse ) {
        # create iterator variable
        my $iterator = $_;
        my $question_already_printed;
        # check if master question is contained in submission questions
        my @match = grep {evalute_match(normalize_string($master_parse[$iterator]->{question_and_answers}{question}{text}),$_)} 
                    @submission_questions;

        # if there's a match
        if(@match) {
            my $missing;
            # increment nr of questions
            $statistics{$submission}{nr_of_questions}++;
     

            # check if questions identical
            my ($m, $closest_match) = evalute_match($master_parse[$iterator]->{question_and_answers}{question}{text}, $match[0]);

            # find the matched question within the submission structure
            my $submission_matched_question = (grep {$_->{question_and_answers}{question}{text} eq $closest_match} $submissions{$submission}->@*)[0];
            # show $submission_matched_question;
            if (scalar (grep {$_->{checkbox} =~ /\[ \s* \S \s* \]/x} $submission_matched_question->{question_and_answers}{answer}->@*) > 0) {
                $statistics{$submission}{nr_answers}++;
            }
            # check if question matches exactly or not
            if (!($closest_match eq $master_parse[$iterator]->{question_and_answers}{question}{text})) {
                # print closest match
                printf "\tmissing question %s:\t%s\n", $master_parse[$iterator]->{question_and_answers}{question}{q_nr}, $master_parse[$iterator]->{question_and_answers}{question}{text};
                printf "\t\tuse instead:\t%s\n", $closest_match;

                #set missing so prints will look nice
                $missing = 1;
            }
            # show $submission_matched_question;
            my @submission_answers = $submission_matched_question->{question_and_answers}{answer}->@*;

            # my @submission_marked_answers = grep {$_->{checkbox} =~ /\[ \s* . \s* \]/x} @submission_answers;
            
            my @master_answers = $master_parse[$iterator]->{question_and_answers}{answer}->@*;

            my $iter = 0;
            # check all answers
            for my $master_answer (@master_answers) {
                $iter++;

                my @answer_match = grep {evalute_match(normalize_string($master_answer->{text}), normalize_string($_->{text}))} 
                    @submission_answers;
                if(@answer_match) {
                    $statistics{$submission}{nr_total_answers}++;

                    my ($m, $closest_match) = evalute_match(normalize_string($master_answer->{text}), normalize_string($answer_match[0]->{text}));
                    if (!($closest_match eq normalize_string($master_answer->{text}))) {
                        if(!$missing) {
                        printf "\tquestion %s:\t%s\n", $master_parse[$iterator]->{question_and_answers}{question}{q_nr}, $master_parse[$iterator]->{question_and_answers}{question}{text};
                        printf "\t\tmissing answer: %s\n", $master_answer->{text};
                        printf "\t\tuse instead:\t%s\n", $closest_match;
                        $missing = 1;
                        }
                    }
                    if ($answer_match[0]->{checkbox} =~ /\[ \s* . \s* \]/x) {
                        push $statistics{$submission}{given_answers_pattern}->@*, 1;     
                    }
                    else {
                        push $statistics{$submission}{given_answers_pattern}->@*, 0;     
                    }
                    
                    if(($master_answer->{checkbox} =~ /\[ \s* \S \s* \]/x) && ($answer_match[0]->{checkbox} =~ /\[ \s* \S \s* \]/x) && scalar (grep {$_->{checkbox} =~ /\[ \s* \S \s* \]/x} @submission_answers) == 1) {
                        $statistics{$submission}{nr_correct_answers}++;     
                    }

                }
                else {
                    if(!$missing) {
                        printf "\tquestion %s:\t%s\n", $master_parse[$iterator]->{question_and_answers}{question}{q_nr}, $master_parse[$iterator]->{question_and_answers}{question}{text};
                        printf "\t\tmissing answer: %s\n", $master_answer->{text};

                        $missing = 1;
                    }
                    else {
                        printf "\t\tmissing answer: %s\n", $master_answer->{text};
                    }

                    # push the missing answer to statistics in the form "q_nr.a_index"
                    push $statistics{$submission}{missing_answers_pattern}->@*, join ".", $iterator+1, $iter;     
                }
            }




        } else {
            printf "\tmissing question: %s %s\n", $master_parse[$iterator]->{question_and_answers}{question}{q_nr}, $master_parse[$iterator]->{question_and_answers}{question}{text};
            
            # push question to statistics
            push $statistics{$submission}{missing_questions_pattern}->@*, $iterator+1;     
        }
        
        # show @match;

    #     my $cnt            = $_;
    #     my @master_answers = map { $_->{text} }
    #       $master_parse[$cnt]->{question_and_answers}{answer}->@*;
    #     my @match = (
    #         grep {
    #             evalute_match(
    #                 $master_parse[$cnt]->{question_and_answers}{question}{text},
    #                 $_
    #             )
    #         } @submission_questions
    #     );
    #     if ( scalar(@match) == 0 ) {
    #         printf "\tmissing question: %s %s\n",
    #           $master_parse[$cnt]->{question_and_answers}{question}{q_nr},
    #           $master_parse[$cnt]->{question_and_answers}{question}{text};
    #     }
    #     else {
    #         my $index = firstidx {
    #             evalute_match(
    #                 $master_parse[$cnt]->{question_and_answers}{question}{text},
    #                 $_->{question_and_answers}{question}{text}
    #             )
    #         }
    #         $submissions{$submission}->@*;

    #         $master_parse[$cnt]->{submissions}{$submission} = [$submissions{$submission}->[$index]->{question_and_answers}{answer}->@*];

    #         my $missing;
    #         my ( $match, $str ) = evalute_match(
    #             $master_parse[$cnt]->{question_and_answers}{question}{text},
    #             $match[0] );

    #         if (
    #             !(
    #                 $str eq
    #                 $master_parse[$cnt]->{question_and_answers}{question}{text}
    #             )
    #           )
    #         {
    #             printf "\tmissing question %s:\t%s\n",
    #               $master_parse[$cnt]->{question_and_answers}{question}{q_nr},
    #               $master_parse[$cnt]->{question_and_answers}{question}{text};
    #             printf "\tusing instead:\t%s\n", $str;
    #             $missing = 1;
    #         }

    #         my @given_answers = map { lc( $_->{text} ) }
    #           $submissions{$submission}->[$index]->{question_and_answers}{answer}->@*;

    #         for my $answer (@master_answers) {

    #             my $tld = Text::Levenshtein::Damerau->new( lc($answer) );
    #             my $closest_match =
    #               $tld->dld_best_match( { list => \@given_answers } );
    #             if ( !( $closest_match eq lc($answer) ) ) {
    #                 if (
    #                     (
    #                         edistance( lc($answer), $closest_match ) /
    #                         length($answer)
    #                     ) < 0.1
    #                   )
    #                 {
    #                     if ( !$missing ) {
    #                         printf "\tquestion: %s %s\n",
    #                           $master_parse[$cnt]
    #                           ->{question_and_answers}{question}{q_nr},
    #                           $master_parse[$cnt]
    #                           ->{question_and_answers}{question}{text};
    #                         $missing = 1;
    #                     }
    #                     printf "\t\tmissing answer: %s\n", $answer;
    #                     printf "\t\tuse instead: %s\n",    $closest_match;
    #                 }
    #                 else {
    #                     if ( !$missing ) {
    #                         printf "\tquestion: %s %s\n",
    #                           $master_parse[$cnt]
    #                           ->{question_and_answers}{question}{q_nr},
    #                           $master_parse[$cnt]
    #                           ->{question_and_answers}{question}{text};
    #                         $missing = 1;
    #                     }
    #                     printf "\t\tmissing answer: %s\n", $answer;
    #                 }
    #             }
    #         }
    #     }
    }
}


sub print_results() {
    Print::print_progress("\n\nResults:");

    for my $key (keys %statistics) {
        printf "%s%s/%s\n", pad( Args::extract_filename($key), 60, "r", ".", 1 ), pad( $statistics{$key}->{nr_correct_answers}, 2, "l", "0", 1 ), pad( $statistics{$key}->{nr_of_questions}, 2, "l", "0", 1 );
    }
}

sub gather_statistics() {
       Print::print_progress("\n\nStatistics:");
    #    show values %statistics;
    
    # my @correctly_answered = map {$_->{nr_correct_answers}} values %statistics;
    # my @total_answered = map {$_->{nr_answers}} values %statistics;
    my $mean_correctly = mean(map {$_->{nr_correct_answers}} values %statistics);
    my $min_correctly = min(map {$_->{nr_correct_answers}} values %statistics);
    my $max_correctly = max(map {$_->{nr_correct_answers}} values %statistics);

    my $mean_answered = mean(map {$_->{nr_answers}} values %statistics);
    my $min_answered = min(map {$_->{nr_answers}} values %statistics);
    my $max_answered = max(map {$_->{nr_answers}} values %statistics);

    printf "%s %s\n%s %s (%s)\n%s %s (%s)\n\n",
        pad("Average number of questions answered", 60, "r", ".", 1),
        pad("".$mean_answered, 2, "l", "0", 1),
        pad("Minimum....", 60, "l", " ", 1),
        pad("".$min_answered, 2, "l", "0", 1),
        ((scalar(grep {$_ == $min_answered} map {$_->{nr_answers}} values %statistics)) == 1 ? join " ", (scalar(grep {$_ == $min_answered} map {$_->{nr_answers}} values %statistics)),  "student" : join " ", (scalar(grep {$_ == $min_answered} map {$_->{nr_answers}} values %statistics)), "students"),
        pad("Maximum....", 60, "l", " ", 1),
        pad("".$max_answered, 2, "l", "0", 1),
        ((scalar(grep {$_ == $max_answered} map {$_->{nr_answers}} values %statistics)) == 1 ? join " ", (scalar(grep {$_ == $max_answered} map {$_->{nr_answers}} values %statistics)),  "student" : join " ", (scalar(grep {$_ == $max_answered} map {$_->{nr_answers}} values %statistics)), "students");


    printf "%s %s\n%s %s (%s)\n%s %s (%s)\n\n",
        pad("Average number of correct answers", 60, "r", ".", 1),
        pad("".$mean_correctly, 2, "l", "0", 1),
        pad("Minimum....", 60, "l", " ", 1),
        pad("".$min_correctly, 2, "l", "0", 1),
        ((scalar(grep {$_ == $min_correctly} map {$_->{nr_correct_answers}} values %statistics)) == 1 ? join " ", (scalar(grep {$_ == $min_correctly} map {$_->{nr_correct_answers}} values %statistics)),  "student" : join " ", (scalar(grep {$_ == $min_correctly} map {$_->{nr_correct_answers}} values %statistics)), "students"),
        pad("Maximum....", 60, "l", " ", 1),
        pad("".$max_correctly, 2, "l", "0", 1),
        ((scalar(grep {$_ == $max_correctly} map {$_->{nr_correct_answers}} values %statistics)) == 1 ? join " ", (scalar(grep {$_ == $max_correctly} map {$_->{nr_correct_answers}} values %statistics)),  "student" : join " ", (scalar(grep {$_ == $max_correctly} map {$_->{nr_correct_answers}} values %statistics)), "students");

    printf "%s:\n", "Results below expectation";
    for my $entry ( keys %statistics) {
        if (($statistics{$entry}->{nr_correct_answers} /  scalar @master_parse) < 0.3) {
            printf "\t%s %s/%s (score < 30%s)\n",  pad(Args::extract_filename($entry), 60, "r",".",1), pad("".($statistics{$entry}->{nr_correct_answers}), 2, "l", "0", 1), pad("".(scalar @master_parse), 2, "l", "0", 1), "%";
        }
    }
    printf "\n\n";
}

sub find_cheaters() {
    # $c = Statistics::RankCorrelation->new( $x, $y, sorted => 1 );
    for my $key (keys %statistics) {
        # my @pattern = $statistics{$key}->{given_answers_pattern};
        for my $comparater (keys %statistics) {
            if(!($key eq $comparater)) {
                # my @comparer = $statistics{$comparater}->{given_answers_pattern};
                my $diff = Array::Diff->diff($statistics{$key}->{given_answers_pattern}, $statistics{$comparater}->{given_answers_pattern});
                show $diff->count;
                # my $c = Statistics::RankCorrelation->new( $statistics{$key}->{given_answers_pattern}, $statistics{$comparater}->{given_answers_pattern}, sorted => 0 );

            }
        }
    }
}

# sub grade_submissions() {
#    #     Print::print_progress("\n\nComputing scores\n");
#    for my $submission(@submission_filenames) {
#        my @answered_questions = grep {$_->{submissions}{$submission}} @master_parse;
#        for my $entry (@answered_questions) {
#            my @master_answers = map {$_->{question_and_answers}{answer}} @answered_questions;
#            for my $answer(@master_answers) {
#             my @test = grep {$_->{checkbox} =~ /\[ \s* . \s* \]/x} $answer->@*;
#             @test = map {$_->{text}} @test;
#             show @test;
#            }

#        }
#    }



# #    for my $entry (@master_parse) {
# #        if ($entry->{submissions}) {
# #            show $entry;
# #        }
# #    } 
# }

# sub grade_submissions() {
#     Print::print_progress("\n\nComputing scores\n");

#     for my $sub ( keys %submissions ) {
#         # printf "%s", pad( Args::extract_filename($sub), 60, "r", ".", 1 );

#         my @answer_pattern;

#         my $correct_count = 0;
#         my $total_count   = 0;
#         my @sub_array     = $submissions{$sub}->@*;

#         # for my $entry (@sub_array) {
#         for my $master_question (@master_parse) {

#             my @correct_answers = grep { $_->{checkbox} =~ /\[ \s* . \s* \]/x }
#               $master_question->{question_and_answers}{answer}->@*;

#             @correct_answers = map {$_->{text}} @correct_answers;

#             # show @correct_answers;

#             my @match_questions = grep {  evalute_match(
#                         $master_question->{question_and_answers}{question}{text},
#                         $_->{question_and_answers}{question}{text}
#                     )} @sub_array;
                    
#             # show @match_questions;
#             if (!($match_questions[0])) {
#                 $total_count++;
#                 next;
#             }
#             # show $match_questions[0];

#             my @given_answers = grep {$_->{checkbox} =~ /\[ \s* . \s* \]/x}$match_questions[0]->{question_and_answers}{answer}->@*;
#             @given_answers = map {$_->{text}} @given_answers;
#             my $correct = 1;
#             for my $entry (@correct_answers) {
#             }
#             # show @given_answers;
#             # # @given_answers = grep { $_->{checkbox} =~ /\[ \s* . \s* \]/x } @given_answers;
#             # # show @given_answers;
#             # show $given_answers[0];
#         }    
#         #     my @correct_answer = grep { $_->{checkbox} =~ /\[ \s* . \s* \]/x }
#         #       $entry->{question_and_answers}{answer}->@*;

#         #     next if ( scalar @correct_answer != 1 );

#         #     my $match = (
#         #         grep {
#         #             evalute_match(
#         #                 $entry->{question_and_answers}{question}{text},
#         #                 $_->{question_and_answers}{question}{text}
#         #             )
#         #         } @master_parse
#         #     )[0];

#         #     my $master_answer = ( grep { $_->{checkbox} =~ /\[ \s* . \s* \]/x }
#         #           $match->{question_and_answers}{answer}->@* )[0];

#         #     if ( $correct_answer[0]->{text} eq $master_answer->{text} ) {
#         #         $correct_count++;
#         #     }
#         #     $total_count++;

#         # }
#         printf " %s/%s\n", pad( $correct_count, 2, "l", "0", 1 ),
#           pad( $total_count, 2, "l", "0", 1 );
#     }
# }

sub evalute_match ( $string, $possible_match ) {
    if ( $string eq $possible_match ) {
        return ( 1, $string );
    }
    elsif (
        lc( $string         =~ s/\s{2,}/ /gr ) eq
        lc( $possible_match =~ s/\s{2,}/ /gr ) )
    {
        return ( 1, ( $string =~ s/\s{2,}/ /gr ) );
    }
    elsif (
        (
            edistance(
                lc( $string         =~ s/\s{2,}/ /gr ),
                lc( $possible_match =~ s/\s{2,}/ /gr )
            ) / length( ( $string =~ s/\s{2,}/ /gr ) )
        ) < 0.1
      )
    {
        my $tld = Text::Levenshtein::Damerau->new( lc($string) );
        return ( 1, $possible_match );
    }
    return undef;
}

sub pad {
    my ( $text, $width, $which, $padchar, $is_trunc ) = @_;
    if ($which) {
        $which = substr( $which, 0, 1 );
    }
    else {
        $which = "r";
    }
    $padchar //= " ";

    my $w = length($text);
    if ( $is_trunc && $w > $width ) {
        $text = substr( $text, 0, $width, 1 );
    }
    else {
        if ( $which eq 'l' ) {
            $text = ( $padchar x ( $width - $w ) ) . $text;
        }
        elsif ( $which eq 'c' ) {
            my $n = int( ( $width - $w ) / 2 );
            $text =
              ( $padchar x $n ) . $text . ( $padchar x ( $width - $w - $n ) );
        }
        else {
            $text .= ( $padchar x ( $width - $w ) );
        }
    }
    $text;
}

sub normalize_string($str) {
    lc($str);
}

sub sanitize_questions($arr) {
    for my $val ( $arr->@* ) {
        $val->{question_and_answers}{question}{text} =
          sanitize_string( $val->{question_and_answers}{question}{text} );
        for my $answer ( $val->{question_and_answers}{answer}->@* ) {
            $answer->{text} = sanitize_string( $answer->{text} );
        }
    }
}

sub sanitize_string($str) {
    trim( $str =~ s/\s{2,}/ /gr );
}

sub usage {
    print
"Usage:\n\trandomizer command syntax:\n\n\t\t./randomizer [options] [arguments]\n\n\tGeneric command options:\n\n";
    print "\t\t-f, --file:\tSpecify the file to be processed.\n";
    print "\t\t-o, --output:\tSpecify the output file.\n";
    print "\t\t-h, --help:\tRead more detailed instructions.\n";
    print "\n";
}

sub validate_args() {

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
