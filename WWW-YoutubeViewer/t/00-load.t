#!perl -T

use 5.014;
use Test::More tests => 1;

BEGIN {
    use_ok( 'WWW::YoutubeViewer' ) || print "Bail out!\n";
}

diag( "Testing WWW::YoutubeViewer $WWW::YoutubeViewer::VERSION, Perl $], $^X" );
