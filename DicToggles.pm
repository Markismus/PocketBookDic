#!/usr/bin/perl

package DicToggles;

use warnings;
use strict;

use DicGlobals;
use Dic2Screen;
use DicConversion;
use DicPrepare;
( $isDebug, $isDebugVerbose, $isDebugVeryVerbose )       = ( 1, 0, 0 );  # Toggles verbosity debug messages
( $isInfo, $isInfoVerbose, $isInfoVeryVerbose )          = ( 1, 0, 0 );  # Toggles verbosity info messages

$isManualValidation = 1; # Manually validate OCRed images.

# Control variable makeKoreaderReady
# Sometimes koreader want something extra. E.g. create css- and/or lua-file, convert <c color="red"> tags to <span style="color:red;">
$isMakeKoreaderReady                         = 1 ; 
$isMakeKoreaderReady_SpanColor2Style         = 0 ;
$isMakeKoreaderReady_SpanWidth2Style         = 0 ;
$isMakeKoreaderReady_SpanStyleWidht2Padding  = 0 ;
$isMakeKoreaderReady_MergeStyles             = 0 ;
$isChangeTable2Div4Koreader                  = 1 ; # Adds lines to lua-file
# Controls for reconstructXDXF
# Controls manual input: 0 disables.
( $lang_from, $lang_to, $format ) = ( "eng", "eng" ,"" ); # Default settings for manual input of xdxf tag.
$reformat_full_name  = 1 ; # Value 1 demands user input for full_name tag.
$reformat_xdxf       = 1 ; # Value 1 demands user input for xdxf tag.

# Control variables for the conversion of ABBYY-generated HTML.
@ABBYY_CSS; # Becomes defined by sub convertABBYY2XDXF
$isABBYYWordlistNeeded   = 1; # Controls creation of an ABBYYWordlist.txt file.
$isABBYYAllCleared       = 0; # Controls creation of a hash-file.
$isABBYYConverterReuse   = 0; # Controls the check for already generated xdxf-file
$isABBYConverted         = 0; # Global variable that gets set to 1 if convertABBYY2XDXF returns an xdxf-array.
# Conversion pauses during keywords
@ABBYYConverterPauseFor = (
# E.g.,
    # 'égard',
    # 'ète',
);
# Manual overrule. Conversion checks whether keyword is allowed and passes it without further tests.
@ABBYYConverterAllowedKeys = (
    q~corbeille-d’argent~,
    q~crespelé, e~,
    q~cul-rond~,
    q~desquels, desquelles~,
    q~duquel~,
    q~fœhn~,
    q~giboyeux, euse~,
    q~glacial, e, als~,
    q~hydro-. V~,
    q~inaliénablement~,
    q~in aliéné, e~,
    q~laquelle~,
    q~melliflu, e~,
    q~peu chère~,
    q~pick-nick n.m.~,
);

# Deliminator for CSV files, usually ",",";" or "\t"(tab).
$CVSDeliminator = ",";

# Controls for convertHTML2XDXF
$isConvertFont2Small         = 0 ;
$isConvertFont2Span          = 0 ;
$isConvertMMCFullText2Span   = 1 ;

use DicHelpUtils;
# Controls escapeHTMLString and unEscapeHTMLString
$EscapeHTMLCharacters             = 0;
$unEscapeHTML                     = 0;


# Shortcuts to Collection of settings.
# If you select both settings, they will be ignored.
our $Just4Koreader   = 0 ;
our $Just4PocketBook = 1 ;

if( $Just4Koreader and !$Just4PocketBook){
    # Controls for Stardict dictionary creation and Koreader stardict compatabiltiy
    $isCreateStardictDictionary = 1; # Turns on Stardict text and binary dictionary creation.
    $SameTypeSequence = "h"; # Either "h" or "m" or "x".
    $updateSameTypeSequence = 1; # If the Stardict files give a sametypesequence value, update the initial value.
    $isConvertColorNamestoHexCodePoints = 1; # Converting takes time.
    $isMakeKoreaderReady = 1; # Sometimes koreader want something extra. E.g. create css- and/or lua-file, convert <c color="red"> tags to <span style="color:red;">

    # Controls for Pocketbook conversion
    $isCreatePocketbookDictionary = 0; # Controls conversion to Pocketbook Dictionary dic-format
    $remove_color_tags = 0; # Not all viewers can handle color/grayscale. Removing them reduces the article size considerably. Relevant for pocketbook dictionary.
    $max_article_length = 640000;
    $max_line_length = 8000;

    # Controls for recoding or deleting images and sounds.
    $isRemoveWaveReferences = 1; # Removes all the references to wav-files Could be encoded in Base64 now.
    $isCodeImageBase64 = 0; # Some dictionaries contain images. Encoding them as Base64 allows coding them inline. Only implemented with convertHTML2XDXF.
    $isConvertGIF2PNG = 0; # Creates a dependency on Imagemagick "convert".

    $unEscapeHTML = 0;
    $ForceConvertNumberedSequencesToChar = 1;
    $ForceConvertBlockquote2Div = 0;
    $EscapeHTMLCharacters = 0;
}
if( $Just4PocketBook and !$Just4Koreader){
    # Controls for Stardict dictionary creation and Koreader stardict compatabiltiy
    $isCreateStardictDictionary = 0; # Turns on Stardict text and binary dictionary creation.
    $SameTypeSequence = "h"; # Either "h" or "m" or "x".
    $updateSameTypeSequence = 1; # If the Stardict files give a sametypesequence value, update the initial value.
    $isConvertColorNamestoHexCodePoints = 0; # Converting takes time and space
    $isMakeKoreaderReady = 0; # Sometimes koreader want something extra. E.g. create css- and/or lua-file, convert <c color="red"> tags to <span style="color:red;">

    # Controls for Pocketbook conversion
    $isCreatePocketbookDictionary = 1; # Controls conversion to Pocketbook Dictionary dic-format
    $remove_color_tags = 1; # Not all viewers can handle color/grayscale. Removing them reduces the article size considerably. Relevant for pocketbook dictionary.
    $max_article_length = 64000;
    $max_line_length = 4000;
    
    # Controls for recoding or deleting images and sounds.
    $isRemoveWaveReferences = 1; # Removes all the references to wav-files Could be encoded in Base64 now.
    $isCodeImageBase64 = 1; # Some dictionaries contain images. Encoding them as Base64 allows coding them inline. Only implemented with convertHTML2XDXF.
    $isConvertGIF2PNG = 0; # Creates a dependency on Imagemagick "convert".

    $unEscapeHTML = 1;
    $ForceConvertNumberedSequencesToChar = 1;
    $ForceConvertBlockquote2Div = 1;
    $EscapeHTMLCharacters = 0;
}
1;