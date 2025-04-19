#!/usr/bin/perl

package DicGlobals;
use strict;
use warnings;

use Exporter;

our @ISA = ('Exporter');
our @EXPORT = ( 
    '$BaseDir',

    '$CVSDeliminator',
    '$cycle_dotprinter',
    '$cycles_per_dot',
    '$DocType',
    '$DoNotFilterDocType',
    '$DumperSuffix',
    '$FileName',
    '$ForceConvertBlockquote2Div',
    '$ForceConvertNumberedSequencesToChar',
    '$FullPath',
    '$isCodeImageBase64',
    '$isConvertColorNamestoHexCodePoints',
    '$isCreateMDict',
    '$isCreatePocketbookDictionary',
    '$CreateTwoHalfPocketBookdictionaries',
    '$isCreateStardictDictionary',
    '$isHandleMobiDictionary',
    '$isTestingOn',
    '$KindleUnpackLibFolder',
    '$lastline_xdxf',
    '$lastline_xml',
    '$LocalPath',
    '$OperatingSystem',
    '$SameTypeSequence',
    '$updateSameTypeSequence',
    '$UseXMLTidy',

    '%EntityConversion',

    '@CleanHTMLTags',
    '@ExcludedHTMLTags',
    '@xdxf_start',
    '@xml_start',
 );

###########################################
### Beginning of manual control input   ###
###########################################

# Last filename will be used.
# Give the filename relative to the base directory defined in $BaseDir.
# However, when an argument is given, it will supercede the last filename
our $FileName;
# Examples given:
$FileName = "dict/Oxford English Dictionary 2nd Ed/Oxford English Dictionary 2nd Ed.xdxf";
$FileName = "dict/stardict-Webster_s_Unabridged_3-2.4.2/Webster_s_Unabridged_3.ifo";

# $BaseDir is the directory where converter.exe and the language folders reside.
# Typically the language folders are named by two letters, e.g. english is named 'en'.
# In each folder should be a collates.txt, keyboard.txt and morphems.txt file.
our $BaseDir="/home/mark/Downloads/PocketbookDic";
our $LocalPath = join('', $FileName=~ m~^(.+?)/[^/]+$~); # Default value
our $FullPath = "$BaseDir/$LocalPath";                   # Default value

# $KindleUnpackLibFolder is the folder in which kindleunpack.py resides.
# You can download KindleUnpack using http with: git clone https://github.com/kevinhendricks/KindleUnpack
# or using ssh with: git clone git@github.com:kevinhendricks/KindleUnpack.git
# Use absolute path beginning with either '/' (root) or '~'(home) on Linux. On Windows use whatever works.
our $KindleUnpackLibFolder="/home/mark/git/KindleUnpack/lib";

our $DumperSuffix = ".Dumper.txt"; # Has to be declared before any call to storeHash or retrieveHash. Otherwise it is undefined, although no error is given.

# Controls for debugging.
our $isTestingOn = 0; # Toggles intermediary output of xdxf-array.
our ($cycle_dotprinter, $cycles_per_dot) = (0 , 300); # A green dot is printed achter $cycles_per_dot ar's have been processed.

# Controls for Stardict dictionary creation and Koreader stardict compatabiltiy
our $isCreateStardictDictionary = 0; # Turns on Stardict text and binary dictionary creation.

# Same Type Seqence is the initial value of the Stardict variable set in the ifo-file.
# "h" means html-dictionary. "m" means text.
# The xdxf-file will be filtered for &#xDDDD; values and converted to unicode if set at "m"
our $SameTypeSequence = "h"; # Either "h" or "m" or "x".
our $updateSameTypeSequence = 1; # If the Stardict files give a sametypesequence value, update the initial value.
our $isConvertColorNamestoHexCodePoints = 1; # Converting takes time.

# Controls for Pocketbook conversion
our $isCreatePocketbookDictionary = 1; # Controls conversion to Pocketbook Dictionary dic-format
our $CreateTwoHalfPocketBookdictionaries = 0; # Controls the conversion to 2 Pocketbook Dictionaries in dic-format
# Force conversion of numbered sequences to characters.
our $ForceConvertNumberedSequencesToChar = 1;

# Nouveau Littré uses doctype symbols, which should be converted before further processing.
our $DoNotFilterDocType = 1;

# Controls for Mobi dictionary handling
our $isHandleMobiDictionary = 1 ;

# Create mdict dictionary
our $isCreateMDict = 0;

# Controls for recoding or deleting images and sounds.
our $isCodeImageBase64                = 0; # Some dictionaries contain images. Encoding them as Base64 allows coding them inline. Only implemented with convertHTML2XDXF.
our $ForceConvertBlockquote2Div       = 0;
our $UseXMLTidy                       = 0; # Enables or disables the use of the subroutine tidyXMLArray. Still experimental, so disable.

#########################################################
###  End of manual control input                     ####
###  (Excluding doctype html entities. See below. )  ####
#########################################################

# Determine operating system.
our $OperatingSystem = "$^O";

# As NouveauLittre showed a rather big problem with named entities, I wrote a special filter
# Here is the place to insert your DOCTYPE string.
# Remember to place it between quotes '..' and finish the line with a semicolon ;
# Last Doctype will be used.
# To omit the filter place an empty DocType string at the end:
# $DocType = '';
our ($DocType,%EntityConversion);
$DocType = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"[<!ENTITY ns "&#9830;"><!ENTITY os "&#8226;"><!ENTITY oo "&#8250;"><!ENTITY co "&#8249;"><!ENTITY a  "&#x0061;"><!ENTITY â  "&#x0251;"><!ENTITY an "&#x0251;&#x303;"><!ENTITY b  "&#x0062;"><!ENTITY d  "&#x0257;"><!ENTITY e  "&#x0259;"><!ENTITY é  "&#x0065;"><!ENTITY è  "&#x025B;"><!ENTITY in "&#x025B;&#x303;"><!ENTITY f  "&#x066;"><!ENTITY g  "&#x0261;"><!ENTITY h  "&#x0068;"><!ENTITY h2 "&#x0027;"><!ENTITY i  "&#x0069;"><!ENTITY j  "&#x004A;"><!ENTITY k  "&#x006B;"><!ENTITY l  "&#x006C;"><!ENTITY m  "&#x006D;"><!ENTITY n  "&#x006E;"><!ENTITY gn "&#x0272;"><!ENTITY ing "&#x0273;"><!ENTITY o  "&#x006F;"><!ENTITY o2 "&#x0254;"><!ENTITY oe "&#x0276;"><!ENTITY on "&#x0254;&#x303;"><!ENTITY eu "&#x0278;"><!ENTITY un "&#x0276;&#x303;"><!ENTITY p  "&#x0070;"><!ENTITY r  "&#x0280;"><!ENTITY s  "&#x0073;"><!ENTITY ch "&#x0283;"><!ENTITY t  "&#x0074;"><!ENTITY u  "&#x0265;"><!ENTITY ou "&#x0075;"><!ENTITY v  "&#x0076;"><!ENTITY w  "&#x0077;"><!ENTITY x  "&#x0078;"><!ENTITY y  "&#x0079;"><!ENTITY z  "&#x007A;"><!ENTITY Z  "&#x0292;">]><html xml:lang="fr" xmlns="http://www.w3.org/1999/xhtml"><head><title></title></head><body>';
if( $DoNotFilterDocType ){ $DocType = ''; }
our @CleanHTMLTags = ( "<!--...-->", "<!DOCTYPE>", "<a>", "<abbr>", "<acronym>", "<address>", "<applet>", "<area>", "<aside>", "<audio>", "<b>", "<base>", "<basefont>", "<bdi>", "<bdo>", "<big>", "<blockquote>", "<body>", "<br>", "<button>", "<canvas>", "<caption>", "<center>", "<cite>", "<code>", "<col>", "<colgroup>", "<data>", "<datalist>", "<dd>", "<del>", "<details>", "<dfn>", "<dialog>", "<dir>", "<div>", "<dl>", "<dt>", "<em>", "<embed>", "<fieldset>", "<figcaption>", "<figure>", "<font>", "<footer>", "<form>", "<frame>", "<frameset>", "<h1>", "<header>", "<hr>", "<html>", "<i>", "<iframe>", "<img>", "<input>", "<ins>", "<kbd>", "<label>", "<legend>", "<li>", "<link>", "<main>", "<map>", "<mark>", "<meta>", "<meter>", "<nav>", "<noframes>", "<noscript>", "<object>", "<ol>", "<optgroup>", "<option>", "<output>", "<p>", "<param>", "<picture>", "<pre>", "<progress>", "<q>", "<rp>", "<rt>", "<ruby>", "<s>", "<samp>", "<script>", "<section>", "<select>", "<small>", "<source>", "<span>", "<strike>", "<strong>", "<style>", "<sub>", "<summary>", "<sup>", "<svg>", "<table>", "<tbody>", "<td>", "<template>", "<textarea>", "<tfoot>", "<th>", "<thead>", "<time>", "<title>", "<tr>", "<track>", "<tt>", "<u>", "<ul>", "<var>", "<video>", "<wbr>" );
our @ExcludedHTMLTags = ( "<head>", "<article>", );

our @xdxf_start = (
                '<?xml version="1.0" encoding="UTF-8" ?>'."\n",
                '<xdxf lang_from="" lang_to="" format="visual">'."\n",
                '<full_name></full_name>'."\n",
                '<description>'."\n",
                '<date></date>'."\n",
                'Created with pocketbookdic.pl'."\n",
                '</description>'."\n");
our $lastline_xdxf = "</xdxf>\n";
our @xml_start = (
                '<?xml version="1.0" encoding="UTF-8" ?>'."\n",                       #[0]
                '<stardict xmlns:xi="http://www.w3.org/2003/XInclude">'."\n",           #[1]
                '<info>'."\n",                                                          #[2]
                '<version>2.4.2</version>'."\n",                                        #[3]
                '<bookname></bookname>'."\n",                                           #[4]
                '<author>pocketbookdic.pl</author>'."\n",                               #[5]
                '<email>rather_open_issue@github.com</email>'."\n",                     #[6]
                '<website>https://github.com/Markismus/PocketBookDic</website>'."\n",   #[7]
                '<description></description>'."\n",                                     #[8]
                '<date>'.gmtime().'</date>'."\n",                                       #[9]
                # '<dicttype></dicttype>'."\n",
                '</info>'."\n");                                                        #[10]
our $lastline_xml = "</stardict>\n";

# Deliminator for CSV files, usually ",",";" or "\t"(tab).
our $CVSDeliminator = ",";

1;