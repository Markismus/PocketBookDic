#!/usr/bin/perl

package DicToggles;

use warnings;
use strict;

use DicGlobals;
use Dic2Screen;
use DicConversion;
( $isDebug, $isDebugVerbose, $isDebugVeryVerbose )       = ( 1, 0, 0 );  # Toggles verbosity debug messages
( $isInfo, $isInfoVerbose, $isInfoVeryVerbose )          = ( 1, 0, 0 );  # Toggles verbosity info messages

$isManualValidation = 1; # Manually validate OCRed images.

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