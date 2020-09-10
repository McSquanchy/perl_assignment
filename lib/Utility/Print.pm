package Utility::Print;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(print_header);

use experimental 'signatures';

#
# Print the ascii text at the beginning of the execution
sub print_header($ascii) {
    printf "%s", $ascii;
}

1;