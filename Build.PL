#!/usr/bin/perl

use utf8;
use 5.010;
use strict;
use warnings;
use Module::Build;

sub fuzzy_re {
    my ($text, $min) = @_;
    local $" = '|';
    qr/(@{[ map {quotemeta(substr($text, 0, $_))} $min..length($text) ]})/;
}

my $gtk_re = fuzzy_re("gtk-youtube-viewer", 3);
my $gtk_youtube_viewer = grep { /^--?$gtk_re\z/ } @ARGV;

my $builder = Module::Build->new(
    module_name       => 'WWW::YoutubeViewer',
    license           => 'perl',
    dist_author       => q{Trizen <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d>},
    dist_version_from => 'lib/WWW/YoutubeViewer.pm',
    release_status    => 'stable',

    build_requires => {
                       'Test::More' => 0,
                      },

    configure_requires => {
                           'Module::Build' => 0,
                          },

    get_options => {
                    'gtk-youtube-viewer' => {
                                             type  => '!',
                                             store => \$gtk_youtube_viewer,
                                            },
                   },

    requires => {
        'perl'                  => 5.016,
        'Data::Dump'            => 0,
        'File::Spec'            => 0,
        'File::Spec::Functions' => 0,
        'File::Path'            => 0,
        'Getopt::Long'          => 0,
        'HTTP::Request'         => 0,
        'JSON'                  => 0,
        'Encode'                => 0,
        'MIME::Base64'          => 0,
        'List::Util'            => 0,
        'LWP::UserAgent'        => 0,
        'LWP::Protocol::https'  => 0,
        'Term::ANSIColor'       => 0,
        'Term::ReadLine'        => 0,
        'Text::ParseWords'      => 0,
        'Text::Wrap'            => 0,
        'URI::Escape'           => 0,

        $gtk_youtube_viewer
        ? (
           'Gtk2'           => 0,
           'File::ShareDir' => 0,
          )
        : (),
    },

    recommends => {
                   'LWP::UserAgent::Cached'  => 0,    # cache support
                   'Term::ReadLine::Gnu::XS' => 0,    # for better STDIN support
                   'JSON::XS'                => 0,    # faster JSON to HASH conversion
                   'Mozilla::CA'             => 0,    # just in case if there are SSL problems
                  },

    auto_features => {
        fixed_width_support => {
                                description => "Print the results in a fixed-width format (--fixed-width, -W)",
                                requires    => {
                                             'Unicode::GCString' => 0,          # this is recommended
                                             #'Text::CharWidth' => 0,           # this works as fallback
                                            },
                               },
    },

    add_to_cleanup     => ['WWW-YoutubeViewer-*'],
    create_makefile_pl => 'traditional',
                                );

$builder->script_files(['bin/youtube-viewer', ($gtk_youtube_viewer ? 'bin/gtk-youtube-viewer' : ())]);
$builder->share_dir('share') if $gtk_youtube_viewer;
$builder->create_build_script();
