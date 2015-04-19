
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

eval { require Test::Kwalitee; Test::Kwalitee->import(
        tests => [ qw(
            extractable
            has_readme
            has_manifest
            has_meta_yml
            has_buildtool
            has_changelog
            no_symlinks
            has_tests
            proper_libs
            no_pod_errors
            use_strict
            has_test_pod
            has_test_pod_coverage
        ) ]
    ) };

plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;
