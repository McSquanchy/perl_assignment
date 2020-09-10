############################################################
#
#                   Print
#
############################################################

package Print;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(print_header);

use experimental 'signatures';

#
# Print the ascii text at the beginning of the execution
sub print_header($ascii) {
    printf "%s", $ascii;
}

#
# Print the current state to STDOUT
sub print_progress($string) {
    printf "%s\n", $string;
}


############################################################
#
#                   ARGS
#
############################################################

package Args;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(usage error_args extract_filename get_processed_filename);

use experimental 'signatures';

sub error_args() {
    warn "\nWrong flags. See --help for more information.\n\n";
}

sub extract_filename($fn) {
    use File::Spec;
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