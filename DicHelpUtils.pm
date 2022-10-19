#!/usr/bin/perl

package DicHelpUtils;
use warnings;
use strict;

use Exporter;

use DicGlobals;
use Dic2Screen;
use DicRoman; 

our @ISA = ('Exporter');
our @EXPORT = (
    'convertBlockquote2Div',
    'convertColorName2HexValue',
    'convertMobiAltCodes',
    'convertNonBreakableSpacetoNumberedSequence',
    'convertNumberedSequencesToChar',
    'cleanOuterTags',
    
    'escapeHTMLString',

    'removeEmptyTagPairs',
    'removeInvalidChars',
    'removeOuterTags',
    
    'startFromStop',
    'startTag',
    'startTagReturnUndef',
    'stopFromStart',

    'unEscapeHTMLArray',
    'unEscapeHTMLString',
    # Export the whole DicRoman module
    'isroman',
    'arabic',
    'Roman',
    'roman',
    'sortroman',
);


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
    my $UnConverted = join('',@_);
    waitForIt("Removing '&nbsp;'.");
    my @results = $UnConverted =~ s~(&nbsp;)~&#160;~sg ;
    shift @results;
    if( scalar @results > 0 ){
        # Make unique results;
        my %unique_results;
        foreach(@results){ $unique_results{$_} = 1; }
        debug("Number of characters removed in convertNonBreakableSpacetoNumberedSequence: ",scalar @results);
        debug( map qq/"$_", /, keys %unique_results );
    }
    my @UnConverted = split(/^/, $UnConverted);
    if( $UnConverted =~ m~\&nbsp;~ ){ debug("Still found '&nbsp;' in array! Quitting"); Debug(@UnConverted); Die(); }
    return( @UnConverted );}
sub convertNumberedSequencesToChar{
    my $UnConverted = join('',@_);
    debug("Entered sub convertNumberedSequencesToChar") if $isTestingOn;
    while( $UnConverted =~ m~\&\#x([0-9A-Fa-f]{1,6});~s ){
        my $HexCodePoint = $1;
        $UnConverted =~ s~\&\#x$HexCodePoint;~chr(hex($HexCodePoint))~seg ;
        debug("Result convertNumberedSequencesToChar: $HexCodePoint"."-> '".chr(hex($HexCodePoint))."'" ) if $isTestingOn;
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

    $UnConverted = removeInvalidChars( $UnConverted );

    return( split(/(\n)/, $UnConverted) );}

sub escapeHTMLString{
    my $String = shift;
    $String =~ s~<~\&lt;~sg;
    $String =~ s~>~\&gt;~sg;
    $String =~ s~'\&apos;~~sg;
    $String =~ s~&~\&amp;~sg;
    $String =~ s~"~\&quot;~sg;
    return $String;}

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

    if( $isConvertMobiAltCodes ){ $xdxf = convertMobiAltCodes( $xdxf ); }

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
    unless( $check ){ debugV('Nothing removed. If \"parser error : PCDATA invalid Char value...\" remains, look at subroutine removeInvalidChars.');}

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
        unless( $block =~ s~^$Start~~s ){ warn "Regex for removal of block start-tag doesn't match."; Die(); }
        unless( $block =~ s~$Stop$~~s ){ warn "Regex for removal of block stop-tag doesn't match."; Die(); }
        $block =~ s~^\s+~~s;
        $block =~ s~\s+$~~s;
    }
    return $block;}

sub startFromStop{ return ("<" . substr( $_[0], 2, (length( $_[0] ) - 3) ) . "( [^>]*>|>)"); }
sub startTag{
    $_[0] =~ s~^\s+~~s;
    my $StartTag = startTagReturnUndef( $_[0]);
    unless( defined $StartTag ){ warn "Regex for key-start '$StartTag' doesn't match."; Die(); }
    return ( $StartTag );}
sub startTagReturnUndef{
    $_[0] =~ s~^\s+~~s;
    unless( $_[0] =~ m~^(?<StartTag><[^>]+>)~s ){ return undef; }
    return ( $+{"StartTag"} );}
sub stopFromStart{
    unless( $_[0] =~ m~<(?<tag>\w+)( |>)~ ){ warn "Regex in stopFromStart doesn't match. Value given is '$_[0]'"; Die(); }
    return( "</" . $+{"tag"}.">" );}


sub unEscapeHTMLArray{
    my $String = unEscapeHTMLString( join('', @_) );
    return( split(/^/, $String) ); }
sub unEscapeHTMLString{
    my $String = shift;
    $String =~ s~\&lt;~<~sg;
    $String =~ s~\&gt;~>~sg;
    $String =~ s~\&apos;~'~sg;
    $String =~ s~\&amp;~&~sg;
    $String =~ s~\&quot;~"~sg;
    return $String;}

1;