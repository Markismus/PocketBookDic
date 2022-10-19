#!/usr/bin/perl

package DicFileUtils;
use warnings;
use strict;

use Encode;
use utf8;
use open IO => ':utf8';
use open ':std', ':utf8';
use feature 'unicode_strings'; # You get funky results with the sub convertNumberedSequencesToChar without this.
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Storable;
use Exporter;

use DicGlobals;
use Dic2Screen;

our @ISA = ('Exporter');
our @EXPORT = (
    'array2File',
    'decode_utf8',
    'encode',
    'file2Array',
    'retrieve',
    'retrieveHash',
    'store',
    'storeHash',
    'string2File',
    'stripTags',
 );

sub array2File {
    my ( $FileName, @Array ) = @_;
    if( $FileName =~ m~(?<dir>.*)/(?<file>[^/]+)~ ){
        my $dir = $+{dir};
        my $file = $+{file};
        unless( -r $dir){
            warn "Can't read '$dir'";
            $dir =~ s~ ~\\ ~g;
            unless( -r $dir ){ warn "Can't read '$dir' with escaped spaces."; }
        }
        unless( -w $dir){ warn "Can't write '$dir'"; }


    }
    debugV("Array to be written:\n",@Array);
    if( -e $FileName){ warn "$FileName already exist" if $isDebugVerbose; };
    unless( open( FILE, ">:encoding(utf8)", $FileName ) ){
      warn "Cannot open $FileName: $!\n";
      Die() ;
    }
    print FILE @Array;
    close(FILE);
    $FileName =~ s/.+\/(.+)/$1/;
    printGreen("Written $FileName. Exiting sub array2File\n") if $isDebugVerbose;
    return ("File written");}
sub file2ArrayOld {

    #This subroutine expects a path-and-filename in one and returns an array
    my $FileName = $_[0];
    my $encoding = $_[1];
    my $verbosity = $_[2];
    my $isBinMode = 0;
    if(defined $encoding and $encoding eq "raw"){
        undef $encoding;
        $isBinMode = 1;
    }
    if(!defined $FileName){debug("File name in file2Array is not defined. Quitting!");Die() if $isRealDead;}
    if( defined $encoding){ open( FILE, "<:encoding($encoding)", $FileName )
      || (warn "Cannot open $FileName: $!\n" and Die());}
    else{    open( FILE, "$FileName" )
      || (warn "Cannot open $FileName: $!\n" and Die());
  }
      if( $isBinMode ){
          binmode FILE;
      }
    my @ArrayLines = <FILE>;
    close(FILE);
    printBlue("Read $FileName, returning array. Exiting file2Array\n") if (defined $verbosity and $verbosity ne "quiet");
    return (@ArrayLines);}
sub file2Array{
    #This subroutine expects a path-and-filename in one and returns an array
    my $FileName = $_[0];
    my $encoding = $_[1];
    my $verbosity = $_[2];
    # Read the raw bytes
    local $/;
    unless( -e $FileName ){
        warn "'$FileName' doesn't exist.";
        if( $FileName =~ m~(?<dir>.*)/(?<file>[^/]+)~ ){
            my $dir = $+{dir};
            my $file = $+{file};
            if( -e $dir ){
                unless( -r $dir){
                    warn "Can't read '$dir'";
                    $dir =~ s~ ~\\ ~g;
                    unless( -r $dir ){ warn "Can't read '$dir' with escaped spaces."; }
                }
                unless( -w $dir){ warn "Can't write '$dir'"; }
            }
            elsif( $dir =~ s~ ~\\ ~g and -e $dir){
                warn "Found '$dir' after escaping spaces";
            }
            elsif( -e "$BaseDir/$dir"){
                warn "Found $BaseDir/$dir. Prefixing '$BaseDir'.";
                $dir = "$BaseDir/$dir";
            }
            else{
                warn "'$dir' doesn't exist";
                my @commands = (
                    "pwd",
                    "ls -larth $dir",
                    "ls -larth $BaseDir/$dir");
                foreach(@commands){
                    print "\$ $_\n";
                    system("$_");
                }
                Die();
            }
        }

        if( -e "BaseDir/$FileName"){
            warn "Changing it to BaseDir/$FileName";
            $FileName = "BaseDir/$FileName";
        }
        elsif( $FileName =~ s~ ~\\ ~g and -e $FileName ){
            warn "Escaped spaces to find filename";
        }
    }
    else{ debugVV( "$FileName exists."); }
    open (my $fh, '<:raw', "$FileName") or (warn "Couldn't open $FileName: $!" and Die() and return undef() );
    my $raw = <$fh>;
    close($fh);
    if( defined $encoding and $encoding eq "raw"){
        printBlue("Read $FileName (raw), returning array. Exiting file2Array\n") if (defined $verbosity and $verbosity ne "quiet");
        return( split(/^/, $raw) );
    }
    elsif( defined $encoding ){
        printBlue("Read $FileName ($encoding), returning array. Exiting file2Array\n") if (defined $verbosity and $verbosity ne "quiet");
        return(split(/^/, decode( $encoding, $raw ) ) );
    }

    my $content;
    # Try to interpret the content as UTF-8
    eval { my $text = decode('utf-8', $raw, Encode::FB_CROAK); $content = $text };
    # If this failed, interpret as windows-1252 (a superset of iso-8859-1 and ascii)
    if (!$content) {
        eval { my $text = decode('windows-1252', $raw, Encode::FB_CROAK); $content = $text };
    }
    # If this failed, give up and use the raw bytes
    if (!$content) {
        $content = $raw;
    }
    my @ReturnArray = split(/^/, $content);
    printBlue("Read $FileName, returning array of size ".@ReturnArray.". Exiting file2Array\n") if (defined $verbosity and $verbosity ne "quiet");

    return @ReturnArray;}
sub retrieveHash{
    info_t("Entering sub retrieveHash.") ;
    foreach( @_ ){ debug_t( $_ ); }
    debug_t( "DumperSuffix is '$DumperSuffix'");
    my $FileName = "$_[0]$DumperSuffix";
    debug_t("Filename in sub storeHash is '$FileName'");
    if( -e $FileName ){
        infoVV("Preferring '$_[0]$DumperSuffix', because it could contain manual edits");
        my @Dumpered = file2Array( "$_[0]$DumperSuffix" );
        my %Dumpered;
        my $index = -1;
        foreach( @Dumpered ){
            $index++;
            # Skip first and last line.
            if( m~\$VAR1 = \\?\{$~ or m~^\s*\};$~ ){ next; }
            debug_t( "[$index] $_" );
            chomp;
            s~^\s*~~;
            my ( $key, $value) = split( / => /, $_ );
            debug_t("key is>$key<");
            debug_t("value is >$value<");
            $key =~ s~^'~~;
            $key =~ s~'$~~;
            $value =~ s~,$~~;
            $value =~ s~^('|")~~;
            $value =~ s~('|")$~~;
            my $check = 0;
            while( $value =~ m~\\x\{([0-9A-Fa-f]+)\}~ ){
                $check++;
                my $oldvalue = $value;
                # $value = $`."\x{$1}".$';
                debug_t("\$` is '$`'");
                debug_t("\$' is '$''");
                debug_t("\$1 is '$1'");
                $value = $`.chr(hex($1)).$';
                debug_t("'$oldvalue' is now '$value'");
            }
            if( $check ){ debug_t("updated value is '$value'") ;}
            $value =~ s~^\\(.)~$1~g; # Remove preceding slashes.
            debug_t("key is>$key<");
            debug_t("value is >$value<");
            unless( $key and $value ){
                warn "Line '$_' in returned array from '$_[0]$DumperSuffix' is not a simple hash structure";
                return( retrieve (@_) );
            }
            else{ $Dumpered{ $key } = $value; }
        }
        if( scalar keys %Dumpered ){ return \%Dumpered; }
        else{ warn "$_[0]$DumperSuffix is not an dumpered HASH"; }
    }
    return( retrieve( @_) );}
sub storeHash{
    info("Entering sub storeHash.") if $isTestingOn ;
    foreach( @_ ){ debug( $_ ) if $isTestingOn ; }
    if( $_[0] =~ m~^HASH\(0x~ ){
        my $Dump = Dumper( $_[0]);
        debug( "DumperSuffix is '$DumperSuffix'") if $isTestingOn;
        my $FileName = "$_[1]$DumperSuffix";
        debug("Filename in sub storeHash is '$FileName'");
        debugV( $Dump );
        array2File( $FileName, $Dump );
        return 1;
    }
    else{ return( store( @_) ); }}
sub string2File{
    my $FileName = shift;
    my @Array = split(/^/, shift);
    array2File( $FileName, @Array);}
sub stripTags{
    my $html = shift;
    $html =~ s~<[^>]+>~~sg;
    return( $html );}

1;