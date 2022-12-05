#!/usr/bin/perl

package DicHelpUtils;
use warnings;
use strict;

use Exporter;
use Data::Compare;

use DicGlobals;
use Dic2Screen;
use DicRoman; 
use DicFileUtils;

our @ISA = ('Exporter');
our @EXPORT = (
    'changeFileExtension',
    'checkSameTypeSequence',
    'checkXMLBookname',
    'convertBlockquote2Div',
    'convertColorName2HexValue',

    'convertMobiAltCodes',
    '$isConvertMobiAltCodes',

    'Compare',      # Imported from Data::Compare
    'convertNonBreakableSpacetoNumberedSequence',
    'convertNonBreakableSpacetoNumberedSequence4Strings',
    'convertNumberedSequencesToChar',
    'convertNumberedSequencesToChar4Strings',
    'cleanOuterTags',

    'escapeHTMLString',
    '$HTMLcodes',
    '$PossibleTags',
    '$isEscapeHTMLCharacters',

    'filterXDXFforEntitites',
    'fixPrefixes',

    'generateEntityHashFromDocType',

    'mergeConsecutiveIdenticallyAttributedSpans',

    'removeBloatFromArray',
    'removeBloatFromString',
    'removeBreakTag',
    'removeEmptyTagPairs',
    'removeInvalidChars',
    'removeOuterTags',

    'startFromStop',
    'startTag',
    'startTagReturnUndef',
    'stopFromStart',

    'tidyXMLArray',

    'unEscapeHTMLArray',
    'unEscapeHTMLString',
    '$unEscapeHTML',

    'updateLocalPath',
    'updateFullPath',

    '@XMLTidied',

    # Export the whole DicRoman module
    'isroman',
    'arabic',
    'Roman',
    'roman',
    'sortroman',
);

sub changeFileExtension{
    my $FileName = shift;
    my $Extention2 = shift;
    unless( $FileName =~ s~\.[^.]+$~\.\Q$Extention2\E~ ){ die2("Regex didn't work"); }
    else{ infoVV("Returned file name: '$FileName'"); }
    return $FileName;}
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
sub checkXMLBookname{
    # check <bookname></bookname>
    if( $_[4] =~ s~(<bookname>)\s*(</bookname>)~$1UnknownDictionary$2~ ){ warn "Empty dictionary name! Replaced it with 'UnknownDictionary'"; }
    return @_;}
our %AlreadyMentionedStylingHTMLTags;
sub cleanOuterTags{
    my $block = shift;
    $block =~ s~^\s+~~s;
    $block =~ s~\s+$~~s;
    if( $block !~ m~^<~ ){ infoV("No outer tag"); return $block; }
    my $Start = startTag( $block );
    foreach( @CleanHTMLTags ){
        if( $Start =~ m~$_~i ){
            info("Styling HTML tag '$_' found as outer start tag.") unless $AlreadyMentionedStylingHTMLTags{ $_ };
            $AlreadyMentionedStylingHTMLTags{ $_ } = 1;
            return( $block);
        }
    }
    my $Stop = stopFromStart( $Start );
    unless( $block =~ s~^$Start~~s ){ warn "Regex for removal of block start-tag doesn't match."; Die(); }
    unless( $block =~ s~$Stop$~~s ){ warn "Regex for removal of block stop-tag doesn't match."; Die(); }
    $block =~ s~^\s+~~s;
    $block =~ s~\s+$~~s;
    return $block;}
sub convertBlockquote2Div{
    # return (@_);
    waitForIt('Converting <blockquote-tags to <div style:"margin 0 0 0 1em;">-tags.');
    my $html = join('', @_);

    $html =~ s~</blockquote>~</div>~sg;

    while( $html =~ m~(?<starttag><blockquote(?<styling>[^>]*)>)~s ){
        my $StartTag    = $+{starttag};
        my $Styling     = $+{styling};
        my $Div;
        if( $Styling =~ s~(?<style>style=")~$+{style}margin: 0 0 0 1em; ~){ $Div = '<div'.$Styling.'>';}
        else{ $Div = '<div'.$Styling.' style="margin: 0 0 0 1em;">'; }
        $html =~ s~\Q$StartTag\E~$Div~sg;
    }
    $html =~ s~(<div[^>]*>)\n~$1~sg;
    if( scalar @_ > 1 ){ return split(/^/, $html) ; }
    else{ return $html; }}
sub convertColorName2HexValue{
    my $html = join( '', @_);
    my %ColorCoding = ( 'aliceblue', '#F0F8FF', 'antiquewhite', '#FAEBD7', 'aqua', '#00FFFF', 'aquamarine', '#7FFFD4', 'azure', '#F0FFFF', 'beige', '#F5F5DC', 'bisque', '#FFE4C4', 'black', '#000000', 'blanchedalmond', '#FFEBCD', 'blue', '#0000FF', 'blueviolet', '#8A2BE2', 'brown', '#A52A2A', 'burlywood', '#DEB887', 'cadetblue', '#5F9EA0', 'chartreuse', '#7FFF00', 'chocolate', '#D2691E', 'coral', '#FF7F50', 'cornflowerblue', '#6495ED', 'cornsilk', '#FFF8DC', 'crimson', '#DC143C', 'cyan', '#00FFFF', 'darkblue', '#00008B', 'darkcyan', '#008B8B', 'darkgoldenrod', '#B8860B', 'darkgray', '#A9A9A9', 'darkgrey', '#A9A9A9', 'darkgreen', '#006400', 'darkkhaki', '#BDB76B', 'darkmagenta', '#8B008B', 'darkolivegreen', '#556B2F', 'darkorange', '#FF8C00', 'darkorchid', '#9932CC', 'darkred', '#8B0000', 'darksalmon', '#E9967A', 'darkseagreen', '#8FBC8F', 'darkslateblue', '#483D8B', 'darkslategray', '#2F4F4F', 'darkslategrey', '#2F4F4F', 'darkturquoise', '#00CED1', 'darkviolet', '#9400D3', 'deeppink', '#FF1493', 'deepskyblue', '#00BFFF', 'dimgray', '#696969', 'dimgrey', '#696969', 'dodgerblue', '#1E90FF', 'firebrick', '#B22222', 'floralwhite', '#FFFAF0', 'forestgreen', '#228B22', 'fuchsia', '#FF00FF', 'gainsboro', '#DCDCDC', 'ghostwhite', '#F8F8FF', 'gold', '#FFD700', 'goldenrod', '#DAA520', 'gray', '#808080', 'grey', '#808080', 'green', '#008000', 'greenyellow', '#ADFF2F', 'honeydew', '#F0FFF0', 'hotpink', '#FF69B4', 'indianred', '#CD5C5C', 'indigo', '#4B0082', 'ivory', '#FFFFF0', 'khaki', '#F0E68C', 'lavender', '#E6E6FA', 'lavenderblush', '#FFF0F5', 'lawngreen', '#7CFC00', 'lemonchiffon', '#FFFACD', 'lightblue', '#ADD8E6', 'lightcoral', '#F08080', 'lightcyan', '#E0FFFF', 'lightgoldenrodyellow', '#FAFAD2', 'lightgray', '#D3D3D3', 'lightgrey', '#D3D3D3', 'lightgreen', '#90EE90', 'lightpink', '#FFB6C1', 'lightsalmon', '#FFA07A', 'lightseagreen', '#20B2AA', 'lightskyblue', '#87CEFA', 'lightslategray', '#778899', 'lightslategrey', '#778899', 'lightsteelblue', '#B0C4DE', 'lightyellow', '#FFFFE0', 'lime', '#00FF00', 'limegreen', '#32CD32', 'linen', '#FAF0E6', 'magenta', '#FF00FF', 'maroon', '#800000', 'mediumaquamarine', '#66CDAA', 'mediumblue', '#0000CD', 'mediumorchid', '#BA55D3', 'mediumpurple', '#9370DB', 'mediumseagreen', '#3CB371', 'mediumslateblue', '#7B68EE', 'mediumspringgreen', '#00FA9A', 'mediumturquoise', '#48D1CC', 'mediumvioletred', '#C71585', 'midnightblue', '#191970', 'mintcream', '#F5FFFA', 'mistyrose', '#FFE4E1', 'moccasin', '#FFE4B5', 'navajowhite', '#FFDEAD', 'navy', '#000080', 'oldlace', '#FDF5E6', 'olive', '#808000', 'olivedrab', '#6B8E23', 'orange', '#FFA500', 'orangered', '#FF4500', 'orchid', '#DA70D6', 'palegoldenrod', '#EEE8AA', 'palegreen', '#98FB98', 'paleturquoise', '#AFEEEE', 'palevioletred', '#DB7093', 'papayawhip', '#FFEFD5', 'peachpuff', '#FFDAB9', 'peru', '#CD853F', 'pink', '#FFC0CB', 'plum', '#DDA0DD', 'powderblue', '#B0E0E6', 'purple', '#800080', 'rebeccapurple', '#663399', 'red', '#FF0000', 'rosybrown', '#BC8F8F', 'royalblue', '#41690', 'saddlebrown', '#8B4513', 'salmon', '#FA8072', 'sandybrown', '#F4A460', 'seagreen', '#2E8B57', 'seashell', '#FFF5EE', 'sienna', '#A0522D', 'silver', '#C0C0C0', 'skyblue', '#87CEEB', 'slateblue', '#6A5ACD', 'slategray', '#708090', 'slategrey', '#708090', 'snow', '#FFFAFA', 'springgreen', '#00FF7F', 'steelblue', '#4682B4', 'tan', '#D2B48C', 'teal', '#008080', 'thistle', '#D8BFD8', 'tomato', '#FF6347', 'turquoise', '#40E0D0', 'violet', '#EE82EE', 'wheat', '#F5DEB3', 'white', '#FFFFFF', 'whitesmoke', '#F5F5F5', 'yellow', '#FFFF00', 'yellowgreen', '#9ACD32' );
    waitForIt("Converting all color names to hex values.");
    # This loop takes 1m26s for a dictionary with 132k entries and no color tags.
    # foreach my $Color(keys %ColorCoding){
    #     $html =~ s~c="$Color">~c="$ColorCoding{$Color}">~isg;
    #     $html =~ s~color:$Color>~c:$ColorCoding{$Color}>~isg;
    # }

    # This takes 1s for a dictionary with 132k entries and no color tags
    # Not tested with Oxford 2nd Ed. yet!!
    $html =~ s~c="(\w+)">~c="$ColorCoding{lc($1)}">~isg;
    # $html =~ s~color:(\w+)>~c:$ColorCoding{lc($1)}>~isg;
    # <span style="color:orchid">▪</span> <i><span style="color:sienna">I stepped back to let them pass.</span>
    # $html =~ s~<span style="color:(?<color>\w+)">(?<colored>(?!</span>).*?)</span>~<span style="color:$ColorCoding{lc($+{color})}">$+{colored}</span>~isg;
    $html =~ s~color:(?<color>\w+)~color:$ColorCoding{lc($+{color})}~isg;
    doneWaiting();
    return( split(/^/,$html) );}

our $isConvertMobiAltCodes = 0; # Apparently, characters in the range of 1-31 are displayed as alt-codes in mobireader.
sub convertMobiAltCodes{
    # my %MobiAltCodes = {
    #     1 => '☺',
    #     2 => '☻',
    #     3 => '♥',
    #     4 => '♦',
    #     5 => '♣',
    #     6 => '♠',
    #     7 => '•',
    #     8 => '◘',
    #     9 => '○',
    #     10 => '◙',
    #     11 => '♂',
    #     12 => '♀',
    #     13 => '♪',
    #     14 => '♫',
    #     15 => '☼',
    #     16 => '►',
    #     17 => '◄',
    #     18 => '↕',
    #     19 => '‼',
    #     20 => '¶',
    #     21 => '§',
    #     22 => '&',
    #     23 => '↨',
    #     24 => '↑',
    #     25 => '↓',
    #     26 => '→',
    #     27 => '←',
    #     28 => '∟',
    #     29 => '↔',
    #     30 => '▲',
    #     31 => '▼'
    # };

    my $xdxf = $_[0]; # Only a string or first entry of array is checked and returned.
    unless( $isConvertMobiAltCodes ){ return $xdxf; }
    waitForIt("Converting Mobi alt-codes, because isConvertMobiAltCodes = $isConvertMobiAltCodes.");
    if( $xdxf =~ s~\x01~☺~g ){ info("Converted mobi alt-code to '☺'");}
    if( $xdxf =~ s~\x02~☻~g ){ info("Converted mobi alt-code to '☻'");}
    if( $xdxf =~ s~\x03~♥~g ){ info("Converted mobi alt-code to '♥'");}
    if( $xdxf =~ s~\x04~♦~g ){ info("Converted mobi alt-code to '♦'");}
    if( $xdxf =~ s~\x05~♣~g ){ info("Converted mobi alt-code to '♣'");}
    if( $xdxf =~ s~\x06~♠~g ){ info("Converted mobi alt-code to '♠'");}
    if( $xdxf =~ s~\x07~•~g ){ info("Converted mobi alt-code to '•'");}
    if( $xdxf =~ s~\x08~◘~g ){ info("Converted mobi alt-code to '◘'");}
    if( $xdxf =~ s~\x09~○~g ){ info("Converted mobi alt-code to '○'");}
    if( $xdxf =~ s~\x0A~◙~g ){ info("Converted mobi alt-code to '◙'");}
    if( $xdxf =~ s~\x0B~♂~g ){ info("Converted mobi alt-code to '♂'");}
    if( $xdxf =~ s~\x0C~♀~g ){ info("Converted mobi alt-code to '♀'");}
    if( $xdxf =~ s~\x0D~♪~g ){ info("Converted mobi alt-code to '♪'");}
    if( $xdxf =~ s~\x0E~♫~g ){ info("Converted mobi alt-code to '♫'");}
    if( $xdxf =~ s~\x0F~☼~g ){ info("Converted mobi alt-code to '☼'");}
    if( $xdxf =~ s~\x10~►~g ){ info("Converted mobi alt-code to '►'");}
    if( $xdxf =~ s~\x11~◄~g ){ info("Converted mobi alt-code to '◄'");}
    if( $xdxf =~ s~\x12~↕~g ){ info("Converted mobi alt-code to '↕'");}
    if( $xdxf =~ s~\x13~‼~g ){ info("Converted mobi alt-code to '‼'");}
    if( $xdxf =~ s~\x14~¶~g ){ info("Converted mobi alt-code to '¶'");}
    if( $xdxf =~ s~\x15~§~g ){ info("Converted mobi alt-code to '§'");}
    if( $xdxf =~ s~\x16~&~g ){ info("Converted mobi alt-code to '&'");}
    if( $xdxf =~ s~\x17~↨~g ){ info("Converted mobi alt-code to '↨'");}
    if( $xdxf =~ s~\x18~↑~g ){ info("Converted mobi alt-code to '↑'");}
    if( $xdxf =~ s~\x19~↓~g ){ info("Converted mobi alt-code to '↓'");}
    if( $xdxf =~ s~\x1A~→~g ){ info("Converted mobi alt-code to '→'");}
    if( $xdxf =~ s~\x1B~←~g ){ info("Converted mobi alt-code to '←'");}
    if( $xdxf =~ s~\x1C~∟~g ){ info("Converted mobi alt-code to '∟'");}
    if( $xdxf =~ s~\x1D~↔~g ){ info("Converted mobi alt-code to '↔'");}
    if( $xdxf =~ s~\x1E~▲~g ){ info("Converted mobi alt-code to '▲'");}
    if( $xdxf =~ s~\x1F~▼~g ){ info("Converted mobi alt-code to '▼'");}
    doneWaiting();
    return($xdxf); }

sub convertNonBreakableSpacetoNumberedSequence{ 
    return( split( /^/, convertNonBreakableSpacetoNumberedSequence4Strings( join('',@_) ) ) ); }
sub convertNonBreakableSpacetoNumberedSequence4Strings{
    my $UnConverted = shift;
    waitForIt("Removing '&nbsp;'.");
    my $result = $UnConverted =~ s~(&nbsp;)~&#160;~sg ;
    if( $result > 0 ){
        debug("Removed '&nbsp' $result times.");
    }
    if( $UnConverted =~ m~\&nbsp;~ ){ die2("Still found '&nbsp;' in array! Quitting\n$UnConverted"); }
    return( $UnConverted );}
sub convertNumberedSequencesToChar{
    return( split( /^/, convertNumberedSequencesToChar4Strings( join('',@_) ) ) );}
sub convertNumberedSequencesToChar4Strings{
    my $UnConverted = shift;
    infoVV("Entered sub convertNumberedSequencesToChar");
    while( $UnConverted =~ m~\&\#x([0-9A-Fa-f]{1,6});~s ){
        my $HexCodePoint = $1;
        my $result = $UnConverted =~ s~\&\#x$HexCodePoint;~chr(hex($HexCodePoint))~seg ;
        info("Result convertNumberedSequencesToChar: $HexCodePoint"."-> '".chr(hex($HexCodePoint))."' (x$result)" ) if $isTestingOn;
    }
    while( $UnConverted =~ m~\&\#([0-9]{1,6});~s  ){
        my $Number = $1;
        if( $Number >= 128 and $Number <=159 ){
            # However, for the characters in the range of 128-159 in Windows-1252, these are the wrong values. For example the Euro (€) is at code point 0x80 in Windows-1252, but in Unicode it is U+20AC. &#x80; is the NCR for a control code and will not display as the Euro. The correct NCR is &#x20AC;.

            $UnConverted =~ s~\&\#$Number;~decode('cp1252', chr(int($Number)))~seg;
            debug("Result convertNumberedSequencesToChar: $Number"."-> '".decode('cp1252', chr(int($Number)))."'" ) if $isTestingOn;
        }
        else{
            $UnConverted =~ s~\&\#$Number;~chr(int($Number))~seg ;
            debug("Result convertNumberedSequencesToChar: $Number"."-> '".chr(int($Number))."'" ) if $isTestingOn;
        }
    }
    info("length html before removeInvalidChars is ".length($UnConverted) );
    $UnConverted = removeInvalidChars( $UnConverted );
    return( $UnConverted);}

our $isEscapeHTMLCharacters             = 0;
# Special characters can be converted to
# &lt; (<), &amp; (&), &gt; (>), &quot; ("), and &apos; (')
# However, the HTML escape sequences and tags should not be converted!
our $PossibleTags = qr~/?(def|mbp|c>|c c="|abr>|ex>|kref>|k>|key|rref|f>|!--|!doctype|a|abbr|acronym|address|applet|area|article|aside|audio|b>|base|basefont|bb|bdo|big|blockquote|body|/?br|button|canvas|caption|center|cite|code|col|colgroup|command|datagrid|datalist|dd|del|details|dfn|dialog|dir|div|dl|dt|em|embed|eventsource|fieldset|figcaption|figure|font|footer|form|frame|frameset|h[1-6]|head|header|hgroup|hr/|html|i>|i |iframe|img|input|ins|isindex|kbd|keygen|label|legend|li|link|map|mark|menu|meta|meter|nav|noframes|noscript|object|ol|optgroup|option|output|p|param|pre|progress|q>|rp|rt|ruby|s>|samp|script|section|select|small|source|span|strike|strong|style|sub|sup|table|tbody|td|textarea|tfoot|th|thead|time|title|tr|track|tt|u>|ul|var|video|wbr)~;
our $HTMLcodes = qr~(lt;|amp;|gt;|quot;|apos;|\#x?[0-9A-Fa-f]{1,6})~;
sub escapeHTMLString{
    my $String = shift;
    unless( $isEscapeHTMLCharacters ){ return $String; }
    # Convert '<' to '&lt;', but not if it's part of a HTML tag.
    $String =~ s~<(?!/?$PossibleTags[^>]*>)~&lt;~gs;
    # Convert '>' to '&gt;', but not if it's part of a HTML tag.
    $String =~ s~(?<!<$PossibleTags[^>]*)>~&gt;~sg;
    # Convert '&' to '&amp', but not if is part of an HTML escape sequence.
    $String =~ s~&(?!$HTMLcodes)~&amp;~gs;
    $String =~ s~'~\&apos;~sg;
    $String =~ s~"~\&quot;~sg;
    return $String;}

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

sub mergeConsecutiveIdenticallyAttributedSpans{
    my $html = shift;
    infoVV("Entering mergeConsecutiveIdenticallyAttributedSpans.");
    # Nested spans will not match!
    my $regex_match = qr~<span(?<attributes>[^>]*)>(?<first_content>(?:(?!</span>).)*)</span>(?<spacing>\s*)<span\g1>(?<second_content>(?:(?!</span>).)*)</span>~s;
    # I am omitting the greedy modificator behind the substitution, so that the info can be dumped.
    if( $isInfoVeryVerbose ){
        while ( $html =~ s~$regex_match~<span$+{attributes}>$+{first_content}$+{spacing}$+{second_content}</span>~s  ){
            infoV("Merged consecutive spans with identical attributes");
            infoVV(Dumper(\%+));
        }
    }
    else{
        while ( my $Count = $html =~ s~$regex_match~<span$+{attributes}>$+{first_content}$+{spacing}$+{second_content}</span>~sg  ){
            infoV("Merged $Count consecutive spans with identical attributes");
        }
    }
    return $html;
}


sub removeBloatFromArray{
    my $xdxf = removeBloatFromString( join('',@_) );
    return( split(/^/, $xdxf) );}
sub removeBloatFromString{
    my $xdxf = shift;
    debugV("Removing bloat from dictionary...");
    my $Round = "First";
    while ( $xdxf =~ s~<blockquote>(?<content><blockquote>(?!<blockquote>).*?</blockquote>)</blockquote>~$+{content}~sg ){ info_t("$Round round (removing double nested blockquotes)"); $Round = "Another"; }
    while( $xdxf =~ s~<ex>\s*</ex>|<ex></ex>|<blockquote></blockquote>|<blockquote>\s*</blockquote>~~sg ){ info_t("And another (removing empty blockquotes and examples)"); }
    while( $xdxf =~ s~\n\n~\n~sg ){ info_t("Finally then..(removing empty lines)");}
    while( $xdxf =~ s~</blockquote>\s+<blockquote>~</blockquote><blockquote>~sg ){ info_t("...another one (removing EOLs between blockquotes)"); }
    while( $xdxf =~ s~</blockquote>\s+</def>~</blockquote></def>~sg ){ info_t("...and another one (removing EOLs between blockquotes and definition stop tags)"); }
    # This a tricky one.
    # OALD9 has a strange string [s]key.bmp[/s] that keeps repeating. No idea why!
    while( $xdxf =~ s~\[s\].*?\.bmp\[/s\]~~sg   ){ info_t("....cleaning house (removing s-blocks with .bmp at the end.)"); }
    while( $xdxf =~ s~xmlns:[^=]+="[^"]*"~~sg   ){ info_t("....cleaning house (removing xmlns-links.)"); }
    while( $xdxf =~ s~(<[^>])\s+>~$1>~sg        ){ info_t("Remove trailing spaces in tags after cleaning house."); }
    $xdxf = removeBreakTag( $xdxf );
    $xdxf = removeEmptyTagPairs( $xdxf );
    debugV("...done!");
    return $xdxf;
}
sub removeBreakTag{
    my $xdxf = shift;
    while( my $count = $xdxf =~ s~(\w+)-<br ?/?>(\w+)~$1$2~sg ){ info_t("...removed $count break-tags inside hyphenated words."); }
    while( my $count = $xdxf =~ s~([\w,.;:'"\])!\?]+)<br ?/?>(\w+|<)~$1 $2~sg ){ info_t("...removed $count break-tags between words."); }
    while( my $count = $xdxf =~ s~(<br[^>]*>)~~sg ){ info_t("...removed $count break-tags."); }
    return $xdxf;
}
sub removeEmptyTagPairs{
    waitForIt("Removing empty tag pairs");
    my $html = shift;
    debug("Length html is ".length($html) );
    # my %matches;
    # while( $html =~ s~<(\S+)[^>]*>\s*</\g1>~~sg ){
    #     if( $isTestingOn ){
    #         info_t($1);
    #         if( exists $matches{ $1 } ){ $matches{ $1 } += 1 ; }
    #         else{
    #             $matches{ $1 } = 1;
    #             info_t("Removed empty <$1>-block.");
    #         }
    #     }
    # }
    foreach( @CleanHTMLTags ){
        s~^<~~;
        s~>$~~;
        if( $html =~ s~<\Q$_\E[^>]*>\s*</\Q$_\E>~~sg ){
            info_t("Removed <$_>..</$_>.");
        }
    }
    # info_t( Dumper( \%matches ) );
    doneWaiting();
    return( $html );}
sub removeInvalidChars{
    my $xdxf = $_[0]; # Only a string or first entry of array is checked and returned.
    waitForIt("Removing invalid characters.");

    $xdxf = convertMobiAltCodes( $xdxf );

    my $check = 0 ;
    # U+0000  0   000     Null character  NUL
    # U+0001  1   001     Start of Heading    SOH / Ctrl-A
    # U+0002  2   002     Start of Text   STX / Ctrl-B
    # U+0003  3   003     End-of-text character   ETX / Ctrl-C1
    # U+0004  4   004     End-of-transmission character   EOT / Ctrl-D2
    # U+0005  5   005     Enquiry character   ENQ / Ctrl-E
    # U+0006  6   006     Acknowledge character   ACK / Ctrl-F
    # U+0007  7   007     Bell character  BEL / Ctrl-G3
    # U+0008  8   010     Backspace   BS / Ctrl-H
    # U+0009  9   011     Horizontal tab  HT / Ctrl-I
    # U+000A  10  012     Line feed   LF / Ctrl-J4
    # U+000B  11  013     Vertical tab    VT / Ctrl-K
    # U+000C  12  014     Form feed   FF / Ctrl-L
    # U+000D  13  015     Carriage return     CR / Ctrl-M5
    # U+000E  14  016     Shift Out   SO / Ctrl-N
    # U+000F  15  017     Shift In    SI / Ctrl-O6
    # U+0010  16  020     Data Link Escape    DLE / Ctrl-P
    # U+0011  17  021     Device Control 1    DC1 / Ctrl-Q7
    # U+0012  18  022     Device Control 2    DC2 / Ctrl-R
    # U+0013  19  023     Device Control 3    DC3 / Ctrl-S8
    # U+0014  20  024     Device Control 4    DC4 / Ctrl-T
    # U+0015  21  025     Negative-acknowledge character  NAK / Ctrl-U9
    # U+0016  22  026     Synchronous Idle    SYN / Ctrl-V
    # U+0017  23  027     End of Transmission Block   ETB / Ctrl-W
    # U+0018  24  030     Cancel character    CAN / Ctrl-X10
    # U+0019  25  031     End of Medium   EM / Ctrl-Y
    # U+001A  26  032     Substitute character    SUB / Ctrl-Z11
    # U+001B  27  033     Escape character    ESC
    # U+001C  28  034     File Separator  FS
    # U+001D  29  035     Group Separator     GS
    # U+001E  30  036     Record Separator    RS
    # U+001F  31  037     Unit Separator  US 
    if( $xdxf =~ s~(\x7f|\x05|\x02|\x01|\x00)~~sg ){ $check++; info( "Removed characters with codes U+007F or between U+0000 and U+001F.");}
    if( $xdxf =~ s~(\x{0080})~Ç~sg ){ $check++; infoV(" Replaced U+0080 with 'Ç'"); }
    if( $xdxf =~ s~(\x{0091})~æ~sg ){ $check++; infoV(" Replaced U+0091 with 'æ'"); }
    if( $xdxf =~ s~(\x{0092})~Æ~sg ){ $check++; infoV(" Replaced U+0092 with 'Æ'"); }
    if( $xdxf =~ s~(\x{0093})~ô~sg ){ $check++; infoV(" Replaced U+0093 with 'ô'"); }
    if( $xdxf =~ s~(\x{0094})~ö~sg ){ $check++; infoV(" Replaced U+0094 with 'ö'"); }
    unless( $check ){ debugV('No invalid characters removed. If \"parser error : PCDATA invalid Char value...\" remains, look at subroutine removeInvalidChars.');}

    doneWaiting();
    return($xdxf); }
sub removeOuterTags{
    my $block = shift;
    $block =~ s~^\s+~~s;
    $block =~ s~\s+$~~s;
    if( $block !~ m~^<~ ){ infoV("No outer tag"); return $block; }
    while( $block =~ m~^<~ ){
        my $Start = startTag( $block );
        my $Stop  = stopFromStart( $Start );
        unless( $block =~ s~^$Start~~s ){ warn "Regex for removal of block start-tag doesn't match."; return undef; }
        unless( $block =~ s~$Stop$~~s ){ warn "Regex for removal of block stop-tag doesn't match."; return undef; }
        $block =~ s~^\s+~~s;
        $block =~ s~\s+$~~s;
    }
    return $block;}

sub startFromStop{ return ("<" . substr( $_[0], 2, (length( $_[0] ) - 3) ) . "( [^>]*>|>)"); }
sub startTag{
    $_[0] =~ s~^\s+~~s;
    my $StartTag = startTagReturnUndef( $_[0]);
    unless( defined $StartTag ){ die2("Regex for key-start '$StartTag' doesn't match."); }
    return ( $StartTag );}
sub startTagReturnUndef{
    $_[0] =~ s~^\s+~~s;
    unless( $_[0] =~ m~^(?<StartTag><(?!/)[^>]+>)~s ){ return undef; }
    return ( $+{"StartTag"} );}
sub stopFromStart{
    unless( $_[0] =~ m~<(?<tag>\w+)( |>)~ ){ die2("Regex in stopFromStart doesn't match. Value given is '$_[0]'"); }
    return( "</" . $+{"tag"}.">" );}

our @XMLTidied;
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

sub updateLocalPath{ $LocalPath = join('', $FileName=~ m~^(.+?/)[^/]+$~); }
sub updateFullPath{ $FullPath = "$BaseDir/$LocalPath"; }

our $unEscapeHTML                     = 0;
sub unEscapeHTMLArray{
    my $String = unEscapeHTMLString( join('', @_) );
    return( split(/^/, $String) ); }
sub unEscapeHTMLString{
    my $String = shift;
    unless( $unEscapeHTML ){ return $String; }
    $String =~ s~\&lt;~<~sg if 0 ; # Disabled, because it generates problems with HTML-parsing
    $String =~ s~\&gt;~>~sg if 0 ; # Disabled, because it generates problems with HTML-parsing
    $String =~ s~\&apos;~'~sg;
    $String =~ s~\&amp;~&~sg;
    $String =~ s~\&quot;~"~sg;
    return $String;}

1;