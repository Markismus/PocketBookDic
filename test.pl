#!/bin/perl
use strict;
use utf8;
use HTML::TreeBuilder 5 -weak; # Ensure weak references in use
use Term::ANSIColor;    #Color display on terminal
use open ":std", ":encoding(UTF-8)";
my $isDebug = 1; # Toggles all debug messages
my $isDebugVerbose = 1; # Toggles all verbose debug messages
my $isDebugVeryVerbose = 1; # Toggles all verbose debug messages
my ( $isInfo, $isInfoVerbose, $isInfoVeryVerbose ) = ( 1, 1 ,1 );  # Toggles info messages
my $BaseDir="/home/mark/Downloads/PocketbookDic";
my $isTestingOn = 1; # Toggles intermediary output of xdxf-array.
updateLocalPath();
updateFullPath();
chdir $BaseDir;

if ( $isTestingOn ){ use warnings; }
my $OperatingSystem = "$^O";
if ($OperatingSystem eq "linux"){ print "Operating system is $OperatingSystem: All good to go!\n";}
else{ print "Operating system is $OperatingSystem: Not linux, so I am assuming Windows!\n";}
sub info{   printCyan( join('',@_)."\n" ) if $isInfo;                   }
sub info_t{ printCyan( join('',@_)."\n" ) if $isInfo and $isTestingOn;  }
sub infoV{  printCyan( join('',@_)."\n" ) if $isInfoVerbose;            }
sub infoVV{ printCyan( join('',@_)."\n" ) if $isInfoVeryVerbose;        }
sub printBlue    { print color('blue') if $OperatingSystem eq "linux";    print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printCyan    { print color('cyan') if $OperatingSystem eq "linux";    print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printGreen   { print color('green') if $OperatingSystem eq "linux";   print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printMagenta { print color('magenta') if $OperatingSystem eq "linux"; print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printRed     { print color('red') if $OperatingSystem eq "linux";     print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub printYellow  { print color('yellow') if $OperatingSystem eq "linux";  print @_; print color('reset') if $OperatingSystem eq "linux"; }
sub array2File {
    my ( $FileName, @Array ) = @_;
    if( $FileName =~ m~(?<dir>.*)/(?<file>[^/]+)~ ){
        my $dir = $+{dir};
        my $file = $+{file};
        unless( -r $dir){
            warn "Can't read '$dir'";
            $dir =~ s~ ~\\ ~g;
            unless( -r $dir ){ warn "Can't read '$dir' with escaped spaces."; }
        }
        unless( -w $dir){ warn "Can't write '$dir'"; }
    }
    debugV("Array to be written:\n",@Array);
    if( -e $FileName){ warn "$FileName already exist" if $isDebugVerbose; };
    unless( open( FILE, ">:encoding(utf8)", $FileName ) ){
      warn "Cannot open $FileName: $!\n";
      Die() ;
    }
    print FILE @Array;
    close(FILE);
    $FileName =~ s/.+\/(.+)/$1/;
    printGreen("Written $FileName. Exiting sub array2File\n") if $isDebugVerbose;
    return ("File written");}
sub debug { $isDebug and printRed( @_, "\n" ); return(1);}
sub debug_t { $isDebug and $isTestingOn and printRed( @_, "\n" ); return(1);}
sub debugV { $isDebugVerbose and printBlue( @_, "\n" ); return(1);}
sub debugVV { $isDebugVeryVerbose and printBlue( @_, "\n" ); return(1);}
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
sub file2Array{
    #This subroutine expects a path-and-filename in one and returns an array
    my $FileName = $_[0];
    my $encoding = $_[1];
    my $verbosity = $_[2];
    # Read the raw bytes
    local $/;
    unless( -e $FileName ){
        warn "'$FileName' doesn't exist.";
        if( $FileName =~ m~(?<dir>.*)/(?<file>[^/]+)~ ){
            my $dir = $+{dir};
            my $file = $+{file};
            if( -e $dir ){
                unless( -r $dir){
                    warn "Can't read '$dir'";
                    $dir =~ s~ ~\\ ~g;
                    unless( -r $dir ){ warn "Can't read '$dir' with escaped spaces."; }
                }
                unless( -w $dir){ warn "Can't write '$dir'"; }
            }
            elsif( $dir =~ s~ ~\\ ~g and -e $dir){
                warn "Found '$dir' after escaping spaces";
            }
            elsif( -e "$BaseDir/$dir"){
                warn "Found $BaseDir/$dir. Prefixing '$BaseDir'.";
                $dir = "$BaseDir/$dir";
            }
            else{
                warn "'$dir' doesn't exist";
                my @commands = (
                    "pwd",
                    "ls -larth $dir",
                    "ls -larth $BaseDir/$dir");
                foreach(@commands){
                    print "\$ $_\n";
                    system("$_");
                }
                Die();
            }
        }

        if( -e "BaseDir/$FileName"){
            warn "Changing it to BaseDir/$FileName";
            $FileName = "BaseDir/$FileName";
        }
        elsif( $FileName =~ s~ ~\\ ~g and -e $FileName ){
            warn "Escaped spaces to find filename";
        }
    }
    else{ debugVV( "$FileName exists."); }
    open (my $fh, '<:raw', "$FileName") or (warn "Couldn't open $FileName: $!" and Die() and return undef() );
    my $raw = <$fh>;
    close($fh);
    if($encoding eq "raw"){
        printBlue("Read $FileName (raw), returning array. Exiting file2Array\n") if (defined $verbosity and $verbosity ne "quiet");
        return( split(/^/, $raw) );
    }
    elsif( defined $encoding ){
        printBlue("Read $FileName ($encoding), returning array. Exiting file2Array\n") if (defined $verbosity and $verbosity ne "quiet");
        return(split(/^/, decode( $encoding, $raw ) ) );
    }

    my $content;
    # Try to interpret the content as UTF-8
    eval { my $text = decode('utf-8', $raw, Encode::FB_CROAK); $content = $text };
    # If this failed, interpret as windows-1252 (a superset of iso-8859-1 and ascii)
    if (!$content) {
        eval { my $text = decode('windows-1252', $raw, Encode::FB_CROAK); $content = $text };
    }
    # If this failed, give up and use the raw bytes
    if (!$content) {
        $content = $raw;
    }
    my @ReturnArray = split(/^/, $content);
    printBlue("Read $FileName, returning array of size ".@ReturnArray.". Exiting file2Array\n") if (defined $verbosity and $verbosity ne "quiet");

    return @ReturnArray;}
print "x" x 80; print"\n";
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

my $file_name = "/home/mark/Downloads/PocketbookDic/"."dict/Grande\ Larousse\ 1989/Grand\ Larousse.pp1-100.formatted-text.noHeaderFooters.NoPictures.NoHyphenLineBreaks.htm";
my $file_name = "/home/mark/Downloads/PocketbookDic/"."dict/Grande\ Larousse\ 1989/Grand\ Larousse.pp1-884.formatted-text.noHeaderFooters.NoPictures.NoHyphenLineBreaks.htm";
my $file_name = "/home/mark/Downloads/PocketbookDic/"."dict/Grande\ Larousse\ 1989/Grand\ Larousse.pp1-6529.formatted-text.noHeaderFooters.NoPictures.NoHyphenLineBreaks.htm";
use Class::Inspector;
my $counter = 0;
if(0){
    info("Now testing HTML::PullParser");
    my $methods_pullparser =   Class::Inspector->methods( 'HTML::PullParser', 'full', 'public' );
    debug("\$methods_pullparser: $methods_pullparser");
    foreach( @{$methods_pullparser}){ debug($_);}

    use HTML::PullParser;

    my $p = HTML::PullParser->new(file => $file_name,
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
info("Now testing HTTP:TreeBuilder");
if( 0 ){
    my $methods_treebuilder =   Class::Inspector->methods( 'HTML::TreeBuilder', 'full', 'public' );
    my $methods_element =   Class::Inspector->methods( 'HTML::Element', 'full', 'public' );
    debug("\$methods_treebuilder: $methods_treebuilder");
    foreach( @{$methods_treebuilder}){ debug($_);}
    debug("\@methods_element: $methods_element");
    foreach( @{$methods_element}){ debug($_);}
}

info("Loading dictionary '$file_name'");
my $html = join('', file2Array($file_name));
info("Start parsing dictionary '$file_name'");
my $tree = HTML::TreeBuilder->new; # empty tree
if( -e $file_name.'.tree' ){
    $tree = retrieve ( $file_name.'.tree' );
    info( "Retrieved tree from '".$file_name.".tree'"); }
else{ $tree->parse($html); }
store( $tree, $file_name.'.tree' );
info("End parsing");

# $tree->dump; # a method we inherit from HTML::Element
# print "And here it is, bizarrely rerendered as HTML:\n",
# $tree->as_HTML, "\n";
# debug( Dumper($tree));
# Now that we're done with it, we must destroy it.
# $tree = $tree->delete; # Not required with weak references
# my $nodes = $tree->guts();
# my $parent_for_nodes = $tree->guts();
# debug( "\$nodes: ", $nodes );
# debug( "parent_for_nodes: ". $parent_for_nodes );
# debug( "content_list: ". $tree->content_list );
# debug( "tag: ".$tree->tag );

info("Starting look_down for body-tag");
my $body = $tree->look_down('_tag', 'body');
info("Found body-tag");
if(0){
    debug( "\$body: ".$body); # Classed as HTML::Element
    debugV( "tag: ".$body->tag );
    debugV( "starttag: ".$body->starttag );
    debugV( "starttag_XML: ".$body->starttag_XML );
    debug( "content: ". $body->content);
    debug( "content_array_ref: ". $body->content_array_ref);
    debug( "content_list: ". $body->content_list);

    debug5( ($body->content_list) );
    debug( "content_refs_list: ". $body->content_refs_list);
    # my @nodes = $body->guts();
    # my $parent_for_nodes = $body->guts();
    # debug( "\@nodes: ", @nodes );
    # debug( "parent_for_nodes: ". $parent_for_nodes );
    print "x" x 80; print"\n";
    debug( "\@{\$body->content_refs_list}");
    debug5(( $body->content_refs_list) );
    debug( "dereferenced \@{\$body->content_refs_list}");
    derefdebug5(( $body->content_refs_list) );
    print "x" x 80; print"\n";
}










$counter = 0;
my(@articles, $article, @ImpossibleKeywords, %ImpossibleKeywords);
my $separator = "|~-_-~|";
my @FailingExtraForms;
sub checkExtraForms{
    my $PossibleKey = shift;
    if( $PossibleKey =~ m~,~){
        $PossibleKey = $`;
        my $ExtraForm = cleanKey($');
        my @ExtraForms = split(/,/, $ExtraForm);
        pushArticle();
        foreach my $Form( @ExtraForms){
            $Form = cleanKey( $Form );
            $Form =~ s~^-~~;
            $Form =~ s~ ~~;
            $Form =~ s~\s*\[~~;
            # Sometimes the given key is a sentence.
            my $Key = $PossibleKey;
            my @Key = split(/ /, $Key);
            $Key = $Key[-1];
            if( $Form =~ m~(?<MaleEnd>\w+)(?<FormEnd>e)$~){
                my $MaleEnd = $+{"MaleEnd"};
                my $FormEnd = $+{"FormEnd"};
                if( $Key =~ m~$MaleEnd$~ ){ $Form = $FormEnd; }
            }
            if( $Form eq 'e' or
                $Form eq 'ë' or
                0 ){
                 pushReferenceArticle( $PossibleKey.$Form, $PossibleKey );
            }
            elsif(
                $Form eq 'es' or
                $Form eq 'gue' or
                $Form =~ m~^(e|i)sse$~ or
                $Form eq 'uë' or
                $Form eq 'ite' or
                $Form eq 'ote' or
                $Form eq 'a' or
                0 ){
                 pushReferenceArticle( substr($PossibleKey, 0,( length($PossibleKey) - 1 )) .$Form, $PossibleKey );
            }
            elsif(
                $Form eq 'aux' or
                $Form eq 'ère' or
                $Form eq 'als' or
                $Form eq 'aque' or
                $Form eq 'ouse' or
                $Form eq 'igné' or
                $Form eq 'use' or
                $Form eq 'ca' or
                $Form eq 'ique' or
                $Form =~ m~(î|i|ï)(v|n)e~ or
                $Form =~ m~^(e|o|i|a)(tt|ll|nn)e$~ or
                $Form =~ m~(è|e|é)t(è|e|é)~ or
                $Form eq 'ées' or
                $Form eq 'aude' or
                0 ){
                 pushReferenceArticle( substr($PossibleKey, 0,( length($PossibleKey) - 2 )) .$Form, $PossibleKey );
            }
            elsif(
                $Form eq 'eu se' or
                $Form eq 'euse' or
                $Form eq 'eresse' or
                $Form eq 'elles' or
                $Form eq 'ante' or
                $Form eq "ienne" or
                $Form eq "ière" or
                $Form eq "eille" or
                $Form eq "oute" or
                0 ){
                pushReferenceArticle( substr($PossibleKey, 0,( length($PossibleKey) - 3 )) .$Form, $PossibleKey );
            }
            elsif(
                $Form eq "douce" or
                $Form =~ m~tr(î|i)ce~ or
                $Form eq "turque" or
                $Form eq "grecque" or
                0 ){
                pushReferenceArticle( substr($PossibleKey, 0,( length($PossibleKey) - 4 )) .$Form, $PossibleKey );
            }
            elsif( $Form =~ m~^\Q$Key\E~ or $Key =~ m~^\Q$Form\E~ ){
                # E.g. adonc, adoncques
                pushReferenceArticle( $Form, $PossibleKey );
            }
            elsif(
                substr($Form,-3, 3) eq substr($Key, -3, 3) or
                substr($Form, 0, 2) eq substr($Key, 0, 2)
                ){
                # E.g. aiche, èche
                pushReferenceArticle( $Form, $PossibleKey );
            }
            elsif(
                $Form !~ m~^\Q$Key\E~ and
                substr($Form,-3, 3) ne substr($Key, -3, 3) and
                length($Form) > length($Key)
                ){
                # Treating it as an unknown plural. E.g auquel, auxquels, auxquelles
                pushReferenceArticle( $Form, $PossibleKey );
            }
            elsif( length($Form) == length($Key) ){
                # E.g. lez, lès
                pushReferenceArticle( $Form, $PossibleKey );
            }
            else{
                push @FailingExtraForms, $PossibleKey."____".$Form;
                debug(length($Form));
                warn "Not a known variant of form from '$PossibleKey': '$Form'.";
                debug("last 3 letters of '$PossibleKey': ". substr($PossibleKey, -3, 3) );
                debug("last 3 letters of '$Form': ". substr($Form, -3, 3) );
            }
        }
    }
    return $PossibleKey;
}
sub cleanKey{
    my $Key = shift;
    $Key =~ s~\<br\/\>~~g;
    $Key =~ s~♦~~g;
    $Key =~ s~\([^)]*\)?~~g;
    $Key =~ s~\[[^\]]*\]~~g;
    $Key =~ s~\]\s*$~~g;
    $Key =~ s~\)$~~g;
    $Key =~ s~^\+~~;
    $Key =~ s~^\d~~;
    $Key =~ s~^\.~~;
    $Key =~ s~\s+$~~g;
    $Key =~ s~^\s+~~g;
    $Key =~ s~,+$~~g;

    return $Key;
}
my %PauseFor;
my @PauseFor = (
    'par-dessus',
    'métempsycose',
    'par-derrière, par-dessous',
    'octi-',
    'pharyng-',
    'T. O.',
    );
foreach( @PauseFor ){ $PauseFor{ $_ } =  1; }

my $Pre = '! |\(|\([^)]+\)(\.|,)? |\? ';
my @AllowedFollowers = (
    '^<span[^>]*>('.$Pre.')?\[',
    '^<span[^>]*>\(devant',
    '^<span[^>]*>\(Acad',
    '^<span[^>]*>n\. ?(m|f|V)?\.?',
    '^<span[^>]*>\(marque déposée\)',
    '^<span[^>]*>('.$Pre.')?adj\.',
    '^<span[^>]*>v\. (pr|(in)?tr)\.',
    '^<span[^>]*>('.$Pre.')?adv\.( V\.)?',
    '^<span[^>]*>('.$Pre.')?loc\. (adv|prép|conj|lat|adj)(\.|,)',
    '^<span[^>]*>('.$Pre.')?préf\.',
    '^<span[^>]*>('.$Pre.')?conj\.',
    'pers. sing. de',
    '^<span[^>]*>('.$Pre.')?pron\. (dém|interr)\.',
    '^<span[^>]*>('.$Pre.')?((A|a)brév\.|Abréviation|(S|s)igle|symbole)',
    '^<span[^>]*>('.$Pre.')?interj\.',
    '^<span[^>]*>pr\. rei\. V\.',
    '^<span[^>]*>éléments? tirés? du',
    '^<span[^>]*>((m|f)\. )?V\.',
    '^\d\. Premier élément',
    '^premiers? éléments?',
    '^<span[^>]*>v. impers,',
    '^<span[^>]*>part, passé\.',
    '^<span[^>]*>\(rarem.',
    );
my $AllowedFollowersRegex = shift @AllowedFollowers;
foreach(@AllowedFollowers){ $AllowedFollowersRegex .= "|".$_; }
my $AllowedFollowersPlainTextRegex = $AllowedFollowersRegex;
$AllowedFollowersPlainTextRegex =~ s~<span\[\^>\]\*>~~sg;

sub followsKeyword{
    # Returns value of criterium
    # Is given een HTML::ELement containing a span-block
    my $content = shift;
    infoVV("followsKeyword is given '$content'") if 0;
    unless( $content =~ m~^HTML::Element=HASH~ ){ return 0; }
    return ( $content->tag eq "span" and $content->as_HTML('<>&') =~ m~$AllowedFollowersRegex~ );
}
sub followsKeywordinPlainText{
    # Returns value of criterium
    # Is given a contents-range of HTML::Element
    my $content;
    foreach( @_ ){
        unless( m~^HTML::Element=HASH~ ){ return 0; }
        $content .= $_->as_text;
    }
    return ( $content !~ m~^HTML::Element=HASH~ and $content =~ m~$AllowedFollowersPlainTextRegex~ );
}
sub moreKeywords{
    my $content = shift;
    return(
        $content =~ m~^HTML::Element~ and
        $content->tag eq "span" and
        (
            $content->as_HTML('<>&') =~ m~<span[^>]*>($Pre)?ou~ or
            $content->as_HTML('<>&') =~ m~<span[^>]*>($Pre)?plur\.~ or
            $content->as_HTML('<>&') =~ m~<span[^>]*>($Pre)?anc\.~
        )
    );
}
sub pushArticle{ if( defined $article ){ push @articles, $article."\n"; $article = undef; } }
sub pushReferenceArticle{
    my $article = shift;
    my $referent = shift;
    infoV("Pushing referencing article '$article'");
    push @articles, $article. $separator . $referent . "\n";
}

TAGBLOCK: foreach my $TagBlock ( ($body->content_list) ){
    $counter++;
    # last if $counter > 50;
    if( $TagBlock =~ m~^HTML::Element~ ){
        debug( "[$counter] tag: '".$TagBlock->tag."'");
        if( $TagBlock->tag eq 'p'){
            my @content = $TagBlock->content_list();
            if( scalar @content == 0){ infoVV("No content.Skipping."); next TAGBLOCK;}
            unless( $content[0] =~ m~^HTML::Element=HASH~ ){
                if( $content[0] !~ m~<|>~ ){
                    # Plain text. An p-subblock appears unencapsulated
                    infoVV("Found plain text. Adding whole p-block to article.");
                    $article .= $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                    next TAGBLOCK;
                }
                else{ warn "Unknown p-block."; die; }
            }
            my $Html = $content[0]->as_HTML('<>&');
            debug( "'$Html'");

            if( scalar @content == 1){
                if( $content[0]->tag eq "span" and
                    $Html =~ m~<span[^>]*>\w</span>~){
                    # Chapter title, e.g. A.
                    # Finish previous article?
                    infoVV("Found chapter title. Skipping.");
                    pushArticle();
                    next TAGBLOCK;
                }
                if( $content[0]->tag eq "span" and
                    (
                        $Html =~ m~style="font-weight:bold;"~ or
                        (
                            $Html =~ m~font-style:italic;"~ and
                            $Html =~ m~<span[^>]*>[’,'.\?\!\-()[\] «»\p{Uppercase}]+</span>~
                        ) or
                        $html =~ m~font-variant:small-caps;~
                    )
                    ){
                    # Single entry in @contents. Probably a title in an article
                    infoVV("Found a title. Adding to article.");
                    $article .= $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                    next TAGBLOCK;
                }
                if( $content[0]->tag eq "span" and
                    (
                        $Html !~ m~style="~ or
                        (
                            (
                                $Html =~ m~font-style:italic;"~ and
                                $Html =~ m~<span[^>]*>\p{Uppercase}[’,'.\?\!\-()[\] «»\p{Lower}\p{Uppercase}]+</span>~
                            ) or
                            $Html =~ m~style="font-style:italic;"~ or
                            (
                                $Html =~ m~style="font-weight:bold;~ and
                                $Html =~ m~<span[^>]*>[’,'.\?\!\-()[\] «»\p{Lower}]+</span>~
                            )
                        )

                    )
                        ){
                    # Simple p-block, just add it to article.
                    infoVV("Found a simple p-block. Adding to article.");
                    $article .= $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                    next TAGBLOCK;
                }
                if( $content[0]->tag eq "a"){
                    # Bookmark
                    infoVV("Found a bookmark a-block. Adding to article.");
                    $article .= $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                    next TAGBLOCK;
                }
                # Unknown instance
                warn "One content entry: No clue";
                die;
            }
            if( scalar @content > 1 ){
                if( $content[0]->tag eq "span" and
                $Html =~ m~style="font-weight:bold;"~ and
                $Html =~ m~<span[^>]*>(?<key>((?!</?span>).)+)</span>~ ){
                    my $PossibleKey = cleanKey( $+{"key"} );
                    my $CorrectMissingBracket = 0;
                    my $temp = undef;
                    my $SecondKey = undef;
                    my $ThirdKey = undef;
                    if( $content[1] =~ m~^HTML::Element~ and
                        (
                            followsKeyword( $content[1] ) or
                            followsKeywordinPlainText( @content[1..$#content] ) or
                            # Bracket appears in the same span as keyword
                            $PossibleKey =~ s~\s*\[$\s*~~ or
                            # Missing left bracket in text
                            (
                                $content[1]->as_HTML('<>&') =~ m~^<span[^>]*>(\w+\]|\w+, -\w+\])~ and
                                $CorrectMissingBracket = 1
                            ) or
                            # Categorization appears in the same span as keyword
                            (
                                $PossibleKey =~ s~\s+((n|V|adj)\.\s*)$~~ and
                                $temp = $1 . $content[1]->as_text and
                                $temp =~ m~^($AllowedFollowersPlainTextRegex)~
                            )
                        )
                        ){
                        # Key followed by bracket fullfills criterium
                        pushArticle();
                        # Check for extra forms
                        infoVV("Found start of new article with key '$PossibleKey'.");
                        my $TBaHtml = $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                        if( $CorrectMissingBracket ){
                            unless ( $TBaHtml =~ s~^(?<start><p><span[^>]*>((?!</?span>).)+</span><span[^>]*>)(?<end>\w+\]|\w+, -\w+\])~$+{"start"}\[$+{"end"}~s ){
                                warn "Regex didn't work for '$TBaHtml'";
                                die;
                            }
                        }
                        $PossibleKey = checkExtraForms( $PossibleKey );
                        $article = $PossibleKey. $separator . $TBaHtml;
                        next TAGBLOCK;
                    }
                    # Two keys separated by ou
                    # E.g. <p><span class="font2" style="font-weight:bold;">abadir </span><span class="font11">ou </span><span class="font2" style="font-weight:bold;">abbadir </span><span class="font11">[abadir] n. m. (origine<br>inconnue ; 1690, Furetière). Nom donné à<br>une pierre sacrée chez les Phéniciens et<br>considérée comme venant du ciel : </span>
                    # E.g. <p><span class="font2" style="font-weight:bold;">aïeul, e, </span><span class="font11">plur. </span><span class="font2" style="font-weight:bold;">aïeuls, es </span><span class="font11">[ajœl] n. (lat.<br>pop. </span><span class="font11" style="font-style:italic;">*aviolus,</span><span class="font11"> dimin. du lat. class. </span>
                    elsif(
                        $content[1] =~ m~^HTML::Element~ and
                        $content[2] =~ m~^HTML::Element~ and
                        moreKeywords( $content[1] ) and
                        (
                            (
                                $content[2]->as_HTML('<>&') =~ m~<span[^>]*>(?<keysecond>((?!</?span>).)+)</span>~ and
                                $temp = $+{keysecond} and
                                $temp =~ m~\s*\[\s*$~
                            ) or
                            (
                                $content[3] =~ m~^HTML::Element~ and
                                (
                                    followsKeyword( $content[3] ) or
                                    followsKeywordinPlainText( @content[3..$#content] )
                                )

                            ) or
                            # Missing left bracket in text
                            (
                                $content[3] =~ m~^HTML::Element~ and
                                $content[3]->as_HTML('<>&') =~ m~^<span[^>]*>(\w+\])~ and
                                $CorrectMissingBracket = 1
                            )
                        ) and
                        $content[2]->tag eq "span" and
                        $content[2]->as_HTML('<>&') =~ m~style="font-weight:bold;"~ and
                        $content[2]->as_HTML('<>&') =~ m~<span[^>]*>(?<keysecond>((?!</?span>).)+)</span>~ ){
                        # Key followed another key by bracket fullfills criterium
                        my $SecondKey = cleanKey( $+{"keysecond"} );
                        $SecondKey =~ s~\s*\[\s*$~~;
                        pushArticle();
                        $PossibleKey = checkExtraForms( $PossibleKey );
                        $SecondKey = checkExtraForms( $SecondKey );
                        my $TBaHtml = $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                        if( $CorrectMissingBracket ){
                            # We're mucking about with the whole p-block in html, because we can't really change the HTTP::Elements of $TagBlock
                            unless ( $TBaHtml =~ s~^(?<start><p>(<span[^>]*>((?!</?span>).)+</span>){3}<span[^>]*>)(?<end>\w+\]|\w+, -\w+\])~$+{"start"}\[$+{"end"}~s ){
                                warn "Regex didn't work for '$TBaHtml'";
                                die;
                            }
                        }
                        infoVV("Found start of new article with key '$PossibleKey'.");
                        infoVV("Also found another form of this key '$SecondKey'.");
                        push @articles, $SecondKey.$separator.$PossibleKey."\n";
                        $article = $PossibleKey. $separator . $TBaHtml;
                        next TAGBLOCK;
                    }
                    # Three keys separated by ou
                    # E.g. <p><span class="font4" style="font-weight:bold;">copayer, </span><span class="font29">ou </span><span class="font4" style="font-weight:bold;">copaïer, </span><span class="font29">ou </span><span class="font4" style="font-weight:bold;">copahier </span><span class="font29">[kopaje] n. m. (du tupi-guarani </span><span class="font29" style="font-style:italic;">copaïba, </span><span class="font29">arbre qui produit le copahu, par changement de suff. ; 1783, </span><span class="font29" style="font-style:italic;">Encycl. méthodique, </span><span class="font29">écrit </span><span class="font29" style="font-style:italic;">copaïer; copayer,</span><span class="font29"> 1835, Acad. ; </span><span class="font29" style="font-style:italic;">copahier,</span><span class="font29"> 1866, Larousse). Arbre à suc résineux et balsamique, d’Amérique et d’Afrique tropicales.</span></p>
                    elsif( scalar @content >= 6 and
                        $content[1] =~ m~^HTML::Element~ and
                        $content[2] =~ m~^HTML::Element~ and
                        $content[3] =~ m~^HTML::Element~ and
                        $content[4] =~ m~^HTML::Element~ and
                        $content[5] =~ m~^HTML::Element~ and
                        $content[6] =~ m~^HTML::Element~ and
                        # $content[1]->tag eq "span" and
                        # $content[1]->as_HTML('<>&') =~ m~<span[^>]*>(! |\()?ou~ or
                        # $content[1]->as_HTML('<>&') =~ m~<span[^>]*>(! |\()?plur\.~ or
                        # $content[1]->as_HTML('<>&') =~ m~<span[^>]*>(! |\()?anc\.~
                        moreKeywords( $content[1] ) and
                        moreKeywords( $content[3] ) and
                        (
                            (
                                $content[2]->as_HTML('<>&') =~ m~<span[^>]*>(?<keysecond>((?!</?span>).)+)</span>~ and
                                $SecondKey = $+{keysecond} and
                                $SecondKey =~ m~\s*\[\s*$~ and
                                $content[4]->as_HTML('<>&') =~ m~<span[^>]*>(?<keythird>((?!</?span>).)+)</span>~ and
                                $ThirdKey = $+{keythird} and
                                $ThirdKey =~ m~\s*\[\s*$~
                            ) or
                            (
                                $content[5] =~ m~^HTML::Element~ and
                                (
                                    followsKeyword( $content[5] ) or
                                    followsKeywordinPlainText( @content[5..$#content] )
                                )

                            ) or
                            # Missing left bracket in text
                            (
                                $content[5] =~ m~^HTML::Element~ and
                                $content[5]->as_HTML('<>&') =~ m~^<span[^>]*>(\w+\])~ and
                                $CorrectMissingBracket = 1
                            )
                        ) and
                        $content[2]->tag eq "span" and
                        $content[2]->as_HTML('<>&') =~ m~style="font-weight:bold;"~ and
                        $content[4]->tag eq "span" and
                        $content[4]->as_HTML('<>&') =~ m~style="font-weight:bold;"~
                        ){
                        # Key followed two keys by bracket fullfills criterium
                        $SecondKey = cleanKey( $SecondKey );
                        $SecondKey =~ s~\s*\[\s*$~~;
                        $ThirdKey = cleanKey( $ThirdKey );
                        $ThirdKey =~ s~\s*\[\s*$~~;
                        pushArticle();
                        $PossibleKey = checkExtraForms( $PossibleKey );
                        $SecondKey = checkExtraForms( $SecondKey );
                        $ThirdKey = checkExtraForms( $ThirdKey );
                        my $TBaHtml = $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                        if( $CorrectMissingBracket ){
                            # We're mucking about with the whole p-block in html, because we can't really change the HTTP::Elements of $TagBlock
                            unless ( $TBaHtml =~ s~^(?<start><p>(<span[^>]*>((?!</?span>).)+</span>){3}<span[^>]*>)(?<end>\w+\]|\w+, -\w+\])~$+{"start"}\[$+{"end"}~s ){
                                warn "Regex didn't work for '$TBaHtml'";
                                die;
                            }
                        }
                        infoVV("Found start of new article with key '$PossibleKey'.");
                        infoVV("Also found another form of this key '$SecondKey'.");
                        push @articles, $SecondKey.$separator.$PossibleKey."\n";
                        push @articles, $ThirdKey.$separator.$PossibleKey."\n";
                        $article = $PossibleKey. $separator . $TBaHtml;
                        next TAGBLOCK;
                    }
                    else{
                        # Criterium not met. Current block taken as a continuation of previous article.
                        infoVV("Found a possible key '$PossibleKey', but it wasn't followed by one of the allowed symbols.");
                        push @ImpossibleKeywords, $PossibleKey;
                        if( exists $PauseFor{ $PossibleKey } ){
                            debug("as_HTML: '".$TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">"."'");
                            debug("as_text: '".$content[1]->as_text."'");
                            debug("temp: '$temp'");
                            debug("AFPTregex: '$AllowedFollowersPlainTextRegex'");
                            debug("AFregex: '$AllowedFollowersRegex'");
                            print "Press ENTER to continu.";
                            <STDIN>;
                        }
                        $ImpossibleKeywords{ $PossibleKey } = $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                        infoVV("Adding block to current article.");
                        $article .= $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                        next TAGBLOCK;
                    }
                }
                else{
                    # Criterium not met. Current block taken as a continuation of previous article.
                    infoVV("Adding block to current article.");
                    $article .= $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
                    next TAGBLOCK;
                }
            }
        }
        else{
            # Add block to article
            infoVV("Adding block to current article.");
            $article .= $TagBlock->as_HTML('<>&')."</".$TagBlock->tag.">";
            next TAGBLOCK;
        }

    }
    else{ debug("[$counter] '$_'");}
}
debug("Keywords that didn't fit in the criteria.");
my $HashStorageAlreadyClearedImpossibleKeywords = "StorageAlreadyClearedImpossibleKeywords.hash";
my %StorageAlreadyClearedImpossibleKeywords;
if( -e $HashStorageAlreadyClearedImpossibleKeywords ){
    %StorageAlreadyClearedImpossibleKeywords = %{ retrieve( $HashStorageAlreadyClearedImpossibleKeywords ) };
}
my $None = 1;
my @CurrentlyShown;
foreach(@ImpossibleKeywords){
    if( exists $StorageAlreadyClearedImpossibleKeywords{ $_} ){ next; }
    else{
        debug($_."________".$ImpossibleKeywords{$_}."\n\n");
        $StorageAlreadyClearedImpossibleKeywords{ $_ } =  1;
        $None = 0;
        push @CurrentlyShown,$_;
    }
}

if( $None ){ print "None\n"; }
my $AllCleared = 0;
if( $AllCleared ){ store \%StorageAlreadyClearedImpossibleKeywords, $HashStorageAlreadyClearedImpossibleKeywords; }
my $Wordlist = 'wordlist.txt';
my $WordlistNeeded = 1;
array2File( $Wordlist, @articles) if $WordlistNeeded;
debugV("Summary CurrentlyShown:");
foreach(sort @CurrentlyShown){ debugV($_);}
debug("FailingExtraForms:");
foreach(@FailingExtraForms){debug($_);}
