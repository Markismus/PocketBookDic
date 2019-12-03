#! /bin/perl
use strict;
use autodie;
use Storable;       #To storage the hash %Warning_per_volume.
use Term::ANSIColor;    #Color display on terminal
use Encode 'encode';

my $isRealDead=1; # Some errors should kill the program. However, somtimes you just want to convert.
my $reformat_xdxf=1; # Demands manual input for xdxf tag.
my ( $lang_from, $lang_to, $format ) = ( "eng", "eng" ,"" ); # Default settings for manual input of xdxf tag.
my $reformat_full_name = 1; # Demands manual input for full_name tag. 
my $no_test=1; # Testing singles out a single ar and generates a xdxf-file containing only that ar.
my $ar_chosen = 410; # Ar singled out when no_test = 0;
my $ar_per_dot = 300; # A green dot is printed achter $ar_per_dot ar's have been processed.
my $i_limit = 27000000000000000000; # Hard limit to the number of lines that are processed.
my $remove_color_tags = 0; # Color tags seem less desirable with greyscale screens. It reduces the article size considerably.
# $BaseDir is the directory where converter.exe and the language folders reside. 
# In each folder should be a collates.txt, keyboard.txt and morphems.txt file.
my $BaseDir="/home/mark/Downloads/DictionaryConverter-neu 171109"; 


chdir $BaseDir || warn "Cannot change to $BaseDir: $!\n";
# Last filename will be used
my $FileName;
$FileName = "Oxford_English_Dictionary_2nd_Ed._P2-2.4.2.xdxf";
$FileName = "dict/OxfordAdvancedLearnersDictionary_en-en/OxfordAdvancedLearnersDictionary_en-en.xdxf";
$FileName = "Oxford_English_Dictionary_2nd_Ed._P1-2.4.2_reconstructed_copy_reconstructed.xdxf";
$FileName = "Oxford_English_Dictionary_2nd_Ed._P1-2.4.2.xdxf";
$FileName = "dict/Liddell Scott Jones.ifo";
$FileName = "dict/Oxford Advanced Learner's Dictionary/Oxford Advanced Learner's Dictionary.ifo";
$FileName = "dict/Duden/duden.ifo";
$FileName = "dict/stardict-Oxford_English_Dictionary_2nd_Ed._P1-2.4.2/Oxford English Dictionary 2nd Ed. P1.ifo";
$FileName = "dict/latin-english.ifo";
$FileName = "dict/LSJ-utf8.csv";

my @xdxf_start = ( 	'<?xml version="1.0" encoding="UTF-8" ?>'."\n",
				'<xdxf lang_from="" lang_to="" format="visual">'."\n",
				'<full_name></full_name>'."\n",
				'<description>'."\n",
				'<date></date>'."\n",
				'Created with pocketbookdic.pl'."\n",
				'</description>'."\n");
my $lastline_xdxf = "</xdxf>\n";
	
sub Debug { PrintRed( @_, "\n" );}
sub DebugV { PrintBlue( @_, "\n" );}
sub DebugFindings {
    DebugV();
    if ( defined $1 )  { DebugV("\$1 is: \"$1\"\n"); }
    if ( defined $2 )  { DebugV("\$2 is: \"$2\"\n"); }
    if ( defined $3 )  { DebugV("\$3 is: \"$3\"\n"); }
    if ( defined $4 )  { DebugV("\$4 is:\n $4\n"); }
    if ( defined $5 )  { DebugV("5 is:\n $5\n"); }
    if ( defined $6 )  { DebugV("6 is:\n $6\n"); }
    if ( defined $7 )  { DebugV("7 is:\n $7\n"); }
    if ( defined $8 )  { DebugV("8 is:\n $8\n"); }
    if ( defined $9 )  { DebugV("9 is:\n $9\n"); }
    if ( defined $10 ) { DebugV("10 is:\n $10\n"); }
    if ( defined $11 ) { DebugV("11 is:\n $11\n"); }
    if ( defined $12 ) { DebugV("12 is:\n $12\n"); }
    if ( defined $13 ) { DebugV("13 is:\n $13\n"); }
    if ( defined $14 ) { DebugV("14 is:\n $14\n"); }
    if ( defined $15 ) { DebugV("15 is:\n $15\n"); }
    if ( defined $16 ) { DebugV("16 is:\n $16\n"); }
    if ( defined $17 ) { DebugV("17 is:\n $17\n"); }
    if ( defined $18 ) { DebugV("18 is:\n $18\n"); }}
sub PrintGreen   { print color('green');   print @_; print color('reset'); }
sub PrintBlue    { print color('blue');    print @_; print color('reset'); }
sub PrintRed     { print color('red');     print @_; print color('reset'); }
sub PrintYellow  { print color('yellow');  print @_; print color('reset'); }
sub PrintMagenta { print color('magenta'); print @_; print color('reset'); }
sub PrintCyan    { print color('cyan');    print @_; print color('reset'); }
sub FiletoArray {

    #This subroutine expects a path-and-filename in one and returns an array
    my $FileName = $_[0];
    if(!defined $FileName){Debug("File name in FiletoArray is not defined. Quitting!");die if $isRealDead;}
    open( FILE, "$FileName" )
      || (warn "Cannot open $FileName: $!\n" and Die() );
    my @ArrayLines = <FILE>;
    close(FILE);
    PrintBlue("Read $FileName, returning array. Exiting FiletoArray\n");
    return (@ArrayLines);}
sub ArraytoFile {
    my ( $FileName, @Array ) = @_;
    # DebugV("Array to be written:\n",@Array);
    open( FILE, ">$FileName" )
      || warn "Cannot open $FileName: $!\n";
    print FILE @Array;
    close(FILE);
    $FileName =~ s/.+\/(.+)/$1/;
    DebugV("Written $FileName. Exiting sub ArraytoFile\n");
    return ("File written");}
sub CleanseAr{
	my @Content = @_;
	my $Content = join('',@Content) ;
	if( $Content =~ m~^<head>(?<head>(?:(?!</head).)+)</head><def>(?<def>(?:(?!</def).)+)</def>~s){
		# DebugFindings();
		# Debug("Well formed ar content entry");
		my $head = $+{head};
		my $def_old = $+{def};
		my $def = $def_old;
		
		# Special characters in $head and $def should be converted to
		#  &lt; (<), &amp; (&), &gt; (>), &quot; ("), and &apos; (')
		$head =~ s~(?<lt><)(?!/?key>)~&lt;~gs;
		$head =~ s~(?<amp>&)(?!(lt;|amp;|gt;|quot;|apos;))~&amp;~gs;
		$def =~ s~(?<lt><)(?!/?(c>|c c="|block|quote|b>|i>|abr>|ex>|kref>|sup>|sub>|dtrn>))~&lt;~gs;
		$def =~ s~(?<amp>&)(?!(lt;|amp;|gt;|quot;|apos;))~&amp;~gs;
		
		# Splits complex blockquote blocks from each other. Small impact on layout.
		$def =~ s~</blockquote><blockquote>~</blockquote>\n<blockquote>~gs;
		# Splits blockquote from next heading </blockquote><b><c c=
		$def =~ s~</blockquote><b><c c=~</blockquote>\n<b><c c=~gs;
		my $def_bytes = length(encode('UTF-8', $def));
		# $Definition_lengths{$head} = $def_bytes;
		
		if( $def_bytes > 100000 ){ 
			Debug("The length of the definition of \"$head\" is $def_bytes bytes.");
			#It should be split in chunks < 100kB
			my @def=split("\n", $def);
			my @defs=();
			my $counter = 0;
			# Split the lines of the definition in separate chunks smaller than 90kB
			foreach my $line(@def){
				$defs[$counter].=$line."\n";
				# Debug($defs[$counter]);
				if( length(encode('UTF-8', $defs[$counter])) > 90000 ){
					Debug("Chunk is larger than 90kB. Creating another chunk.");
					chomp $defs[$counter];
					$counter++;
				}
			}
			chomp $defs[$counter];
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
			Debug("Counter reached $counter.");
			$def="";
			for(my $a = 0; $a < $counter; $a = $a + 1 ){
					Debug("\$a is $a");
					$def.=$defs[$a]."</def>\n</ar>\n<ar>\n<head>$newhead$Symbols[$a]</k></head><def>";
					Debug("Added chunk ",($a+1)," to \$def together with \"</def></ar>\n<ar><head>$newhead$Symbols[$a]</k></head><def>\".");
			}
			$def .= $defs[$counter];
			
		}
		
		# Deletes the too long lines.
		my @def = split(/\n/,$def);
		my $def_line_counter = 0;
		 foreach my $line (@def){
		 	$def_line_counter++;
		 	if (length(encode('UTF-8', $line)) > 4096){
		 	# So I would like to cut the line at say 3500 chars not in the middle of a tag, so before a tag.
		 	# index STR,SUBSTR,POSITION
		 	my $cut_location = index $line, "<", 3500;
		 	if($cut_location == -1 or $cut_location > 4000){
		 		# Saw this with definition without tags a lot a greek characters. Word count <3500, bytes>7500.
		 		# New cut location is from half the line.
		 		$cut_location = index $line, "<", int(length($line)/2);
		 		# But sometimes there are no tags
		 		if($cut_location == -1 or $cut_location > 4000){ 
		 			$cut_location = index $line, ".", 3500;
		 			if($cut_location == -1 or $cut_location > 4000){ 
		 				$cut_location = index $line, ".", int(length($line)/2);
		 			}
		 		}


		 	}
		 	Debug("Definition line $def_line_counter is ",
		 		length($line),
		 		" characters and ",
		 		length(encode('UTF-8', $line)),
		 		" bytes. Cut location is $cut_location.");
		 	my $cutline_begin = substr($line, 0, $cut_location);
		 	my $cutline_end = substr($line, $cut_location);
		 	Debug ("Line taken to be cut:") and PrintYellow("$line\n") and 
		 	Debug("First part of the cut line is:") and PrintYellow("$cutline_begin\n") and
		 	Debug("Last part of the cut line is:") and PrintYellow("$cutline_end\n") and
		 	die if $cut_location > 4000;
		 	# splice array, offset, length, list
		 	splice @def, $def_line_counter, 0, ($cutline_end);
		 	$line = $cutline_begin;
		 	}
			
		 }
		 $def = join("\n",@def);
		# Debug($def);

		if($remove_color_tags){
			# Removes all color from lemma description. 
			# <c c="darkslategray"><c>Derived:</c></c> <c c="darkmagenta">
			$def =~ s~<\?c>~~gs;
			$def =~ s~<c c=[^>]+>~~gs;
		}
		
		# $def =~ s~</blockquote>~</blockquote>\n~gs;
		# $def =~ s~</?blockquote>~~gs;
		# $def =~ s~▸~~;
		# Debug("IAMHERE");
		$Content =~ s~\Q$def_old\E~$def~s;
	}
	else{Debug("Not well formed ar content!!\n$Content");}
	# @Content = split(/\n/, $Content);
	# foreach my $line(@Content){ 
	# 	if (length(encode('UTF-8', $line)) > 4096){
	# 		Debug("This line is ",length($_)," characters and ",length(encode('UTF-8', $_))," bytes:\n",$line); 
	# 		while( $line =~ s~(</?[^>]+>)(?!\n)~$1\n~s ){ PrintYellow("$1\n");}
	# 		PrintGreen($line);
	# 		die;
	# 	}
	# }
	# $Content =~ s~(</?[^>]+>)(?!\n)~$1\n~gs;
	# remove wav-files displaying
	# Example:
	# <rref>
	#z_epee_1_gb_2.wav</rref>
	$Content =~ s~<rref>((?!\.wav</rref>).)+\.wav</rref>~~gs;
	return( $Content );}
sub ConvertStardictXMLtoXDXF{
	my $StardictXML = join('',@_);
	my @xdxf = @xdxf_start;
	if( $StardictXML =~ m~<bookname>(?<bookname>((?!</book).)+)</bookname>~s ){
		substr($xdxf[2], 11, 0) = $+{bookname};
	}
	if( $StardictXML =~ m~<date>(?<date>((?!</date>).)+)</date>~s ){
		substr($xdxf[4], 6, 0) = $+{date};
	}
	PrintCyan("Converting stardict xml to xdxf xml. This will take some time.\n");
	# Initialize variables for collection
	my ($key, $def, $article, $definition) = ("","", 0, 0);
	# Initialize variables for testing
	my ($test_loop, $counter,$max_counter) = (0,0,40) ;
	foreach(@_){
		$counter++;
		# Change state to article
		if(m~<article>~){ $article = 1; Debug("Article start tag found at line $counter.") if $test_loop;}

		# Match key within article outside of definition
		if($article and !$definition and m~<key>(?<key>((?!</key>).)+)</key>~){ $key = $+{key}; Debug("Key \"$key\" found at line $counter.") if $test_loop;}
		# change state to definition
		if(m~<definition type="x">~){ $definition = 1; Debug("Definition start tag found at line $counter.") if $test_loop;}
		# Fails for multiline definitions such as:
			# <definition type="x">
			# <![CDATA[<k>&apos;Arry</k>
			# <b>&apos;Arry</b>
			# <blockquote><blockquote>(<c c="darkslategray">ˈærɪ</c>)</blockquote></blockquote>
			# <blockquote><blockquote><c c="gray">[The common Christian name <i>Harry</i> vulgarly pronounced without the aspirate.]</c></blockquote></blockquote>
			# <blockquote><blockquote>Used humorously for: A low-bred fellow (who ‘drops his <i>h&apos;</i>s’) of lively temper and manners. Hence <b>&apos;Arryish</b> <i>a.</i>, vulgarly jovial.</blockquote></blockquote>
			# <blockquote><blockquote><blockquote><blockquote><blockquote><blockquote><ex><b>1874</b> <i>Punch&apos;s Almanac</i>, <c c="darkmagenta">&apos;Arry on &apos;Orseback.</c> <b>1881</b> <i><abr>Sat.</abr> <abr>Rev.</abr></i> <abr>No.</abr> 1318. 148 <c c="darkmagenta">The local &apos;Arry has torn down the famous tapestries of the great hall.</c> <b>1880</b> W. Wallace in <i>Academy</i> 28 Feb. 156/1 <c c="darkmagenta">He has a fair stock of somewhat &apos;Arryish animal spirits, but no real humour.</c></ex></blockquote></blockquote></blockquote></blockquote></blockquote></blockquote>]]>
			# </definition>
		s~<definition type="x">~~;
		s~<\!\[CDATA\[~~;
		s~<k>\Q$key\E</k>~~;
		s~<b>\Q$key\E</b>~~;
		s~^[\n\s]+$~~;
		if($definition and m~(?<def>((?!\]\]>).)+)(\]\]>)?~s){ 
			my $fund = $+{def};
			$fund =~ s~</definition>\n?~~;
			$def .= $fund if $fund!~m~^[\n\s]+$~; 
			Debug("Added definition \"$fund\" at line $counter.") if $test_loop and $fund ne "" and $fund!~m~^[\n\s]+$~;
		}
		if(  m~</definition>~ ){ 
			$definition = 0; 
			Debug("Definition stop tag found at line $counter.") if $test_loop; 
		}
		if(  !$definition and $key ne "" and $def ne ""){
			Debug("Found key \'$key\' and definition \'$def\'") if $test_loop;
			push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";	
			($key, $def, $definition) = ("","",0);
		}
		# reset on end of article
		if(m~</article>~ ){ 
			($key, $def, $article) = ("","",0);  
			Debug("Article stop tag found at line $counter.\n") if $test_loop;
		}
		die if $counter==$max_counter and $test_loop;
	}

	# while( $StardictXML =~ s~<article>[\n\s]*<key>(?<key>((?!</key>).)+)</key>[\n\s]*<definition type="m">[\n\s]*<!\[CDATA\[(?<def>((?!\]\]>).)+)\]\]>[\n\s]*</definition>[\n\s]*</article>~~s){
	# 	# Debug("Found key \'$+{key}\' and definition \'$+{def}\'");
	# 	push @xdxf, "<ar><head><k>$+{key}</k></head><def>$+{def}</def></ar>\n";
	# }
	push @xdxf, $lastline_xdxf;
	return(@xdxf);}
sub ConvertCVStoXDXF{
	my @cvs = @_;
	my @xdxf = @xdxf_start;
	my $number= 0;
	foreach(@cvs){
		$number++;
		my $comma_is_at = index $_, ",", 0;
		my $key = substr $_, 0, $comma_is_at - 1;
		my $def = substr $_, $comma_is_at + 1;
		# Remove whitespaces at the beginning of the definition and EOL at the end.
		$def =~ s~^\s+~~;
		$def =~ s~\n$~~;
		# Debug("Key is:\n \'$key\'");
		# Debug("Definition is:\n \'$def\'");
		push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
		Debug("Pushed <ar><head><k>$key</k></head><def>$def</def></ar>") if $number<20;
	}
	push @xdxf, $lastline_xdxf;
	return(@xdxf);}

# Create the array @xdxf
my @xdxf;
## Load from xdxffile
if( $FileName =~ m~\.xdxf$~){@xdxf = FiletoArray($FileName);}
elsif( -e substr($FileName, 0, (length($FileName)-4)).".xdxf"){ 
	@xdxf = FiletoArray(substr($FileName, 0, (length($FileName)-4)).".xdxf") ;
	$FileName = substr($FileName, 0, (length($FileName)-4)).".xdxf";
}
## Load from ifo-, dict- and idx-files
elsif( $FileName =~ m~^(?<filename>((?!\.ifo).)+)\.ifo$~){ 
	# Check wheter a converted xml-file already exists or create one.
	if(! -e $+{filename}.".xml"){ 
		# Convert the ifo/dict using stardict-bin2text $FileName $FileName.".xml";
		system("stardict-bin2text \"$FileName\" \"$+{filename}.xml\"");
	}
	# Create an array from the stardict xml-dictionary.
	my @StardictXML = FiletoArray("$+{filename}.xml");
	@xdxf = ConvertStardictXMLtoXDXF(@StardictXML);
	# Write it to disk so it hasn't have to be done again.
	ArraytoFile($+{filename}.".xdxf", @xdxf);
	# Debug(@xdxf); # Check generated @xdxf
	$FileName=$+{filename}.".xdxf";
}
## Load from comma separated values cvs-file. 
## It is assumed that every line has a key followed by a comma followed by the definition.
elsif( $FileName =~ m~^(?<filename>((?!\.csv).)+)\.csv$~){ 
	my @cvs = FiletoArray($FileName);
	@xdxf = ConvertCVStoXDXF(@cvs);
	# Write it to disk so it hasn't have to be done again.
	ArraytoFile($+{filename}.".xdxf", @xdxf);
	Debug(@xdxf); # Check generated @xdxf
	$FileName=$+{filename}.".xdxf";
}
else{Debug("Not a known extension for the given filename. Quitting!");die;}

# Construct a new xdxf array to prevent converter.exe from crashing.
## Initial values
my @xdxf_constructed = ();
my $i = 0;
my ($Description, $Description_content) = ( 0 , "" );
my ($ar, $ar_content, $ar_count, $ar_dotprinter) = ( 0, "", 0);
my $xdxf_closing = "</xdxf>\n";
## Step through the array line by line.
foreach my $entry (@xdxf){
	$i++; 	
	# Handling of dxdf end tag
		if ( $entry =~ m~$xdxf_closing~ or $i_limit < $i or ($ar_count == ($ar_chosen + 1) and $no_test == 0) ){
			push @xdxf_constructed, $xdxf_closing;
			last;
		}
		
	# Check whether every line ends with an EOL. 
	# The criterion has rather diminished through the building of the script.
	if($entry =~ m~^.*\n$~s){
		# PrintYellow($entry);
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
			PrintMagenta("<xdxf ".$xdxf.">\n");
			push @xdxf_constructed, "<xdxf ".$xdxf.">\n";
			next;
		}
		# Handling of full_name tag
		if ( $entry =~ m~^<full_name>~){
			if ( $entry !~ m~^<full_name>.*</full_name>\n$~){ Debug("full_name tag is not on one line. Investigate!\n"); die if $isRealDead;}
			elsif( $reformat_full_name and $entry =~ m~^<full_name>(.*)</full_name>\n$~ ){ 
				my $full_name = $1;
				print("Full_name is \"$1\".\nWould you like to change it? (press enter to keep default \[$1\] ");
				my $one = <STDIN>; chomp $one; if( $one ne ""){ $full_name = $one ; };
				
			}
		}
		# Handling of Description
		if ( $entry =~ m~^(?<des><description>)~){  push @xdxf_constructed, $+{des}."\n"; $Description = 1;} #Start of description block
		if($Description){
			if( $entry =~ m~^(?<des><description>)?(?<cont>((?!</desc).)*)(?<closetag></description>)?\n$~ ){
				
				#DebugFindings();
				#Debug("?<des> is $+{des}\n?<cont> is $+{cont}\n?<closetag> is $+{closetag}\n");
				$Description_content .= $+{cont} ; # Debug($Description_content);
				
				if( $+{closetag} eq "</description>"){ 
					# Debug("Matched description closing tag!\n"); 
					chomp $Description_content; 
					push @xdxf_constructed, $Description_content."\n".$+{closetag}."\n"; 
					$Description = 0;
				}

				# print("Regex working!\n"); 
			}
			next;
		}
		# Handling of an ar-tag
		if ( $entry =~ m~^(?<ar><ar>)~){  #Start of ar block
			$ar_count++; $ar_dotprinter++; if( $ar_dotprinter == $ar_per_dot){ PrintGreen("."); $ar_dotprinter=0;}

			push @xdxf_constructed, $+{ar}."\n"  if ( $no_test or $ar_count==$ar_chosen); 
			$ar = 1;
		}
		if( $ar ){
			if( $entry =~ m~^(?<ar><ar>)?(?<cont>((?!</ar).)*)(?<closetag></ar>)?\n$~ ){
				# DebugFindings();
				# Debug("?<ar> is $+{ar}\n?<cont> is $+{cont}\n?<closetag> is $+{closetag}\n");
				$ar_content .= $+{cont} ; # Debug($ar_content);

				if( $+{closetag} eq "</ar>"){ 
					# Debug("Matched ar closing tag!\n"); 
					my $cleansedcontent = CleanseAr($ar_content); 
					push @xdxf_constructed, $cleansedcontent."\n".$+{closetag}."\n" if ($no_test or $ar_count==$ar_chosen); 
					$ar = 0; 
					$ar_content = "";	
				}
			}
			next;
		}

		push @xdxf_constructed, $entry;
		next;
	}
	else{ 	Debug("Line without a EOL: $i");
			Debug("[",$i-3,"]: ",$xdxf[$i-3]);
			Debug("[",$i-2,"]: ",$xdxf[$i-2]);
			Debug("[",$i-1,"]: ",$xdxf[$i-1]);
			Debug("[",$i,"]: ",$xdxf[$i]);
			Debug("[",$i+1,"]: ",$xdxf[$i+1]);
			die if $isRealDead; }
}

PrintMagenta("Total number of lines processed \$i = ",$i,".\n");
PrintMagenta("Total number of ar processed \$ar = ",$ar,".\n");

my $dict_xdxf=$FileName;
$dict_xdxf =~ s~\.xdxf~_reconstructed\.xdxf~;
ArraytoFile($dict_xdxf, @xdxf_constructed);
my $ConvertCommand = "WINEDEBUG=-all wine converter.exe \"$dict_xdxf\" $lang_from";
Debug($ConvertCommand);
system($ConvertCommand);
