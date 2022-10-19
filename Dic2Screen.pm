#!/usr/bin/perl

package Dic2Screen;
use warnings;
use strict;
use Term::ANSIColor;
use Exporter;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use DicGlobals;

our @ISA = ('Exporter');
our @EXPORT = (
    'debug',
    'debug_t',
    'debugV',
    'debugVV',
    'debugFindings',
    'Die',
    'doneWaiting',
    'Dumper',
    'getLoggingTime',
    'info',
    'info_t',
    'infoV',
    'infoVV',
    'printBlue',
    'printCyan',
    'printGreen',
    'printMagenta',
    'printRed',
    'printYellow',
    'shortenStrings4Debug',
    'waitForIt',

    '$isDebug',
    '$isDebugVerbose',
    '$isDebugVeryVerbose',
    '$isInfo',
    '$isInfoVerbose',
    '$isInfoVeryVerbose',
);

our ( $isDebug, $isDebugVerbose, $isDebugVeryVerbose ); # Toggles verbosity debug messages
our ( $isInfo,  $isInfoVerbose,  $isInfoVeryVerbose );    # Toggles verbosity info messages
# Default values
( $isDebug, $isDebugVerbose, $isDebugVeryVerbose )       = ( 1, 0, 0 );
( $isInfo, $isInfoVerbose, $isInfoVeryVerbose )          = ( 1, 0, 0 );

sub debug   { $isDebug            and                  printRed(  shortenStrings4Debug(@_), "\n" ); return(1);}
sub debug_t { $isDebug            and $isTestingOn and printRed(  shortenStrings4Debug(@_), "\n" ); return(1);}
sub debugV  { $isDebugVerbose     and                  printBlue( shortenStrings4Debug(@_), "\n" ); return(1);}
sub debugVV { $isDebugVeryVerbose and                  printBlue( shortenStrings4Debug(@_), "\n" ); return(1);}

sub debugFindings {
    debugV();
    if ( defined $1 )  { debugV("\$1 is: \"$1\"\n"); }
    if ( defined $2 )  { debugV("\$2 is: \"$2\"\n"); }
    if ( defined $3 )  { debugV("\$3 is: \"$3\"\n"); }
    if ( defined $4 )  { debugV("\$4 is:\n $4\n"); }
    if ( defined $5 )  { debugV("5 is:\n $5\n"); }
    if ( defined $6 )  { debugV("6 is:\n $6\n"); }
    if ( defined $7 )  { debugV("7 is:\n $7\n"); }
    if ( defined $8 )  { debugV("8 is:\n $8\n"); }
    if ( defined $9 )  { debugV("9 is:\n $9\n"); }
    if ( defined $10 ) { debugV("10 is:\n $10\n"); }
    if ( defined $11 ) { debugV("11 is:\n $11\n"); }
    if ( defined $12 ) { debugV("12 is:\n $12\n"); }
    if ( defined $13 ) { debugV("13 is:\n $13\n"); }
    if ( defined $14 ) { debugV("14 is:\n $14\n"); }
    if ( defined $15 ) { debugV("15 is:\n $15\n"); }
    if ( defined $16 ) { debugV("16 is:\n $16\n"); }
    if ( defined $17 ) { debugV("17 is:\n $17\n"); }
    if ( defined $18 ) { debugV("18 is:\n $18\n"); }}

sub Die{
    sub showCallStack {
      my ( $path, $line, $subr );
      my $max_depth = 30;
      my $i = 1;
        debug("--- Begin stack trace ---");
        while ( ( my @call_details = (caller($i++)) ) && ($i<$max_depth) ) {
        debug("$call_details[1] line $call_details[2] in function $call_details[3]");
        }
        debug("--- End stack trace ---");
    }

    showCallStack();
    die if $isRealDead;}

sub doneWaiting{ printCyan("Done at ",getLoggingTime(),"\n");}

sub info{   printCyan( join('',shortenStrings4Debug(@_))."\n" ) if $isInfo;                   }
sub info_t{ printCyan( join('',shortenStrings4Debug(@_))."\n" ) if $isInfo and $isTestingOn;  }
sub infoV{  printGreen( join('',shortenStrings4Debug(@_))."\n" ) if $isInfoVerbose;            }
sub infoVV{ printBlue( join('',shortenStrings4Debug(@_))."\n" ) if $isInfoVeryVerbose;        }

sub getLoggingTime {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "%04d%02d%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $nice_timestamp;}

sub printBlue    { print color('blue')      if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printCyan    { print color('cyan')      if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printGreen   { print color('green')     if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printMagenta { print color('magenta')   if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printRed     { print color('red')       if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printYellow  { print color('yellow')    if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }

sub shortenStrings4Debug{
    my $String = join('', @_);
    if( $_[0] =~ m~no short~i or 
        length($String)<2000 ){ 
        return @_; 
    }
    return( substr($String, 0, 1000)."\n".( ( "." x 80 )."\n") x 3 . substr($String, -1000, 1000) );}

sub waitForIt{ printCyan(join('', @_)," This will take some time. ", getLoggingTime(),"\n");}

1;