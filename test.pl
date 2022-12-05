#!/bin/perl
use strict;
use utf8;
use open IO => ':utf8';
use open ':std', ':utf8';
use feature 'unicode_strings'; # You get funky results with the sub convertNumberedSequencesToChar without this.
use lib "./";

use DicGlobals;
use Dic2Screen;
use DicHelpUtils;
use DicFileUtils;
use DicConversion;
use DicPrepare;
use DicControls;

$FileName = "dict/Grande\ Larousse\ 1989/Grand\ Larousse.pp1-100.formatted-text.noHeaderFooters.NoPictures.NoHyphenLineBreaks.htm";
$FileName = "dict/Grande\ Larousse\ 1989/Grand\ Larousse.pp1-884.formatted-text.noHeaderFooters.NoPictures.NoHyphenLineBreaks.htm";
$FileName = "dict/Grande\ Larousse\ 1989/Grand\ Larousse.pp1-6529.formatted-text.noHeaderFooters.NoPictures.NoHyphenLineBreaks.htm";
$FileName = "dict/Grande\ Larousse\ 1989/Grand\ Larousse.pp1-6529.formatted-text.noHeaderFooters.NoPictures.NoHyphenLineBreaks.htm";
updateLocalPath();
updateFullPath();
chdir $BaseDir;


my $FileListingIndex = 20;
# Start array on a line ...9, so that the index of the array follows the line numbers.
if( ( __LINE__ % 10   ) != 8 ){ warn "\@FileListing doesn't start on line ending with 9!"; }
my @FileListing = (
    'Grand Larousse.p1.flexible-layout.HFPicTBgrdHphLB.htm',
    'Grand Larousse.p1.flexible-layout.HphLB.htm',
    'Grand Larousse.p1.flexible-layout.PicTBgrdHphLB.htm',
    'Grand Larousse.p1.flexible-layout.TBgrdHphLB.htm',
    'Grand Larousse.p1.formatted-text.HFPicHphLB.htm',
    'Grand Larousse.p1.formatted-text.HFPicTBgrdHphLB.htm',
    'Grand Larousse.p1.formatted-text.HphLB.htm',
    'Grand Larousse.p1.formatted-text.PicTBgrdHphLB.htm',
    'Grand Larousse.p1.plain-text.HFHphLB.htm',
    'Grand Larousse.p1.plain-text.HFPicHphLB.htm',
    'Grand Larousse.p1.plain-text.HphLB.htm',
    'Grand Larousse.p6237.flexible-layout.ColorHphLB.htm',
    'Grand Larousse.p6237.flexible-layout.HFPicColorHphLB.htm',
    'Grand Larousse.p6237.formatted-text.ColorsHphLB.htm',
    'Grand Larousse.p6237.formatted-text.HFPicTBgrdHphLB.htm',
    'Grand Larousse.pp1-100.flexible-layout.htm',
    'Grand Larousse.pp1-100.formatted-text.htm',
    'Grand Larousse.pp1-100s.htm',
    'Grand Larousse.pp1-6529.formatted-text.NoPictures.htm',
    'Grand Larousse.avoir.formatted-text.NoPictures.htm',
    'Grand Larousse.pp1-6529.formatted-text.NoPicture_reconstructed.xdxf',
);
$FileName = $LocalPath.$FileListing[ $FileListingIndex ];
info("Testing file '$FileName'");
my $isInspectPullParser = 0;
my $isInspectTreeBuilder = 0;
my $isTestConvertABBYY2XDXF = 0;
my $isTestTables4Koreader = 1;
if ( $isTestingOn ){ use warnings; }
my $OperatingSystem = "$^O";
if ($OperatingSystem eq "linux"){ print "Operating system is $OperatingSystem: All good to go!\n";}
else{ print "Operating system is $OperatingSystem: Not linux, so I am assuming Windows!\n";}

use charnames ();
sub debug5{
    my $counter = 0;
    my $Replace = 0;
    foreach(@_){ if( m~^HTML|^REF|^SCALAR|^ARRAY~ ){ $Replace = 1; } }
    foreach(@_){
    $counter++;
    next if $_ eq undef or $_ eq '';
    if( m~^\s+$~){ $_ = "\~\^\\s+\$\~";}
    if( $_ eq '  '){$_ = "two spaces";}
    if( $Replace and $_ !~ m~^HTML|^REF|^SCALAR|^ARRAY~ ){
        my $replacement= "'".charnames::viacode(ord($_) )."'";
        s~^.~~;
        while($_){
                $replacement .= " '" .charnames::viacode(ord($_) )."'";
                s~^.~~;
        }
        $_= $replacement;
    }
    debug( "$counter: '".$_."'" );
    last if $counter == 5;
    }
}
sub derefdebug5{
    my @deref;
    foreach(@_){ next if $_ eq undef; push @deref, ${$_}; }
    debug5(@deref);
}

use Class::Inspector;
my $counter = 0;
if( $isInspectPullParser ){
    info("Now testing HTML::PullParser");
    my $methods_pullparser =   Class::Inspector->methods( 'HTML::PullParser', 'full', 'public' );
    debug("\$methods_pullparser: $methods_pullparser");
    foreach( @{$methods_pullparser}){ debug($_);}

    use HTML::PullParser;

    my $p = HTML::PullParser->new(file => $FileName,
                                start => 'event, tagname, @attr',
                                end   => 'event, tagname',
                                ignore_elements => [qw(script style)],
                               ) || die "Can't open: $!";
     while (my $token = $p->get_token) {
         #...do something with $token
         $counter++;
        debug( "$counter: $token" );
        debug5( @{$token} );
        # debug( ${$$token});
        print "_" x 80; print "\n";
        last if $counter == 35;
     }
    info("HTTP:PullParser doesn't allow for getting a whole tag-block encapsulating the inner tag-blocks.");
}
if( $isInspectTreeBuilder ){
    info("Now testing HTTP:TreeBuilder");
    my $methods_treebuilder =   Class::Inspector->methods( 'HTML::TreeBuilder', 'full', 'public' );
    my $methods_element =   Class::Inspector->methods( 'HTML::Element', 'full', 'public' );
    debug("\$methods_treebuilder: $methods_treebuilder");
    foreach( @{$methods_treebuilder}){ debug($_);}
    debug("\@methods_element: $methods_element");
    foreach( @{$methods_element}){ debug($_);}
}
if( $isTestConvertABBYY2XDXF ){
    info("Loading dictionary '$FileName'");
    my $html = join('', file2Array($BaseDir ."/". $FileName));
    my @xdxf = removeBloatFromArray( convertABBYY2XDXF( $html ) );

    my $XDXF_name = changeFileExtension( $FileName, "xdxf");
    array2File( $BaseDir ."/". $XDXF_name, @xdxf );
    my @xml = convertXDXFtoStardictXML( @xdxf );
    my $XML_name = changeFileExtension( $FileName, "xml");
    array2File( $BaseDir ."/". $XML_name, @xml);
    convertXML2Binary( $XML_name );
}
if( $isTestTables4Koreader ){
    my $xdxf = file2String( $FileName );
    my $regex = qr~<ar>((?!(</?ar>|<table[^>]*>)).)+</ar>\s*~s;
    $xdxf =~ s~$regex~~sg;
    my @count = $xdxf =~ m~<ar>((?:(?!</?ar>).)+)</ar>\s*~sg;
    debug(scalar @count);
    my $count = 0;
    my %results;
    foreach(@count){
        $count++;
        m~<k>([^<]+)</k>~s;
        my $key = $1;
        $results{ $key }{"length"} = length($_);
        $results{ $key }{"content"} = $_;
        $results{ $key }{"count"} = $count;
        debug("[$count] '$key' (".$results{ $key }{"length"}.")");
    }
    my $minimum = 99999999999;
    foreach( sort keys %results){
        if ($results{$_}{"length"} < $minimum){ $results{"minimum"} = $_; $minimum = $results{$_}{"length"}; }
    }
    debug("The key with the minimum length of ".$results{ $results{"minimum"} }{"length"}." is '".$results{"minimum"}."'");
    array2File( $LocalPath.'table_test.xdxf', ( $xdxf ) );
}