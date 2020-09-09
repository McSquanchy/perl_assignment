package Utility::Args;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(usage);

sub usage {
    print "\nUsage:\n\trandomizer command syntax:\n\n\t./randomizer [options] [arguments] [optional arguments]\n\n\tGeneric command options:\n\n";
    print "\t\t-m, --master:\tSpecify the file to be processed.\n";
    print "\t\t-h, --help:\tRead more detailed instructions.\n";
    print "\n\tOptional parameters:\n\n";
    print "\t\t-o, --output:\tSpecify the output file.\n";
    print "\n";
}


1;