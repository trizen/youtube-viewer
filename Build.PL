#!/usr/bin/perl

use utf8;
use 5.010;
use strict;
use warnings;
use Module::Build;

my $gtk_youtube_viewer = 0;

my $builder = Module::Build->new(
    module_name       => 'WWW::YoutubeViewer',
    license           => 'perl',
    dist_author       => q{Daniel "Trizen" Șuteu <trizenx@gmail.com>},
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
                 'Data::Dump'             => 0,
                 'File::Spec'             => 0,
                 'File::Spec::Functions'  => 0,
                 'File::Path'             => 0,
                 'Getopt::Long'           => 0,
                 'HTTP::Request'          => 0,
                 'JSON'                   => 0,
                 'MIME::Base64'           => 0,
                 'List::Util'             => 0,
                 'LWP::UserAgent'         => 0,
                 'LWP::UserAgent::Cached' => 0,
                 'LWP::Protocol::https'   => 0,
                 'Term::ANSIColor'        => 0,
                 'Term::ReadLine'         => 0,
                 'Text::ParseWords'       => 0,
                 'Text::Wrap'             => 0,
                 'URI::Escape'            => 0,
                },

    recommends => {
                   'Term::ReadLine::Gnu::XS' => 0,    # for a better user input support
                   'JSON::XS'                => 0,    # faster JSON to HASH conversion
                  },

    auto_features => {
        fixed_width_support => {
                                description => "Print the results in a fixed-width format (--fixed-width, -W)",
                                requires    => {
                                             'Text::CharWidth' => 0,
                                            },
                               },

        (
         $gtk_youtube_viewer
         ? (
            threads_support => {
                                description => "Threads support for gtk-youtube-viewer. (with use_threads => 1)",
                                requires    => {
                                             'threads'       => 0,
                                             'Thread::Queue' => 0,
                                            },
                               },
           )
         : ()
        ),
    },

    add_to_cleanup     => ['WWW-YoutubeViewer-*'],
    create_makefile_pl => 'traditional',
                                );

if ($gtk_youtube_viewer) {
    if (ref($builder->{properties}) eq 'HASH' and ref($builder->{properties}{requires}) eq 'HASH') {
        $builder->{properties}{requires}{'Gtk2'}           = 0;
        $builder->{properties}{requires}{'File::ShareDir'} = 0;
    }
}

$builder->script_files(['bin/youtube-viewer', ($gtk_youtube_viewer ? 'bin/gtk-youtube-viewer' : ())]);
$builder->share_dir('share') if $gtk_youtube_viewer;
$builder->create_build_script();
