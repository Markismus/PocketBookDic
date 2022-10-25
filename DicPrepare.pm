#!/usr/bin/perl

package DicPrepare;
use warnings;
use strict;
use utf8;
use open IO => ':utf8';
use open ':std', ':utf8';
use feature 'unicode_strings'; # You get funky results with the sub convertNumberedSequencesToChar without this.
use Exporter;

use DicGlobals;
use DicToggles;
use Dic2Screen;
use DicHelpUtils;
use DicFileUtils;
use DicConversion;

our @ISA = ('Exporter');
our @EXPORT = (
    'cleanseAr',

    'loadXDXF',

    'makeKoreaderReady',
    '$isMakeKoreaderReady',
    '$isMakeKoreaderReady_SpanColor2Style',
    '$isMakeKoreaderReady_SpanWidth2Style',
    '$isMakeKoreaderReady_SpanStyleWidht2Padding',
    '$isMakeKoreaderReady_MergeStyles',
    '$isChangeTable2Div4Koreader',

    'reconstructXDXF',
 );

sub cleanseAr{
    # Usage: my $Content = cleanseAr( @Content );
    # Usage: my $Content = cleanseAr( $Content );
    my $Content = join('',@_) ;

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

                     Die() if ($cut_location > $max_line_length);
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
            if ( $OperatingSystem eq "linux"){
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
                $xdxf[2] = $saved_xdxf[2];
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

# Control variable makeKoreaderReady
# Sometimes koreader want something extra. E.g. create css- and/or lua-file, convert <c color="red"> tags to <span style="color:red;">
our $isMakeKoreaderReady                         = 1 ; 
our $isMakeKoreaderReady_SpanColor2Style         = 0 ;
our $isMakeKoreaderReady_SpanWidth2Style         = 0 ;
our $isMakeKoreaderReady_SpanStyleWidht2Padding  = 0 ;
our $isMakeKoreaderReady_MergeStyles             = 0 ;
our $isChangeTable2Div4Koreader                  = 1 ; # Adds lines to lua-file
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
        q~-- Remove p start- and stoptags from table~."\n",
        q~while html:find("(<table[^>]+>.-)</?p[^>]*>(.-</table>)") do~."\n",
        q~  html  = html:gsub("(<table[^>]+>.-)</?p[^>]*>(.-</table>)", "%1%2")~."\n",
        q~end~."\n",
        q~-- If malformed tables continue to stop Koreader from displaying beyond the start~."\n",
        q~-- of a table, please uncomment the following lines to convert them to a~."\n",
        q~-- simulation of a table constructed from div-blocks, vertical bars and~."\n",
        q~-- horizontal lines.~."\n\n",
        q~-- html = html:gsub("<table[^>]+>", '<p></p><hr style="height:1px;color:black;" /><div style="display:block;">')~."\n",
        q~-- html = html:gsub("</table>", '</div><p></p>')~."\n",
        q~-- html = html:gsub("<tr[^>]*>", '<div style="display:block;">')~."\n",
        q~-- html = html:gsub("<td[^>]*>", '<div style="display:inline;">|') -- ｜~."\n",
        q~-- html = html:gsub("</td>", '</div>')~."\n",
        q~-- html = html:gsub("</tr>", '|</div><hr style="height:1px;color:black;" />')~."\n",
        );
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
    if( $dict_xdxf_reconstructed !~ s~\.[^\.]+$~_reconstructed\.xdxf~ ){ debug("Filename substitution did not work for : \"$dict_xdxf_reconstructed\""); Die(); }
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
            if ( $entry !~ m~^<full_name>.*</full_name>\n$~){ debug("full_name tag is not on one line. Investigate!\n"); Die();}
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

1;