
use utf8;
use 5.010;
use strict;
use warnings;
use Module::Build;

my $gtk  = grep { /^--?gtk\z/ } @ARGV;
my $gtk2 = grep { /^--?gtk2\z/ } @ARGV;
my $gtk3 = grep { /^--?gtk3\z/ } @ARGV;

my $builder = Module::Build->new(

    module_name       => 'WWW::YoutubeViewer',
    license           => 'perl',
    dist_author       => q{Trizen <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d>},
    dist_version_from => 'lib/WWW/YoutubeViewer.pm',
    release_status    => 'stable',

    build_requires => {
                       'Test::More' => 0,
                      },

    extra_manify_args => { utf8 => 1 },

    configure_requires => {
                           'Module::Build' => 0,
                          },

    get_options => {
        'gtk' => {
                  type  => '!',
                  store => \$gtk,
                 },

        'gtk2' => {
                   type  => '!',
                   store => \$gtk2,
                  },

        'gtk3' => {
                   type  => '!',
                   store => \$gtk3,
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
        'Memoize'               => 0,
        'MIME::Base64'          => 0,
        'List::Util'            => 0,
        'LWP::UserAgent'        => 0,
        'LWP::Protocol::https'  => 0,
        'Term::ANSIColor'       => 0,
        'Term::ReadLine'        => 0,
        'Text::ParseWords'      => 0,
        'Text::Wrap'            => 0,
        'URI::Escape'           => 0,

        ($gtk || $gtk2)
        ? (
           'Gtk2'           => 0,
           'File::ShareDir' => 0,
          )
        : (),

        $gtk3
        ? (
           'Gtk3'           => 0,
           'File::ShareDir' => 0,
           'Storable'       => 0,
           'Digest::MD5'    => 0,
          )
        : (),
    },

    recommends => {
                   'LWP::UserAgent::Cached'  => 0,    # cache support
                   'Term::ReadLine::Gnu'     => 0,    # for better STDIN support (+history)
                   'JSON::XS'                => 0,    # faster JSON to HASH conversion
                   'Mozilla::CA'             => 0,    # just in case if there are SSL problems
                   'Unicode::GCString'       => 0,    # fixed-width format (--fixed-width, -W)
                  },

    add_to_cleanup     => ['WWW-YoutubeViewer-*'],
    create_makefile_pl => 'traditional',
);

$builder->script_files(
                       ['bin/youtube-viewer',
                        ($gtk ? ('bin/gtk-youtube-viewer', 'bin/gtk2-youtube-viewer', 'bin/gtk3-youtube-viewer') : ()),
                        ($gtk2 ? ('bin/gtk-youtube-viewer', 'bin/gtk2-youtube-viewer') : ()),
                        ($gtk3 ? ('bin/gtk-youtube-viewer', 'bin/gtk3-youtube-viewer') : ()),
                       ]
                      );

$builder->share_dir('share') if ($gtk || $gtk2 || $gtk3);
$builder->create_build_script();
