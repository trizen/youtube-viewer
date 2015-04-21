#!perl

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

eval {
         require Test::Kwalitee;
         Test::Kwalitee->import('kwalitee_ok');
         kwalitee_ok();
         done_testing();
     };

plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;
