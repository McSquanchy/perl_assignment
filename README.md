# Introduction to Perl

This repo contains my solution to the assignment given in class.

## Maintainer

Kevin Buman (kevin.buman@students.fhnw.ch)

## Lecturer

Dr. Damian Conway

## Documentation

## Environment

The following programs were written and tested on vagrant running an "ubuntu/trusty64" box. In addition, all code was also tested and run on version 5.1.7 of elementary OS. In order to run the programs, perl v5.32.0 is **required**. All code has been formatted with an online [perl formatter](https://www.tutorialspoint.com/online_perl_formatter.htm).

### Assignment 1

#### Description of the task

The idea is to provide a program that, given a master file, creates a cleaned up "empty" version of said master file. This includes doing the following:

* Replace all [X] with [ ] 
* Shuffle the choices for each question
* Save to a new file

#### Approach

During initial research I stumbled upon the CPAN module [Tie::File](https://metacpan.org/pod/Tie::File), which let's you tie each line of a file to an array. Using this approach, I can easily shuffle lines without having to read the entire file into a string. If I know the indices of the answer lines, I can just use `shuffle()` to change the order.

#### Pseudocode

```
program question_randomizer(masterfile)
	@input 		<- tie(masterfile)
	@output 	<- tie(output_file)
	@output 	<- @input
	untie @input
	@answers 	<- []
	
	for each line in @output do
		if line is beginning of new question
			push @answers {indices => []}
		elsif line contains answer
			replace [X] with [ ]
			push @answers[-1]{incides} line_index
		
	for entry in @answers
		shuffle indices in @output
	
	untie @output
```

#### Usage

```
-m / --master		path to master file
-o / --output		path to desired output file
-h / --help			display usage
-s / --silent		disable console output (except errors)
```

#### Limitations and Fault tolerance

The program makes the following assumptions about the provided master file:

* Each question must begin with a number, followed by a dot (i.e. "82.").
* Lines which contain answers must contain a set of square brackets ("[]"). 
  * Correct answers must enclose exactly one non-space character within the brackets (i.e. "[x]")
  * False answers must not enclose any non-space character within the brackets (i.e. "[ ]")
  * Other lines must not contain square brackets

The program allows the following:

* Questions don't have to be separated by a series of repeating characters (i.e."-----------------")
* Multi-line questions
* The number of possible choices may differ for each question
* The correct answer may be marked with any non-space character
* Whitespaces within brackets can be non-uniform among all answer
* Empty lines are permitted between answers

#### Error handling

The program provides basic error handling. An error will be thrown when

* missing or wrong arguments are provided
* either the input or output file cannot be opened

#### Known Issues

There appears to be an issue with either the module `Tie::File` or with Windows/Unix file formats. Using `Tie::File` seems to add a blank line at the end every file accessed. I didn't address this, but if it's really an issue, simply delete the last line in both files after the program executed.

#### Tests

I provide a few test files in `test/question_randomizer/`. Each of them has one or more special cases that are intended to demonstrate the robustness of the program. `file1..7` show various edge cases that the program is able to manage. `file8` shows a case where, if you inject some text with square brackets, the program will not provide an intended solution.

In a Unix environment, simply call

```bash
 for f in ../test/question_randomizer/* ; do ./question_randomizer.pl -m $f -o "${f%.*}-processed.txt" -s; done
```

from `bin/`.

#### Requirements

The following CPAN modules are required to execute the program:

```
Tie::File
```

### Assignment 2 

#### Description of the task

The idea is to provide a program that, given a master file and a number of completed exams, checks each exam against the master file and grades it. For each exam submission, the program prints out the score (i.e. 11/30).	

#### Approach

I parse the master file as well as all the exam files into hashes. Then, I iterate over the parsed master file and compare it against each submitted exam file, printing out missing questions and/or answers. Each correctly answered question is counted. In the end, I simply print out a score consisting of the number of right answers and the total number questions present in the file. The code provided attempts to solve **all** parts of the assignment. For further details, please refer to the code documentation.

#### Reasoning

In order to get a halfway decent program, one must assume that some of the submitted exams will have changed in either layout or content. For this reason, I use the provided master file as my ground truth, comparing everything against it. If this is not done, it will be significantly harder to detect / account for abusive tactics (i.e. attempts at cheating). For example, if you compare the the exam files against the master file, and not vice versa, a student could try to answer a simple question, copy it numerous times and increase the question number each time. In such a case, all questions and answers in the exam file will be valid, which could lead to the student achieving a perfect score.

#### Extensions

##### 2. Inexact matching

In order to achieve this, I wrote a little function called `evaluate_match($string1, $$string2)`, which uses the Levenshtein-Damerau distance. I use it instead of `eq`  to achieve inexact matching. If a match has been found, I simply check whether the strings match exactly. If this is not the case, I print out the closest match that is being used to continue.

In the case where two or more answers match the current answer in the master file, I use the one with the least distance to the original.

##### 3. Creating statistics

To do this, I created a `$statistics` hash, which keeps track of all the scores. After examining all files, I print out minimum, maximum and average numbers for the set. Additionally, I report all cases where the achieved result is more than one standard deviation below the average.

##### 4. Collusion detection

For each pair of students, I count how many answers they have answered the same. Out of those, I look at the ones that they have both gotten wrong. I count them and evaluate the fraction
$$
p = \frac{nr. \ wrong \ answers}{nr. \ same \ answers}.
$$
Without further statistical analysis, I simply chose to report the pairs where $nr. \ wrong \ answers > 3$ and  $p >= 0.3$. As an example, let's say the exam has 20 questions with each 5 possible answers, 1 of which is correct. If two students answered 14 questions correctly,  and also answered the other questions in the same way, then $p = \frac{6}{20} = 0.3$. 

This calculation makes the assumption that every answer  is equally likely to be chosen. Naturally, this is not true. However, for smaller classes of students (30-50), I've found that it's quite hard to find a good estimate, since many answers have never been chosen and it makes not much sense to assume a zero probability for some of the answers.

#### Requirements

The following CPAN modules are required to execute the program:

```
String::Util
Text::Levenshtein::Damerau
Regexp::Grammars
Getopt::Long
Statistics::Basic
```

#### Tests

I provide a few test files in `test/scores/`. In each folder, read the comment at the top of the first file to see what is being tested. For most test cases, simply provide the program with the master file `test/scores/master/test_master.txt`. In some subfolders,  a different master file is included. In those cases, simply use the one inside the specific folder. The test files cover a variety of edge cases and should convince the user that the program works great in most cases.

#### Discussion

The program provided works reliably for most of the exams. If a student response matches the master,apart from marked answers, then the score is absolutely trustworthy. However, one is best advised to not solely rely on this program to score a multiple choice exam. Using '[', ']' characters or numbers in a clever way might allow certain individuals to manipulate the scoring procedure in order to achieve a more favorable score. Especially for small number of exams (<30), it might be best to give each file a quick glance and check whether the layout has changed in any significant way.
