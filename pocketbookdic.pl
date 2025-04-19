#!/bin/perl
use strict;
use utf8;
use open IO => ':utf8';
use open ':std', ':utf8';
use feature 'unicode_strings'; # You get funky results with the sub convertNumberedSequencesToChar without this.
use Time::HiRes qw/ time /;

use lib '/home/mark/git/PocketBookDic/';
use DicGlobals;
use Dic2Screen;
use DicConversion;
use DicFileUtils;
use DicHelpUtils;
use DicPrepare;
use DicControls;

if ( $isTestingOn ){ use warnings; }

# When an argument is given, it will supercede the filename set in DicGlobals.
# Command line argument handling
if( defined($ARGV[0]) ){
    printYellow("Command line arguments provided:\n");
    @ARGV = map { decode_utf8($_, 1) } @ARGV; # Decode terminal input to utf8.
    foreach(@ARGV){ printYellow("\'$_\'\n"); }
    printYellow("Found command line argument: $ARGV[0].\nAssuming it is meant as the dictionary file name.\n");
    $FileName = $ARGV[0];
}
else{
    printYellow("No commandline arguments provided. Remember to either use those or define \$FileName in the script.\n");
    printYellow("First argument is the dictionary name to be converted. E.g dict/dictionary.ifo (Remember to slash forward!)\n");
    printYellow("Second is the language directory name or the CSV deliminator. E.g. eng\nThird is the CVS deliminator. E.g \",\", \";\", \"\\t\"(for tab)\n");
}
my $language_dir = "";
if( defined($ARGV[1]) and $ARGV[1] !~ m~^.$~ and $ARGV[1] !~ m~^\\t$~ ){
    printYellow("Found command line argument: $ARGV[1].\nAssuming it is meant as language directory.\n");
    $language_dir = $ARGV[1];
    $lang_from = $language_dir;
}
if ( defined($ARGV[1]) and ($ARGV[1] =~ m~^(\\t)$~ or $ARGV[1] =~ m~^(.)$~ )){
    debugFindings();
    printYellow("Found a command line argument consisting of one character.\n Assuming \"$1\" is the CVS deliminator.\n");
    $CVSDeliminator = $ARGV[1];
}

if( defined($ARGV[2]) and ($ARGV[2] =~ m~^(.t)$~ or $ARGV[2] =~ m~^(.)$~) ){
    printYellow("Found a command line argument consisting of one character.\n Assuming \"$1\" is the CVS deliminator.\n");
    $CVSDeliminator = $ARGV[2];
}
elsif( defined($ARGV[2]) and $FileName =~ m~\.csv$~i ){ 
    printYellow("Found a command line argument consisting of multiple characters and a cvs-extension in the filename.\n Assuming \"$ARGV[2]\" is the CVS deliminator.\n");
    $CVSDeliminator = $ARGV[2];
}

# Determine operating system.
if ($OperatingSystem eq "linux"){ print "Operating system is $OperatingSystem: All good to go!\n";}
else{ print "Operating system is $OperatingSystem: Not linux, so I am assuming Windows!\n";}

updateLocalPath();
updateFullPath();

# Checks for inline base64 coding.
# Image inline coding won't work for pocketbook dictionary.
if ($isCreatePocketbookDictionary and $isCodeImageBase64){
    debug("Images won't be encoded in reconstructed dictionary, if Pocketbook dictionary creation is enabled.");
    debug("The definition would become too long and crash 'converter.exe'.");
    debug("Set \"\$isCreatePocketbookDictionary = 0;\" if you want imaged encoded inline for Stardict- and XDXF-format.");
}

# To store/load the hash %ReplacementImageStrings or %ValidatedOCRedImages.
if( $isCodeImageBase64 ){
    use MIME::Base64;    # To encode into Bas64
    $ReplacementImageStringsHashFileName = join('', $FileName=~m~^(.+?\.)[^.]+$~)."replacement.hash";
    if( -e $ReplacementImageStringsHashFileName ){ %ReplacementImageStrings = %{ retrieveHash($ReplacementImageStringsHashFileName)}; }
    storeHash(\%ReplacementImageStrings, $ReplacementImageStringsHashFileName); # To check whether filename is storable.
    if( scalar keys %ReplacementImageStrings == 0 ){ unlink $ReplacementImageStringsHashFileName; }
}

# Path checking and cleaning
$BaseDir=~s~/$~~; # Remove trailing slashforward '/'.
if( -e "$BaseDir/converter.exe"){
    debugV("Found converter.exe in the base directory $BaseDir.");
}
elsif( $isCreatePocketbookDictionary ){
    debug("Can't find converter.exe in the base directory $BaseDir. Cannot convert to Pocketbook.");
    $isCreatePocketbookDictionary = 0;
}
else{ debugV("Base directory not containing \'converter.exe\' for PocketBook dictionary creation.");}
# Pocketbook converter.exe is dependent on a language directory in which has 3 txt-files: keyboard, morphems and collates.
# Default language directory is English, "en".

$KindleUnpackLibFolder=~s~/$~~; # Remove trailing slashforward '/'.
if( -e "$KindleUnpackLibFolder/kindleunpack.py"){
    debugV("Found \'kindleunpack.py\' in $KindleUnpackLibFolder.");
}
elsif( $isHandleMobiDictionary ){
    debug("Can't find \'kindleunpack.py\' in $KindleUnpackLibFolder. Cannot handle mobi dictionaries.");
    $isHandleMobiDictionary = 0;
}
else{ debugV("$KindleUnpackLibFolder doesn't contain \'kindleunpack.py\' for mobi-format handling.");}
chdir $BaseDir || warn "Cannot change to $BaseDir: $!\n";
debug("Local path is $LocalPath.");
debug("Full path is $FullPath");

# Generate entity hash defined in DOCTYPE
%EntityConversion = generateEntityHashFromDocType($DocType);

# Fill array from file.
my @xdxf;
@xdxf = loadXDXF();
if( $Just4PocketBook ){ @xdxf = split( /^/, makePocketbookReady( @xdxf ) ); }
array2File("testLoaded_line".__LINE__.".xdxf", @xdxf) if $isTestingOn;
my $SizeOne = scalar @xdxf;
debugV("\$SizeOne\t=\t$SizeOne");
# Remove bloat from xdxf.
if( $FileName !~ m~_unbloated\.xdxf$~ ){
    @xdxf = removeBloatFromArray( @xdxf );
    if( $FileName =~ m~xdxf$~ ){
        my $Unbloated = $FileName;
        $Unbloated =~ s~\.xdxf$~_unbloated.xdxf~;
        array2File($Unbloated, @xdxf);
    }
}
my $SizeTwo = scalar @xdxf;
if( $SizeTwo > $SizeOne){ debug("Unbloated \@xdxf ($SizeTwo) has more indices than before ($SizeOne)."); }
else{ debugV("\$SizeTwo\t=\t$SizeTwo");}
array2File("testUnbloated_line".__LINE__.".xdxf", @xdxf) if $isTestingOn;
# filterXDXFforEntitites
@xdxf = filterXDXFforEntitites(@xdxf);
my $SizeThree = scalar @xdxf;
if( $SizeThree > $SizeTwo){ debug("\$SizeThree ($SizeThree) is larger than \$SizeTwo ($SizeTwo"); }
else{ debugV("\$SizeThree\t=\t$SizeThree");}
array2File("testFiltered_line".__LINE__.".xdxf", @xdxf) if $isTestingOn;

my @xdxf_reconstructed = reconstructXDXF( @xdxf );
my $SizeFour = scalar @xdxf;
if( $SizeFour > $SizeThree){ debug("\$SizeFour ($SizeFour) is larger than \$SizeThree ($SizeThree"); }
else{ debugV("\$SizeFour\t=\t$SizeFour");}

array2File("test_Constructed_line".__LINE__.".xdxf", @xdxf_reconstructed) if $isTestingOn;

# If SameTypeSequence is not "h", remove &#xDDDD; sequences and replace them with characters.
if ( $SameTypeSequence ne "h" or $ForceConvertNumberedSequencesToChar ){
    @xdxf_reconstructed = convertNonBreakableSpacetoNumberedSequence( @xdxf_reconstructed );
    array2File("test_convertednbsp_line".__LINE__.".xdxf", @xdxf_reconstructed) if $isTestingOn;
    @xdxf_reconstructed = convertNumberedSequencesToChar( @xdxf_reconstructed );
    array2File("test_converted2char_line".__LINE__.".xdxf", @xdxf_reconstructed) if $isTestingOn;
}
if( $ForceConvertBlockquote2Div or $isCreatePocketbookDictionary ){
    @xdxf_reconstructed = convertBlockquote2Div( @xdxf_reconstructed );
    array2File("test_converted2div_line".__LINE__.".xdxf", @xdxf_reconstructed) if $isTestingOn;
}
if ( $unEscapeHTML ){ @xdxf_reconstructed = unEscapeHTMLArray( @xdxf_reconstructed ); }
array2File("test_unEscapedHTML_line".__LINE__.".xdxf", @xdxf_reconstructed) if $isTestingOn;

if( $UseXMLTidy ){
    @xdxf_reconstructed = tidyXMLArray( @xdxf_reconstructed);
}
# Save reconstructed XDXF-file
my $dict_xdxf=$FileName;
if( $dict_xdxf !~ s~\.xdxf$~_reconstructed\.xdxf~ ){ die2("Filename substitution did not work for : '$dict_xdxf'"); }
array2File($dict_xdxf, @xdxf_reconstructed);

# Convert colors to hexvalues
if( $isConvertColorNamestoHexCodePoints ){ @xdxf_reconstructed = convertColorName2HexValue(@xdxf_reconstructed); }
# Create Stardict dictionary
if( $isCreateStardictDictionary ){
    if ( $isMakeKoreaderReady ){ @xdxf_reconstructed = makeKoreaderReady(@xdxf_reconstructed); }
    # Save reconstructed XML-file
    my @StardictXMLreconstructed = convertXDXFtoStardictXML(@xdxf_reconstructed);
    my $dict_xml = $FileName;
    if( $dict_xml !~ s~\.xdxf$~_reconstructed\.xml~ ){ die2("Filename substitution did not work for : '$dict_xml'"); }

    # Remove spaces in filename
    $dict_xml =~ s~(?<!\\) ~\ ~g;

    # check <bookname></bookname>
    if( $StardictXMLreconstructed[4] =~ s~(<bookname>)\s*(</bookname>)~$1UnknownDictionary$2~ ){ warn "Empty dictionary name!"; }
    array2File($dict_xml, @StardictXMLreconstructed);

    convertXML2Binary( $dict_xml );

    # Remove oft-file from old dictionary
    unlink join('', $FileName=~m~^(.+?)\.[^.]+$~)."_reconstructed.idx.oft" if $isTestingOn;
}

# Create Pocketbook dictionary

if( $isCreatePocketbookDictionary ){
    my $ConvertCommand;
    unless( $CreateTwoHalfPocketBookdictionaries ){
        if( $language_dir ne "" ){ $lang_from = $language_dir ;}
        if( $OperatingSystem eq "linux"){ $ConvertCommand = "WINEDEBUG=-all wine converter.exe \"$BaseDir/$dict_xdxf\" $lang_from"; }
        else{ $ConvertCommand = "converter.exe \"$dict_xdxf\" $lang_from"; }
        printYellow("Running system command:\"$ConvertCommand\"\n");
        system($ConvertCommand);
    }
    else{
        my $HalfLengthXDXF = int( scalar(@xdxf_reconstructed)/2 );
        info("Current half length is $HalfLengthXDXF");
        while( $xdxf_reconstructed[$HalfLengthXDXF] !~ m~^<ar>~  ){ print($xdxf_reconstructed[$HalfLengthXDXF]); $HalfLengthXDXF++; }
        info( "The array index $HalfLengthXDXF and the following lines are:\n$xdxf_reconstructed[$HalfLengthXDXF]$xdxf_reconstructed[$HalfLengthXDXF+1]$xdxf_reconstructed[$HalfLengthXDXF+2]");
        my @FirstHalf = splice(@xdxf_reconstructed, 0, $HalfLengthXDXF);
        info("scalar \@FirstHalf = ". scalar @FirstHalf);
        push @FirstHalf, $lastline_xdxf;
        my $FirstHalfName = $dict_xdxf;
        $FirstHalfName =~ s~reconstructed~reconstructed.1sfHalf~;
        array2File($FirstHalfName, @FirstHalf);
        my @SecondHalf = @xdxf_reconstructed;
        my $index = 0;
        my @start;
        while( $FirstHalf[$index] !~ m~<ar>~){
            push @start, $FirstHalf[$index];
            $index++;
        }
        unshift @SecondHalf, @start;
        my $SecondHalfName = $dict_xdxf;
        $SecondHalfName =~ s~reconstructed~reconstructed.2ndHalf~;

        array2File($SecondHalfName, @SecondHalf);
        if( $language_dir ne "" ){ $lang_from = $language_dir ;}
        if( $OperatingSystem eq "linux"){ $ConvertCommand = "WINEDEBUG=-all wine converter.exe \"$BaseDir/$FirstHalfName\" $lang_from"; }
        else{ $ConvertCommand = "converter.exe \"$FirstHalfName\" $lang_from"; }
        printYellow("Running system command:\"$ConvertCommand\"\n");
        system($ConvertCommand);
        if( $OperatingSystem eq "linux"){ $ConvertCommand = "WINEDEBUG=-all wine converter.exe \"$BaseDir/$SecondHalfName\" $lang_from"; }
        else{ $ConvertCommand = "converter.exe \"$SecondHalfName\" $lang_from"; }
        printYellow("Running system command:\"$ConvertCommand\"\n");
        system($ConvertCommand);
    }
}
my $Renamed = join('', $FileName=~m~^(.+?)\.[^.]+$~);
rename $Renamed.".xdxf", $Renamed.".backup.xdxf" if $isTestingOn;

if( $isCreateMDict ){
    my $mdict = join('', @xdxf_reconstructed);
    my $dictdata ;
    # Strip dictionary data
    if( $mdict =~ s~(?<start>(?:(?!<ar>).)+)<ar>~<ar>~s ){$dictdata = $+{start};}
    else{ die2("Regex mdict to strip dictionary data failed. Quitting.");}
    debugV("1st Length \$mdict is ", length($mdict));
    #Strip tags and insert EOLs.
    $mdict =~ s~<ar>\n<head><k>~~gs;
    debugV("2nd Length \$mdict is ", length($mdict));

    $mdict =~ s~</k></head><def>~\n~gs;
    debugV("3rd Length \$mdict is ", length($mdict));

    # Replace endtags
    $mdict =~ s~</def>\n</ar>~\n</>~gs;
    $mdict =~ s~</xdxf>\n~~;
    debug("Length \$mdict is ", length($mdict));

    # Insert keyword at start definition.
    $mdict =~ s~(?<pos_before>(?<key>[^\n]+)\n)~$+{pos_before}<bold>$+{key}</bold> ~s;
    $mdict =~ s~(?<pos_before></>\n(?<key>[^\n]+)\n)~$+{pos_before}<bold>$+{key}</bold> ~sg;
    debug("Length \$mdict is ", length($mdict));
    string2File($Renamed.".mdict.txt", $mdict);
}
chdir $BaseDir;
array2File("XmlTidied_line".__LINE__.".xml", @XMLTidied ) if $UseXMLTidy;
# Save hash for later use.
storeHash(\%ReplacementImageStrings, $ReplacementImageStringsHashFileName) if scalar keys %ReplacementImageStrings;

if( scalar keys %ValidatedOCRedImages ){
    unless( storeHash(\%ValidatedOCRedImages, $ValidatedOCRedImagesHashFileName) ){
        die2("Cannot store hash ValidatedOCRedImages.");
    } # To check whether filename is storable.
}