#!/usr/bin/perl

package DicRoman;
use warnings;
use strict;

use Exporter;

our @ISA = ('Exporter');
our @EXPORT = ( 
    'isroman',
    'arabic',
    'Roman',
    'roman',
    'sortroman',
);

# Localized Roman Package, because LCL uses lxxxx, which is strictly speaking not a roman number.
#Begin
our %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
our %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
our @figure = reverse sort keys %roman_digit;
$roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;

sub isroman{
    my $String= shift;

    if(    defined $String and $String=~m/^[ivxlcm]+$/    ){    return(1);    }
    else{    return(0);    }
}
sub arabic{
    my $arg = shift;
    isroman $arg or return undef;
    my($last_digit) = 1000;
    my($arabic);
    foreach (split(//, uc $arg)) {
        my($digit) = $roman2arabic{$_};
        $arabic -= 2 * $last_digit if $last_digit < $digit;
        $arabic += ($last_digit = $digit);
    }
    $arabic;
}
sub Roman{
    my $arg = shift;
    0 < $arg and $arg < 4000 or return undef;
    my($x, $roman);
    foreach (@figure) {
        my($digit, $i, $v) = (int($arg / $_), @{$roman_digit{$_}});
        if (1 <= $digit and $digit <= 3) {
            $roman .= $i x $digit;
        } elsif ($digit == 4) {
            $roman .= "$i$v";
        } elsif ($digit == 5) {
            $roman .= $v;
        } elsif (6 <= $digit and $digit <= 8) {
            $roman .= $v . $i x ($digit - 5);
        } elsif ($digit == 9) {
            $roman .= "$i$x";
        }
        $arg -= $digit * $_;
        $x = $i;
    }
    $roman;
}
sub roman{
    lc Roman shift;
}
sub sortroman{
    return ( sort {arabic($a) <=> arabic($b)} @_ );
}
#End Localized Roman Package

1;