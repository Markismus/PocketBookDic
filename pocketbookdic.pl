#!/bin/perl
use strict;
# use autodie; # Does not get along with pragma 'open'.
use utf8;
use open IO => ':utf8';
use open ':std', ':utf8';
use feature 'unicode_strings'; # You get funky results with the sub convertNumberedSequencesToChar without this.
use feature 'say';
use Time::HiRes qw/ time /;
use Encode;

use lib '/home/mark/git/PocketBookDic/';
use DicGlobals;
use Dic2Screen;
use DicConversion;
use DicToggles;
use DicFileUtils;
use DicHelpUtils;
use DicPrepare;
use DicRoman;

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

$LocalPath = join('', $FileName=~ m~^(.+?)/[^/]+$~); # Update value with command line argument.
$FullPath = "$BaseDir/$LocalPath";                   # Update value with command line argument.

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

if( $isConvertImagesUsingOCR ){
    use Image::OCR::Tesseract 'get_ocr';
    $Image::OCR::Tesseract::DEBUG = 0;
    $ValidatedOCRedImagesHashFileName = join('', $FileName=~m~^(.+?\.)[^.]+$~)."validation.hash";
    if( -e $ValidatedOCRedImagesHashFileName ){ %ValidatedOCRedImages = %{ retrieveHash($ValidatedOCRedImagesHashFileName)}; }
    %OCRedImages = %ValidatedOCRedImages;
    info("Number of imagestrings OCRed is ".scalar keys %ValidatedOCRedImages);
    unless( storeHash(\%ValidatedOCRedImages, $ValidatedOCRedImagesHashFileName) ){ warn "Cannot store hash ValidatedOCRedImages."; Die();} # To check whether filename is storable.
    if( scalar keys %ValidatedOCRedImages == 0 ){ unlink $ValidatedOCRedImagesHashFileName; }
    else{ info("Mistakes in the validated values can be manually corrected by editing '$ValidatedOCRedImagesHashFileName'"); }
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


sub checkSameTypeSequence{
    my $FileName = $_[0];
    if(! $updateSameTypeSequence ){return;}
    elsif( -e substr($FileName, 0, (length($FileName)-4)).".ifo"){
        my $ifo = join( '',  file2Array(substr($FileName, 0, (length($FileName)-4)).".ifo") ) ;
        if($ifo =~ m~sametypesequence=(?<sametypesequence>\w)~s){
            printGreen("Initial sametypesequence was \"$SameTypeSequence\".");
            $SameTypeSequence = $+{sametypesequence};
            printGreen(" Updated to \"$SameTypeSequence\".\n");
        }
    }
    elsif( -e substr($FileName, 0, (length($FileName)-4)).".xml"){
        my $xml = join( '',  file2Array(substr($FileName, 0, (length($FileName)-4)).".xml") );
        # Extract sametypesequence from Stardict XML
        if( $xml =~ m~<definition type="(?<sametypesequence>\w)">~s){
            printGreen("Initial sametypesequence was \"$SameTypeSequence\".");
            $SameTypeSequence = $+{sametypesequence};
            printGreen(" Updated to \"$SameTypeSequence\".\n");
        }
    }
    return;}
sub filterXDXFforEntitites{
    my( @xdxf ) = @_;
    my @Filteredxdxf;
    if( scalar keys %EntityConversion == 0 ){
        debugV("No \%EntityConversion hash defined");
        return(@xdxf);
    }
    else{debug("These are the keys:", keys %EntityConversion);}
    $cycle_dotprinter = 0 ;
    waitForIt("Filtering entities based on DOCTYPE.");
    foreach my $line (@xdxf){
        $cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
        foreach my $EntityName(keys %EntityConversion){
            $line =~ s~(\&$EntityName;)~$EntityConversion{$EntityName}~g;
        }
        push @Filteredxdxf, $line;
    }
    doneWaiting();
    return (@Filteredxdxf);}
sub fixPrefixes{
                my( $PreviousDefinition, $CurrentDefinition ) = @_;
                debugV("\$CurrentDefinition:\n\"", $CurrentDefinition,"\"");
                debugV("\$PreviousDefinition:\n\"", $PreviousDefinition,"\"");
            
                my( $CurrentDefinitionPrefix, $PreviousDefinitionPrefix) = ( "", "");
                
                my @PossiblePrefixes = $PreviousDefinition =~ m~<sup>[ivx]+\.</sup>~gs;
                if( scalar @PossiblePrefixes > 0 ){
                    debugV("\@PossiblePrefixes\t=\t@PossiblePrefixes");
                    debugV("Multiple entries found.");
                    my $LastPrefix = $PossiblePrefixes[-1];
                    $LastPrefix =~ s~<sup>|</sup>|\.~~sg;
                    debugV("\$LastPrefix:\t=\t$LastPrefix");
                    my $LastPrefixArabic = arabic($LastPrefix);
                    $LastPrefixArabic++;
                    $CurrentDefinitionPrefix = "<sup>".roman($LastPrefixArabic).".</sup>";
                    debugV("\$CurrentDefinitionPrefix\t=\t$CurrentDefinitionPrefix");
                }
                else{
                    $PreviousDefinitionPrefix = '<sup>i.</sup>';
                    $CurrentDefinitionPrefix = '<sup>ii.</sup>';
                }
                
                $PreviousDefinition = $PreviousDefinitionPrefix.$PreviousDefinition;
                $CurrentDefinition  = $CurrentDefinitionPrefix.$CurrentDefinition;
                
                my $UpdatedDefinition = $PreviousDefinition."\n".$CurrentDefinition;
                debugV("\$UpdatedDefinition:\n\"", $UpdatedDefinition, "\"");
                return( $UpdatedDefinition);}
sub generateEntityHashFromDocType{
    my $String = $_[0]; # MultiLine DocType string. Not Array!!!
    my %EntityConversion=( );
    while($String =~ s~<!ENTITY\s+(?<name>[^\s]+)\s+"(?<meaning>.+?)">~~s){
        debugV("$+{name} --> $+{meaning}");
        $EntityConversion{$+{name}} = $+{meaning};
    }
    return(%EntityConversion);}
sub removeBloat{
    my $xdxf = join('',@_);
    debugV("Removing bloat from dictionary...");
    while ( $xdxf =~ s~<blockquote>(?<content><blockquote>(?!<blockquote>).*?</blockquote>)</blockquote>~$+{content}~sg ){ debugV("Another round (removing double nested blockquotes)");}
    while( $xdxf =~ s~<ex>\s*</ex>|<ex></ex>|<blockquote></blockquote>|<blockquote>\s*</blockquote>~~sg ){ debugV("And another (removing empty blockquotes and examples)"); }
    while( $xdxf =~ s~\n\n~\n~sg ){ debugV("Finally then..(removing empty lines)");}
    while( $xdxf =~ s~</blockquote>\s+<blockquote>~</blockquote><blockquote>~sg ){ debugV("...another one (removing EOLs between blockquotes)"); }
    while( $xdxf =~ s~</blockquote>\s+</def>~</blockquote></def>~sg ){ debugV("...and another one (removing EOLs between blockquotes and definition stop tags)"); }
    # This a tricky one.
    # OALD9 has a strange string [s]key.bmp[/s] that keeps repeating. No idea why!
    while( $xdxf =~ s~\[s\].*?\.bmp\[/s\]~~sg ){ debugV("....cleaning house (removing s-blocks with .bmp at the end.)"); }
    debugV("...done!");
    return( split(/^/, $xdxf) );}
my @XMLTidied;
sub tidyXMLArray{
    my $UseXMLTidyHere = 0;
    my $UseXMLLibXMLPrettyPrint = 0;
    my $UseXMLBlockArray = 0;
    if( $UseXMLTidyHere ){
        use XML::Tidy;
        use warnings;
        array2File("tobetidied.xml", @_) ;

        # create new   XML::Tidy object by loading:  MainFile.xml
        my $tidy_obj = XML::Tidy->new('filename' => 'tobetidied.xml');

        # tidy  up  the  indenting
       $tidy_obj->tidy();

        # write out changes back to MainFile.xml
        $tidy_obj->write();
        my @ReturnedXML = file2Array( "tobetidied.xml" );
        my @TidiedXML;
        foreach( @ReturnedXML){
            if( $_ eq "\n" or $_ eq '<?xml version="1.0" encoding="utf-8"?>'."\n"){ next;}
            push @TidiedXML, $_;
        }
        return( @TidiedXML );    }
    elsif($UseXMLLibXMLPrettyPrint){
        use XML::LibXML;
        array2File("tobetidied.xml", @_);
        my $document = XML::LibXML->new->parse_file('tobetidied.xml');
        my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");
        $pp->pretty_print($document); # modified in-place
        return( split(/^/,$document->toString ) );
    }
    elsif( $UseXMLBlockArray ){
        my $xml = join('', @_);
        $xml =~ s~(?<!\n)(</?blockquote[^>]*>)~$1\n$2~sg;
        $xml =~ s~(</?blockquote[^>]*>)(?>!\n)~$1\n$2~sg;
        $xml =~ s~\n\n~\n~sg;
        if(scalar @_ > 1){ return (split( /^/, $xml) ); }
        else{ return $xml;}
    }
    else{
        my $xml = join('', @_);
        $xml =~ s~(?!\n)(</?blockquote[^>]*>)~$1\n$2~sg;
        $xml =~ s~(</?blockquote[^>]*>)(?!\n)~$1\n$2~sg;
        $xml =~ s~\n\n~\n~sg;
        push @XMLTidied, $xml;
        if(scalar @_ > 1){ return (split( /^/, $xml) ); }
        else{ return $xml;}
    }}

# Generate entity hash defined in DOCTYPE
%EntityConversion = generateEntityHashFromDocType($DocType);

# Fill array from file.
my @xdxf;
@xdxf = loadXDXF();
array2File("testLoaded_line".__LINE__.".xdxf", @xdxf) if $isTestingOn;
my $SizeOne = scalar @xdxf;
debugV("\$SizeOne\t=\t$SizeOne");
# Remove bloat from xdxf.
if( $FileName !~ m~_unbloated\.xdxf$~ ){
    @xdxf = removeBloat(@xdxf);
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
if( $dict_xdxf !~ s~\.xdxf$~_reconstructed\.xdxf~ ){ debug("Filename substitution did not work for : \"$dict_xdxf\""); Die(); }
array2File($dict_xdxf, @xdxf_reconstructed);

# Convert colors to hexvalues
if( $isConvertColorNamestoHexCodePoints ){ @xdxf_reconstructed = convertColorName2HexValue(@xdxf_reconstructed); }
# Create Stardict dictionary
if( $isCreateStardictDictionary ){
    if ( $isMakeKoreaderReady ){ @xdxf_reconstructed = makeKoreaderReady(@xdxf_reconstructed); }
    # Save reconstructed XML-file
    my @StardictXMLreconstructed = convertXDXFtoStardictXML(@xdxf_reconstructed);
    my $dict_xml = $FileName;
    if( $dict_xml !~ s~\.xdxf$~_reconstructed\.xml~ ){ debug("Filename substitution did not work for : \"$dict_xml\""); Die(); }

    # Remove spaces in filename
    # my @dict_xml = split('/',$dict_xml);
    $dict_xml =~ s~(?<!\\) ~\ ~g;
    # $dict_xml = join('/', @dict_xml);
    # check <bookname></bookname>
    if( $StardictXMLreconstructed[4] =~ s~(<bookname>)\s*(</bookname>)~$1UnknownDictionary$2~ ){ warn "Empty dictionary name!"; }
    array2File($dict_xml, @StardictXMLreconstructed);

    # Convert reconstructed XML-file to binary
    if ( $OperatingSystem eq "linux"){
        my $dict_bin = $dict_xml;
        $dict_bin =~ s~\.xml~\.ifo~;
        my $command = "stardict-text2bin \"$BaseDir/$dict_xml\" \"$BaseDir/$dict_bin\" ";
        printYellow("Running system command:\n$command\n");
        system($command);
        # Workaround for dictzip
        if( $dict_bin =~ m~ |\(|\)~ ){
            debug_t("Spaces or braces found, so dictzip will have failed. Running it again while masking the spaces.");
            if( $dict_bin !~ m~(?<filename>[^/]+)$~){ debug("Regex not working for dictzip workaround."); die if $isRealDead; }
            my $SpacedFileName = $+{filename};
            
            my $Path = $dict_bin;
            if( $Path =~ s~\Q$SpacedFileName\E~~ ){ debug("Changing to path $Path"); }
            unless( chdir $Path ){ warn "Couldn't change directory to '$Path'"; }
            else{ info_t("Directory change successfull."); }

            $SpacedFileName =~ s~ifo$~dict~;
            my $MaskedFileName = $SpacedFileName;
            $MaskedFileName =~ s~ ~__~g;
            $MaskedFileName =~ s~\(~___~g;
            $MaskedFileName =~ s~\)~____~g;

            if( -e $SpacedFileName ){ rename "$SpacedFileName", "$MaskedFileName"; }
            else{ warn "Couldn't find '$SpacedFileName'."; }
            my $command = "dictzip $MaskedFileName";
            printYellow("Running system command:\n$command\n");
            system($command);
            unless( rename "$MaskedFileName.dz", "$SpacedFileName.dz"){ warn "Couldn't rename '$MaskedFileName.dz'"; }
        }
        else{ debug("No spaces in filename."); debug("\$dict_bin is \'$dict_bin\'"); }
    }
    else{
        debug("Not linux, so you the script created an xml Stardict dictionary.");
        debug("You'll have to convert it to binary manually using Stardict editor.")
    }
    # Remove oft-file from old dictionary
    unlink join('', $FileName=~m~^(.+?)\.[^.]+$~)."_reconstructed.idx.oft" if $isTestingOn;
}

# Create Pocketbook dictionary
if( $isCreatePocketbookDictionary ){
    my $ConvertCommand;
    if( $language_dir ne "" ){ $lang_from = $language_dir ;}
    if( $OperatingSystem eq "linux"){ $ConvertCommand = "WINEDEBUG=-all wine converter.exe \"$BaseDir/$dict_xdxf\" $lang_from"; }
    else{ $ConvertCommand = "converter.exe \"$dict_xdxf\" $lang_from"; }
    printYellow("Running system command:\"$ConvertCommand\"\n");
    system($ConvertCommand);
}
my $Renamed = join('', $FileName=~m~^(.+?)\.[^.]+$~);
rename $Renamed.".xdxf", $Renamed.".backup.xdxf" if $isTestingOn;

if( $isCreateMDict ){
    my $mdict = join('', @xdxf_reconstructed);
    my $dictdata ;
    # Strip dictionary data
    if( $mdict =~ s~(?<start>(?:(?!<ar>).)+)<ar>~<ar>~s ){$dictdata = $+{start};}
    else{ debug("Regex mdict to strip dictionary data failed. Quitting."); Die();}
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
        warn "Cannot store hash ValidatedOCRedImages.";
        Die();
    } # To check whether filename is storable.
}