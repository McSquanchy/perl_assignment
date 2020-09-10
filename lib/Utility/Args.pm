package Utility::Args;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(usage error_args extract_filename get_processed_filename);

use experimental 'signatures';
use File::Spec;
use List::Util 'shuffle';
use Tie::File;
use Text::LineNumber;

sub usage {
    print "\nUsage:\n\trandomizer command syntax:\n\n\t./randomizer [options] [arguments] [optional arguments]\n\n\tGeneric command options:\n\n";
    print "\t\t-m, --master:\tSpecify the file to be processed.\n";
    print "\t\t-h, --help:\tRead more detailed instructions.\n";
    print "\n\tOptional parameters:\n\n";
    print "\t\t-o, --output:\tSpecify the output file.\n";
    print "\n";
}

sub error_args {
    warn "\nWrong flags. See --help for more information.\n\n";
}

sub extract_filename($fn) {
    my $system_separator = File::Spec->catfile( '', '' );
    my @split            = split /$system_separator/, $fn;
    return $split[-1];
}

sub get_processed_filename($initialfile) {
    sub {
        sprintf '%04d%02d%02d-%02d%02d%02d', $_[5] + 1900, $_[4] + 1, $_[3], $_[2], $_[1], $_[0];
        }
        ->(localtime) . "-" . $initialfile;
}





1;