#!/usr/bin/perl

package DicConversion;
use strict;
use utf8;
use open IO => ':utf8';
use open ':std', ':utf8';
use feature 'unicode_strings'; # You get funky results with the sub convertNumberedSequencesToChar without this.
use lib '/home/mark/git/PocketBookDic/';

use DicGlobals;
use Dic2Screen;
use Exporter;
use DicFileUtils;
use DicHelpUtils;

if( $isTestingOn ){ use warnings; }
our @ISA = ('Exporter');
our @EXPORT = (
    'convertABBYY2XDXF',
    '$isABBYYAllCleared',
    '$isABBYConverted',
    '$isABBYYConverterReuse',
    '$isABBYYWordlistNeeded',
    '@ABBYYConverterAllowedKeys',
    '@ABBYYConverterPauseFor',
    '@ABBYY_CSS',

    'convertCVStoXDXF',
    '$CVSDeliminator',

    'convertHTML2XDXF',
    '$DebugKeyWordConvertHTML2XDXF',
    '$isConvertDiv2SpaninHTML2DXDF',
    '$isConvertFont2Small',
    '$isConvertFont2Span',
    '$isConvertMMCFullText2Span',

    'convertImage2Base64',
    '$isConvertGIF2PNG',

    'convertIMG2Text',
    '$isRemoveUnSubstitutedImageString',
    '$isRemoveUnSourcedImageStrings',

    'convertRAWML2XDXF',
    'convertStardictXMLtoXDXF',
    'convertXDXFtoStardictXML',
    'convertXML2Binary',
    
    'generateXDXFTagBased',
    '$HigherFrequencyTags',
    '$isDeleteLowerFrequencyTagsinFilterTagsHash',
    '$isExcludeImgTags',
    '$isgatherSetsVerbose',
    '$isRemoveMpbAndBodyTags',
    '$isSkipKnownStylingTags',
    '$MinimumSetPercentage',

    '%ReplacementImageStrings',
    '$ReplacementImageStringsHashFileName',
    '%OCRedImages',
    '%ValidatedOCRedImages',
    '$ValidatedOCRedImagesHashFileName',
    '$isManualValidation',
);

# Control variables for the conversion of ABBYY-generated HTML.
our @ABBYY_CSS; # Becomes defined by sub convertABBYY2XDXF
our $isABBYYWordlistNeeded   = 1; # Controls creation of an ABBYYWordlist.txt file.
our $isABBYYAllCleared       = 0; # Controls creation of a hash-file.
our $isABBYYConverterReuse   = 0; # Controls the check for already generated xdxf-file
our $isABBYConverted         = 0; # Global variable that gets set to 1 if convertABBYY2XDXF returns an xdxf-array.
# Conversion pauses during keywords
our @ABBYYConverterPauseFor = (
# E.g.,
    # 'égard',
    # 'ète',
    # 'unipolaire',
    # 'germain, e'
);
# Manual overrule. Conversion checks whether keyword is allowed and passes it without further tests.
our @ABBYYConverterAllowedKeys = (
# E.g.,
    # q~corbeille-d’argent~,
    # q~crespelé, e~,
    # q~cul-rond~,
    # q~desquels, desquelles~,
    # q~duquel~,
    # q~fœhn~,
    # q~giboyeux, euse~,
    # q~glacial, e, als~,
    # q~hydro-. V~,
    # q~inaliénablement~,
    # q~in aliéné, e~,
    # q~laquelle~,
    # q~melliflu, e~,
    # q~peu chère~,
    # q~pick-nick n.m.~,
);
sub convertABBYY2XDXF{
    # Usage: @xdxf = convertABBYY2XDXF( $html );
    if( $isABBYYConverterReuse ){
        my $XDXFFileName = $FileName;
        $XDXFFileName =~ s~\.\w+$~~;
        $XDXFFileName .= ".xdxf";
        if( -e $XDXFFileName ){
            $isABBYConverted = 1;
            return ( file2Array( $XDXFFileName ) );
        }
    }
    use HTML::TreeBuilder 5 -weak; # Ensure weak references in use
    my $html = shift;
    if( $html =~ m~<style type="text/css">(?<css>((?!</style>).)+)</style>~s ){
        push @ABBYY_CSS, $+{css};
    }
    info("Start parsing dictionary '$FileName'");
    my $tree = HTML::TreeBuilder->new; # empty tree
    if( -e $FileName.'.tree' ){
        $tree = retrieve ( $FileName.'.tree' );
        info( "Retrieved tree from '".$FileName.".tree'"); }
    else{
        $html = convertNonBreakableSpacetoNumberedSequence4Strings( $html );
        $html = convertNumberedSequencesToChar4Strings( $html );
        $html = mergeConsecutiveIdenticallyAttributedSpans( $html );
        $tree->p_strict(1); # https://metacpan.org/pod/HTML::TreeBuilder#p_strict
        $tree->parse( $html );
    }
    debugV( "tree '$tree'");
    # tree 'HTML::TreeBuilder=HASH(0x562d600afcf0)'

    unless( $tree =~ m~HTML::TreeBuilder=HASH~ ){
        unlink $FileName . '.tree';
        Die("\$tree not a HTML::TreeBuilder hash. \$tree='$tree'\n Deleted old tree-file. Rerun script.");
    }
    store( $tree, $FileName.'.tree' );
    info("End parsing");

    info("Starting look_down for body-tag");
    my $body = $tree->look_down('_tag', 'body');
    info("Found body-tag");

    my $counter = 0;
    our ( @articles, $article, @ImpossibleKeywords, %ImpossibleKeywords, @FailingExtraForms );
    sub addArticle{
        my $TagBlock = shift;
        infoVV("Entering addArticle.");
        my $html = asHTML($TagBlock);
        my @check = checkAddedHTML4StartArticle( $html );
        if( scalar @check == 3 ){
            addArticle( $check[0]);
            pushArticle();
            setArticle( $check[1], $check[2] );
        }
        elsif( defined $article ){
            $article .= $html;
            infoVV("Added to article:\n'$html'");
        }
        else{
            infoV("No defined article, so nothing to add to.");
            infoV("Ignored content:\n'$html'");
        }
    }
    sub asHTML{
        my $content = shift;
        unless( $content =~ m~^HTML::Element=HASH~ ){
            warn "Not an HTML::Element object!";
            debug("'$content'");
            return( $content );
        }
        return( removeBreakTag( $content->as_HTML('<>&', "    ", {}) ) );
    }
    sub checkAddedHTML4StartArticle{
        # Usage: @checks = checkAddedHTML4StartArticle( $html );
        # The sub returns either an array of scalar 3 or of 1;
        # If it returns 3 values, they are the start of the article before the break, the new keyword and the start of the new article.
        # If it returns 1 value, it is just the given html-string.
        infoVV("Entering checkAddedHTML4StartArticle");
        my $html = shift;

        # Sometimes ABBY doesn't generate a new paragraph, but breaks the current to start a new lemma.
        # So the criterium is a <br>-tag followed by a span-bold.
        # <p><span class="font0" style="font-weight:bold;">unipolaire </span><span class="font2">[ynipoler] adj. (de wm-2etde<br></span><span class="font2" style="font-style:italic;">polaire ;</span><span class="font2"> 1845, Bescherelle, au sens 1 ; sens 2,<br>1877, Littré). </span><span class="font0" style="font-weight:bold;">1. </span><span class="font2">Qui n’a qu’un pôle élec-<br>trique : </span><span class="font2" style="font-style:italic;">Appareil, interrupteur unipolaire.<br></span><span class="font0" style="font-weight:bold;">|| 2. </span><span class="font2">Se dit d’un neurone dont le corps cel-<br>lulaire porte un seul prolongement, comme<br>les neurones en T des ganglions spinaux,<br></span><span class="font0" style="font-weight:bold;">unique </span><span class="font2">[ynik] adj. (lat. </span><span class="font2" style="font-style:italic;">unicus,</span><span class="font2"> unique,<br>seul, sans égal, de </span><span class="font2" style="font-style:italic;">unus,</span><span class="font2"> un [seul] ; fin du<br>xv<sup>e</sup> s., Molinet, au sens 1 </span><span class="font2" style="font-style:italic;">[seul et unique,<br></span><span class="font2">1751, </span><span class="font2" style="font-style:italic;">Encyclopédie —</span><span class="font2"> discours prélimi-<br>naire; </span><span class="font2" style="font-style:italic;">...fils... unique,</span><span class="font2"> 1668, Molière] ; sens2,<br>1876, Larousse [art. </span><span class="font2" style="font-style:italic;">voie —</span><span class="font2"> sur une route,<br>xx<sup>e</sup> s. ; </span><span class="font2" style="font-style:italic;">sens unique,</span><span class="font2"> janv. 1914, </span><span class="font2" style="font-style:italic;">la Science et<br>la Vie,</span><span class="font2"> p. 31] ; sens 3,1640, Corneille ; sens 4,<br>av. 1696, La Bruyère ; sens 5,1758, Diderot).</span></p>
        my @BreakBoldSpans = $html =~ m~(<br[^>]*></span><span[^>]+?bold[^>]+>(?:(?!</?span>).)+</span>)~sg;
        if( scalar @BreakBoldSpans == 0 ){ infoVV("No break followed by bold span found."); }
        else{
            infoV("Found break followed by span tag, that has bold styling.");
            infoV("\@BreakBoldSpans:");
            foreach(@BreakBoldSpans){debug_t("'$_'");}
        }

        # However, sometimes it is just a bold-span after a comma. I am going to assume that the misinterpreted '.' forces ABBY to continue the paragraph.
        # So the criterium is a ',' followed by a span-bold
        # If a keyword is found, the comma should be corrected to a point.
        # <p><span class="font20" style="font-weight:bold;">♦ En guise de </span><span class="font29">loc. prép. (v. 1050, </span><span class="font29" style="font-style:italic;">Vie de saint Alexis,</span><span class="font29"> au sens de « à la façon de » ; sens actuel, 1651, Scarron). Pour servir de, pour jouer le même rôle que : </span><span class="font29" style="font-style:italic;">On étend des haïks en guise de nappes</span><span class="font29"> (Fromentin), </span><span class="font4" style="font-weight:bold;">guitare </span><span class="font29">[gitar] n. f. (anc. provenç. </span>
        my @CommaBoldSpans = $html =~ m~(,\s*</span><span[^>]+?bold[^>]+>(?:(?!</?span>).)+</span>)~sg;
        if( scalar @CommaBoldSpans == 0 ){ infoVV("No comma followed by bold span found."); }
        else{
            infoV("Found comma followed by span tag, that has bold styling.");
            infoV("\@CommaBoldSpans:");
            foreach(@CommaBoldSpans){debug_t("'$_'");}
        }

        foreach my $PossibleKeySpan( @BreakBoldSpans, @CommaBoldSpans  ){
            infoVV("PossibleKeySpan: '$PossibleKeySpan'");
            $html =~ m~\Q$PossibleKeySpan\E~s;
            # my $BeforeBreak = $`.'</span>';
            my $BeforeBreak = $`;
            my $AfterBreak = $';
            if( $PossibleKeySpan =~ s~^<br[^>]*></span>~~ ){$BeforeBreak .= '</span>'; }
            elsif( $PossibleKeySpan =~ s~^,\s*</span>~~ ){  $BeforeBreak .= '.</span>'; }
            debug_t("BeforeBreak: '$BeforeBreak'");
            debug_t("AfterBreak: '$AfterBreak'");
            debug_t("PossibleKeySpan: '$PossibleKeySpan'");
            unless( $PossibleKeySpan =~ m~^<span[^>]+>(?<key>((?!</?span>).)+)</span>~s ){ warn "Regex didn't work for:'$PossibleKeySpan'"; next; }
            my $KeyAfterBreak = cleanKey($+{key});
            infoVV("Possible key after break is '$KeyAfterBreak'");
            if( followsKeywordinPlainText( stripTags( $AfterBreak ) ) ){
                # Found another keyword.
                info("Found another keyword '$KeyAfterBreak'. Returning three values");
                return ( $BeforeBreak, $KeyAfterBreak, $PossibleKeySpan.$AfterBreak );
            }
            else{
                debug_t("No keyword found");
                debug_t("Plain text after break:\n'".stripTags( $AfterBreak )."'");
            }
        }
        return ($html);
    }
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
                    warn "Not a known variant of form for '$PossibleKey': '$Form'.";
                    debug("last 3 letters of '$PossibleKey': ". substr($PossibleKey, -3, 3) );
                    debug("last 3 letters of '$Form': ". substr($Form, -3, 3) );
                }
            }
        }
        return $PossibleKey;
    }
    sub cleanKey{
        my $Key = $_[0];
        $Key =~ s~<br ?/?>~~gs;
        $Key =~ s~\[[^\]]*\]~~g;
        $Key =~ s~\]\s*$~~g;
        $Key =~ s~\)$~~g;
        $Key =~ s~^\+~~;
        $Key =~ s~^\.~~;
        $Key =~ s~\s+$~~g;
        $Key =~ s~^\s+~~g;
        $Key =~ s~,+$~~g;
        $Key =~ s~^\^~~g;
        $Key =~ s~^\*~~g;
        # Changes (imitable in limitable, but will not change (K) into lK)
        $Key =~ s~^\(([^)]+)$~l$1~;
        # Sometimes causes entire keys to be deleted, e.g. <span class="font4" style="font-weight:bold;">(K) , </span>
        # $Key =~ s~\([^)]*\)?~~g;
        # Remove numerical prefixes, so that reconstructXDXF can put the descriptions in the same article.
        $Key =~ s~^\d\.? ~~g;
        $Key =~ s~(\w+)(n\.(m\.)?)$~$1 $2~;
        # Correct OCR, e.g. cambré» e
        $Key =~ s~» ~, ~;
        $Key =~ s~<sup>((?!</?sup>).)+</sup>~*~;
        $Key =~ s~<sub>((?!</?sub>).)+</sub>~~;
        $Key =~ s~<a[^>]*>((?:(?!</?a[^>]*>).)*)</a>~$1~g;
        if( $Key eq '' ){ return $_[0]; }
        else{ return $Key; }
    }
    our %PauseFor;
    foreach( @ABBYYConverterPauseFor ){ $PauseFor{ $_ } =  1; }
    our %AllowedKeys;
    foreach( @ABBYYConverterAllowedKeys ){ $AllowedKeys{ $_ } =  1; }
    our $Pre = '! |\(|\([^)]+\)(\.|,)? +|\? ';
    our @AllowedFollowers = (
        '^<span[^>]*>('.$Pre.')?\[',
        '^<span[^>]*>\((devant|Acad|\d{4}, )',
        '^<span[^>]*>n\. ?(m|f|V)?\.?',
        '^<span[^>]*>\(marque déposée\)',
        '^<span[^>]*>('.$Pre.')?adj\.',
        '^<span[^>]*>v\. (pr|(in)?tr)\.',
        '^<span[^>]*>('.$Pre.')?adv\.( V\.)?',
        'pers. sing. de',
        '^<span[^>]*>('.$Pre.')?(pron|prép|interj|intr|loc|préf|conj)\.',
        '^<span[^>]*>('.$Pre.')?((A|a)brév\.|Abréviation|(S|s)igle|symbole)',
        '^<span[^>]*>pr\. rei\. V\.',
        '^<span[^>]*>éléments? tirés? du',
        '^<span[^>]*>((m|f)\. )?V\.',
        '^\d\. Premier élément',
        '^premiers? éléments?',
        '^<span[^>]*>v. impers,',
        '^<span[^>]*>part, passé\.',
        '^<span[^>]*>\(rarem.',
        );
    our $AllowedFollowersRegex = shift @AllowedFollowers;
    foreach(@AllowedFollowers){ $AllowedFollowersRegex .= "|".$_; }
    our $AllowedFollowersPlainTextRegex = $AllowedFollowersRegex;
    $AllowedFollowersPlainTextRegex =~ s~<span\[\^>\]\*>~~sg;

    sub followsKeyword{
        # Returns value of criterium
        # Is given een HTML::ELement containing a span-block
        my $content = shift;
        infoVV("followsKeyword is given '$content'") if 0;
        unless( $content =~ m~^HTML::Element=HASH~ ){ return 0; }
        return ( $content->tag eq "span" and asHTML( $content ) =~ m~$AllowedFollowersRegex~ );}
    sub followsKeywordinPlainText{
        # Returns value of criterium
        # Is given a contents-range of HTML::Element
        my $content;
        foreach( @_ ){
            if( m~^HTML::Element=HASH~ ){ $content .= $_->as_text; }
            else{ $content .= stripTags($_);}
        }
        return ( $content !~ m~^HTML::Element=HASH~ and $content =~ m~$AllowedFollowersPlainTextRegex~ );}
    sub moreKeywords{
        my $content = shift;
        return(
            $content =~ m~^HTML::Element~ and
            $content->tag eq "span" and
            (
                $content->as_HTML('<>&', "  ", {}) =~ m~<span[^>]*>($Pre)?ou~ or
                $content->as_HTML('<>&', "  ", {}) =~ m~<span[^>]*>($Pre)?plur\.~ or
                $content->as_HTML('<>&', "  ", {}) =~ m~<span[^>]*>($Pre)?anc\.~
            )
        );}
    sub pushArticle{ if( defined $article ){
        $article .= '</def></ar>'."\n";
        # Allow no tags in Possible key.
        unless( $article =~ m~<k>(?<key>.+)</k>~ ){ Die("regex doesn't work for '$article'"); }
        my $Key = $+{"key"};
        if($Key =~ m~[<>]+~){ Die( "'<'or '>' found in key '$Key'."); }
        infoV("Pushing article '$article'");
        push @articles, $article;
        $article = undef; } }
    sub pushReferenceArticle{
        my $ReferringKey = shift;
        my $Referent = shift;
        infoV("Pushing referring key '$ReferringKey'");
        # E.g. <ar><head><k>abaissante</k></head><def>abaissant</def></ar>
        my $article = '<ar><head><k>'.$ReferringKey.'</k></head><def>'.$Referent.'</def></ar>'."\n";
        push @articles, $article;}
    sub setArticle{
        infoVV("Entering setArticle");
        my $HeadK = shift;
        my $Def = shift;
        infoVV("HeadK: '$HeadK'");
        infoVV("Def: '$Def'");
        pushArticle();
        my @Check = checkAddedHTML4StartArticle( $Def );
        if( scalar @Check == 3 ){
            setArticle( $HeadK, $Check[0] );
            pushArticle();
            setArticle( $Check[1], $Check[2] );
        }
        else{ $article = '<ar><head><k>'.$HeadK .'</k></head><def>' . $Def; }}
        my @ContentBodyList = ( $body->content_list );
    TAGBLOCK: for( my $counter = 0; $counter < scalar @ContentBodyList; $counter++){
        # foreach my $TagBlock ( @ContentBodyList ){
        my $TagBlock = $ContentBodyList[$counter];
        if( $TagBlock =~ m~^HTML::Element~ ){
            debugV( "[$counter] tag: '".$TagBlock->tag."'");
            # If tagblock contains an ul with li-blocks, splice the consecutive contents as tagblocks in @ContentBodyList at position $counter+1.
            # Will this work?
            if( $TagBlock->tag eq 'ul'){
                my @content = $TagBlock->content_list();
                my $index = 0;
                my @li_content;
                foreach( @content ){
                    debugV("[$index] '$_', tag '".$_->tag."'"); $index++;
                    unless( $_->tag eq "li" ){
                        warn "Found unexpected block within ul-block:\n'".asHTML($TagBlock)."'";
                        Die();
                    }
                    push @li_content, $_->content_list();
                }
                splice @ContentBodyList, ($counter + 1), 0, @li_content;
                next TAGBLOCK;
            }
            if( $TagBlock->tag eq 'p'){
                my @content = $TagBlock->content_list();
                if( scalar @content == 0){ infoVV("No content.Skipping."); next TAGBLOCK;}
                unless( $content[0] =~ m~^HTML::Element=HASH~ ){
                    if( $content[0] !~ m~<|>~ ){
                        # Plain text. An p-subblock appears unencapsulated
                        infoVV("Found plain text.");
                        unless( defined $article ){
                            debug("$content[0]");
                            foreach(@content){ debug( asHTML( $_ ) ); }
                            warn "Found plain text outside of article.";
                            Die();
                        }
                        addArticle( $TagBlock );
                        next TAGBLOCK;
                    }
                    else{ warn "Unknown p-block."; die; }
                }
                my $asHtml = removeBreakTag( asHTML( $content[0] ) );
                debugV( "'$asHtml'");

                if( scalar @content == 1){
                    if( $content[0]->tag eq "span" and
                        $asHtml =~ m~<span[^>]*>(\w)</span>~){
                        # Chapter title, e.g. 'a':
                        # <p><span class="font34" style="font-weight:bold;">a</span></p>
                        # However, this is not a chapter title:
                        # <p><span class="font24" style="font-weight:bold;">■ &nbsp;&nbsp;<sup>1</sup> &nbsp;&nbsp;■ <sub>t</sub> i &nbsp;&nbsp;ii. &nbsp;■</span></p>
                        # <p><span class="font3" style="font-weight:bold;">A</span></p>
                        # <p><span class="font29">On procède de façon analogue quand on<br>dit : </span><span class="font29" style="font-style:italic;">Henri IV est mort en 1610 ;</span><span class="font29"> on donne<br>alors une indication de date, et c’est en ce<br>sens restreint que l’on prend, en linguis-<br>tique, le mot </span><span class="font29" style="font-style:italic;">temps.</span></p>
                        # Obviously the difference is in class, font34 vs font3.
                        # If one doesn't want to discriminate based on class, always a lofty goal, how can one furnish a criterion?
                        # For instance, the current article should be of a different letter and one lower in the alphabet.
                        # This can be done with ord() for the ascii values.
                        # However, when facing the comparison of é and f this breaks down.
                        # Unicode has pre-composed characters and their canonical equivalents.
                        # The decomposition (into an equivalent sequence) changes characters into a combination of a base character and an accent. Then the base characters can be compared as before with the ord( ascii character ).
                        # The module Unicode::Normalize contains functions to convert between the two.
                        my $PossibleChapterTitle = $1;
                        if( scalar @articles == 0 ){ next TAGBLOCK; }
                        unless( defined $article ){ warn "Unexpected result."; Die(); }
                        unless( $article =~ m~<k>([^<]+)</k>~){ warn "Regex doesn't work."; Die(); }
                        my $CurrentKey = $1;
                        unless( defined $CurrentKey ){ warn "CurrentKey is not defined:\n'$article'"; debug(@articles[-1]); Die(); }
                        if( ord($CurrentKey) + 1 == ord( $PossibleChapterTitle ) ){
                            # Finish previous article?
                            infoVV("Found chapter title. Skipping.");
                            pushArticle();
                        }
                        else{
                            addArticle( $TagBlock );
                        }
                        next TAGBLOCK;
                    }
                    # <p><span class="font20" style="font-weight:bold;text-decoration:underline;">| Sa | Sé ~~]</span></p>
                    # <span class="font27" style="font-weight:bold;font-style:italic;">HISTOIRE DE £’ « E MUET »</span>'
                    if( $content[0]->tag eq "span" and
                        (
                            $asHtml =~ m~style="font-weight:bold;"~ or
                            (
                                $asHtml =~ m~font-style:italic;"~ and
                                $asHtml =~ m~<span[^>]*>[«»’,;:'./()|\\\h\?\!\-[\]\p{Uppercase}]+</span>~
                            ) or
                            $asHtml =~ m~font-variant:small-caps;~ or
                            $asHtml =~ m~text-decoration:underline~ or
                            (
                                # Bold letters starting with a word all in capitals
                                $asHtml =~ m~font-weight:bold;~ and
                                # <span class="font27" style="font-weight:bold;font-style:italic;">1. LEXIQUE ET VOCABULAIRE</span>
                                $asHtml =~ m~<span[^>]*>(\d\. )?[«»’,;:'./()|\\\h\?\!\-[\]\p{Upper}]+ ~
                            )
                        )
                        ){
                        # Single entry in @contents. Probably a title in an article
                        infoVV("Found a title.");
                        addArticle( $TagBlock );
                        next TAGBLOCK;
                    }
                    # <p><span class="font29" style="font-weight:bold;font-style:italic;">l’ami de monpère/un ami de mon<br>père.</span></p>
                    # <span class="font17" style="font-weight:bold;font-style:italic;">chies      chat Jean *</span>
                    # <span class="font1" style="font-weight:bold;font-style:italic;">On le voit s’annoncer de loin par les traits de feu qu'il lance devant lui. L'incendie augmente, l’Orient paraît tout en flammes : à leur éclat, on attend l’astre longtemps avant qu'il se montre; à chaque instant on croit le noir paraître; on le voit enfin. Un point brillant part comme un éclair, et remplit aussitôt l’espace; le voile des ténèbres s’efface et tombe (Jean-Jacques Rousseau).</span>
                    # <span class="font29" style="font-weight:bold;font-style:italic;">aimeft)           plaist</span>
                    if( $content[0]->tag eq "span" and
                        (
                            $asHtml !~ m~style="~ or
                            # <span class="font27" style="font-weight:bold;font-style:italic;">« QUI », « QUEL », «OÙ », etc.</span>
                            $asHtml =~ m~^<span[^>]*>[«»’,;:'./()|\\\?\!\-[\]]+~ or
                            (
                                (
                                    # <span class="font29" style="font-weight:bold;font-style:italic;">Où l’indécis | ( au précis | se joint</span>
                                    # <span class="font28" style="font-weight:bold;font-style:italic;">Sur les humides bords | | des royau\mes du vent a                      a</span>
                                    $asHtml =~ m~font-style:italic;"~ and
                                    $asHtml =~ m~^<span[^>]*>\p{Uppercase}[«»’,;:'./()|\\\d\h\?\!\-[\]\p{Lower}\p{Uppercase}]+</span>~
                                ) or
                                $asHtml =~ m~style="font-style:italic;"~ or
                                (
                                    $asHtml =~ m~style="font-weight:bold;~ and
                                    $asHtml =~ m~^<span[^>]*>[«»’,;:'./()|\\\h\?\!\-[\]\p{Lower}]+</span>~
                                ) or
                                (
                                    $asHtml =~ m~style="font-weight:bold;~ and
                                    $asHtml =~ m~^<span[^>]*>[[«»’,;:'./()|\\\h\?\!\-[\]\p{lower}]+ ~
                                )
                            )

                        )
                            ){
                        # Simple p-block, just add it to article.
                        infoVV("Found a simple p-block.");
                        addArticle( $TagBlock );
                        next TAGBLOCK;
                    }
                    if( $content[0]->tag eq "a"){
                        # Bookmark
                        infoVV("Found a bookmark a-block.");
                        addArticle( $TagBlock );
                        next TAGBLOCK;
                    }
                    # Unknown instance
                    warn "One content entry: No clue";
                    die;
                }
                if( scalar @content > 1 ){
                    if( $content[0]->tag eq "span" and
                        $asHtml =~ m~style="font-weight:bold;"~ and
                        $asHtml =~ m~<span[^>]*>(?<key>((?!</?span>).)+)</span>~ ){
                        my $PossibleKey = cleanKey( $+{"key"} );
                        if( $PossibleKey =~ m~^(♦|•|\||[ILVX]+\.|\d?°|—|■|«)~ ){
                            infoVV("Subkey '$PossibleKey' starting with '$1' found.");
                            addArticle( $TagBlock );
                            next TAGBLOCK;
                        }
                        unless( defined $PossibleKey and $PossibleKey ne '' ){ Die( "Possible key is not defined are empty for '$asHtml" ); }
                        my $CorrectMissingBracket = 0;
                        my $temp = undef;
                        my $SecondKey = undef;
                        my $ThirdKey = undef;
                        if( exists $PauseFor{ $PossibleKey } ){
                            debug("as_HTML: '". asHTML( $TagBlock )."'");
                            debug("as_text: '".$TagBlock->as_text."'");
                            debug("AFPTregex: '$AllowedFollowersPlainTextRegex'");
                            debug("AFregex: '$AllowedFollowersRegex'");
                            print "Press ENTER to continu.";
                            <STDIN>;
                        }
                        if( $content[1] =~ m~^HTML::Element~ and
                            (
                                followsKeyword( $content[1] ) or
                                followsKeywordinPlainText( @content[1..$#content] ) or
                                $AllowedKeys{ $PossibleKey } or
                                # Bracket appears in the same span as keyword
                                $PossibleKey =~ s~\s*\[\s*~~ or
                                # Missing left bracket in text
                                (
                                    asHTML( $content[1] ) =~ m~^<span[^>]*>\^?(\w+\]|\w+, -\w+\])~ and
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
                            my $TBaHtml = asHTML( $TagBlock );
                            if( $CorrectMissingBracket ){
                                unless ( $TBaHtml =~ s~^(?<start><p><span[^>]*>((?!</?span>).)+</span><span[^>]*>)\^?(?<end>\w+\]|\w+, -\w+\])~$+{"start"}\[$+{"end"}~s ){
                                    warn "Regex didn't work for '$TBaHtml'";
                                    die;
                                }
                            }
                            $PossibleKey = checkExtraForms( $PossibleKey );
                            setArticle( $PossibleKey, $TBaHtml );
                            if( exists $PauseFor{ $PossibleKey } ){
                                debug("Article: '$article'");
                                print "At line ".__LINE__.". Press ENTER to continu.";
                                <STDIN>;
                            }
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
                                    asHTML( $content[2] ) =~ m~<span[^>]*>(?<keysecond>((?!</?span>).)+)</span>~ and
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
                                    asHTML( $content[3] ) =~ m~^<span[^>]*>\^?(\w+\])~ and
                                    $CorrectMissingBracket = 1
                                )
                            ) and
                            $content[2]->tag eq "span" and
                            asHTML( $content[2] ) =~ m~style="font-weight:bold;"~ and
                            asHTML( $content[2] ) =~ m~<span[^>]*>(?<keysecond>((?!</?span>).)+)</span>~ ){
                            # Key followed another key by bracket fullfills criterium
                            my $SecondKey = cleanKey( $+{"keysecond"} );
                            $SecondKey =~ s~\s*\[\s*$~~;
                            pushArticle();
                            $PossibleKey = checkExtraForms( $PossibleKey );
                            $SecondKey = checkExtraForms( $SecondKey );
                            my $TBaHtml = asHTML( $TagBlock );
                            if( $CorrectMissingBracket ){
                                # We're mucking about with the whole p-block in html, because we can't really change the HTTP::Elements of $TagBlock
                                unless ( $TBaHtml =~ s~^(?<start><p>(<span[^>]*>((?!</?span>).)+</span>){3}<span[^>]*>)\^?(?<end>\w+\]|\w+, -\w+\])~$+{"start"}\[$+{"end"}~s ){
                                    warn "Regex didn't work for '$TBaHtml'";
                                    die;
                                }
                            }
                            infoVV("Found start of new article with key '$PossibleKey'.");
                            infoVV("Also found another form of this key '$SecondKey'.");
                            # E.g. <ar><head><k>abaissante</k></head><def>abaissant</def></ar>
                            pushReferenceArticle( $SecondKey, $PossibleKey);
                            setArticle( $PossibleKey, $TBaHtml );
                            if( exists $PauseFor{ $PossibleKey } ){
                                debug("Article: '$article'");
                                print "Press ENTER to continu.";
                                <STDIN>;
                            }
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
                            # $content[1]->as_HTML('<>&', " ", {}) =~ m~<span[^>]*>(! |\()?ou~ or
                            # $content[1]->as_HTML('<>&', " ", {}) =~ m~<span[^>]*>(! |\()?plur\.~ or
                            # $content[1]->as_HTML('<>&', " ", {}) =~ m~<span[^>]*>(! |\()?anc\.~
                            moreKeywords( $content[1] ) and
                            moreKeywords( $content[3] ) and
                            (
                                (
                                    asHTML( $content[2] ) =~ m~<span[^>]*>(?<keysecond>((?!</?span>).)+)</span>~ and
                                    $SecondKey = $+{keysecond} and
                                    $SecondKey =~ m~\s*\[\s*$~ and
                                    asHTML( $content[4] ) =~ m~<span[^>]*>(?<keythird>((?!</?span>).)+)</span>~ and
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
                                    asHTML( $content[5] ) =~ m~^<span[^>]*>\^?([\w\^]+\])~ and
                                    $CorrectMissingBracket = 1
                                )
                            ) and
                            $content[2]->tag eq "span" and
                            asHTML( $content[2] ) =~ m~style="font-weight:bold;"~ and
                            $content[4]->tag eq "span" and
                            asHTML( $content[4] ) =~ m~style="font-weight:bold;"~
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
                            my $TBaHtml = asHTML( $TagBlock );
                            if( $CorrectMissingBracket ){
                                # We're mucking about with the whole p-block in html, because we can't really change the HTTP::Elements of $TagBlock
                                unless ( $TBaHtml =~ s~^(?<start><p>(<span[^>]*>((?!</?span>).)+</span>){3}<span[^>]*>)\^?(?<end>\w+\]|\w+, -\w+\])~$+{"start"}\[$+{"end"}~s ){
                                    warn "Regex didn't work for '$TBaHtml'";
                                    die;
                                }
                            }
                            infoVV("Found start of new article with key '$PossibleKey'.");
                            infoVV("Also found another form of this key '$SecondKey'.");
                            pushReferenceArticle( $SecondKey, $PossibleKey );
                            pushReferenceArticle( $ThirdKey,  $PossibleKey );
                            setArticle( $PossibleKey, $TBaHtml );
                            if( exists $PauseFor{ $PossibleKey } ){
                                debug("Article: '$article'");
                                print "Press ENTER to continu.";
                                <STDIN>;
                            }
                            next TAGBLOCK;
                        }
                        else{
                            # Criterium not met. Current block taken as a continuation of previous article.
                            infoVV("Found a possible key '$PossibleKey', but it wasn't followed by one of the allowed symbols.");
                            push @ImpossibleKeywords, $PossibleKey;
                            $ImpossibleKeywords{ $PossibleKey } = asHTML( $TagBlock );
                            addArticle( $TagBlock );
                            if( exists $PauseFor{ $PossibleKey } ){
                                debug("Article: '$article'");
                                print "Press ENTER to continu.";
                                <STDIN>;
                            }
                            next TAGBLOCK;
                        }
                    }
                    else{
                        # Criterium not met. Current block taken as a continuation of previous article.
                        addArticle( $TagBlock );
                        next TAGBLOCK;
                    }
                }
            }
            else{
                # Add block to article
                addArticle( $TagBlock );
                next TAGBLOCK;
            }

        }
        else{ debugV("[$counter] '$_'");}
    }
    pushArticle();
    debugV("Keywords that didn't fit in the criteria.");
    my $HashStorageAlreadyClearedImpossibleKeywords = "StorageAlreadyClearedImpossibleKeywords.hash";
    my %StorageAlreadyClearedImpossibleKeywords;
    if( -e $HashStorageAlreadyClearedImpossibleKeywords ){
        %StorageAlreadyClearedImpossibleKeywords = %{ retrieve( $HashStorageAlreadyClearedImpossibleKeywords ) };
    }
    my $None = 1;
    my @CurrentlyShown;
    my @CurrentlyShownWithDescription;
    foreach(@ImpossibleKeywords){
        if( exists $StorageAlreadyClearedImpossibleKeywords{ $_} ){ next; }
        else{
            push @CurrentlyShownWithDescription, $_."________".$ImpossibleKeywords{$_}."\n\n";
            push @CurrentlyShown,$_;
            debugV( $CurrentlyShownWithDescription[-1] );
            $StorageAlreadyClearedImpossibleKeywords{ $_ } =  1;
            $None = 0;
        }
    }

    if( $None ){ debugV("None") ; }
    if( $isABBYYAllCleared ){ store(\%StorageAlreadyClearedImpossibleKeywords, $HashStorageAlreadyClearedImpossibleKeywords); }
    my $ABBYYWordlist = 'ABBYYWordlist.txt';
    array2File( $ABBYYWordlist, @articles) if $isABBYYWordlistNeeded;
    debugV("Summary CurrentlyShown:");
    my $ABBYYImpossibleKeyWordList = 'ABBYYImpossibleKeyWordList.txt';
    my $ABBYYImpossibleKeyWordListWithDescription = 'ABBYYImpossibleKeyWordListWithDescription.txt';
    my @ImpossibleKeywordList;
    foreach(sort @CurrentlyShown){ debugV($_); push @ImpossibleKeywordList, $_, "\n"; }
    array2File( $ABBYYImpossibleKeyWordList, @ImpossibleKeywordList);
    array2File( $ABBYYImpossibleKeyWordListWithDescription, @CurrentlyShownWithDescription );
    debugV("FailingExtraForms:");
    foreach(@FailingExtraForms){debugV($_);}
    $isABBYConverted = 1;
    return( @xdxf_start, @articles, "</xdxf>" );}

# Deliminator for CSV files, usually ",",";" or "\t"(tab).
our $CVSDeliminator = ",";
sub convertCVStoXDXF{
    my @cvs = @_;
    my @xdxf = @xdxf_start;
    my $number= 0;
    my $Max_debuglines = 3;
    info("\$CVSDeliminator is \'$CVSDeliminator\'.") if $number<$Max_debuglines;
    foreach(@cvs){
        $number++;
        info("CVS line is: $_") if $number<$Max_debuglines;
        m~\Q$CVSDeliminator\E~s;
        my $key = $`; # Special variable $PREMATCH
        my $def = $'; # Special variable $POSTMATCH
        info("key found: '$key'") if $number<$Max_debuglines;
        info("def found: '$def'") if $number<$Max_debuglines;
        unless( defined $key and defined $def and $key ne '' and $def ne ''){
            warn "key and/or definition are undefined.";
            debug("CVSDeliminator is '$CVSDeliminator'");
            debug("CVS line is '$_'");
            debug("Array index is $number");
            Die();
        }
        # Remove whitespaces at the beginning of the definition and EOL at the end.
        $def =~ s~^\s+~~;
        $def =~ s~\s+$~~;
        push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
        debug("Pushed <ar><head><k>$key</k></head><def>$def</def></ar>") if $number<10;
    }
    push @xdxf, $lastline_xdxf;
    if( $isTestingOn ){ array2File( "test_CVSConversion".__LINE__.".xdxf", @xdxf ); }
    return(@xdxf);}

# Controls for convertHTML2XDXF
our $DebugKeyWordConvertHTML2XDXF = "Gewirr"; # In convertHTML2XDXF only debug messages from this entry are shown. E.g. "Gewirr"
our $isConvertDiv2SpaninHTML2DXDF = 0 ;
our $isConvertFont2Small          = 0 ;
our $isConvertFont2Span           = 0 ;
our $isConvertMMCFullText2Span    = 1 ;

sub convertHTML2XDXF{
    # Converts html generated by KindleUnpack to xdxf
    my $encoding = shift @_;
    my $html = join('',@_);
    my @xdxf = @xdxf_start;
    # Content excerpt Duden 7. Auflage 2011:
        # <idx:entry scriptable="yes"><idx:orth value="a"></idx:orth><div height="4"><a id="filepos242708" /><a id="filepos242708" /><a id="filepos242708" /><div><sub> </sub><sup> </sup><b>a, </b><b>A </b><img hspace="0" align="middle" hisrc="Images/image15902.gif"/>das; - (UGS.: -s), - (UGS.: -s) [mhd., ahd. a]: <b>1.</b> erster Buchstabe des Alphabets: <i>ein kleines a, ein gro\xDFes A; </i> <i>eine Brosch\xFCre mit praktischen Hinweisen von A bis Z (unter alphabetisch angeordneten Stichw\xF6rtern); </i> <b>R </b>wer A sagt, muss auch B sagen (wer etwas beginnt, muss es fortsetzen u. auch unangenehme Folgen auf sich nehmen); <sup>*</sup><b>das A und O, </b>(SELTENER:) <b>das A und das O </b>(die Hauptsache, Quintessenz, das Wesentliche, Wichtigste, der Kernpunkt; urspr. = der Anfang und das Ende, nach dem ersten [Alpha] und dem letzten [Omega] Buchstaben des griech. Alphabets); <sup>*</sup><b>von A bis Z </b>(UGS.; von Anfang bis Ende, ganz und gar, ohne Ausnahme; nach dem ersten u. dem letzten Buchstaben des dt. Alphabets). <b>2.</b> &#139;das; -, -&#155; (MUSIK) sechster Ton der C-Dur-Tonleiter: <i>der Kammerton a, A.</i> </div></div></idx:entry><div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif"/></div> <idx:entry scriptable="yes"><idx:orth value="\xE4"></idx:orth><div height="4"><div><b>\xE4, </b><b>\xC4 </b><img hspace="0" align="middle" hisrc="Images/image15906.gif"/>das; - (ugs.: -s), - (ugs.: -s) [mhd. \xE6]: Buchstabe, der f\xFCr den Umlaut aus a steht.</div></div></idx:entry><div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif"/></div> <idx:entry scriptable="yes"><idx:orth value="a"></idx:orth><div height="4"><div><sup><font size="2">1&#8204;</font></sup><b>a</b><b> </b>= a-Moll; Ar.</div></div></idx:entry><div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif"/></div>
    # (The /xE6 was due to Perl output encoding set to UTF-8.)
    # Prettified:
        # <idx:entry scriptable="yes">
        #     <idx:orth value="a"></idx:orth>
        #     <div height="4"><a id="filepos242708" /><a id="filepos242708" /><a id="filepos242708" />
        #         <div><sub> </sub><sup> </sup><b>a, </b><b>A </b><img hspace="0" align="middle" hisrc="Images/image15902.gif" />das; - (UGS.: -s), - (UGS.: -s) [mhd., ahd. a]: <b>1.</b> erster Buchstabe des Alphabets: <i>ein kleines a, ein gro\xDFes A; </i> <i>eine Brosch\xFCre mit praktischen Hinweisen von A bis Z (unter alphabetisch angeordneten Stichw\xF6rtern); </i> <b>R </b>wer A sagt, muss auch B sagen (wer etwas beginnt, muss es fortsetzen u. auch unangenehme Folgen auf sich nehmen); <sup>*</sup><b>das A und O, </b>(SELTENER:) <b>das A und das O </b>(die Hauptsache, Quintessenz, das Wesentliche, Wichtigste, der Kernpunkt; urspr. = der Anfang und das Ende, nach dem ersten [Alpha] und dem letzten [Omega] Buchstaben des griech. Alphabets); <sup>*</sup><b>von A bis Z </b>(UGS.; von Anfang bis Ende, ganz und gar, ohne Ausnahme; nach dem ersten u. dem letzten Buchstaben des dt. Alphabets). <b>2.</b> &#139;das; -, -&#155; (MUSIK) sechster Ton der C-Dur-Tonleiter: <i>der Kammerton a, A.</i> </div>
        #     </div>
        # </idx:entry>
        # <div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif" /></div>
        # <idx:entry scriptable="yes">
        #     <idx:orth value="\xE4"></idx:orth>
        #     <div height="4">
        #         <div><b>\xE4, </b><b>\xC4 </b><img hspace="0" align="middle" hisrc="Images/image15906.gif" />das; - (ugs.: -s), - (ugs.: -s) [mhd. \xE6]: Buchstabe, der f\xFCr den Umlaut aus a steht.</div>
        #     </div>
        # </idx:entry>
        # <div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif" /></div>
        # <idx:entry scriptable="yes">
        #     <idx:orth value="a"></idx:orth>
        #     <div height="4">
        #         <div><sup>
        #                 <font size="2">1&#8204;</font>
        #             </sup><b>a</b><b> </b>= a-Moll; Ar.</div>
        #     </div>
        # </idx:entry>
        # <div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif" /></div>
    # Content excerpt Prettified:
        # <idx:entry>
        #     <idx:orth value="A">
        # </idx:entry>
        # <b>A N M</b>
        # <blockquote>Aulus (Roman praenomen); (abb. A./Au.); [Absolvo, Antiquo => free, reject];</blockquote>
        # <hr />
        # <idx:entry>
        #     <idx:orth value="Abba">
        # </idx:entry>
        # <b>Abba, undeclined N M</b>
        # <blockquote>Father; (Aramaic); bishop of Syriac/Coptic church; (false read obba/decanter);</blockquote>
        # <hr />
        # <idx:entry>
        #     <idx:orth value="Academia">
        #         <idx:infl>
        #             <idx:iform name="" value="Academia" />
        #             <idx:iform name="" value="Academiabus" />
        #             <idx:iform name="" value="Academiad" />
        #             <idx:iform name="" value="Academiae" />
        #             <idx:iform name="" value="Academiai" />
        #             <idx:iform name="" value="Academiam" />
        #             <idx:iform name="" value="Academiarum" />
        #             <idx:iform name="" value="Academias" />
        #             <idx:iform name="" value="Academiis" />
        #             <idx:iform name="" value="Academium" />
        #         </idx:infl>
        #         <idx:infl>
        #             <idx:iform name="" value="Academiaque" />
        #             <idx:iform name="" value="Academiabusque" />
        #             <idx:iform name="" value="Academiadque" />
        #             <idx:iform name="" value="Academiaeque" />
        #             <idx:iform name="" value="Academiaique" />
        #             <idx:iform name="" value="Academiamque" />
        #             <idx:iform name="" value="Academiarumque" />
        #             <idx:iform name="" value="Academiasque" />
        #             <idx:iform name="" value="Academiisque" />
        #             <idx:iform name="" value="Academiumque" />
        #         </idx:infl>
        # </idx:entry>
        # <b>Academia, Academiae N F</b>
        # <blockquote>academy, university; gymnasium where Plato taught; school built by Cicero;</blockquote>
        # <hr />
        # <idx:entry>
    # Duden entry around "früh"
        # <idx:entry scriptable="yes">
        #     <idx:orth value="früh"></idx:orth>
        #     <div height="4"><a id="filepos17894522" /><a id="filepos17894522" />
        #         <div><sub> </sub><sup> </sup><sup>
        #                 <font size="2">1&#8204;</font>
        #             </sup><b>fr</b><u><b><b>ü</b></b></u><b>h</b><b> </b>
        #             <mmc:no-fulltext>&#139;Adj.&#155; [mhd. vrüe(je), ahd. fruoji, zu: fruo, </mmc:no-fulltext>
        #             <mmc:fulltext-word value="‹Adj.› mhd. vrüeje, ahd. fruoji, zu: fruo, " /><a href="#filepos17896263">
        #                 <font size="+1"><b><img hspace="0" align="middle" hisrc="Images/image15907.gif" /></b></font> <sup>
        #                     <font size="-1">2</font>
        #                 </sup>früh
        #             </a>]: <b>1.</b> in der Zeit noch nicht weit fortgeschritten, am Anfang liegend, zeitig: <i>am -en Morgen; </i> <i>
        #                 <mmc:no-fulltext>in -er, -[e]ster Kindheit; </mmc:no-fulltext>
        #                 <mmc:fulltext-word value="in -er, -ester Kindheit; " />
        #             </i> <i>es ist noch f. am Tage; </i> <i>f. blühende Tulpen; </i> Ü <i>der -e (junge) Nietzsche; </i> Ü <i>die -esten (ältesten) Kulturen; </i> <sup>*</sup><b>von f. auf </b>(von früher Kindheit, Jugend an: <i>sie ist von f. auf an Selbstständigkeit gewöhnt). </i> <b>2.</b> früher als erwartet, als normalerweise geschehend, eintretend; frühzeitig, vorzeitig: <i>ein -er Winter; </i> <i>ein -er Tod; </i> <i>eine -e (früh reifende) Sorte Äpfel; </i> <i>wir nehmen einen -eren Zug; </i> <i>Ostern ist, fällt dieses Jahr f.; </i> <i>er kam -er als erwartet; </i> <i>sie ist zu f., noch f. genug gekommen; </i> <i>ihre f. (in jungen Jahren) verstorbene Mutter; </i> <i>ein f. vollendeter (in seiner Kunst schon in jungen Jahren zu absoluter Meisterschaft gelangter [u. jung verstorbener]) Maler; </i> <i>sie hat f. geheiratet; </i> <i>-er oder später (zwangsläufig irgendwann einmal) wird sie doch umziehen müssen.</i>
        #         </div>
        #     </div>
        # </idx:entry>
        # <div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif" /><br /></div>
        # <idx:entry scriptable="yes">
        #     <idx:orth value="früh"></idx:orth>
        #     <div height="4"><a id="filepos17896263" />
        #         <div><sup>
        #                 <font size="2">2&#8204;</font>
        #             </sup><b>fr</b><u><b><b>ü</b></b></u><b>h</b><b> </b>&#139;Adv.&#155; [mhd. vruo, ahd. fruo, eigtl. = (zeitlich) vorn, voran]: morgens, am Morgen: <i>heute f., [am] Dienstag f.; </i> <i>kommst du morgen f.?; </i> <i>er arbeitet von f. bis spät [in die Nacht] (den ganzen Tag).</i> </div>
        #     </div>
        # </idx:entry>
        # <div height="10" align="center"><img hspace="0" vspace="0" align="middle" losrc="Images/image15903.gif" hisrc="Images/image15904.gif" src="Images/image15905.gif" /><br /></div>
    # Clean images out of the html
    if( $html =~ m~<img[^>]+>~s and $isConvertImagesUsingOCR ){
        $html = convertIMG2Text( $html );
        if( $isTestingOn ){
            my $ConvertedIMG2TextHTML = $FileName;
            debug_t( $FileName );
            unless( $ConvertedIMG2TextHTML =~ s~html$~test.html~ ){ warn "Regex for filename for test.html does not match."; Die(); }
            string2File( $ConvertedIMG2TextHTML, $html );
        }
    }

    # my @indexentries = $html=~m~<idx:entry scriptable="yes">((?:(?!</idx:entry>).)+)</idx:entry>~gs; # Only works for Duden
    my @indexentries = $html=~m~<idx:entry[^>]*>((?:(?!<idx:entry).)+)~gs; # Collect from the start until the next starts.
    if( scalar @indexentries == 0 ){
        if ($html =~ m~<meta name="generator" content="ABBYY FineReader 15">~s){
            warn "Found meta content to be ABBYY FineReader 15. Trying convertABBYY2XDXF";
            return( convertABBYY2XDXF( $html ) );
        }
        else{
        warn "No idx-entry tags found in html. Trying convertRAWML2XDXF";
        return( convertRAWML2XDXF( $html ) );
        }
    }

    if($isTestingOn){ array2File("test_html_indexentries.html",map(qq/$_\n/,@indexentries)  ) ; }

    waitForIt("Converting indexentries from HTML to XDXF.");
    my $number = 0;
    my $lastkey = "";
    my $lastInflectionEntries="";
    my %ConversionDebugStrings;
    my ($TotalRemovalTime,$TotalImageConversion,$TotalEncodingConversionTime,$TotalConversion2SpanTime,$TotalArticleExtraction) = (0,0,0,0,0);
    foreach (@indexentries){
        my $TotalTime = 0;
        $number++;
        my $isLoopDebugging = 0;
        if(m~<idx:orth value="\Q$DebugKeyWordConvertHTML2XDXF\E"~ and $isTestingOn){ $isLoopDebugging = 1; }
        debug($_) if $isLoopDebugging;
        # Removal of tags
        my $start = time;
        # Remove <a />, </a>, </idx:entry>, <br/>, <hr />, <betonung/>, <mmc:fulltext-word ../> tags
        s~</?a[^>]*>|<betonung\s*/>|</idx:entry>|<br\s*/>|<hr\s*/>|<mmc:fulltext-word[^>]+>~~sg;
        # Remove empty tag-pairs
        $_ = removeEmptyTagPairs( $_ );
        $TotalRemovalTime += time - $start;
        # Convert or remove <img...>, e.g. <img hspace="0" align="middle" hisrc="Images/image15907.gif" />
        $start = time;
        if( $isConvertImagesUsingOCR and m~<img[^>]+>~s ){ $_ = convertIMG2Text( $_ ); }
        if( $isCodeImageBase64       and m~<img[^>]+>~s ){ $_ = convertImage2Base64( $_ ); }
        else{  s~<img[^>]+>~~sg; } # No images-resources are used in xdxf.
        $TotalImageConversion += time - $start;

        # Include encoding conversion
        $start = time;
        while( $encoding eq "cp1252" and m~\&\#(\d+);~s ){
            my $encoded = $1;
            my $decoded = decode( $encoding, pack("N", $encoded) );
            # The decode step generates four hex values: a triplet of <0x00> followed by the one that's wanted. This goes awry if there are multiple non-zero octets.
            while( ord( substr( $decoded, 0, 1) ) == 0 ){
                $decoded = substr( $decoded, 1 );
            }
            # Skip character because it cannot be handled by code and is most probably the same in cp1252 and unicode.
            if( length($decoded)>1 ){
                # Convert to hexadecimal value so that the while-loop doesn't become endless.
                my $hex = sprintf("%X", $encoded);
                $decoded = "&#x$hex;";
            }
            # If character is NL, than replacement should be \n
            elsif( ord($decoded) == 12 ){ $decoded = "\n";}
            my $DebugString = "Encoding is $encoding. Encoded is $encoded. Decoded is \'$decoded\' of length ".length($decoded).", numbered ".ord($decoded);
            $ConversionDebugStrings{$encoded} = $DebugString;
            s~\&\#$encoded;~$decoded~sg;
        }
        $TotalEncodingConversionTime += time - $start;
        # Change div-blocks to spans
        if( $isConvertDiv2SpaninHTML2DXDF ){ s~(</?)div[^>]*>~$1span>~sg; }
        my $round = 0;
        # Change font- to spanblocks
        $start = time;
        while( $isConvertFont2Small and s~<font size="(?:2|-1)">((?:(?!</font).)+)</font>~<small>$1</small>~sg ){
            $round++;
            debug("font-blocks substituted with small-blocks in round $round.") if m~<idx:orth value="$DebugKeyWordConvertHTML2XDXF"~;
        }
        $round = 0;
        while( $isConvertFont2Span and s~<font(?<fontstyling>[^>]*)>(?<content>(?:(?!</font).)*)</font>~<span$+{"fontstyling"}>$+{"content"}</span>~sg ){
            $round++;
            debug("font-blocks substituted with span-blocks in round $round.") if m~<idx:orth value="$DebugKeyWordConvertHTML2XDXF"~;
        }
        # Change <mmc:no-fulltext> to <span>
        $round = 0;
        while( $isConvertMMCFullText2Span and s~<mmc:no-fulltext>((?:(?!</mmc:no-fulltext).)+)</mmc:no-fulltext>~<span> $1</span>~sg ){
            $round++;
            debug("<mmc:no-fulltext>-blocks substituted with spans in round $round.") if $number<3;
        }
        $TotalConversion2SpanTime = time - $start;
        # Create key&definition strings.
        $start = time;
        # m~^<idx:orth value="(?<key>[^"]+)"></idx:orth>(?<def>.+)$~s; # Works only for Duden
        s~<idx:orth value="(?<key>[^"]+)">~~s; # Remove idx-orth value.
        my $key = $+{key};
        if( defined $key and $key ne "" ){    debug("Found \$key $key.") if $isLoopDebugging; }
        else{ debug("No key found! Dumping and Quitting:\n\n$_"); die;}
        s~</idx:orth>~~sg; # Remove closing tag if present.

        #Handle inflections block
        # Remove inflections category tags
        s~</?idx:infl>~~sg;
        # <idx:iform name="" value="Academia" />
        my @inflections = m~<idx:iform name="" value="(\w*)"/>~sg;
        s~<idx:iform[^>]*>~~sg;
        my $InflectionEntries="";
        foreach my $inflection(@inflections){
            # Create string to append after main definition.
            if( defined $inflection and $inflection ne $key and $inflection ne "" ){
                my $ExtraEntry = "<ar><head><k>$inflection</k></head><def><blockquote>↑".pack("U", 0x2009)."<i>$key</i></blockquote></def></ar>\n";
                $InflectionEntries = $InflectionEntries.$ExtraEntry;
            }
        }

        # Remove leftover empty lines.
        s~  ~ ~sg;
        s~\t\t~\t~sg;
        s~\n\n~\n~sg;
        # Remove trailing and leading spaces and line endings
        s~^\s+~~sg;
        s~\s+$~~sg;

        # Assign remaining entry to $def.
        my $def = "<blockquote>".$_."</blockquote>";
        debugV("key found: $key") if $number<5;
        debugV("def found: $def") if $number<5;
        # Remove whitespaces at the beginning of the definition and EOL at the end.
        $def =~ s~^\s+~~;
        $def =~ s~\n$~~;
        # Switch position sup/span/small blocks
        # <sup><small>1&#8204;</small></sup>
        # $html =~ s~<sup><small>([^<]*)</small>~<sup>$1~sg;
        $def =~ s~<sup><small>([^<]*)</small></sup>~<small><sup>$1</sup></small>~sg;
        # $html =~ s~<sup><span>([^<]*)</span>~<sup>$1~sg;
        $def =~ s~<sup><span>([^<]*)</span></sup>~<span><sup>$1</sup></span>~sg;
        $def =~ s~<sub><small>([^<]*)</small></sub>~<small><sub>$1</sub></small>~sg;
        $def =~ s~<sub><span>([^<]*)</span></sub>~<span><sub>$1</sub></span>~sg;
        # Put space in front of ‹, e.g. ‹Adj.›, if it's lacking
        $def =~ s~([^\s])‹~$1 ‹~sg;
        if( $key eq $lastkey){
            # Change the last entry to append current definition
            $xdxf[-1] =~ s~</def></ar>\n~\n$def</def></ar>\n~s;
            debug("Added to the last definition. It's now:\n$xdxf[-1]") if $isLoopDebugging;
        }
        else{
            # Because I want the inflections to follow in the index on the full definition.
            if( $lastInflectionEntries ne "" ){
                $xdxf[-1] =~ s~\n$~\n$lastInflectionEntries~s;
                $lastInflectionEntries = "";
            }
            push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
            debug("Pushed <ar><head><k>$key</k></head><def>$def</def></ar>") if $isLoopDebugging;
        }
        # To allow appending definitions of identical keys
        $lastkey = $key;
        # To allow inflection entries after the main entry
        $lastInflectionEntries = $lastInflectionEntries.$InflectionEntries;
        $TotalArticleExtraction += time - $start;
        my @Names = ("TotalRemovalTime","TotalImageConversion","TotalEncodingConversionTime","TotalConversion2SpanTime","TotalArticleExtraction");
        foreach($TotalRemovalTime,$TotalImageConversion,$TotalEncodingConversionTime,$TotalConversion2SpanTime,$TotalArticleExtraction){
            my $Name = shift @Names;
            infoVV("$Name: $_");
            $TotalTime += $_;
        }
        infoVV("Total time in loop: $TotalTime");
    }

    foreach( sort keys %ConversionDebugStrings){ debug($ConversionDebugStrings{$_}); }
    doneWaiting();
    push @xdxf, $lastline_xdxf;
    return(@xdxf);}
our $isConvertGIF2PNG                 = 0; # Creates a dependency on Imagemagick "convert".
our (%ReplacementImageStrings, $ReplacementImageStringsHashFileName);
sub convertImage2Base64{
    $_ =  shift;
    my @imagestrings = m~(<img[^>]+>)~sg;
    debug("Number of imagestrings found is ", scalar @imagestrings) if m~<idx:orth value="$DebugKeyWordConvertHTML2XDXF"~;
    my $replacement;
    foreach my $imagestring(@imagestrings){
        # debug('$ReplacementImageStrings{$imagestring}: ',$ReplacementImageStrings{$imagestring});
        if ( exists $ReplacementImageStrings{$imagestring} ){
            $replacement = $ReplacementImageStrings{$imagestring}
        }
        else{
            # <img hspace="0" align="middle" hisrc="Images/image15907.gif"/>
            $imagestring =~ m~hisrc="(?<image>[^"]*?\.(?<ext>gif|jpg|png|bmp))"~si;
            debug("Found image named $+{image} with extension $+{ext}.") if m~<idx:orth value="$DebugKeyWordConvertHTML2XDXF"~;
            my $imageName = $+{image};
            my $imageformat = $+{ext};
            if( -e "$FullPath/$imageName"){
                if ( $isConvertGIF2PNG and $imageformat =~ m~gif~i){
                    # Convert gif to png
                    my $Command="convert \"$FullPath/$imageName\" \"$FullPath/$imageName.png\"";
                    debug("Executing command: $Command") if m~<idx:orth value="$DebugKeyWordConvertHTML2XDXF"~;
                    `$Command`;
                    $imageName = "$imageName.png";
                    $imageformat = "png";
                }
                my $image = join('', file2Array("$FullPath/$imageName", "raw", "quiet") );
                my $encoded = encode_base64($image);
                $encoded =~ s~\n~~sg;
                $replacement = '<img src="data:image/'.$imageformat.';base64,'.$encoded.'" alt="'.$imageName.'"/>';
                $replacement =~ s~\\\"~"~sg;
                debug($replacement) if m~<idx:orth value="$DebugKeyWordConvertHTML2XDXF"~;
                $ReplacementImageStrings{$imagestring} = $replacement;
            }
            else{
                $replacement = ""; 
                Die("Can't find $FullPath/$imageName. Quitting.");
            }
        }
        s~\Q$imagestring\E~$replacement~;
    }
    return $_;}
our $isManualValidation = 1; # Default value
our $isRemoveUnSubstitutedImageString = 1;
our $isRemoveUnSourcedImageStrings    = 1;
our (%OCRedImages, %ValidatedOCRedImages, $ValidatedOCRedImagesHashFileName);
sub convertIMG2Text{
    my $String = shift;
    info_t("Entering convertIMG2Text");
    debugVV( $String."\n");

    # Get absolute ImagePath
    my $CurrentDir = `pwd`; chomp $CurrentDir;
    unless( $CurrentDir eq $BaseDir){ warn "'$CurrentDir' is another than '$BaseDir'"; }
    else{ infoV("Working from '$BaseDir'"); }
    infoV("$FileName");
    unless( $FileName =~ m~(?<localpath>.+?)[^/]+$~ ){ warn "Regex didn't match for local path"; Die(); }
    my $ImagePath = $CurrentDir . "/" . $+{localpath};
    debugV( "Imagepath is '$ImagePath'");

    # Collect ImageStrings;
    my @ImageStrings = $String =~ m~(<img[^>]+>)~sg;
    unless( scalar @ImageStrings ){ warn "No imagestrings found in convertIMG2Text. Why is the sub called?"; return $String; }

    my $counter = 0;
    my %ImageStringsHandled;
    IMAGESTRING: foreach my $ImageString( @ImageStrings){
        # Deal with already handled imagestrings in $String.
        if( $ImageStringsHandled{ $ImageString } ){ next; }
        # Unhandled imagestring.
        $counter++;
        if( $ImageString =~ m~alt="x([0-9A-Fa-f]+)"~ ){
            infoV("Alternative expression for image is U+$1.");
            # my $smiley_from_code_point = "\N{U+263a}";
            my $Alt = chr( hex($1) );
            if( $String =~ s~\Q$ImageString\E~$Alt~sg ){
                infoV("Substituted imagestring '$ImageString' with '$Alt'");
                $ImageStringsHandled{ $ImageString } = 1;
                next IMAGESTRING;
            }
            else{ warn "Regex substitution alternative expression doesn't work."; Die(); }
        }
        my @Sources = $ImageString =~ m~(\w*src="[^"]+")~sg;
        unless( scalar @Sources ){
            warn "No sources found in imagestring:\n'$ImageString'";
            $ImageStringsHandled{ $ImageString } = 1;
            if( $isRemoveUnSourcedImageStrings ){
                unless( $String =~ s~\Q$ImageString\E~~sg){ warn "Couldn't remove unsourced imagestring"; Die(); }
                next IMAGESTRING;
            }
        }

        our %Sources;
        foreach( @Sources ){
            unless( m~(?<type>\w*src)="(?<imagename>[^"]+)"~s ){ warn "Regex sources doesn't work."; Die(); }
            $Sources{ $+{"imagename"} } = $+{"type"};
        }
        our %SourceQuality = { "src" => 1, "hisrc" => 2, "lowsrc" => 0 };
        sub sourceQuality{
            # Filename to src/hisrc/losrc to 1/2/0
            # Descending sort so $a and $b are swapped.
            $SourceQuality{ $Sources{ $b } } <=> $SourceQuality { $Sources { $a } }
        }
        SOURCE: foreach my $Source ( sort sourceQuality keys %Sources ){
            # Change to absolute path
            my $SourceInfo = "Quality of '$Source' is '$Sources{ $Source }'";
            $Source = $ImagePath . $Source;
            # If the source has been validated, act upon it.
            if( exists $ValidatedOCRedImages{ $Source } ){
                if( defined $ValidatedOCRedImages{ $Source } and $ValidatedOCRedImages{ $Source } ne "VALIDATED AS INCORRECT" ){
                    unless ( $String =~ s~\Q$ImageString\E~$ValidatedOCRedImages{ $Source }~sg ){
                        warn "ImageString '$ImageString' not matched for substitution with '$ValidatedOCRedImages{ $Source }'."; Die();
                    }
                    else{
                        infoV("ImageString '$ImageString' substituted with '$ValidatedOCRedImages{ $Source }'.");
                    }
                    $ImageStringsHandled{ $ImageString } = 1;
                    next IMAGESTRING;
                }
                else{ next SOURCE; }
            }
            # No validated recognition of source image available.
            elsif( $isManualValidation ){
                unless( -e $Source ){ warn "Image file '$Source' not found."; next SOURCE; }
                # No use in running the OCR twice.
                unless( exists $OCRedImages{ $Source } ){
                    my $text = get_ocr( $Source, undef, "eng+equ --psm 10" );
                    chomp $text;
                    info_t( "Imagestring =\n'".$ImageString."'");
                    info_t( $SourceInfo );
                    info( "Tesseract identified image '$Source' as '$text'");
                    $OCRedImages{ $Source } = $text;
                }
                if( $OCRedImages{ $Source } eq '' ){ debug("No result from OCR."); }

                # Validate OCRedImages manually and store them or quit.
                my $substitution = 0;
                system("feh --borderless --auto-zoom --image-bg white --geometry 300x300 \"$Source\"&");
                printGreen("\n\n--------->Is the image '$Source' correctly recognized as '".$OCRedImages{$Source}."'?\nPress enter to keep or provide a correction or quit manual validation [Enter|Provide correction|No|quit]");
                my $input = <STDIN>;
                system( "killall feh 2>/dev/null");
                chomp $input;
                if( $input =~ m~quit~i ){
                    $isManualValidation = 0;
                    next SOURCE;
                }
                elsif( $input eq ''){
                    $ValidatedOCRedImages{ $Source } = $OCRedImages{ $Source };
                    $substitution = 1;
                }
                elsif( $input =~ m~no~i ){
                    $ValidatedOCRedImages{ $Source } = "VALIDATED AS INCORRECT";
                    $substitution = 0;
                }
                else{
                    $ValidatedOCRedImages{ $Source } = $input;
                    $substitution = 1;
                }
                storeHash(\%ValidatedOCRedImages, $ValidatedOCRedImagesHashFileName);

                if( $substitution ){
                    unless ( $String =~ s~\Q$ImageString\E~$ValidatedOCRedImages{ $Source }~sg ){
                        warn "ImageString '$ImageString' not matched for substitution with '$ValidatedOCRedImages{ $Source }'";
                        Die();
                    }
                    $ImageStringsHandled{ $ImageString } = 1;
                    next IMAGESTRING;
                }
            }
        }
        # End SOURCE-loop. If the code is here, than no substitution has been made for the imagestring.
        if( $isRemoveUnSubstitutedImageString ){
            unless( $String =~ s~\Q$ImageString\E~~sg ){ warn "Image-tag '$ImageString' could not be removed"; Die(); }
            $ImageStringsHandled{ $ImageString } = 1;
        }
    }
    infoV("Leaving convertIMG2Text");
    return $String;}
sub convertRAWML2XDXF{
    # Converts html generated by KindleUnpack to xdxf
    my $rawml = join('',@_);
    my $xdxf_try =  generateXDXFTagBased( $rawml );
    if( $xdxf_try ){ return (@{ $xdxf_try }); }
    my @xdxf = @xdxf_start;
    # Snippet Rawml
    #<html><head><guide><reference title="Dictionary Search" type="search" onclick="index_search()"/></guide></head><body><mbp:pagebreak/><p>Otwarty słownik hiszpańsko-polski</p> <p>Baza tłumaczeń: 2010 Jerzy Kazojć – CC-BY-SA</p> <p>Baza odmian: Athame – GPL3</p> <mbp:pagebreak/><mbp:frameset> <mbp:pagebreak/><h3> a </h3> ku, na, nad, o, po, przy, u, w, za <hr/> <h3> abacero </h3> sklepikarz <hr/> <h3> ábaco </h3> abakus, liczydło <hr/> <h3> abad </h3> opat <hr/> <h3> abadejo </h3> dorsz <hr/> <h3> abadía </h3> opactwo <hr/> <h3> abajo </h3> dolny <hr/> <h3> abalanzar </h3> równoważyć <hr/> <h3> abalanzarse </h3> rzucać, rzucić <hr/> <h3> abalear </h3> przesiewać, wiać <hr/> <h3> abanar </h3> chwiać, potrząsać, trząść, wstrząsać <hr/> <h3> abanderado </h3> chorąży, lider <hr/> <h3> abandonado </h3> opuszczony, porzucony <hr/> <h3> abandonar </h3> opuścić, opuszczać, porzucać, porzucić, pozostawiać, zaniechać, zostawiać, zrezygnować <hr/>

    # Prettified rawml
    # <html>

    # <head>
    #     <guide>
    #         <reference title="Dictionary Search" type="search" onclick="index_search()" />
    #     </guide>
    # </head>

    # <body>
        # <mbp:pagebreak />
        # <p>Otwarty słownik hiszpańsko-polski</p>
        # <p>Baza tłumaczeń: 2010 Jerzy Kazojć – CC-BY-SA</p>
        # <p>Baza odmian: Athame – GPL3</p>
        # <mbp:pagebreak />
        # <mbp:frameset>
            # <mbp:pagebreak />
            # <h3> a </h3> ku, na, nad, o, po, przy, u, w, za
            # <hr />
            # <h3> abacero </h3> sklepikarz
            # <hr />
            # <h3> ábaco </h3> abakus, liczydło
            # <hr />
            # <h3> abad </h3> opat
            # <hr />
            # <h3> abadejo </h3> dorsz
            # <hr />
            # ...
            # ...
            # ...
            # <h3> zurriago </h3> bat, batog, bicz, bykowiec, knut, pejcz, szpicruta
            # <hr />
        #     <h3> zurrir </h3> śmiać
        # </mbp:frameset>
        # <mbp:pagebreak />
    # </body>

    # </html>

    # <body topmargin="0" leftmargin="0" rightmargin="0" bottommargin="0">
    #     <div align="center" bgcolor="yellow">
    #         <p>Dictionary Search</p>
    #     </div>
    # </body>

    my (@indexentries, $headervalue);
    for( $headervalue = 3; $headervalue > 0; $headervalue--){
        debug( "headervalue = $headervalue.   scalar \@indexentries = ".scalar @indexentries);
        @indexentries = $rawml=~m~(<h(?:$headervalue)>(?:(?!<hr|<mbp).)+)<hr ?/>~gs; # Collect from the start until the next starts.
        if( @indexentries > 10 ){ last; }
    }
    unless( @indexentries ){
        warn("No indexentries found in rawml-string. Quitting");
        Die($rawml);
        goto DONE; # In case $isRealDead = 0
    }
    else{ info("Found ".scalar @indexentries." indexentries.\n"); }
    waitForIt("Converting indexentries from RAWML to XDXF.");
    my $isLoopDebugging = 1;
    my $lastkey = "";
    my $number = 0;
    foreach (@indexentries){
        $number++;
        # Create key&definition strings.
        # <h3> zurrir </h3> śmiać
        debug( "headervalue = $headervalue") if $number < 5;
        s~<h(?:$headervalue)> ?(?<key>[^<]+)</h(?:$headervalue)>~~s; # Remove h3-block value.
        my $key = $+{key};
        if( defined $key and $key ne "" ){  debug("Found \$key $key.") if $isLoopDebugging; $isLoopDebugging++ if $isLoopDebugging; $isLoopDebugging = 0 if $isLoopDebugging == 10; }
        else{ debug("No key found! Dumping and Quitting:\n\n$_"); die;}
        # Remove leftover empty lines.
        s~  ~ ~sg;
        s~\t\t~\t~sg;
        s~\n\n~\n~sg;
        # Remove trailing and leading spaces and line endings
        s~^\s+~~sg;
        s~\s+$~~sg;

        # Assign remaining entry to $def.
        my $def = "<blockquote>".$_."</blockquote>";
        # Remove trailing space from key.
        $key =~ s~\s+$~~sg;
        debugV("key found: $key") if $number<5;
        debugV("def found: $def") if $number<5;
        # Remove whitespaces at the beginning of the definition and EOL at the end.
        $def =~ s~^\s+~~;
        $def =~ s~\n$~~;
        # $html =~ s~<sup><span>([^<]*)</span>~<sup>$1~sg;
        $def =~ s~<sup><span>([^<]*)</span></sup>~<span><sup>$1</sup></span>~sg;
        $def =~ s~<sub><small>([^<]*)</small></sub>~<small><sub>$1</sub></small>~sg;
        $def =~ s~<sub><span>([^<]*)</span></sub>~<span><sub>$1</sub></span>~sg;
        # Put space in front of ‹, e.g. ‹Adj.›, if it's lacking
        $def =~ s~([^\s])‹~$1 ‹~sg;
        if( $key eq $lastkey){
            # Change the last entry to append current definition
            $xdxf[-1] =~ s~</def></ar>\n~\n$def</def></ar>\n~s;
            debug("Added to the last definition. It's now:\n$xdxf[-1]") if $isLoopDebugging;
        }
        else{
            push @xdxf, "<ar><head><k>$key</k></head><def>$def</def></ar>\n";
            debug("Pushed <ar><head><k>$key</k></head><def>$def</def></ar>") if $isLoopDebugging;
        }
        # To allow appending definitions of identical keys
        $lastkey = $key;
    }
    DONE:
    doneWaiting();
    push @xdxf, $lastline_xdxf;
    return(@xdxf);}
sub convertStardictXMLtoXDXF{
    my $StardictXML = join('',@_);
    my @xdxf = @xdxf_start;
    # Extract bookname from Stardict XML
    if( $StardictXML =~ m~<bookname>(?<bookname>((?!</book).)+)</bookname>~s ){
        my $bookname = $+{bookname};
        # xml special symbols are not recognized by converter in the dictionary title.
        $bookname = unEscapeHTMLString( $bookname);
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
    my $ExtraDescription = ".";
    my $SourceAuthor = "";
    my $SourceEmail = "";
    my $SourceWebsite = "";
    my $SourceDescription = "";
    if( $StardictXML =~ m~<author>(?<sourceauthor>((?!</author>).)+)</author>~s ){
        $SourceAuthor = " Source author is ". unEscapeHTMLString( $+{sourceauthor} ).".";
    }
    if( $StardictXML =~ m~<email>(?<sourceemail>((?!</email>).)+)</email>~s ){
        $SourceEmail = " Source email is ". unEscapeHTMLString( $+{sourceemail} ).".";
    }
    if( $StardictXML =~ m~<website>(?<SourceWebsite>((?!</website>).)+)</website>~s ){
        $SourceWebsite = " Source website is ". unEscapeHTMLString( $+{SourceWebsite} ).".";
    }
    if( $StardictXML =~ m~<description>(?<SourceDescription>((?!</description>).)+)</description>~s ){
        $SourceDescription = " Source description is ". unEscapeHTMLString( $+{SourceDescription} );
    }
    $ExtraDescription .= $SourceAuthor.$SourceDescription.$SourceEmail.$SourceWebsite;
    substr($xdxf[5], 29, 0 ) = $ExtraDescription;

    waitForIt("Converting stardict-xml to xdxf-xml.");
    # Initialize variables for collection
    my ($key, $def, $article, $definition) = ("","", 0, 0);
    # Initialize variables for testing
    my ($test_loop, $counter,$max_counter) = (0,0,40) ;
    foreach(@_){
        $counter++;
        # Change state to article
        if(m~<article>~){ $article = 1; debug("Article start tag found at line $counter.") if $test_loop;}

        # Match key within article outside of definition
        if($article and !$definition and m~<key>(?<key>((?!</key>).)+)</key>~){
            $key = $+{key};
            debug("Key \"$key\" found at line $counter.") if $test_loop;
        }
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
        Die() if $counter==$max_counter and $test_loop;
    }
    doneWaiting();
    push @xdxf, $lastline_xdxf;
    return(@xdxf);}
sub convertXDXFtoStardictXML{
    # Usage: my @xml = convertXDXFtoStardictXML( @xdxf );
    my $xdxf = join('',@_);
    $xdxf = removeInvalidChars( $xdxf );
    my @xml = @xml_start;
    if( $xdxf =~ m~<full_name>(?<bookname>((?!</full_name).)+)</full_name>~s ){
        my $bookname = $+{bookname};
        # xml special symbols are not recognized by converter in the dictionary title.
        $bookname = unEscapeHTMLString( $bookname );
        substr($xml[4], 10, 0) = $bookname;
    }
    if( $xdxf =~ m~<date>(?<date>((?!</date>).)+)</date>~s ){
        substr($xml[9], 6, 0) = $+{date};
    }
    my $Description="";
    if( $xdxf =~ m~<xdxf (?<XDXFDescription>((?!>).)+)>~s ){
        $Description .= $+{XDXFDescription};
    }
    if( $xdxf =~ m~<description>(?<DescriptionBlock>((?!</description>).)+)</description>~s ){
        $Description .= ". ".$+{DescriptionBlock};
        $Description =~ s~<date></date>\n*~~s;
        $Description =~ s~<date>(?<sourcedate>((?!</date>).)+)</date>~Date Source: $+{sourcedate}~;
    }
    substr($xml[8], 13, 0) = $Description;
    waitForIt("Converting xdxf-xml to Stardict-xml." );
    my @articles = $xdxf =~ m~<ar>((?:(?!</ar).)+)</ar>~sg ;
    printCyan("Finished getting articles at ", getLoggingTime(),"\n" );
    $cycle_dotprinter = 0;
    my $PreviousKey = "";
    foreach my $article ( @articles){
        $cycle_dotprinter++; if( $cycle_dotprinter == $cycles_per_dot){ printGreen("."); $cycle_dotprinter=0;}
        # <head><k>a</k></head>
        $article =~ m~<head><k>(?<key>((?!</k).)+)</k>~s;
        my $CurrentKey = escapeHTMLString($+{key});
        $article =~ m~<def>(?<definition>((?!</def).)+)</def>~s;
        my $CurrentDefinition = $+{definition};
        # Append the current definition to the previous one
        if( $CurrentKey ne $PreviousKey){
            push @xml, "<article>\n";
            push @xml, "<key>".$CurrentKey."</key>\n\n";
            push @xml, '<definition type="'.$SameTypeSequence.'">'."\n";
            push @xml, '<![CDATA['.$CurrentDefinition.']]>'."\n";
            push @xml, "</definition>\n";
            push @xml, "</article>\n\n";
            $PreviousKey = $CurrentKey;
        }
        else{
            my $PreviousStopArticle = pop @xml;
            my $PreviousStopDefinition = pop @xml;
            my $PreviousCDATA = pop @xml;
            if ( '<![CDATA['.$CurrentDefinition.']]>'."\n" eq "$PreviousCDATA" ){ debug("Double entry found. Skipping!"); next;}
            debugV("\n\$CurrentKey:\n\"", $CurrentKey, "\"");
            debugV("\$CurrentDefinition:\n\"", $CurrentDefinition, "\"");
            debugV("\$PreviousStopArticle:\n\"", $PreviousStopArticle, "\"");
            debugV("\$PreviousStopDefinition:\n\"", $PreviousStopDefinition, "\"");
            debugV("\$PreviousCDATA:\n\"", $PreviousCDATA, "\"");
            debugV("Quitting before anything is tested. If testing is OK: remove next 'die'-statement");
            my $PreviousDefinition = $PreviousCDATA;
            $PreviousDefinition =~ s~^<!\[CDATA\[(?<definition>.+?)\]\]>\n$~$+{definition}~s;
            debugV("\$PreviousDefinition:\n\"", $PreviousDefinition, "\"");
            my $UpdatedCDATA = '<![CDATA[' . fixPrefixes($PreviousDefinition,$CurrentDefinition) . "]]>\n";
            debugV("\$UpdatedCDATA:\n\"",$UpdatedCDATA, "\"");
            push @xml, $UpdatedCDATA, $PreviousStopDefinition, $PreviousStopArticle;
        }
    }
    push @xml, "\n";
    push @xml, $lastline_xml;
    push @xml, "\n";
    doneWaiting();
    return( checkXMLBookname( @xml ) );}
sub convertXML2Binary{
    # Convert reconstructed XML-file to binary
    # Usage: convertXML2Binary( Filename-with-extension-xml );
    if ( $OperatingSystem eq "linux"){
        my $dict_xml = shift;
        my $dict_bin = $dict_xml;
        $dict_bin =~ s~\.xml~\.ifo~;
        my $command = "stardict-text2bin \"$BaseDir/$dict_xml\" \"$BaseDir/$dict_bin\" ";
        printYellow("Running system command:\n$command\n");
        system($command);
        # Workaround for dictzip
        if( $dict_bin =~ m~ |\(|\)~ ){
            debug_t("Spaces or braces found, so dictzip will have failed. Running it again while masking the spaces.");
            if( $dict_bin !~ m~(?<filename>[^/]+)$~){ debug("Regex not working for dictzip workaround."); Die(); }
            my $SpacedFileName = $+{filename};

            my $Path = $dict_bin;
            if( $Path =~ s~\Q$SpacedFileName\E~~ ){ debug("Changing to path $Path"); }
            unless( chdir $Path ){ warn "Couldn't change directory to '$Path'"; }
            else{ info_t("Directory change successfull."); }

            $SpacedFileName =~ s~ifo$~dict~;
            my $MaskedFileName = $SpacedFileName;
            $MaskedFileName =~ s~ ~__~g;
            $MaskedFileName =~ s~\(~___~g;
            $MaskedFileName =~ s~\)~____~g;

            if( -e $SpacedFileName ){ rename "$SpacedFileName", "$MaskedFileName"; }
            else{ warn "Couldn't find '$SpacedFileName'."; }
            my $command = "dictzip $MaskedFileName";
            printYellow("Running system command:\n$command\n");
            system($command);
            unless( rename "$MaskedFileName.dz", "$SpacedFileName.dz"){ warn "Couldn't rename '$MaskedFileName.dz'"; }
        }
        else{ debug("No spaces in filename."); debug("\$dict_bin is \'$dict_bin\'"); }
    }
    else{
        debug("Not linux, so the script created an XML Stardict dictionary.");
        debug("You'll have to convert it to binary manually using Stardict editor.")
    }
}

our $HigherFrequencyTags = 10 ; # Tags below this frequency, e.g. 10 times, are considered lower frequency.
our $isDeleteLowerFrequencyTagsinFilterTagsHash = 0 ; # And the consequeces of that can be toggled, too.
our $isExcludeImgTags    = 1 ; # <img.../>-tags are removed if toggle is positive.
our $isgatherSetsVerbose = 0 ;    # Controls verbosity of tag functions
our $isRemoveMpbAndBodyTags = 0 ; # <mbp...> and <body>-tags are removed if toggle is positive.
our $isSkipKnownStylingTags = 1 ; # <b>-, <i>-tags and such are usually not relevant for structuring lemma/definition pairs. However, <font...>-tags sometimes are. So check.
our $MinimumSetPercentage = 80 ; # A tag-set should be at least this percentage to be considered the outer tags for an article.
sub generateXDXFTagBased{
    info("\nEntering generateXDXFTagBased");
    my $rawml = join('', @_);
    # $rawml = removeEmptyTagPairs( $rawml ); # Don't because they can be deliminating, acting as a separator between articles.

    my %Info;
    $Info{ "isExcludeImgTags" }     = $isExcludeImgTags;
    $Info{ "isSkipKnownStylingTags" } = $isSkipKnownStylingTags;
    $Info{ "HigherFrequencyTags"}   = $HigherFrequencyTags;
    $Info{ "isDeleteLowerFrequencyTagsinFilterTagsHash" } = $isDeleteLowerFrequencyTagsinFilterTagsHash;
    $Info{ "isRemoveMpbAndBodyTags"} = $isRemoveMpbAndBodyTags;
    $Info{ "minimum set percentage"}= $MinimumSetPercentage;
    $Info{ "rawml" }                = \$rawml;

    sub countTagsAndLowerCase{
        # Generates 2 hash references in %Info named "lowered stop-tags" and "counted tags hash".
        # Usage: countTagsAndLowerCase( \%Info );
        my $Info = shift;
        my (%tags, %LoweredStopTags);
        my $rawml = ${ $$Info{ "rawml" } };
        foreach(@{ $$Info{ "tags" } } ){
            if( m~^</[A-Z0-9]+>$~ ){
                my $lc = lc($_);
                unless( $LoweredStopTags{$_} ){
                    debug("Upper case stop tag '$_'. Lowering it.");
                    $rawml =~ s~\Q$_\E~$lc~g;
                }
                $LoweredStopTags{$_} = 1;
                $_ = $lc;
            }
            if( $tags{$_} ){ $tags{$_} = 1 + $tags{$_} ; }
            else{ $tags{$_} = 1; }
        }
        $$Info{ "rawml with lowered stop-tags"} = \$rawml;
        $$Info{ "lowered stop-tags"} = \%LoweredStopTags;
        $$Info{ "counted tags hash"} = \%tags;}
    sub filterTagsHash{
        # Usage: filterTagsHash( \%Info );
        # Uses the hash keys "counted tags hash" and "rawml".
        # Generates 4 keys in given hash, resp. "removed tags", "filtered rawml", "filtered tags hash" and "deleted tags".

        my $Info = shift;
        my %tags = %{ $$Info{ "counted tags hash" } };
        my $rawml = ${ $$Info{ "rawml with lowered stop-tags"} };
        my (%DeletedTags, %LowerFrequencyTags);
        sub sorttags{
            sub stripped{
                my $c = shift;
                $c =~ s~</?~~;
                return $c;
            }
            $tags{$a} <=> $tags{$b} or
            &stripped($a) cmp &stripped($b) or
            $a cmp $b}
        foreach( sort sorttags keys %tags ){
            if( m~</?a( |>)|</?i( |>)|</?b( |>)|</?font( |>)~i){
                unless( $DeletedTags{ substr($_, 0, 5) } ){ debug("Deleted '$_' from list of tags."); }
                $DeletedTags{ substr($_, 0, 5) } = 1;  # Use of substr to prevent flooding with anchor references.
                delete $tags{$_};     # Skip known styling.
            }
            elsif( m~^<img[^>]+>$~ and $$Info{ "isExcludeImgTags" } ){ delete $tags{$_}; }             # Remove img-tags if they're excluded
            # This also eliminates low  frequency <div .....> even if there are high frequency <div>-tags, leading to different counts for start- and stop-tags.
            elsif ( $tags{$_} > $$Info{ "HigherFrequencyTags"} ){ print "\$tags{$_} = $tags{$_}\n";}  # Keep and print higher frequency tags
            elsif ( $$Info{ "isDeleteLowerFrequencyTagsinFilterTagsHash" } ){
                unless( $LowerFrequencyTags{ $_ } ){ debug("Deleted '$_' from list of tags due to too low frequency ($tags{$_})."); }
                $LowerFrequencyTags{ $_ } = 1;
                delete $tags{$_};
            }
        }

        my %RemovedTags;
        foreach (keys %tags){
            if( $$Info{"isRemoveMpbAndBodyTags"} and
                ( m~</?mbp:~ or m~</?body~ )
                ){
                unless( defined $RemovedTags{$_} ){
                    $rawml =~ s~\Q$_\E~~sg;
                }
                $RemovedTags{ $_ } = 1;
            }
        }
        $$Info{ "removed tags" } = \%RemovedTags;
        $$Info{ "filtered rawml" } = \$rawml;
        $$Info{ "filtered tags hash" } = \%tags;
        $$Info{ "deleted tags"} = \%DeletedTags;}
    sub findArticlesBySets{
        # Structure @{$SetInfo}
        # [
        #   #0
        #   {
        #     'set' => [
        #                #0
        #                '</ar>',
        #                #1
        #                94837,
        #                #2
        #                '<ar>',
        #                #3
        #                94837
        #              ],
        #     'regex' => '<ar>((?!<ar>|</ar>).)+</ar>',
        #     'percentage' => 99,
        #     'disjunction' => '<ar>|</ar>'
        #   },
        #
        # ]
        infoVV("Entering findArticlesBySets.");
        my $Info = shift;
        my $SetInfo = $$Info{ "SetInfo" };
        my $rawml = ${$$Info{ "filtered rawml" }};
        my $length_rawml = length ( $rawml );
        foreach( sort {-($$a{"percentage"} <=> $$b{"percentage"}) } @$SetInfo ){
            print "\n-----".$$_{"set"}[0]."------\n";
            debug($$_{"percentage"}."%");
            if( $$_{"percentage"} < $$Info{ "minimum set percentage"}){
                debug("Maximum percentage (".$$_{"percentage"}."%)is below minimum (".$$Info{ "minimum set percentage"}."). No use trying for sets.");
                info("You can lower \$MinimumSetPercentage at the start of generateXDXFTagBased to change this behaviour.");
                last;
            }
            my $test = $rawml;
            # # Remove start.
            infoVV( "disjunction: ".Dumper( $$_{"disjunction"} ) );
            my $Start = qr~^(?<start>(?:(?!($$_{"disjunction"})).)+)~s;
            $test =~ s~$Start~~;
            # # Remove end.
            # # my $End = qr~(?<endregex>(?:(?<!($$_{"disjunction"})).)+)$~s; # Creates a Variable length negative lookbehind with capturing is experimental in regex;
            infoVV( "set :".Dumper( $$_{"set"} ) );
            my $End = qr~(?<end>(?:(?<!($$_{"set"}[0])).)+)$~s; # Creates a Variable length negative lookbehind with capturing is experimental in regex;
            $test =~ s~$End~~;
            infoVV( "regex :".Dumper( $$_{"regex"} ));
            my @articles = $test =~ m~($$_{"regex"})~sg;
            $test =~ s~$$_{"regex"}~~sg;
            my $length_test = length($test);
            my $percentage_left = int( $length_test / $length_rawml * 100 );
            debug("Length of the remaining test is $length_test ($percentage_left %)");
            debug(substr($test,0,2000));
            if( length($test) == 0 ){
                info("Articles identified.");
                info("Number of articles found: ".scalar @articles." with regex '".$$_{"regex"}."'.");
                info("0\n".$articles[0]);
                info("1\n".$articles[1]);
                info("2\n".$articles[2]);
                $$Info{ "articles"} = \@articles;
                $$Info{ "article stop tag"} = $$_{"set"}[0];
                infoVV("Exiting findArticlesBySets with value 1.");
                return 1;
            }
            else{ @articles = (); }
        }
        info("No articles found by using sets.");
        infoVV("Exiting findArticlesBySets with value 0.");
        return 0;}
    sub gatherSets{
        info("\nEntering gatherSets");
        # Usage: gatherSets( \%Info ); # Uses the hash key "filtered tags hash" and generates the keys "sets" and "SkippedTags", resp. an array- and a hash-reference.
        my $Info = shift;
        my $tags = $$Info{ "filtered tags hash" };
        my $Fails = 0;
        my $LowFrequencyCriterium = 100;
        $$Info{ "LowFrequencyCriterium"} = $LowFrequencyCriterium;

        my @sets; # Used for storing references to arrays of a set. Each set starts with the endtag, followed by a frequency and continues with start-tags accompagnied by their frequencies.
        # [
        #   #0
        #   [
        #     #0
        #     '</ar>',
        #     #1
        #     94837,
        #     #2
        #     '<ar>',
        #     #3
        #     94837
        #   ],
        #   .....
        # ]

        my %SkippedTags;
        my @GatheredStartTags;
        # Find stop-tags and match them to starting tags
        foreach my $key ( sort keys %$tags ){
            my $count = 0;
            if( $$Info{ "isSkipKnownStylingTags" } and $key =~ m~</?a( |>)|</?i( |>)|</?b( |>)|</?font( |>)~i){ $SkippedTags{$key} = "known styling"; next; } # Skip known styling.
            if( ($$tags{$key} < $LowFrequencyCriterium ) and ($isgatherSetsVerbose == 0) ){ $SkippedTags{$key} = "too low frequency";  next; }
            unless( $key =~ m~^<\/~ ){  $SkippedTags{$key} = "not a stop tag"; next; }
            info("Reviewing endtag '$key' ($$tags{$key})");
            my @set;
            push @sets, \@set;
            push @set, $key, $$tags{$key};
            $key =~ s~(^<\/)~~;
            my @info;
            foreach ( keys %$tags ){
                s~^<~~;
                if( substr(lc($key), 0, length($key)-1 ) eq substr(lc($_), 0, length($key)-1 ) # To check that the keywords start the same
                    ){
                    if( substr($_, length($key)-1, 1 ) eq " " or substr($_, length($key)-1, 1 ) eq ">" ){ # end the same
                        push @info, "<$_ (".$$tags{"<".$_}.")";
                        $count = $count + $$tags{"<".$_};
                        push @set, "<".$_, $$tags{"<".$_};
                        push @GatheredStartTags, "<".$_;
                    }
                    else{ debugV("<$_ has at ". (length($key) - 1 )." the character '".substr($_, length($key)-1, 1 )."'"); }
                }

            }
            if( scalar @info > 5 ){
                info( $info[0]);
                info( $info[1]);
                info( ".. .. "x10 );
                info( ".. .. "x10 );
                info( $info[-2]);
                info( $info[-1]);
            }
            else{ info( join("\n", @info ) ); }
            unless( $$tags{"</".$key} == $count){
                $Fails++;
                debug("The stop- (".$$tags{"</".$key}.") and starttags ($count) have a different count.");
            }
            else{ info("The stop- and starttags have the same count ($count)."); }

        }
        if( $Fails ){ debug( "There were $Fails unequal counts of start- and stoptags."); }
        else{ info("All obvious pairs of start- en stop-tags appear in equal numbers."); }
        $Data::Dumper::Indent = 3;
        infoVV( Dumper( \@sets ));
        foreach( @GatheredStartTags ){ if( exists $SkippedTags{ $_ } ){ delete $SkippedTags{ $_ }; } }

        # Check whether there is a tag-pair that remains uniform troughout.
        # So not more than one opening tag
        # So each content must be equal, e.g. ''.
        my $rawml = ${$$Info{"filtered rawml"}};
        SET: for( my $j =0; $j < scalar @sets; $j++){
            my $set = $sets[$j];
            debug_t( "Loop SET, index $j: ".Dumper($set) );
            PAIR: for( my $i = 2; $i< scalar @{$set}; $i+=2 ){
                my $regex = "($$set[$i](?:(?!(?:$$set[$i]|$$set[0])).)*$$set[0])";
                debug_t("regex :".$regex);
                debug_t("length rawml used: ". length $rawml );
                debugVV(substr( $rawml, 0, 2000 ) );
                my @TagBlocks = $rawml =~ m~$regex~sg;
                if( scalar @TagBlocks == 0 ){ warn "regex '$regex' didn't match!"; Die(); }
                debugVV(@TagBlocks[0..99]);
                my $TagBlock = shift @TagBlocks;
                debug_t("Tag-block is '$TagBlock'");
                foreach( @TagBlocks){
                    if( $_ ne $TagBlock ){
                        debug("TagBlock: $TagBlock");
                        debug("TagBlock: $_");
                        debug_t("Not all tag-blocks are the same. Next pair.");
                        next PAIR;
                    }
                }
                # All tag-blocks are identical!
                debug("Tag-block '$TagBlock' are all identical. Moving it to skipped tags.");
                # register $TagBlock as a skipped tag.
                $SkippedTags{ $TagBlock } = "all identical";
                debug_t( "Skipped tag '$TagBlock' has value '$SkippedTags{$TagBlock}.");
                # Remove start-tag and set index 2 back
                splice( @{$set}, $i, 2 );
                debug_t( Dumper($set) );
                $i -= 2;
                # Remove stop-tag if no further start-tags remains
                if( scalar @{$set} == 2 ){
                    debug_t("Only the stop-tag and frequency remain. Removing set.");
                    splice( @sets, $j, 1 );
                    debug_t( Dumper( @sets ));
                    $j--;
                    next SET;
                }
            }
        }

        # printDumperFiltered( \%SkippedTags, '<\?a ?' );
        logSets( $FileName, \@sets );
        $Info{ "sets" }              = \@sets;
        $Info{ "SkippedTags" }       = \%SkippedTags;}
    sub logSets{
        my $FileName = shift;
        my $Data = join('', Dumper( shift ));

        $FileName =~ s~.+/([^/]+)~$1~;

        $Data =~ s~\n+\s*(\[|\]\;)~$1~g;
        $Data =~ s~\n+\s*(\d+)~$1~g;

        my $LogDirName = "$BaseDir/dict/logs";
        unless( -e $LogDirName ){
            mkdir $LogDirName || ( Die("Couldn't create directory '$LogDirName'.") );
        }
        my $LogName = "$LogDirName/$FileName.sets.log";
        array2File( $LogName, $Data); }
    sub logTags{
        my $FileName = shift;
        my $Data = join('', Dumper( shift ));

        $FileName =~ s~.+/([^/]+)~$1~;

        # $Data =~ s~\n+\s*(\[|\]\;)~$1~g;
        # $Data =~ s~\n+\s*(\d+)~$1~g;

        my $LogDirName = "$BaseDir/dict/logs";
        unless( -e $LogDirName ){
            mkdir $LogDirName || ( Die("Couldn't create directory '$LogDirName'.") );
        }
        my $LogName = "$LogDirName/$FileName.tags.log";
        array2File( $LogName, $Data); }
    sub sets2Percentages{
        info("\nEntering sets2Percentages");
        # Usage: sets2Percentages( \%Info );
        # Uses the hash keys "sets" and "filtered rawml" to generate the key "SetInfo", an array-reference.

        my $Info = shift;
        my @sets = @{ $$Info{ "sets" } };
        my $rawml   =   ${ $$Info{ "filtered rawml"} };

        my %Percentages;

        my @SetInfo;
        # [
        #   #0
        #   {
        #     'set' => [
        #                #0
        #                '</ar>',
        #                #1
        #                94837,
        #                #2
        #                '<ar>',
        #                #3
        #                94837
        #              ],
        #     'regex' => '<ar>((?!<ar>|</ar>).)+</ar>',
        #     'percentage' => 99,
        #     'disjunction' => '<ar>|</ar>'
        #   },
        # .....
        # ]

        for( my $set = 0; $set < scalar @sets; $set++ ){
            my $test = $rawml;
            debug_t( Dumper($sets[$set]) );
            debugVV( scalar @{ $sets[$set] });
            my $disjunction = $sets[$set][2]; # Set equal to first start-tag
            debug_t("disjunction: ", $disjunction);
            debugVV( scalar @{ $sets[$set]});
            for( my $index = 4; $index < scalar @{ $sets[$set] }; $index += 2 ){
                $disjunction = "$sets[$set][$index]|$disjunction";
                infoVV("set $set, index $index, disjunction: '$disjunction'");
            }
            my $regex;
            $regex = "(DISJUNCTION)(?:(?!DISJUNCTION|$sets[$set][0]).)+$sets[$set][0]";
            infoVV("Regex formed: '$regex'");
            $regex =~ s~DISJUNCTION~$disjunction~sg;
            infoVV("Regex formed: '$regex'");
            $test =~ s~$regex~~gs;
            my $percentage = int( 100 - length($test) / length($rawml) * 100 );
            $SetInfo[$set]{"set"}           = $sets[$set];      # Array of the keywords and their frequencies
            $SetInfo[$set]{"regex"}         = $regex;
            $SetInfo[$set]{"disjunction"}   = $disjunction."|$sets[$set][0]";
            $SetInfo[$set]{"percentage"}    = $percentage;
            $Percentages{$sets[$set][0]}    = $SetInfo[$set]{"percentage"};
            info("Removed stringlength is $percentage\% for $sets[$set][0] ($sets[$set][1])");
        }
        infoVV( Dumper( \@SetInfo ) );

        $Percentages{ "max_amount" } = 0;
        $Percentages{ "stop-tag" } = "";
        foreach( keys %Percentages ){
            if( m~max_amount|stop-tag|remaining~ ){ next; }
            debugVV( $_);
            if( $Percentages{ $_ } > $Percentages{ "max_amount" } ){
                $Percentages{ "max_amount" }    = $Percentages{ $_ };
                $Percentages{ "stop-tag" }       = $_;
            }
            debugVV( $Percentages{ $_ } );
            debugVV( $Percentages{ "max_amount" } );
            debugVV( "----")
        }
        info("The maximum amount of string is ".$Percentages{ "max_amount" }."% and is removed with blocks that end with ".$Percentages{ "stop-tag" }."." );
        $Info{ "SetInfo" } = \@SetInfo;
        infoVV("Exiting sub sets2Percentages.");}
    sub splitArticlesIntoKeyAndDefinition{
        # Usage: splitArticlesIntoKeyAndDefinition(\%Info)
        # returns 1 on success.
        infoVV("Entering splitArticlesIntoKeyAndDefinition.");
        my $Info = shift;
        my $articles = $$Info{ "articles" };
        debugV( Dumper ( $$Info{ "sets"} ) );
        my @csv;
        my $OldCVSDeliminator = $CVSDeliminator;
        $CVSDeliminator = "||||";
        unless( @$articles > 0 ){ warn "No articles were given to sub splitArticlesIntoKeyAndDefinition!"; Die(); }
        my $counter = 0;
        foreach my $article( @$articles ){
            $counter++;
            # Check outer article tags and remove them.
            if( defined $$Info{ "article stop tag"} ){
                my $Stoptag = $$Info{ "article stop tag"}; # </ar>
                my $Starttag = startTag( $article );
                debugVV("Start-tag = '$Starttag'");
                unless( $Stoptag eq stopFromStart( $Starttag ) ){ warn "Article stop-tag registered in %Info doesn't match start-tag"; die; }
                $article = cleanOuterTags( $article );
            }
            debug( "Article to be split is '$article'" ) if $counter < 6;

            # Check starting key-tag and check them against high frequency tags.
            my $KeyStartTag = startTag( $article );
            debug( "Key start tag: $KeyStartTag") if $counter < 6;
            my $KeyStopTag = stopFromStart( $KeyStartTag );
            debug( "Key stop tag: $KeyStopTag") if $counter < 6;
            my $HighFrequencyTagRecognized = 0;
            foreach my $Set( @{ $$Info{ "sets" } } ){
                if( $KeyStopTag eq $$Set[0] ){ $HighFrequencyTagRecognized = 1; last; }
                else{ debugVV( "'$KeyStopTag' isn't equal to '$$Set[0]'"); }
            }
            unless( $HighFrequencyTagRecognized ){ warn "Key start tag is not a high frequency tag."; Die(); }
            # Match key and definition. Push cleaned string to csv-array.
            unless( $article =~ m~\Q$KeyStartTag\E(?<key>.+?)\Q$KeyStopTag\E(?<definition>.+)$~s){ warn "Regex for key-block doesn't match."; die;}
            infoV("Found a key and definition in article.") if $counter < 6;
            my $Key         = removeOuterTags( $+{ "key" } );
            my $Definition  = cleanOuterTags( $+{ "definition" } );
            infoVV("Key is '$Key'") if $counter < 6;
            infoVV("Definition is '$Definition'") if $counter < 6;
            push @csv, $Key.$CVSDeliminator.$Definition;
        }
        # Create xdxf-array and store csv- and xdxf-arrays in info hash.
        $$Info{ "csv" } = \@csv;
        my @xdxf = convertCVStoXDXF( @csv );
        $CVSDeliminator = $OldCVSDeliminator;

        if( scalar @xdxf ){ $$Info{ "xdxf" } = \@xdxf; return 1; }
        else{ return 0; }}
    sub splitRawmlIntoArticles{
        infoVV("Entering splitRawmlIntoArticles.");
        # Usage: splitRawmlIntoArticles( \%Info );
        # Takes the hash keys "SkippedTags" and "filtered rawml" and generates the keys "articles" and "filtered SkippedTags", resp. an array- and a hash-reference.

        my $Info = shift;
        my %SkippedTags = %{ $$Info{ "SkippedTags"    } };
        my $rawml       = ${ $$Info{ "filtered rawml" } };

        # Filter SkippedTags
        foreach( sort { $SkippedTags{$a} cmp $SkippedTags{$b} or $a cmp $b } keys %SkippedTags ){
            if( $SkippedTags{$_} =~ m~known styling|too low frequency~ ){ infoV("'$_' (".$SkippedTags{$_}.") didn't form a set. Now deleted."); delete $SkippedTags{$_}; }
            elsif( m~^<img[^>]+>$~ and $isExcludeImgTags ){ infoV("'$_' (".$SkippedTags{$_}.") didn't form a set. Now deleted."); delete $SkippedTags{$_}; }
            else{ info("'$_' (".$SkippedTags{$_}.") didn't form a set. Retained for splitting.");}
        }

        debugV( Dumper( \%SkippedTags ) );
        SKIPPEDTAG: foreach my $SplittingTag( sort keys %SkippedTags){
            infoVV("Evaluating '$SplittingTag' as a splitting tag.");
            my @chunks = split(/\Q$SplittingTag\E/, $rawml );
            my $FirstArticle = shift @chunks;
            my $LastArticleWithEndDictionary = pop @chunks;
            $LastArticleWithEndDictionary =~ s~^\s*~~;
            # Check that all chunks start with a tag
            my $StartTag = "unknown";
            my $counter = 0;
            my %StartTags;
            for( my $i = 0; $i < scalar @chunks; $i++){
                my $chunk = $chunks[$i];
                $counter++;
                if( ($counter % 100) eq 0 ){ printGreen(".");}
                $chunk =~ s~^\s+~~;
                if( $chunk eq '' ){
                    # Empty chunk, chuck it.
                    infoVV( "count is $counter");
                    infoVV( "\$chunks[$i] is '$chunks[$i]'");
                    splice ( @chunks, $i, 1);
                    infoVV( "\$chunks[$i] is '$chunks[$i]'");
                    infoVV( "\$chunks[$i+1] is '$chunks[$i+1]'");
                    infoVV( "\$chunks[$i-1] is '$chunks[$i-1]'");
                    $i--;
                    next;
                }
                infoVV( "Chunk is\n'$chunk'") if $counter < 6;
                my $NewStartTag = startTagReturnUndef( $chunk );
                $StartTags{ $NewStartTag } += 1;
                infoVV( "The count for \$StartTags{$NewStartTag} is $StartTags{$NewStartTag}.") if $counter < 6;
                unless( defined $StartTag ){
                    info("Chunk doesn't start with a tag. Skipping splitting tag '$SplittingTag'.");
                    next SKIPPEDTAG;
                }
                unless( $NewStartTag eq $StartTag or $StartTag eq "unknown"){
                    if( $NewStartTag =~ m~^<a ~ and # Were dealing with an anchor-tag
                        $chunk =~ s~$NewStartTag~~ and startTagReturnUndef( $chunk ) eq $StartTag # But after removal it's still the same tag.
                        ){
                        $chunks[$i] = $chunk; # Update array after removal
                    }
                    else{
                        info("Start-tags of chunks are different: '$StartTag' vs '$NewStartTag'. Skipping splitting tag '$SplittingTag'.");
                        info("New chunk: '$chunks[$i]'");
                        info("Old chunk: '$chunks[$i-1]'");
                        info( Dumper(\%StartTags));
                        next SKIPPEDTAG;
                    }
                }
                elsif( $StartTag eq "unknown" ){ $StartTag = $NewStartTag; }
            }
            print "\n";
            infoVV( "Finished checking chunks for uniformity in splitRawmlIntoArticles.");
            my $StopTag = stopFromStart( $StartTag );
            info("Found that splitting tag '$SplittingTag' results in an uniform key-block surrounded by '$StartTag....$StopTag'.");

            infoV("First article:\n'$FirstArticle'");
            my @NumberofStartTags = $chunks[0] =~ m~($StartTag)~sg;
            my $NumberofStartTags = scalar @NumberofStartTags;
            infoVV("Found ". $NumberofStartTags ." start-tags");
            if( $NumberofStartTags == 1 ){
                infoVV("One start-tag '$StartTag' found in first chunk.");
                # Fix first and last article
                $FirstArticle =~ m~$StartTag(?:(?!\Q$StartTag\E).)+$~s; # Match the last tag
                $Info{ "start dictionary"} = $`;
                unshift @chunks, $&;
                infoV( "Start dictionary is\n'". $Info{ "start dictionary"} ."'");
                infoV( "First article is \n'". $& ."'");
                infoV( "Last article:\n'$LastArticleWithEndDictionary'");
                my @LastStopTags = $LastArticleWithEndDictionary =~ m~(</[^>]+>)~sg;
                foreach my $LastStopTag (@LastStopTags){
                    my $LastStartTag = startFromStop( $LastStopTag );
                    unless( $LastArticleWithEndDictionary =~ m~^((?!\Q$LastStopTag\E).)*\Q$LastStartTag\E((?!\Q$LastStopTag\E).)*\Q$LastStopTag\E~ ){
                        # No preceding start-tag: Cut at this last stop tag.
                        $LastArticleWithEndDictionary =~ m~$LastStopTag~;
                        $Info{ "end dictionary" } = $LastStopTag.$';
                        push @chunks, $`;
                        if( $chunks[-1] !~ m~^\Q$StartTag\E~ ){
                            unless( $chunks[-1] =~ m~^\s*$~ ){ debug("Last article is not properly formed:\n'". $chunks[-1]."'"); }
                            pop @chunks;
                        }
                        else{ infoV( "Last article is\n'".$`."'"); }
                        infoV( "End dictionary is\n'". $LastStopTag.$'."'");
                        unless( defined $Info{ "end dictionary" } ){ warn "Didn't separate end of dictionary from last article."; die; }
                        last;
                    }
                }
            }
            elsif( $NumberofStartTags > 1 ){
                infoVV("More than one ($NumberofStartTags) start-tag '$StartTag' found in first chunk.");

                # Fix first article
                $FirstArticle =~ m~($StartTag.+)$~s; # Match from the first start-tag to the end
                $Info{ "start dictionary"} = $`;
                unshift @chunks, $&;
                infoV( "Start dictionary is\n'". $Info{ "start dictionary"} ."'");
                infoV( "First article is \n'". $& ."'");
                # Fix last article
                infoV("Start-tag is '$StartTag' which occurs $NumberofStartTags times in an article.");
                if( $LastArticleWithEndDictionary =! m~$StartTag~s ){
                    # No last article in the end of the Dictionary
                    $Info{ "end dictionary" } = $LastArticleWithEndDictionary;
                }
                elsif( $chunks[0] =~ m~((?:$StartTag(?:(?!(?:$StartTag|StopTag)).)+$StopTag){$NumberofStartTags})~s ){
                    # Not nested
                    infoV("Last article with end of the dictionary:\n'$LastArticleWithEndDictionary'");
                    my $regex = qr~^(?<last_article>(?:$StartTag(?:(?!(?:$StartTag|$StopTag)).)+$StopTag){$NumberofStartTags})(?<end_dictionary>.+)$~;
                    unless ( $LastArticleWithEndDictionary =~ m~$regex~s ){ warn "Regex didn't work\n$regex"; Die();}
                    $Info{ "end dictionary" } = $+{ "end_dictionary" };
                    push @chunks, $+{"lastarticle"};
                    infoV( "Last article is\n'". $chunks[-1] );
                    infoV( "End dictionary is\n'" . $Info{"end dictionary"} . "'");
                    unless( defined $Info{ "end dictionary" } ){ warn "Didn't separate end of dictionary from last article."; die; }
                }
            }
            unless( defined $Info{ "start dictionary" } ){ warn "Didn't separate start of dictionary from first article."; die; }
            unless( defined $Info{ "end dictionary"   } ){ warn "Didn't separate end of dictionary from last article."; die; }
            $$Info{ "filtered SkippedTags" } = \%SkippedTags;
            $$Info{ "articles"} = \@chunks;
            info( "Articles were split.");
            last;
        }}

    # Get all tags
    our @tags = $rawml =~ m~(<[^>]*>)~sg;
    $Info{ "tags" } = \@tags;
    logTags( $FileName, \@tags);

    # Hash all tags with their frequency and filter them
    countTagsAndLowerCase( \%Info ); # Generates 2 hash references in %Info named "lowered stop-tags" and "counted tags hash".
    filterTagsHash( \%Info ); # Uses the hash key { "counted tags hash" }. Generates 4 keys in given hash, resp. "removed tags", "filtered rawml", "filtered tags hash" and "deleted tags".

    # Gather the start- and stop tag sets.
    gatherSets( \%Info ); # Uses the hash key "filtered tags hash" and generates the keys "sets" and "SkippedTags", resp. an array- and a hash-reference.

    # Find the percentages that the sets occupy of the rawml.
    sets2Percentages( \%Info ); # Uses the hash keys "sets" and "filtered rawml" to generate the key "SetInfo", an array-reference.

    # Are there high frequency tag-blocks that contain all other high frequency blocks?
    unless( exists $Info{ "articles" } ){ findArticlesBySets( \%Info ); }

    # Is there a high frequency tag that doesn't have a partner, e.g. <hr /> or <hr/>? Splitting at such a tag could give uniform chunks;
    unless( exists $Info{ "articles" } ){ splitRawmlIntoArticles( \%Info ); } # Takes the hash keys "SkippedTags" and "filtered rawml" and generates the keys "articles" and "filtered SkippedTags", resp. an array- and a hash-reference.


    if( exists $Info{ "articles" } ){
        info( "Articles were found.");
        if( splitArticlesIntoKeyAndDefinition(\%Info) ){
            info("Articles were split into keys and definitions");
        }
    }
    else{ debug( "No articles found with sub generateXDXFTagBased(), yet"); }
    return ( $Info{ "xdxf"} )}

1;