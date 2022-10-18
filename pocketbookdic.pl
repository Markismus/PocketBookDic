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
sub cleanseAr{
    my @Content = @_;
    my $Content = join('',@Content) ;
    
    # Special characters in $head and $def should be converted to
    #  &lt; (<), &amp; (&), &gt; (>), &quot; ("), and &apos; (')
    my $PossibleTags = qr~/?(def|mbp|c>|c c="|abr>|ex>|kref>|k>|key|rref|f>|!--|!doctype|a|abbr|acronym|address|applet|area|article|aside|audio|b>|base|basefont|bb|bdo|big|blockquote|body|/?br|button|canvas|caption|center|cite|code|col|colgroup|command|datagrid|datalist|dd|del|details|dfn|dialog|dir|div|dl|dt|em|embed|eventsource|fieldset|figcaption|figure|font|footer|form|frame|frameset|h[1-6]|head|header|hgroup|hr/|html|i>|i |iframe|img|input|ins|isindex|kbd|keygen|label|legend|li|link|map|mark|menu|meta|meter|nav|noframes|noscript|object|ol|optgroup|option|output|p|param|pre|progress|q>|rp|rt|ruby|s>|samp|script|section|select|small|source|span|strike|strong|style|sub|sup|table|tbody|td|textarea|tfoot|th|thead|time|title|tr|track|tt|u>|ul|var|video|wbr)~;
    my $HTMLcodes = qr~(lt;|amp;|gt;|quot;|apos;|\#x?[0-9A-Fa-f]{1,6})~;
        
    $Content =~ s~(?<lt><)(?!$PossibleTags)~&lt;~gs if $EscapeHTMLCharacters;
    $Content =~ s~(?<amp>&)(?!$HTMLcodes)~&amp;~gs if $EscapeHTMLCharacters;
    
    # Remove preceding and trailing empty lines.
    $Content =~ s~^\n~~gs;
    $Content =~ s~\n$~~gs;

    if( $Content =~ m~^<head>(?<head>(?:(?!</head).)+)</head><def>(?<def>(?:(?!</def).)+)</def>~s){
        # debugFindings();
        # debug("Well formed ar content entry");
        my $head = $+{head};
        my $def_old = $+{def};
        my $def = $def_old;
        $def =~ s~</?mbp[^>]*>~~sg;

        my $ExtraDebugging = 0;
        if( $head eq $DebugKeyWordCleanseAr ){ debug("Found debug keyword in cleanseAr. Extra debugging on for this article."); $ExtraDebugging = 1; }
        if( $ExtraDebugging ){ debug("\$max_line_length\t=\t$max_line_length"); }

        if( $isCreatePocketbookDictionary){
            # Splits complex blockquote blocks from each other. Small impact on layout.
            $def =~ s~</blockquote><blockquote>~</blockquote>\n<blockquote>~gs;
            # Splits blockquote from next heading </blockquote><b><c c=
            $def =~ s~</blockquote><b><c c=~</blockquote>\n<b><c c=~gs;
            # Remove base64 encoded content: $replacement = '<img src="data:image/'.$imageformat.';base64,'.$encoded.'" alt="'.$imageName.'"/>';
            $def =~ s~<img src="data:[^/]+/[^;]+;base64[^>]+>~~g;
            # Splits the too long lines.
            if( length($def) > 2000){ $def = join('', tidyXMLArray( $def ) );}
            my @def = split(/\n/,$def);
            my $def_line_counter = 0;
            foreach my $line (@def){
                 $def_line_counter++;
                 if( $ExtraDebugging ){ debug("'$line'");}
                
                my $lengthLineUTF8 = length(encode('UTF-8', $line));
                my $lengthLine = length($line);
                if( $lengthLine == 0){ next; }
                my $RatioLenghtUTF = $lengthLineUTF8 / $lengthLine;

                if( $ExtraDebugging ){ debug("\$lengthLineUTF8\t=\t$lengthLineUTF8 (bytes)"); debug("\$lengthLine\t=\t$lengthLine (chars)"); debug("\$RatioLenghtUTF = $RatioLenghtUTF"); }
                 # Finetuning of cut location
                 if ( $lengthLineUTF8 > $max_line_length){
                    if ( $isCutDoneWithTidyXML ){ $line = join('', tidyXMLArray( $line ) ); next; }
                     if( $ExtraDebugging ){ debug("\$lengthLineUTF8 > $max_line_length"); }
                     # So I would like to cut the line at say 3500 chars not in the middle of a tag, so before a tag.
                     # index STR,SUBSTR,POSITION
                     sub cutsize{
                         # Usage: $cutsize = cutsize( $line, $cut_location);
                         my ($line, $cut_location) = @_;
                         my $bytesize = length(encode('UTF-8', substr($line, 0, $cut_location) ) );
                         return $bytesize;
                     }
                     my $cut_location = rindex $line, "<", int($max_line_length * 0.85 / $RatioLenghtUTF );
                     if($cut_location < 1 ){
                         # No "<" found.
                         if( $ExtraDebugging ){ debug("No '<' found."); }
                         $cut_location = (rindex $line, " ", int($max_line_length * 0.85 / $RatioLenghtUTF)) + 1 ;
                         if($cut_location < 1){
                             debug("No Space found in substring. Quitting"); die;
                         }
                     }
                     elsif(cutsize( $line, $cut_location) > $max_line_length){
                         debug("Don't know what happend, yet." );
                         debug("Line");
                         debug($line);
                         debug("\$lengthLineUTF8\t=\t$lengthLineUTF8 (bytes)"); debug("\$lengthLine\t=\t$lengthLine (chars)"); debug("\$RatioLenghtUTF = $RatioLenghtUTF");
                         debug("\$max_line_length\t=\t$max_line_length");
                         debug("\$cut_location\t=\t$cut_location");
                         debug("int($max_line_length * 0.85 / $RatioLenghtUTF )\t=\t",int($max_line_length * 0.85 / $RatioLenghtUTF ));
                         debug("index \$line, \"<\", int(\$max_line_length * 0.85 / \$RatioLenghtUTF )\t=\t", index $line, "<", int($max_line_length * 0.85 / $RatioLenghtUTF ));
                         debug("rindex \$line, \"<\", int(\$max_line_length * 0.85 / \$RatioLenghtUTF )\t=\t", rindex $line, "<", int($max_line_length * 0.85 / $RatioLenghtUTF ));
                         debug("rindex \$line, \"<\", int(\$max_line_length * 0.85 / \$RatioLenghtUTF )\t=\t", rindex substr($line, 0, int($max_line_length * 0.85 / $RatioLenghtUTF )), "<");
                         debug("cutsize is too big: ",cutsize( $line, $cut_location));
                         debug("First piece");
                         debug(substr($line, 0, $cut_location));
                         debug("Second piece");
                         debug(substr($line, $cut_location));
                         die;


                     }
                     debugV("Definition line $def_line_counter of lemma $head is ",length($line)," characters and ",length(encode('UTF-8', $line))," bytes. Cut location is $cut_location.");
                     my $cutline_begin = substr($line, 0, $cut_location)."\n";
                     if( $ExtraDebugging ){ debug("cutline_begin is ",length(encode('UTF-8', $cutline_begin))," bytes"); }
                     my $cutline_end = substr($line, $cut_location);
                     if( $ExtraDebugging){ debug("Line taken to be cut:") and printYellow("$line\n") and
                     debug("First part of the cut line is:") and printYellow("$cutline_begin\n") and
                     debug("Last part of the cut line is:") and printYellow("$cutline_end\n"); }

                     die if ($cut_location > $max_line_length) and $isRealDead;
                     # splice array, offset, length, list
                     splice @def, $def_line_counter, 0, ($cutline_end);
                     $line = $cutline_begin;
                 }
            }
            $def = join("\n",@def);
            # debug($def);
            # Creates multiple articles if the article is too long.

            my $def_bytes = length(encode('UTF-8', $def));
            if( $def_bytes > $max_article_length ){
                debugV("The length of the definition of \"$head\" is $def_bytes bytes.");
                #It should be split in chunks < $max_article_length , e.g. 64kB
                my @def=split("\n", $def);
                my @definitions=();
                my $counter = 0;
                my $loops = 0;
                my $concatenation = "";
                # Split the lines of the definition in separate chunks smaller than 90kB
                foreach my $line(@def){
                    $loops++;
                    # debug("\$loops is $loops. \$counter at $counter" );
                    $concatenation = $definitions[$counter]."\n".$line;
                    if( length(encode('UTF-8', $concatenation)) > $max_article_length ){
                        debugV("Chunk is larger than ",$max_article_length,". Creating another chunk.");
                        chomp $definitions[$counter];
                        $counter++;

                    }
                    $definitions[$counter] .= "\n".$line;
                }
                chomp $definitions[$counter];
                # Join the chunks with the relevant extra tags to form multiple ar entries.
                # $Content is between <ar> and </ar> tags. It consists of <head>$head</head><def>$def_old</def>
                # So if $def is going to replace $def_old in the later substitution: $Content =~ s~\Q$def_old\E~$def~s; ,
                # how should the chunks be assembled?
                # $defs[0]."</def></ar><ar><head>$head</head><def>".$defs[1]."...".$def[2]
                my $newhead = $head;
                $newhead =~ s~</k>~~;
                # my @Symbols = (".",":","⁝","⁞");
                # my @Symbols = ("a","aa","aaa","aaaa");
                my @Symbols = ("","","","");
                # debug("Counter reached $counter.");
                $def="";
                for(my $a = 0; $a < $counter; $a = $a + 1 ){
                        # debug("\$a is $a");
                        $def.=$definitions[$a]."</def>\n</ar>\n<ar>\n<head>$newhead$Symbols[$a]</k></head><def>\n";
                        debugV("Added chunk ",($a+1)," to \$def together with \"</def></ar>\n<ar><head>$newhead$Symbols[$a]</k></head><def>\".");
                }
                $def .= $definitions[$counter];

            }

        }



        if($remove_color_tags){
            # Removes all color from lemma description.
            # <c c="darkslategray"><c>Derived:</c></c> <c c="darkmagenta">
            # Does not remove for example <span style="color:#472565;"> and corresponding </span>!!!
            # Does not remove for example <font color="#007000">noun</font>!!!
            $def =~ s~<\?c>~~gs;
            $def =~ s~<c c=[^>]+>~~gs;
            # Does not remove span-blocks with nested html-blocks.
            $def =~ s~<span style="color:#\d+;">(?<colored_text>[^<]*)</span>~$+{colored_text}~gs;
            # Does not remove font-blocks with nested html-blocks.
            $def =~ s~<font color="#\d+">(?<colored_text>[^<]*)</font>~$+{colored_text}~gs;
        }

        $Content =~ s~\Q$def_old\E~$def~s;
    }
    else{debug("Not well formed ar content!!\n\"$Content\"");}

    if ($isRemoveWaveReferences){
        # remove wav-files displaying
        # Example:
        # <rref>
        #z_epee_1_gb_2.wav</rref>
        #<rref>z_a__gb_2.wav</rref>
        # <c c="blue"><b>ac</b>‧<b>quaint</b></c> /əˈkweɪnt/ <abr>BrE</abr> <rref>bre_ld41acquaint.wav</rref> <abr>AmE</abr> <rref>ame_acquaint.wav</rref><i><c> verb</c></i><c c="green"> [transitive]</c><i><c c="maroon"> formal</c></i>
        $Content =~ s~(<abr>(AmE|BrE)</abr>)? *<rref>((?!\.wav</rref>).)+\.wav</rref>~~gs;
    }

    return( $Content );}
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
sub loadXDXF{
    # Create the array @xdxf
    my @xdxf;
    my $PseudoFileName = join('', $FileName=~m~^(.+?\.)[^.]+$~)."xdxf";
    ## Load from xdxffile
    if( $FileName =~ m~\.xdxf$~){ @xdxf = file2Array($FileName); }
    elsif( -e $PseudoFileName ){
        @xdxf = file2Array($PseudoFileName);
        # Check SameTypeSequence
        checkSameTypeSequence($FileName);
        # Change FileName to xdxf-extension
        $FileName = $PseudoFileName;
    }
    ## Load from ifo-, dict- and idx-files
    elsif( $FileName =~ m~^(?<filename>((?!\.ifo).)+)\.(ifo|xml)$~){
        # Check wheter a converted xml-file already exists or create one.
        if(! -e $+{filename}.".xml"){
            # Convert the ifo/dict using stardict-bin2text $FileName $FileName.".xml";
            if ( $OperatingSystem == "linux"){
                printCyan("Convert the ifo/dict using system command: \"stardict-bin2text $FileName $FileName.xml\"\n");
                system("stardict-bin2text \"$FileName\" \"$+{filename}.xml\"");
            }
            else{ debug("Not linux, so you can't use the script directly on ifo-files, sorry!\n",
                "First decompile your dictionary with stardict-editor to xml-format (Textual Stardict dictionary),\n",
                "than either use the ifo- or xml-file as your dictioanry name for conversion.")}
        }
        # Create an array from the stardict xml-dictionary.
        my @StardictXML = file2Array("$+{filename}.xml");
        @xdxf = convertStardictXMLtoXDXF(@StardictXML);
        # Write it to disk so it hasn't have to be done again.
        array2File($+{filename}.".xdxf", @xdxf);
        # debug(@xdxf); # Check generated @xdxf
        $FileName=$+{filename}.".xdxf";
    }
    ## Load from comma separated values cvs-file.
    ## It is assumed that every line has a key followed by a comma followed by the definition.
    elsif( $FileName =~ m~^(?<filename>((?!\.csv).)+)\.csv$~){
        my @cvs = file2Array($FileName);
        @xdxf = convertCVStoXDXF(@cvs);
        # Write it to disk so it hasn't have to be done again.
        array2File($+{filename}.".xdxf", @xdxf);
        # debug(@xdxf); # Check generated @xdxf
        $FileName=$+{filename}.".xdxf";
    }
    elsif(    $FileName =~ m~^(?<filename>((?!\.mobi).)+)\.mobi$~ or
            $FileName =~ m~^(?<filename>((?!\.azw3?).)+)\.azw3?$~ or
            $FileName =~ m~^(?<filename>((?!\.html?).)+)\.html?$~    ){
        # Use full path and filename
        my $InputFile = "$BaseDir/$FileName";
        my $OutputFolder = substr($InputFile, 0, length($InputFile)-5);
        unless( $OutputFolder =~ m~([^/]+)$~ ){ warn "Couldn't match dictionary name for '$OutputFolder'" ; Die(); }
        my $DictionaryName = $1;
        my $HTMLConversion = 0;
        my $RAWMLConversion = 0;
        if( $FileName =~ m~^(?<filename>((?!\.mobi).)+)\.mobi$~ or
            $FileName =~ m~^(?<filename>((?!\.azw3?).)+)\.azw3?$~     ){

            # Checklist
            if ($OperatingSystem eq "linux"){ debugV("Converting mobi to html on Linux is possible.") }
            else{ debug("Not Linux, so the script can't convert mobi-format. Quitting!"); die; }
            my $python_version = `python --version`;
            if(  substr($python_version, 0,6) eq "Python"){
                debug("Found python responding as expected.");
            }
            else{ debug("Python binary not working as expected/not installed. Quitting!"); die; }

            # Conversion mobi to html
            if( -e "$OutputFolder/mobi7/$DictionaryName.html" ){
                debug("html-file found. Mobi-file already converted.");
                $HTMLConversion = 1;
                $LocalPath = "$LocalPath/$DictionaryName/mobi7";
                $FullPath = "$FullPath/$DictionaryName/mobi7";
                $FileName = "$LocalPath/$DictionaryName.html";
            }
            elsif( -e "$OutputFolder/mobi7/$DictionaryName.rawml" ){
                debug("rawml-file found. Mobi-file already converted, but KindleUnpack failed to convert it to html.");
                debug("Will try at the rawml-file, but don't get your hopes up!");
                $RAWMLConversion = 1;
                $LocalPath = "$LocalPath/$DictionaryName/mobi7";
                $FullPath = "$FullPath/$DictionaryName/mobi7";
                $FileName = "$LocalPath/$DictionaryName.rawml";
            }
            else{
                chdir $KindleUnpackLibFolder || warn "Cannot change to $KindleUnpackLibFolder: $!\n";
                waitForIt("The script kindelunpack.py is now unpacking the file:\n$InputFile\nto: $OutputFolder.");
                my $returnstring = `python kindleunpack.py -r -s --epub_version=A -i "$InputFile" "$OutputFolder"`;
                if( $returnstring =~ m~Completed\n*$~s ){
                    debug("Succes!");
                    chdir $BaseDir || warn "Cannot change to $BaseDir: $!\n";
                    rename "$OutputFolder/mobi7/book.html", "$OutputFolder/mobi7/$DictionaryName.html";
                    doneWaiting();
                    $HTMLConversion = 1;
                    $LocalPath = "$LocalPath/$DictionaryName/mobi7";
                    $FullPath = "$FullPath/$DictionaryName/mobi7";
                    $FileName = "$LocalPath/$DictionaryName.html";
                }
                else{
                    debug("KindleUnpack failed to convert the mobi-file.");
                    debug($returnstring);
                    if( -e "$OutputFolder/mobi7/$DictionaryName.rawml" ){
                        debug("rawml-file found. Mobi-file already converted, but KindleUnpack failed to convert it to html.");
                        debug("Will try at the rawml-file, but don't get your hopes up!");
                        $RAWMLConversion = 1;
                        $LocalPath = "$LocalPath/$DictionaryName/mobi7";
                        $FullPath = "$FullPath/$DictionaryName/mobi7";
                        $FileName = "$LocalPath/$DictionaryName.rawml";
                        chdir $BaseDir || warn "Cannot change to $BaseDir: $!\n";
                    }
                    else{ Die(); }
                }
            }
            debug("After conversion dictionary name is '$DictionaryName'.");
            debug("Local path for generated html is \'$LocalPath\'.");
            debug("Full path for generated html is \'$FullPath\'.");
            debug("Filename for generated html is \'$FileName\'.");
        }
        elsif( $FileName =~ m~^(?<filename>((?!\.html?).)+)\.html?$~    ){
            $HTMLConversion = 1;
        }

        # Output of KindleUnpack.pyw
        my $encoding = "UTF-8";
        if( $HTMLConversion ){
            my @html = file2Array($FileName);
            @xdxf = convertHTML2XDXF($encoding,@html);
            array2File("testConvertedHTML.xdxf", @xdxf) if $isTestingOn;
        }
        elsif( $RAWMLConversion ){
            my @rawml = file2Array( $FileName );
            @xdxf = convertRAWML2XDXF( @rawml );
            if( scalar @xdxf == (1+scalar @xdxf_start) ){ debug("Not able to handle the rawml-file. Quitting!"); Die(); }
        }
        # Check whether there is a saved reconstructed xdxf to get the language and name from.
        if(-e  "$LocalPath/$DictionaryName"."_reconstructed.xdxf"){
            my @saved_xdxf = file2Array("$LocalPath/$DictionaryName"."_reconstructed.xdxf");
            if( $saved_xdxf[1] =~ m~<xdxf lang_from="[^"]+" lang_to="[^"]+" format="visual">~ ){
                $xdxf[1] = $saved_xdxf[1];
            }
            if( $saved_xdxf[2] =~ m~<full_name>[^<]+</full_name>~ ){
                @xdxf[2] = @saved_xdxf[2];
            }
        }
        else{debug('No prior dictionary reconstructed.');}
        $FileName="$LocalPath/$DictionaryName".".xdxf";
        # Write it to disk so it hasn't have to be done again.
        array2File($FileName, @xdxf);
        # debug(@xdxf); # Check generated @xdxf
    }
    elsif( $FileName =~ m~^(?<filename>((?!\.epub).)+)\.epub$~i ){
        debug("Found an epub-file. Unzipping.");
        unless( $FileName =~ m~([^/]+)$~ ){ warn "Couldn't match dictionary name for '$FileName'" ; Die(); }
        my $DictionaryName = $1;
        debug('$DictionaryName = "', $DictionaryName, '"');
        my $LocalPath = substr($FileName, 0, length($FileName)-length($DictionaryName) );
        chdir $BaseDir."/".$LocalPath;
        my $SubDir = substr($DictionaryName, 0, length($DictionaryName)-5);
        $SubDir =~ s~ ~__~g;
        unless( -e $SubDir){`mkdir "$SubDir"`; debug( "Made directory '$SubDir'"); }
        else{ debug("Directory '$SubDir' already exists. Files will be overwritten if present."); }
        my $UnzipCommand = "7z e -y \"$DictionaryName\" -o\"$SubDir\"";
        debugV("Executing command:\n '$UnzipCommand'");
        system($UnzipCommand);
        debug("\"$SubDir/*.html\"");

        my @html = glob("$SubDir/*.html");
        debugV('@html = ', @html);
        @xdxf = @xdxf_start;
        foreach my $HTMLFile( @html ){
            my $Content = join('', file2Array($HTMLFile) );
            # <style type="text/css">
            # p{text-align:left;text-indent:0;margin-top:0;margin-bottom:0;}
            # .ww{color:#FFFFFF;}
            # .gag{font-weight:bold;}
            # .gc{font-weight:bold;text-decoration:underline;}
            # .g4{color:#115349;}
            # .g5{color:#3B3B3B;}
            # .g6_s{color:#472565;}
            # .gm{font-style:italic;}
            # .gaa_gj{font-weight:bold;}
            # .gh{font-weight:bold;}
            # </style>
            my (@Classes, %Classes);
            if( $Content =~ m~<style type="text/css">(?<styleblock>(?!</style>).+)</style>~s ){
                my $StyleBlock = $+{styleblock};
                debugV("StyleBlock is \n$StyleBlock");
                @Classes = $StyleBlock =~ m~\.([^\{]+)\{(?<style>[^\}]+)\}~sg;
                while( @Classes){
                    my $Class = shift @Classes;
                    my $Style = shift @Classes;
                    $Class = "class=\"$Class\"";
                    $Style = "style=\"$Style\"";
                    debugV("Class '$Class' is style '$Style'");
                    $Classes{$Class} =  $Style;
                }
            }
            else{ debug("No StyleBlock found.");}
            foreach my $Class( keys %Classes){
                $Content =~ s~\Q$Class\E~$Classes{$Class}~sg;
            }
            debugV($Content);
            my @Paragraphs = $Content =~ m~(<p[^>]*>(?:(?!</p>).)+</p>)~sg;
            foreach(@Paragraphs){
                debugV($_);
            }
            debugV("number of paragraphs in '$HTMLFile' is ", scalar @Paragraphs);
            my $isLoopDebugging = 0;
            while(@Paragraphs){
                my $Key = shift @Paragraphs;
                my $Def = shift @Paragraphs;
                # <p style="color:#FFFFFF;"><sub>q  32 chars
                # </sub></p>            10 chars
                $Key = substr( $Key, 32, length($Key) - 42);
                # debug('$Key is ', $Key);
                # debug('$Def is ', $Def);
                push @xdxf, "<ar><head><k>$Key</k></head><def>$Def</def></ar>\n";
                debug("Pushed <ar><head><k>$Key</k></head><def>$Def</def></ar>") if $isLoopDebugging;
            } # Finished all Paragraphs

        } # Finished all HTMLFiles
        push @xdxf, "</xdxf>\n";
        my $XDXFfile = $DictionaryName;
        $XDXFfile =~ s~epub$~xdxf~;
        array2File($XDXFfile, @xdxf);

        $FileName = $LocalPath.$XDXFfile;

        debugV("Current directory was ", `pwd`);
        debugV("Returning to basedir '$BaseDir'.");
        chdir $BaseDir;
    }
    else{debug("Not an extension that the script can handle for the given filename. Quitting!");die;}


    return( @xdxf );}
sub makeKoreaderReady{
    my $html = join('',@_);
    waitForIt("Making the dictionary Koreader ready.");
    # Not moving it to lua, because it also works with Goldendict.
    $html =~ s~<c>~<span>~sg;
    $html =~ s~<c c="~<span style="color:~sg;
    $html =~ s~</c>~</span>~sg;
    # <span color="#0000ff"> $isMakeKoreaderReady_SpanColor2Style $isMakeKoreaderReady_SpanWidth2Style $isMakeKoreaderReady_SpanStyleWidht2Padding $isMakeKoreaderReady_MergeStyles
    while( $isMakeKoreaderReady_SpanColor2Style        and $html =~ s~(<span[^>]+?) (color)="([^"]+"[^>]*>)~$1 style="$2:$3~sg ){ printGreen("."); }
    while( $isMakeKoreaderReady_SpanWidth2Style        and $html =~ s~(<span[^>]+?) (width)="([^"]+"[^>]*>)~$1 style="$2:$3~sg ){ printRed( "."); }
    while( $isMakeKoreaderReady_SpanStyleWidht2Padding and $html =~ s~style="width:-(\d+)"~style="padding-left:$1px"~sg ){ printMagenta( "."); }
    # while( $html =~ s~(<[^>]+?) (size)="([^"]+"[^>]*>)~$1 style="$2:$3~sg ){ printGreen "."; }
    # while( $html =~ s~(<[^>]+?) (height)="([^"]+"[^>]*>)~$1 style="$2:$3~sg ){ printGreen "."; }
    while( $isMakeKoreaderReady_MergeStyles            and $html =~ s~(<[^>]+? style="[^"]*)("[^>]*?) style="([^"]*"[^>]*>)~$1;$2~ ){ printYellow("."); }
    # Things done with css-file
    my @css;
    my $FileNameCSS = join('', $FileName=~m~^(.+?)\.[^.]+$~)."_reconstructed.css";
    # Remove large blockquote margins
    if( scalar @ABBYY_CSS ){ @css = @ABBYY_CSS };
    push @css, "blockquote { margin: 0 0 0 1em }\n";
    # Remove images
    # $html =~ s~<img[^>]+>~~sg;
    # push @css, "img { display: none; }\n"; # Doesn't work. Placeholder [image] still appears in Koreader.
    if(scalar @css>0){array2File($FileNameCSS,@css);}
    # Things done with lua-file
    my @lua;
    my $FileNameLUA = join('', $FileName=~m~^(.+?)\.[^.]+$~)."_reconstructed.lua";
    # Example
    # return function(html)
    # html = html:gsub('<c c=\"', '<span style="color:')
    # html = html:gsub('</c>', '</span>')
    # html = html:gsub('<c>', '<span>')
    # return html
    # end
    # Example
    # return function(html)
    # -- html = html:gsub(' style=', ' zzztyle=')
    # html = html:gsub(' [Ss][Tt][Yy][Ll][Ee]=', ' zzztyle=')
    # return html
    # end
    my @ChangeTable2Div = (
        q~while html:find("(<table[^>]+>.-)</?p[^>]*>(.-</table>)") do~,
        q~    html  = html:gsub("(<table[^>]+>.-)</?p[^>]*>(.-</table>)", "%1%2")~,
        q~end~,
        q~html = html:gsub("<table[^>]+>", '<p></p><div style="display:table;>')~,
        q~html = html:gsub("<tr[^>]+>", '<p><div style="display:table-row;">')~,
        q~html = html:gsub("<td[^>]+>", '<div style="display:table-cell;">|') -- ｜~,
        q~html = html:gsub("</td>", '</div>')~,
        q~html = html:gsub("</tr>", '</div></p><hr style="height:3px;color:black;" />')~,
        q~html = html:gsub("</table>", '</div><p></p>')~,
        q~return html~,
        q~end~, );
    my $lua_start = "return function(html)\n";
    my $lua_end = "return html\nend\n";
    # Remove images
    push @lua, "html = html:gsub('<img[^>]+>', '')\n";
    if( $isChangeTable2Div4Koreader ){ push @lua, @ChangeTable2Div; }
    if(scalar @lua>0){
        unshift @lua, $lua_start;
        push @lua, $lua_end;
        array2File($FileNameLUA,@lua);
    }
    doneWaiting();
    
    return(split(/$/, $html));}
sub reconstructXDXF{
    # Construct a new xdxf array to prevent converter.exe from crashing.
    ## Initial values
    my @xdxf = @_;
    my @xdxf_reconstructed = ();
    my $xdxf_closing = "</xdxf>\n";
    
    # Initalizing values based on found values in reconstructed xdxf-file
    my $full_name;
    my $dict_xdxf_reconstructed =  $FileName;
    if( $dict_xdxf_reconstructed !~ s~\.[^\.]+$~_reconstructed\.xdxf~ ){ debug("Filename substitution did not work for : \"$dict_xdxf_reconstructed\""); die if $isRealDead; }
    if( -e $dict_xdxf_reconstructed ){
        my @xdxf_reconstructed = file2Array($dict_xdxf_reconstructed);
        my $xdxf_reconstructed = join('', @xdxf_reconstructed[0..20]);
        debugV("First 20 lines of xdxf_reconstructed:\n", $xdxf_reconstructed);
        #<xdxf lang_from="fr" lang_to="nl" format="visual">
        if( $xdxf_reconstructed =~ m~<xdxf lang_from="(?<lang_from>\w+)" lang_to="(?<lang_to>\w+)" format="visual">~ ){
            $lang_from = $+{lang_from};
            $lang_to = $+{lang_to};
        }
        # <full_name>Van Dale FR-NL 2010</full_name>
        if( $xdxf_reconstructed =~ m~<full_name>(?<full_name>[^<]+)</full_name>~ ){
            $full_name = $+{full_name};
        }
    }

    waitForIt("Reconstructing xdxf array.");
    ## Step through the array line by line until the articles start.
    ## Then push (altered) entry to array.

    foreach my $entry (@xdxf){
        # Handling of xdxf tag
        if ( $entry =~ m~^<xdxf(?<xdxf>.+)>\n$~){
            my $xdxf = $+{xdxf};
            if( $reformat_xdxf and $xdxf =~ m~ lang_from="(.*)" lang_to="(.*)" format="(.*)"~){
                $lang_from = $1 if defined $1 and $1 ne "";
                $lang_to = $2 if defined $2 and $2 ne "";
                $format = $3 if defined $3 and $3 ne "";
                print(" lang_from is \"$1\". Would you like to change it? (press enter to keep default \[$lang_from\] ");
                my $one = <STDIN>; chomp $one; if( $one ne ""){ $lang_from = $one ; }
                print(" lang_to is \"$2\". Would you like to change it? (press enter to keep default \[$lang_to\] ");
                my $two = <STDIN>; chomp $two; if( $two ne ""){ $lang_to = $two ; }
                print(" format is \"$3\". Would you like to change it? (press enter to keep default \[$format\] ");
                my $three = <STDIN>; chomp $three; if( $three ne ""){ $format = $three ; }
                $xdxf= 'lang_from="'.$lang_from.'" lang_to="'.$lang_to.'" format="'.$format.'"';
            }
            $entry = "<xdxf ".$xdxf.">\n";
            printMagenta($entry);
        }
        # Handling of full_name tag
        elsif ( $entry =~ m~^<full_name>~){
            if ( $entry !~ m~^<full_name>.*</full_name>\n$~){ debug("full_name tag is not on one line. Investigate!\n"); die if $isRealDead;}
            elsif( $reformat_full_name and $entry =~ m~^<full_name>(?<fullname>((?!</full).)*)</full_name>\n$~ ){
                my $old_name = $full_name;
                $full_name = $+{fullname};
                if ( $old_name eq ""){ $old_name = $full_name; }
                print("Full_name is \"$full_name\".\nWould you like to change it? (press enter to keep default \[$old_name\] ");
                my $one = <STDIN>; chomp $one;
                if( $one ne ""){ $full_name = $one ; }
                else{ $full_name = $old_name;}
                debug("\$entry was: $entry");
                $entry = "<full_name>$full_name</full_name>\n";
                debug("Fullname tag entry is now: ");
            }
            printMagenta($entry);
        }
        # Handling of Description. Turns one line into multiple.
        elsif( $entry =~ m~^(?<des><description>)(?<cont>((?!</desc).)*)(?<closetag></description>)\n$~ ){
            my $Description_content .= $+{cont} ;
            chomp $Description_content;
            $entry = $+{des}."\n".$Description_content."\n".$+{closetag}."\n";
        }
        # Handling of an ar-tag
        elsif ( $entry =~ m~^<ar>~){last;}  #Start of ar block
        
        push @xdxf_reconstructed, $entry;
    }

    # Push cleaned articles to array
    my $xdxf = join( '', @xdxf);
    my @articles = $xdxf =~ m~<ar>((?:(?!</ar).)+)</ar>~sg ;
    my ($ar, $ar_count) = ( 0, -1);
    my (%KnownKeys,@IndexedDefinitions,@IndexedKeys);
    foreach my $article (@articles){
        $ar_count++; $cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
        $article = cleanseAr($article);
        chomp $article;
        # <head><k>accognoscundis</k></head><def><blockquote>accognosco</blockquote></def>
        $article =~ m~<head><k>(?<key>(?:(?!</k>).)+)</k></head><def>(?<def>(?:(?!</def>).)+)</def>~s;
        if( exists $KnownKeys{$+{key}} ){
            # Append definition to other definition.
            my $CurrentDefinition = $+{def};
            my $PreviousDefinition = $IndexedDefinitions[$KnownKeys{$+{key}}];
            $IndexedDefinitions[$KnownKeys{$+{key}}] = fixPrefixes($PreviousDefinition, $CurrentDefinition);

            $ar_count--;
        }
        else{
            $KnownKeys{$+{key}} = $ar_count;
            $IndexedKeys[$ar_count] = $+{key};
            $IndexedDefinitions[$ar_count] = $+{def};
        }
    }
    # push @xdxf_reconstructed, "<ar>\n$article\n</ar>\n";    
    foreach( @IndexedKeys ){
        push @xdxf_reconstructed, "<ar>\n<head><k>$_</k></head><def>$IndexedDefinitions[$KnownKeys{$_}]</def>\n</ar>\n";    
    }
    push @xdxf_reconstructed, $xdxf_closing;
    printMagenta("\nTotal number of articles processed \$ar = ",scalar @articles,".\n");
    doneWaiting();
    return( @xdxf_reconstructed );}
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
if( $dict_xdxf !~ s~\.xdxf$~_reconstructed\.xdxf~ ){ debug("Filename substitution did not work for : \"$dict_xdxf\""); die if $isRealDead; }
array2File($dict_xdxf, @xdxf_reconstructed);

# Convert colors to hexvalues
if( $isConvertColorNamestoHexCodePoints ){ @xdxf_reconstructed = convertColorName2HexValue(@xdxf_reconstructed); }
# Create Stardict dictionary
if( $isCreateStardictDictionary ){
    if ( $isMakeKoreaderReady ){ @xdxf_reconstructed = makeKoreaderReady(@xdxf_reconstructed); }
    # Save reconstructed XML-file
    my @StardictXMLreconstructed = convertXDXFtoStardictXML(@xdxf_reconstructed);
    my $dict_xml = $FileName;
    if( $dict_xml !~ s~\.xdxf$~_reconstructed\.xml~ ){ debug("Filename substitution did not work for : \"$dict_xml\""); die if $isRealDead; }
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