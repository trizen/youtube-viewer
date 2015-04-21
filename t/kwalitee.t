#!perl

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    plan( skip_all => 'these tests are for release candidate testing' )
        unless $ENV{RELEASE_TESTING};
}

eval {
         require Test::Kwalitee;
         Test::Kwalitee->import('kwalitee_ok');
         kwalitee_ok();
         done_testing();
     };

plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;
