#! /bin/perl
use strict;
use autodie;
use Term::ANSIColor;    #Color display on terminal
use Encode 'encode';
use utf8;
use open ':std', ':encoding(UTF-8)';
use feature 'unicode_strings'; # You get funky results with the sub convertNumberedSequencesToChar without this.

my $isRealDead=1; # Some errors should kill the program. However, somtimes you just want to convert.

# Controls manual input: 0 disables.
my ( $lang_from, $lang_to, $format ) = ( "eng", "eng" ,"" ); # Default settings for manual input of xdxf tag.
my $reformat_full_name = 1; # Demands manual input for full_name tag.
my $reformat_xdxf=1; # Demands manual input for xdxf tag.

# This controls the maximum article length.
# If set too large, the old converter will crash and the new will truncate the entry.
my $max_article_length = 64000;
# This controls the maximum line length.
# If set too large, the converter wil complain about bad XML syntax and exit.
my $max_line_length = 4000;
# Deliminator for CSV files, usually ",",";" or "\t"(tab).
my $CVSDeliminator = ",";

my $no_test=1; # Testing singles out a single ar and generates a xdxf-file containing only that ar.
my $ar_chosen = 410; # Ar singled out when no_test = 0;
my ($cycle_dotprinter, $cycles_per_dot) = (0 , 300); # A green dot is printed achter $cycles_per_dot ar's have been processed.
my $i_limit = 27000000000000000000; # Hard limit to the number of lines that are processed.
my $remove_color_tags = 0; # Color tags seem less desirable with greyscale screens. It reduces the article size considerably.
my $isdebug = 1; # Turns off all debug messages
my $isdebugVerbose = 0; # Turns off all verbose debug messages
my $isCreateStardictDictionary = 1; # Turns on Stardict text and binary dictionary creation.
my $isCreatePocketbookDictionary = 0; # Controls conversion to Pocketbook Dictionary dic-format
my $isTestingOn = 1; # Turns tests on
my $isRemoveWaveReferences = 1; # Removes a the references to wav-files
# Same Type Seqence is the initial value of the Stardict variable set in the ifo-file.
# "h" means html-dictionary. "m" means text.
# The xdxf-file will be filtered for &#xDDDD; values and converted to unicode if set at "m"
my $SameTypeSequence = "h"; # Either "h" or "m" or "x".
my $updateSameTypeSequence = 1; # If the Stardict files give a sametypesequence value, update the initial value.
# $BaseDir is the directory where converter.exe and the language folders reside.
# In each folder should be a collates.txt, keyboard.txt and morphems.txt file.
# my $BaseDir="C:/Users/Debiel/Downloads/PocketbookDic";
my $BaseDir="/home/mark/Downloads/DictionaryConverter-neu 171109";

chdir $BaseDir || warn "Cannot change to $BaseDir: $!\n";

# Last filename will be used
my $FileName;
$FileName = "Oxford_English_Dictionary_2nd_Ed._P2-2.4.2.xdxf";
$FileName = "dict/OxfordAdvancedLearnersDictionary_en-en/OxfordAdvancedLearnersDictionary_en-en.xdxf";
$FileName = "Oxford_English_Dictionary_2nd_Ed._P1-2.4.2_reconstructed_copy_reconstructed.xdxf";
$FileName = "Oxford_English_Dictionary_2nd_Ed._P1-2.4.2.xdxf";
$FileName = "dict/Liddell Scott Jones.ifo";
$FileName = "dict/LSJ-utf8.csv";
$FileName = "dict/test/Oxford\ English\ Dictionary\ 2nd\ Ed.\ P1_lines_951058-951205.xdxf";
$FileName = "dict/test/Oxford\ English\ Dictionary\ 2nd\ Ed.\ P2_article_ending_at_381236reconstructed.xdxf";
$FileName = "dict/stardict-Oxford_English_Dictionary_2nd_Ed._P2-2.4.2/Oxford English Dictionary 2nd Ed. P2.ifo";
$FileName = "dict/stardict-Oxford_English_Dictionary_2nd_Ed._P1-2.4.2/Oxford English Dictionary 2nd Ed. P1.ifo";
$FileName = "dict/Duden/duden.ifo";
$FileName = "dict/Oxford Advanced Learner's Dictionary/Oxford Advanced Learner's Dictionary.ifo";
$FileName = "dict/latin-english.ifo";
$FileName = "dict/NouveauLittre-Stardict/output.ifo";
$FileName = "dict/Oxford_English_Dictionary_2nd_Ed.xdxf";
$FileName = "dict/Oxford_English_Dictionary_2nd_Ed/testhtml/testhtml.xml";
# However, when an argument is given, it will supercede the last filename
if( defined($ARGV[0]) ){
	printYellow("Command line arguments provided:\n");
	foreach(@ARGV){ printYellow("\'$_\'\n"); }
	printYellow("Found command line argument: $ARGV[0].\nAssuming it is meant as the dictionary file name.\n");
	$FileName = $ARGV[0];
}
else{
	printYellow("No commandline arguments provided. Remember to either use those or define \$FileName in the script.\n");
	printYellow("First argument is the dictionary name to be converted. E.g dict/dictionary.ifo (Remember to slash forward!)\n");
	printYellow("Second is the language directory name or the CSV deliminator. E.g. eng\nThird is the CVS deliminator. E.g \",\", \";\", \"\\t\"(for tab)\n");
}


# As NouveauLittre showed a rather big problem with named entities, I decided to write a special filter
# Here is the place to insert your DOCTYPE string.
# Remember to place it between quotes '..' and finish the line with a semicolon ;
# Last Doctype will be used. To omit the filter place an empty DocType string at the end:
# $DocType = '';
my ($DocType,%EntityConversion);
$DocType = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"[<!ENTITY ns "&#9830;"><!ENTITY os "&#8226;"><!ENTITY oo "&#8250;"><!ENTITY co "&#8249;"><!ENTITY a  "&#x0061;"><!ENTITY â  "&#x0251;"><!ENTITY an "&#x0251;&#x303;"><!ENTITY b  "&#x0062;"><!ENTITY d  "&#x0257;"><!ENTITY e  "&#x0259;"><!ENTITY é  "&#x0065;"><!ENTITY è  "&#x025B;"><!ENTITY in "&#x025B;&#x303;"><!ENTITY f  "&#x066;"><!ENTITY g  "&#x0261;"><!ENTITY h  "&#x0068;"><!ENTITY h2 "&#x0027;"><!ENTITY i  "&#x0069;"><!ENTITY j  "&#x004A;"><!ENTITY k  "&#x006B;"><!ENTITY l  "&#x006C;"><!ENTITY m  "&#x006D;"><!ENTITY n  "&#x006E;"><!ENTITY gn "&#x0272;"><!ENTITY ing "&#x0273;"><!ENTITY o  "&#x006F;"><!ENTITY o2 "&#x0254;"><!ENTITY oe "&#x0276;"><!ENTITY on "&#x0254;&#x303;"><!ENTITY eu "&#x0278;"><!ENTITY un "&#x0276;&#x303;"><!ENTITY p  "&#x0070;"><!ENTITY r  "&#x0280;"><!ENTITY s  "&#x0073;"><!ENTITY ch "&#x0283;"><!ENTITY t  "&#x0074;"><!ENTITY u  "&#x0265;"><!ENTITY ou "&#x0075;"><!ENTITY v  "&#x0076;"><!ENTITY w  "&#x0077;"><!ENTITY x  "&#x0078;"><!ENTITY y  "&#x0079;"><!ENTITY z  "&#x007A;"><!ENTITY Z  "&#x0292;">]><html xml:lang="fr" xmlns="http://www.w3.org/1999/xhtml"><head><title></title></head><body>';
$DocType = '';

# Pocketbook converter.exe is dependent on a language directory in which has 3 txt-files: keyboard, morphems and collates.
# Default language directory is English, "en".
my $language_dir = "";
if( defined($ARGV[1]) and $ARGV[1] !~ m~^.$~ and $ARGV[1] !~ m~^\\t$~ ){
	printYellow("Found command line argument: $ARGV[1].\nAssuming it is meant as language directory.\n");
	$language_dir = $ARGV[1];
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

my @xdxf_start = ( 	'<?xml version="1.0" encoding="UTF-8" ?>'."\n",
				'<xdxf lang_from="" lang_to="" format="visual">'."\n",
				'<full_name></full_name>'."\n",
				'<description>'."\n",
				'<date></date>'."\n",
				'Created with pocketbookdic.pl'."\n",
				'</description>'."\n");
my $lastline_xdxf = "</xdxf>\n";
my @xml_start = ( 	'<?xml version="1.0" encoding="UTF-8" ?>'."\n",
					'<stardict xmlns:xi="http://www.w3.org/2003/XInclude">'."\n",
					'<info>'."\n",
					'<version>2.4.2</version>'."\n",
					'<bookname></bookname>'."\n",
					'<author>pocketbookdic.pl</author>'."\n",
					'<email></email>'."\n",
					'<website></website>'."\n",
					'<description></description>'."\n",
					'<date></date>'."\n",
					'<dicttype></dicttype>'."\n",
					'</info>'."\n");
my $lastline_xml = "</stardict>\n";
# Determine operating system.
my $OperatingSystem = "$^O";
if ($OperatingSystem eq "linux"){ print "Operating system is $OperatingSystem: All good to go!\n";}
else{ print "Operating system is $OperatingSystem: Not linux, so I am assuming Windows!\n";}

sub array2File {
    my ( $FileName, @Array ) = @_;
    # debugV("Array to be written:\n",@Array);
    open( FILE, ">$FileName" )
      || warn "Cannot open $FileName: $!\n";
    print FILE @Array;
    close(FILE);
    $FileName =~ s/.+\/(.+)/$1/;
    printGreen("Written $FileName. Exiting sub array2File\n");
    return ("File written");}
sub debug { $isdebug and printRed( @_, "\n" ); return(1);}
sub debugV { $isdebugVerbose and printBlue( @_, "\n" ); return(1);}
sub debugFindings {
    debugV();
    if ( defined $1 )  { debugV("\$1 is: \"$1\"\n"); }
    if ( defined $2 )  { debugV("\$2 is: \"$2\"\n"); }
    if ( defined $3 )  { debugV("\$3 is: \"$3\"\n"); }
    if ( defined $4 )  { debugV("\$4 is:\n $4\n"); }
    if ( defined $5 )  { debugV("5 is:\n $5\n"); }
    if ( defined $6 )  { debugV("6 is:\n $6\n"); }
    if ( defined $7 )  { debugV("7 is:\n $7\n"); }
    if ( defined $8 )  { debugV("8 is:\n $8\n"); }
    if ( defined $9 )  { debugV("9 is:\n $9\n"); }
    if ( defined $10 ) { debugV("10 is:\n $10\n"); }
    if ( defined $11 ) { debugV("11 is:\n $11\n"); }
    if ( defined $12 ) { debugV("12 is:\n $12\n"); }
    if ( defined $13 ) { debugV("13 is:\n $13\n"); }
    if ( defined $14 ) { debugV("14 is:\n $14\n"); }
    if ( defined $15 ) { debugV("15 is:\n $15\n"); }
    if ( defined $16 ) { debugV("16 is:\n $16\n"); }
    if ( defined $17 ) { debugV("17 is:\n $17\n"); }
    if ( defined $18 ) { debugV("18 is:\n $18\n"); }}
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
	if( $Content =~ m~^<head>(?<head>(?:(?!</head).)+)</head><def>(?<def>(?:(?!</def).)+)</def>~s){
		# debugFindings();
		# debug("Well formed ar content entry");
		my $head = $+{head};
		my $def_old = $+{def};
		my $def = $def_old;

		# Special characters in $head and $def should be converted to
		#  &lt; (<), &amp; (&), &gt; (>), &quot; ("), and &apos; (')
		$head =~ s~(?<lt><)(?!/?(key>|k>))~&lt;~gs;
		$head =~ s~(?<amp>&)(?!(lt;|amp;|gt;|quot;|apos;))~&amp;~gs;
		$def =~ s~(?<lt><)(?!/?(c>|c c="|block|quote|b>|i>|abr>|ex>|kref>|sup>|sub>|dtrn>|k>|key>|rref|f>))~&lt;~gs;
		$def =~ s~(?<amp>&)(?!(lt;|amp;|gt;|quot;|apos;|\#x?[0-9A-Fa-f]{1,6}))~&amp;~gs;
		# $def =~ s~(?<amp>&)(?!([^;]{1,6};))~&amp;~gs; # This excludes the removal of & before &#01234;

		if( $isCreatePocketbookDictionary){
			# Splits complex blockquote blocks from each other. Small impact on layout.
			$def =~ s~</blockquote><blockquote>~</blockquote>\n<blockquote>~gs;
			# Splits blockquote from next heading </blockquote><b><c c=
			$def =~ s~</blockquote><b><c c=~</blockquote>\n<b><c c=~gs;


			# Splits the too long lines.
			my @def = split(/\n/,$def);
			my $def_line_counter = 0;
			foreach my $line (@def){
			 	$def_line_counter++;
			 	# Finetuning of cut location
			 	if (length(encode('UTF-8', $line)) > $max_line_length){
				 	# So I would like to cut the line at say 3500 chars not in the middle of a tag, so before a tag.
				 	# index STR,SUBSTR,POSITION
				 	my $cut_location = index $line, "<", int($max_line_length * 0.85);
				 	if($cut_location == -1 or $cut_location > $max_line_length){
				 		# Saw this with definition without tags a lot a greek characters. Word count <3500, bytes>7500.
				 		# New cut location is from half the line.
				 		$cut_location = index $line, "<", int(length($line)/2);
				 		# But sometimes there are no tags
				 		if($cut_location == -1 or $cut_location > $max_line_length){
				 			$cut_location = index $line, ".", int($max_line_length * 0.85);
				 			if($cut_location == -1 or $cut_location > $max_line_length){
				 				$cut_location = index $line, ".", int(length($line)/2);
				 			}
				 		}


				 	}
			 		debugV("Definition line $def_line_counter is ",length($line)," characters and ",length(encode('UTF-8', $line))," bytes. Cut location is $cut_location.");
			 		my $cutline_begin = substr($line, 0, $cut_location);
			 		my $cutline_end = substr($line, $cut_location);
			 		debug ("Line taken to be cut:") and printYellow("$line\n") and
			 		debug("First part of the cut line is:") and printYellow("$cutline_begin\n") and
			 		debug("Last part of the cut line is:") and printYellow("$cutline_end\n") and
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
			$def =~ s~<\?c>~~gs;
			$def =~ s~<c c=[^>]+>~~gs;
		}

		$Content =~ s~\Q$def_old\E~$def~s;
	}
	else{debug("Not well formed ar content!!\n$Content");}

	if ($isRemoveWaveReferences){
		# remove wav-files displaying
		# Example:
		# <rref>
		#z_epee_1_gb_2.wav</rref>
		$Content =~ s~<rref>((?!\.wav</rref>).)+\.wav</rref>~~gs;
	}

	return( $Content );}
sub convertCVStoXDXF{
	my @cvs = @_;
	my @xdxf = @xdxf_start;
	my $number= 0;
	foreach(@cvs){
		$number++;
		debugV("\$CVSDeliminator is \'$CVSDeliminator\'.") if $number<10;
		debugV("CVS line is: $_") if $number<10;
		m~(?<key>((?!$CVSDeliminator).)+)$CVSDeliminator(?<def>.+)~;
		# my $comma_is_at = index $_, $CVSDeliminator, 0;
		# debug("The deliminator is at: $comma_is_at") if $number<10;
		# my $key = substr $_, 0, $comma_is_at - 1;
		# my $def = substr $_, $comma_is_at + length($CVSDeliminator);
		my $key = $+{key};
		my $def = $+{def};

		debugV("key found: $key") if $number<10;
		debugV("def found: $def") if $number<10;
		# Remove whitespaces at the beginning of the definition and EOL at the end.
		$def =~ s~^\s+~~;
		$def =~ s~\n$~~;
		push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
		debugV("Pushed <ar><head><k>$key</k></head><def>$def</def></ar>") if $number<10;
	}
	push @xdxf, $lastline_xdxf;
	return(@xdxf);}
sub convertNonBreakableSpacetoNumberedSequence{
	my $UnConverted = join('',@_);
	debugV("Entered sub convertNonBreakableSpacetoNumberedSequence");
	$UnConverted =~ s~\&nbsp;~&#160;~sg ;
	my @Converted = split(/$/, $UnConverted);
	return( @Converted );}
sub convertNumberedSequencesToChar{
	my $UnConverted = join('',@_);
	debugV("Entered sub convertNumberedSequencesToChar");
	$UnConverted =~ s~\&\#x([0-9A-Fa-f]{1,6});~chr("0x".$1)~seg ;
	$UnConverted =~ s~\&\#([0-9]{1,6});~chr(int($1))~seg ;
	# while(0 and $UnConverted =~ m~(?<match>\&\#(?<number>[0-9]{1,6});)~s){
	# 	my $match = $+{match};
	# 	my $replace = chr(int($+{number}));
	# 	debug($+{number});
	# 	debugFindings();
	# 	debug("'",chr($+{number}),"'");
	# 	$UnConverted =~ s~$match~$replace~s;

	# }
	return( split(/(\n)/, $UnConverted) );}
sub convertStardictXMLtoXDXF{
	my $StardictXML = join('',@_);
	my @xdxf = @xdxf_start;
	# Extract bookname from Stardict XML
	if( $StardictXML =~ m~<bookname>(?<bookname>((?!</book).)+)</bookname>~s ){
		my $bookname = $+{bookname};
		# xml special symbols are not recognized by converter in the dictionary title.
		$bookname =~ s~&lt;~<~;
		$bookname =~ s~&amp;~&~;
		$bookname =~ s~&apos;~'~;
		substr($xdxf[2], 11, 0) = $bookname;
	}
	# Extract date if present from Stardict XML
	if( $StardictXML =~ m~<date>(?<date>((?!</date>).)+)</date>~s ){
		substr($xdxf[4], 6, 0) = $+{date};
	}
	# Extract sametypesequence from Stardict XML
	if( $updateSameTypeSequence and $StardictXML =~ m~<definition type="(?<sametypesequence>\w)">~s){
		$SameTypeSequence = $+{sametypesequence};
	}

	printCyan("Converting stardict xml to xdxf xml. This will take some time. ",getLoggingTime(),"\n");
	# Initialize variables for collection
	my ($key, $def, $article, $definition) = ("","", 0, 0);
	# Initialize variables for testing
	my ($test_loop, $counter,$max_counter) = (0,0,40) ;
	foreach(@_){
		$counter++;
		# Change state to article
		if(m~<article>~){ $article = 1; debug("Article start tag found at line $counter.") if $test_loop;}

		# Match key within article outside of definition
		if($article and !$definition and m~<key>(?<key>((?!</key>).)+)</key>~){ $key = $+{key}; debug("Key \"$key\" found at line $counter.") if $test_loop;}
		# change state to definition
		if(m~<definition type="\w">~){ $definition = 1; debug("Definition start tag found at line $counter.") if $test_loop;}
		# Fails for multiline definitions such as:
			# <definition type="x">
			# <![CDATA[<k>&apos;Arry</k>
			# <b>&apos;Arry</b>
			# <blockquote><blockquote>(<c c="darkslategray">ˈærɪ</c>)</blockquote></blockquote>
			# <blockquote><blockquote><c c="gray">[The common Christian name <i>Harry</i> vulgarly pronounced without the aspirate.]</c></blockquote></blockquote>
			# <blockquote><blockquote>Used humorously for: A low-bred fellow (who ‘drops his <i>h&apos;</i>s’) of lively temper and manners. Hence <b>&apos;Arryish</b> <i>a.</i>, vulgarly jovial.</blockquote></blockquote>
			# <blockquote><blockquote><blockquote><blockquote><blockquote><blockquote><ex><b>1874</b> <i>Punch&apos;s Almanac</i>, <c c="darkmagenta">&apos;Arry on &apos;Orseback.</c> <b>1881</b> <i><abr>Sat.</abr> <abr>Rev.</abr></i> <abr>No.</abr> 1318. 148 <c c="darkmagenta">The local &apos;Arry has torn down the famous tapestries of the great hall.</c> <b>1880</b> W. Wallace in <i>Academy</i> 28 Feb. 156/1 <c c="darkmagenta">He has a fair stock of somewhat &apos;Arryish animal spirits, but no real humour.</c></ex></blockquote></blockquote></blockquote></blockquote></blockquote></blockquote>]]>
			# </definition>
		s~<definition type="\w">~~;
		s~<\!\[CDATA\[~~;
		s~<k>\Q$key\E</k>~~;
		s~<b>\Q$key\E</b>~~;
		s~^[\n\s]+$~~;
		if($definition and m~(?<def>((?!\]\]>).)+)(\]\]>)?~s){
			my $fund = $+{def};
			$fund =~ s~</definition>\n?~~;
			$def .= $fund if $fund!~m~^[\n\s]+$~;
			debug("Added definition \"$fund\" at line $counter.") if $test_loop and $fund ne "" and $fund!~m~^[\n\s]+$~;
		}
		if(  m~</definition>~ ){
			$definition = 0;
			debug("Definition stop tag found at line $counter.") if $test_loop;
		}
		if(  !$definition and $key ne "" and $def ne ""){
			debug("Found key \'$key\' and definition \'$def\'") if $test_loop;
			push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
			($key, $def, $definition) = ("","",0);
		}
		# reset on end of article
		if(m~</article>~ ){
			($key, $def, $article) = ("","",0);
			debug("Article stop tag found at line $counter.\n") if $test_loop;
		}
		die if $counter==$max_counter and $test_loop and $isRealDead;
	}
	printCyan("\nDone at ", getLoggingTime(),"\n");
	push @xdxf, $lastline_xdxf;
	return(@xdxf);}
sub convertXDXFtoStardictXML{
	my $xdxf = join('',@_);
	my @xml = @xml_start;
	if( $xdxf =~ m~<full_name>(?<bookname>((?!</full_name).)+)</full_name>~s ){
		my $bookname = $+{bookname};
		# xml special symbols are not recognized by converter in the dictionary title.
		$bookname =~ s~&lt;~<~;
		$bookname =~ s~&amp;~&~;
		$bookname =~ s~&apos;~'~;
		substr($xml[4], 10, 0) = $bookname;
	}
	if( $xdxf =~ m~<date>(?<date>((?!</date>).)+)</date>~s ){
		substr($xml[9], 6, 0) = $+{date};
	}
	if( $xdxf =~ m~<xdxf (?<description>((?!>).)+)>~s ){
		substr($xml[8], 13, 0) = $+{description};
	}
	printCyan("Converting xdxf-xml to Stardict-xml. This will take some time.", getLoggingTime(),"\n" );
	$cycle_dotprinter = 0;
	# The compilation of this string: while($xdxf =~ s~<ar>(?<article>((?!</ar).)+)</ar>~~s){...}
	# is that the regex is recompiled for every iteration. This takes 45m for a dict with 70k entries.
	while($xdxf =~ s~<ar>(?<article>((?!</ar).)+)</ar>~~s){
		$cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
		my $article = $+{article};
		push @xml, "<article>\n";
		# <head><k>a</k></head>
		$article =~ m~<head><k>(?<key>((?!</k).)+)</k>~s;
		push @xml, "<key>".$+{key}."</key>\n\n";
		$article =~ m~<def>(?<definition>((?!</def).)+)</def>~s;
		push @xml, '<definition type="'.$SameTypeSequence.'">'."\n";
		push @xml, '<![CDATA['.$+{definition}.']]>'."\n";
		push @xml, "</definition>\n";
		push @xml, "</article>\n\n";
	}
	push @xml, "\n";
	push @xml, $lastline_xml;
	push @xml, "\n";
	printCyan("\nDone at ", getLoggingTime(),"\n" );
	return(@xml);}
sub newConvertXDXFtoStardictXML{
	my $xdxf = join('',@_);
	my @xml = @xml_start;
	if( $xdxf =~ m~<full_name>(?<bookname>((?!</full_name).)+)</full_name>~s ){
		my $bookname = $+{bookname};
		# xml special symbols are not recognized by converter in the dictionary title.
		$bookname =~ s~&lt;~<~;
		$bookname =~ s~&amp;~&~;
		$bookname =~ s~&apos;~'~;
		substr($xml[4], 10, 0) = $bookname;
	}
	if( $xdxf =~ m~<date>(?<date>((?!</date>).)+)</date>~s ){
		substr($xml[9], 6, 0) = $+{date};
	}
	if( $xdxf =~ m~<xdxf (?<description>((?!>).)+)>~s ){
		substr($xml[8], 13, 0) = $+{description};
	}
	printCyan("Converting xdxf-xml to Stardict-xml. This will take some time.", getLoggingTime(),"\n" );
	my @articles = $xdxf =~ m~<ar>((?:(?!</ar).)+)</ar>~sg ;
	printCyan("Finished getting articles at ", getLoggingTime(),"\n" );
	array2File("testNewConvertArrayIn.xml",($xdxf)) if $isTestingOn;
	array2File("testNewConvertArticlesOut.xml",@articles) if $isTestingOn;
	$cycle_dotprinter = 0;
	foreach my $article ( @articles){
		$cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
		push @xml, "<article>\n";
		# <head><k>a</k></head>
		$article =~ m~<head><k>(?<key>((?!</k).)+)</k>~s;
		push @xml, "<key>".$+{key}."</key>\n\n";
		$article =~ m~<def>(?<definition>((?!</def).)+)</def>~s;
		push @xml, '<definition type="'.$SameTypeSequence.'">'."\n";
		push @xml, '<![CDATA['.$+{definition}.']]>'."\n";
		push @xml, "</definition>\n";
		push @xml, "</article>\n\n";
	}
	push @xml, "\n";
	push @xml, $lastline_xml;
	push @xml, "\n";
	printCyan("\nDone at ", getLoggingTime(),"\n" );
	return(@xml);}
sub altConvertXDXFtoStardictXML{
	my @xdxf = @_;
	my @xml = @xml_start;
	printCyan("Converting xdxf-xml to Stardict-xml. This will take some time.", getLoggingTime(),"\n" );
	$cycle_dotprinter = 0;
	my ($article, $concat) = ("", 0);
	foreach my $line (@xdxf){
		debug("\$article pos(1): $article");
		$cycle_dotprinter++;
		if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
		if( $line =~ m~<full_name>(?<bookname>((?!</full_name).)+)</full_name>~s ){
			my $bookname = $+{bookname};
			# xml special symbols are not recognized by converter in the dictionary title.
			$bookname =~ s~&lt;~<~;
			$bookname =~ s~&amp;~&~;
			$bookname =~ s~&apos;~'~;
			substr($xml[4], 10, 0) = $bookname;
			next;
		}
		if( $line =~ m~<date>(?<date>((?!</date>).)+)</date>~s ){
			substr($xml[9], 6, 0) = $+{date};
			next;
		}
		if( $line =~ m~<xdxf (?<description>((?!>).)+)>~s ){
			substr($xml[8], 13, 0) = $+{description};
			next;
		}
		if( $line =~ m~<ar>((?!</ar).*$)~s){ $article = $article.$1 ; $concat = 1 ; debug("\$article pos(2): $article"); next;}
		if( $line =~ m~^(.*)</ar>~s){
			$article = $article.$1 ;
			debug("\$article pos(3): $article");
			$article =~ s~</?ar>\n?~~sg;
			push @xml, "<article>\n";
			# <head><k>a</k></head>
			$article =~ m~<head><k>(?<key>((?!</k).)+)</k>~s;
			push @xml, "<key>".$+{key}."</key>\n\n";
			$article =~ m~<def>(?<definition>((?!</def).)+)</def>~s;
			push @xml, '<definition type="'.$SameTypeSequence.'">'."\n";
			push @xml, '<![CDATA['.$+{definition}.']]>'."\n";
			push @xml, "</definition>\n";
			push @xml, "</article>\n\n";
			$article = "";
			$concat = 0;
			next;
		}
		if( $concat == 1 ){ $article = $article.$line; next;}
	}
	push @xml, "\n";
	push @xml, $lastline_xml;
	push @xml, "\n";
	printCyan("\nDone at ", getLoggingTime(),"\n" );
	return(@xml);}
sub file2Array {

    #This subroutine expects a path-and-filename in one and returns an array
    my $FileName = $_[0];
    if(!defined $FileName){debug("File name in file2Array is not defined. Quitting!");die if $isRealDead;}
    open( FILE, "$FileName" )
      || (warn "Cannot open $FileName: $!\n" and die);
    my @ArrayLines = <FILE>;
    close(FILE);
    printBlue("Read $FileName, returning array. Exiting file2Array\n");
    return (@ArrayLines);}
sub filterXDXFforEntitites{
	my( @xdxf ) = @_;
	my @Filteredxdxf;
	if( scalar keys %EntityConversion == 0 ){
		debugV("No \%EntityConversion hash defined");
		return(@xdxf);
	}
	else{debugV("These are the keys:", keys %EntityConversion);}
	$cycle_dotprinter = 0 ;
	printCyan("Filtering entities based on DOCTYPE. This will take some time. ", getLoggingTime(),"\n");
	foreach my $line (@xdxf){
		$cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
		foreach my $EntityName(keys %EntityConversion){
			$line =~ s~(\&$EntityName;)~$EntityConversion{$EntityName}~g;
		}
		push @Filteredxdxf, $line;
	}
	printCyan("\nDone at ", getLoggingTime(), "\n");
	return (@Filteredxdxf);}
sub generateEntityHashFromDocType{
	my $String = $_[0]; # MultiLine DocType string. Not Array!!!
	my %EntityConversion=( );
	while($String =~ s~<!ENTITY\s+(?<name>[^\s]+)\s+"(?<meaning>.+?)">~~s){
		debugV("$+{name} --> $+{meaning}");
		$EntityConversion{$+{name}} = $+{meaning};
	}
	return(%EntityConversion);}
sub getLoggingTime {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "%04d%02d%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $nice_timestamp;}
sub loadXDXF{
	my ($FileName,$OperatingSystem) = @_;

	# Create the array @xdxf
	my @xdxf;

	## Load from xdxffile
	if( $FileName =~ m~\.xdxf$~){@xdxf = file2Array($FileName);}
	elsif( -e substr($FileName, 0, (length($FileName)-4)).".xdxf"){
		@xdxf = file2Array(substr($FileName, 0, (length($FileName)-4)).".xdxf") ;
		# Check SameTypeSequence
		checkSameTypeSequence($FileName);
		# Change FileName to xdxf-extension
		$FileName = substr($FileName, 0, (length($FileName)-4)).".xdxf";
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
	else{debug("Not a known extension for the given filename. Quitting!");die;}
	return ($FileName, @xdxf);}
sub printGreen   { print color('green') if $OperatingSystem eq "linux";   print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printBlue    { print color('blue') if $OperatingSystem eq "linux";    print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printRed     { print color('red') if $OperatingSystem eq "linux";     print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printYellow  { print color('yellow') if $OperatingSystem eq "linux";  print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printMagenta { print color('magenta') if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printCyan    { print color('cyan') if $OperatingSystem eq "linux";    print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub oldReconstructXDXF{
	# Construct a new xdxf array to prevent converter.exe from crashing.
	## Initial values
	my @xdxf = @_;
	my @xdxf_reconstructed = ();
	my $i = 0;
	my ($Description, $Description_content) = ( 0 , "" );
	my ($ar, $ar_content, $ar_count) = ( 0, "", 0);
	my $xdxf_closing = "</xdxf>\n";
	## Step through the array line by line.
	printCyan("Reconstructing xdxf array. This will take some time. ", getLoggingTime(),"\n");
	foreach my $entry (@xdxf){
		$i++;
		# Handling of dxdf end tag
		if ( $entry =~ m~$xdxf_closing~ or $i_limit < $i or ($ar_count == ($ar_chosen + 1) and $no_test == 0) ){
			push @xdxf_reconstructed, $xdxf_closing;
			last;
		}
		# Check whether every line ends with an EOL.
		# The criterion has rather diminished through the building of the script.
		if($entry =~ m~^.*\n$~s){
			# Handling of xdxf tag
			if ( $entry =~ m~^<xdxf(.+)>\n$~){
				my $xdxf = $1;
				if( $reformat_xdxf and $xdxf =~ m~ lang_from="(.*)" lang_to="(.*)" format="(.*)"~){
					$lang_from = $1 if defined $1 and $1 ne "";
					$lang_to = $2 if defined $2 and $2 ne "";
					$format = $3 if defined $3 and $3 ne "";
					print(" lang_from is \"$1\". Would you like to change it? (press enter to keep default \[$lang_from\] ");
					my $one = <STDIN>; chomp $one; if( $one ne ""){ $lang_from = $one ; }
					print(" lang_to is \"$2\". Would you like to change it? (press enter to keep default \[$lang_to\] ");
					my $one = <STDIN>; chomp $one; if( $one ne ""){ $lang_to = $one ; }
					print(" format is \"$3\". Would you like to change it? (press enter to keep default \[$format\] ");
					my $one = <STDIN>; chomp $one; if( $one ne ""){ $format = $one ; }
					$xdxf= 'lang_from="'.$lang_from.'" lang_to="'.$lang_to.'" format="'.$format.'"';
				}
				printMagenta("<xdxf ".$xdxf.">\n");
				push @xdxf_reconstructed, "<xdxf ".$xdxf.">\n";
				next;
			}
			# Handling of full_name tag
			if ( $entry =~ m~^<full_name>~){
				if ( $entry !~ m~^<full_name>.*</full_name>\n$~){ debug("full_name tag is not on one line. Investigate!\n"); die if $isRealDead;}
				elsif( $reformat_full_name and $entry =~ m~^<full_name>(?<fullname>((?!</full).)*)</full_name>\n$~ ){
					my $full_name = $+{fullname};
					my $old_name = $full_name;
					print("Full_name is \"$full_name\".\nWould you like to change it? (press enter to keep default \[$full_name\] ");
					my $one = <STDIN>; chomp $one; if( $one ne ""){ $full_name = $one ; };
					debug("\$entry is: $entry");
					$entry = "<full_name>$full_name</full_name>\n";
					debug("Fullname tag entry is now:$entry");
				}
			}
			# Handling of Description
			if ( $entry =~ m~^(?<des><description>)~){  push @xdxf_reconstructed, $+{des}."\n"; $Description = 1;} #Start of description block
			if($Description){
				if( $entry =~ m~^(?<des><description>)?(?<cont>((?!</desc).)*)(?<closetag></description>)?\n$~ ){

					#debugFindings();
					#debug("?<des> is $+{des}\n?<cont> is $+{cont}\n?<closetag> is $+{closetag}\n");
					$Description_content .= $+{cont} ; # debug($Description_content);

					if( $+{closetag} eq "</description>"){
						# debug("Matched description closing tag!\n");
						chomp $Description_content;
						push @xdxf_reconstructed, $Description_content."\n".$+{closetag}."\n";
						$Description = 0;
					}

					# print("Regex working!\n");
				}
				next;
			}
			# Handling of an ar-tag
			if ( $entry =~ m~^(?<ar><ar>)~){  #Start of ar block
				$ar_count++; $cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}

				push @xdxf_reconstructed, $+{ar}."\n"  if ( $no_test or $ar_count==$ar_chosen);
				$ar = 1;
			}
			if( $ar ){
				if( $entry =~ m~^(?<ar><ar>)?(?<cont>((?!</ar).)*)(?<closetag></ar>)?\n$~ ){
					# debugFindings();
					# debug("?<ar> is $+{ar}\n?<cont> is $+{cont}\n?<closetag> is $+{closetag}\n");
					$ar_content .= $+{cont} ; # debug($ar_content);

					if( $+{closetag} eq "</ar>"){
						# debug("Matched ar closing tag!\n");
						my $cleansedcontent = cleanseAr($ar_content);
						push @xdxf_reconstructed, $cleansedcontent."\n".$+{closetag}."\n" if ($no_test or $ar_count==$ar_chosen);
						$ar = 0;
						$ar_content = "";
					}
				}
				next;
			}

			push @xdxf_reconstructed, $entry;
			next;
		}
		else{ 	debug("Line without a EOL: $i");
				debug("[",$i-3,"]: ",$xdxf[$i-3]);
				debug("[",$i-2,"]: ",$xdxf[$i-2]);
				debug("[",$i-1,"]: ",$xdxf[$i-1]);
				debug("[",$i,"]: ",$xdxf[$i]);
				debug("[",$i+1,"]: ",$xdxf[$i+1]);
				die if $isRealDead; }
	}

	printMagenta("\nTotal number of lines processed \$i = ",$i+1,".\n");
	printMagenta("Total number of articles processed \$ar = ",$ar+1,".\n");
	printCyan("Done at ",getLoggingTime,"\n");
	return( @xdxf_reconstructed );}
sub reconstructXDXF{
	# Construct a new xdxf array to prevent converter.exe from crashing.
	## Initial values
	my @xdxf = @_;
	my @xdxf_reconstructed = ();
	my $xdxf_closing = "</xdxf>\n";
	
	printCyan("Reconstructing xdxf array. This will take some time. ", getLoggingTime(),"\n");
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
				my $one = <STDIN>; chomp $one; if( $one ne ""){ $lang_to = $one ; }
				print(" format is \"$3\". Would you like to change it? (press enter to keep default \[$format\] ");
				my $one = <STDIN>; chomp $one; if( $one ne ""){ $format = $one ; }
				$xdxf= 'lang_from="'.$lang_from.'" lang_to="'.$lang_to.'" format="'.$format.'"';
			}
			$entry = "<xdxf ".$xdxf.">\n";
			printMagenta($entry);
		}
		# Handling of full_name tag
		elsif ( $entry =~ m~^<full_name>~){
			if ( $entry !~ m~^<full_name>.*</full_name>\n$~){ debug("full_name tag is not on one line. Investigate!\n"); die if $isRealDead;}
			elsif( $reformat_full_name and $entry =~ m~^<full_name>(?<fullname>((?!</full).)*)</full_name>\n$~ ){
				my $full_name = $+{fullname};
				my $old_name = $full_name;
				print("Full_name is \"$full_name\".\nWould you like to change it? (press enter to keep default \[$full_name\] ");
				my $one = <STDIN>; chomp $one; if( $one ne ""){ $full_name = $one ; };
				debug("\$entry is: $entry");
				$entry = "<full_name>$full_name</full_name>\n";
				debug("Fullname tag entry is now: ");
			}
			printMagenta($entry);
		}
		# Handling of Description. Turns one line into multiple.
		elsif( $entry =~ m~^(?<des><description>)?(?<cont>((?!</desc).)*)(?<closetag></description>)\n$~ ){
			my $Description_content .= $+{cont} ; 
			chomp $Description_content;
			$entry = @xdxf_reconstructed, $+{des}."\n".$Description_content."\n".$+{closetag}."\n";
		}
		# Handling of an ar-tag
		elsif ( $entry =~ m~^<ar>~){last;}  #Start of ar block
		
		push @xdxf_reconstructed, $entry;
	}

	# Push cleaned articles to array
	my $xdxf = join( '', @xdxf);
	my @articles = $xdxf =~ m~<ar>((?:(?!</ar).)+)</ar>~sg ;
	my ($ar, $ar_count) = ( 0, 0);
	foreach my $article (@articles){
		$ar_count++; $cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
		cleanseAr($article);
		chomp $article;
		push @xdxf_reconstructed, "<ar>\n$article\n</ar>\n";
	}
	
	push @xdxf_reconstructed, $xdxf_closing;
	printMagenta("\nTotal number of articles processed \$ar = ",scalar @articles,".\n");
	printCyan("Done at ",getLoggingTime,"\n");
	return( @xdxf_reconstructed );}
sub testSub{
	my $TestFileName = "test_newConvert.xdxf";
	if( $isTestingOn == 0){return;}
	if( -e $TestFileName){
		my @test_Unicode = file2Array("test_newConvert.xdxf");
		array2File( "test_newConvert.xml", newConvertXDXFtoStardictXML(@test_Unicode) )  ;
	}
	else{ Debug("test_newConvert.xdxf not found")}
	return;}
sub testUnicode{
	# Test unicode conversion
	my @test_Unicode = file2Array("test_Unicode.xdxf");
	array2File("test_Unicode.xml", @test_Unicode);
	@test_Unicode = filterXDXFforEntitites( @test_Unicode );
	array2File("test_Unicode_filtered.xml", @test_Unicode);
	@test_Unicode = convertNonBreakableSpacetoNumberedSequence( @test_Unicode );
	array2File("test_Unicode_nbsp.xml", @test_Unicode);
	@test_Unicode = convertNumberedSequencesToChar( @test_Unicode );
	debugV(@test_Unicode,"\n");
	array2File("test_Unicode_ConvertedSequences.xml", @test_Unicode);
	return;}

# Generate entity hash defined in DOCTYPE
%EntityConversion = generateEntityHashFromDocType($DocType);
# Some testing
testSub() if $isTestingOn;
# Result test is that it is imperative to use:
# use feature 'unicode_strings';
testUnicode() if $isTestingOn;

# Fill array from file.
my @xdxf;
($FileName, @xdxf) = loadXDXF( $FileName, $OperatingSystem );
array2File("testLoadedDVDX.xml", @xdxf) if $isTestingOn;
# filterXDXFforEntitites
@xdxf = filterXDXFforEntitites(@xdxf);
array2File("testFilteredDVDX.xml", @xdxf) if $isTestingOn;
my @xdxf_reconstructed = reconstructXDXF( @xdxf );
array2File("test_Constructed.xml", @xdxf_reconstructed) if $isTestingOn;
# If SameTypeSequence is not "h", remove &#xDDDD; sequences and replace them with characters.
if ( $SameTypeSequence ne "h" ){
	@xdxf_reconstructed = convertNumberedSequencesToChar(
							convertNonBreakableSpacetoNumberedSequence( @xdxf_reconstructed )
								) ;
}
# Save reconstructed XDXF-file
my $dict_xdxf=$FileName;
if( $dict_xdxf !~ s~\.xdxf~_reconstructed\.xdxf~ ){ debug("Filename substitution did not work for : \"$dict_xdxf\""); die if $isRealDead; }
array2File($dict_xdxf, @xdxf_reconstructed);

# Create Stardict dictionary
if( $isCreateStardictDictionary ){
	# Save reconstructed XML-file
	my @StardictXMLreconstructed = newConvertXDXFtoStardictXML(@xdxf_reconstructed);
	# my @StardictXMLreconstructed = convertXDXFtoStardictXML(@xdxf_reconstructed);
	my $dict_xml = $FileName;
	if( $dict_xml !~ s~\.xdxf~_reconstructed\.xml~ ){ debug("Filename substitution did not work for : \"$dict_xml\""); die if $isRealDead; }
	array2File($dict_xml, @StardictXMLreconstructed);

	# Convert reconstructed XML-file to binary
	if ( $OperatingSystem == "linux"){
		my $dict_bin = $dict_xml;
		$dict_bin =~ s~\.xml~\.ifo~;
		my $command = "stardict-text2bin \"$dict_xml\" \"$dict_bin\" ";
		printYellow("Running system command:\"$command\"\n");
		system($command);
	}
	else{ 
		debug("Not linux, so you the script created an xml Stardict dictionary.");
		debug("You'll have to convert it to binary manually using Stardict editor.")
	}

}

# Create Pocketbook dictionary
if( $isCreatePocketbookDictionary ){
	my $ConvertCommand;
	if( $language_dir ne "" ){ $lang_from = $language_dir ;}
	if( $OperatingSystem eq "linux"){ $ConvertCommand = "WINEDEBUG=-all wine converter.exe \"$dict_xdxf\" $lang_from"; }
	else{ $ConvertCommand = "converter.exe \"$dict_xdxf\" $lang_from"; }
	printYellow("Running system command:\"$ConvertCommand\"\n");
	system($ConvertCommand);
}
