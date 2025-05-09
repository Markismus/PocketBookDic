#!/usr/bin/perl

package DicManualCuts;

use warnings;
use strict;
use utf8;

use DicGlobals;
use Exporter;
use Dic2Screen;
use DicHelpUtils;

our @ISA = ('Exporter');
our @EXPORT = ( '%DictInfo4FileName' );
our %DictInfo4FileName;
my (%DictInfo,$FileName);
# The name of the rawml/html-file without path within single quotes
$FileName = 'Le Grand Robert de la langue française (Dictionnaires Le Robert) (Z-Library).rawml';
# All html-strings within qr~\Q...\E~ quotes to make them fully unescaped regular expressions.
 %DictInfo = (
        "Start" => qr~\Q<html><head><guide><reference title="Dictionary Search" type="search" onclick="index_search()"/></guide></head><body><center> <h1>Le Grand Robert. 2005</h1> <h5>Generated by Dsl2Mobi-0.5-dev</h5> <hr width="10%"/> <a onclick="index_search('dic')">Index</a><br/> <hr/> </center> <mbp:pagebreak/>\E~s,
        "End" => qr~\Q<div> <img hspace="0" vspace="0" align="middle" recindex="00001"/> <table width="100%" bgcolor="#992211"><tr><th widht="100%" height="2px"></th></tr></table> </div>  <mbp:pagebreak/></body></html>\E~,
        "Split" => qr~\Q<div> <img hspace="0" vspace="0" align="middle" recindex="00001"/> <table width="100%" bgcolor="#992211"><tr><th widht="100%" height="2px"></th></tr></table> </div>\E~,
        "KeyTagStart" => qr~\Q<font size="6" color="#002984"><b>\E~,
        "KeyTagEnd" => qr~\Q</b></font>\E~,
    );
 $DictInfo4FileName{$FileName} = \%DictInfo;
# The name of the rawml/html-file without path within single quotes
$FileName = 'Etymology Dictionary (Douglas Harper).rawml';
# All html-strings within qr~\Q...\E~ quotes to make them fully unescaped regular expressions.
 %DictInfo = (
        "Start" => qr~\Q<html><head><guide><reference title="Dictionary Search" type="search" onclick="index_search()"/></guide></head><body><mbp:pagebreak/><mbp:frameset> <mbp:pagebreak/>\E~s,
        "End" => qr~\Q<br/> <mbp:pagebreak/></mbp:frameset> <mbp:pagebreak/></body></html><body topmargin="0" leftmargin="0" rightmargin="0" bottommargin="0" > <div align="center" bgcolor="yellow"/> <a onclick="index_search()">Dictionary Search</a> </body><body topmargin="0" leftmargin="0" rightmargin="0" bottommargin="0" > <div align="center" bgcolor="yellow"/> <a onclick="index_search()">Dictionary Search</a> </body><body topmargin="0" leftmargin="0" rightmargin="0" bottommargin="0" > <div align="center" bgcolor="yellow"/> <a onclick="index_search()">Dictionary Search</a> </body>\E~,
        "Split" => qr~\Q<br/> <mbp:pagebreak/>\E~,
        "KeyTagStart" => qr~\Q<h2>\E~,
        "KeyTagEnd" => qr~\Q</h2>\E~,
    );
 $DictInfo4FileName{$FileName} = \%DictInfo;


