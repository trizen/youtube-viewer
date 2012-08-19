use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'WWW::YoutubeViewer',
    license           => 'perl',
    dist_author       => q{Trizen <trizenx@gmail.com>},
    dist_version_from => 'lib/WWW/YoutubeViewer.pm',
    build_requires    => { 'Test::More' => 0, },
    requires          => {
        'perl'                  => 5.010,
        'Data::Dump'            => 0,
        'File::Spec::Functions' => 0,
        'Getopt::Long'          => 0,
        'HTTP::Request'         => 0,
        'LWP::UserAgent'        => 0,
        'Term::ANSIColor'       => 0,
        'Term::UI'              => 0,
        'Text::ParseWords'      => 0,
        'Text::Wrap'            => 0,
        'URI::Escape'           => 0,
        'XML::Fast'             => 0,
    },
    recommends         => {
        'List::Util'              => 0,
        'LWP::Protocol::https'    => 0,
        'Term::ReadKey'           => 0,
        'Term::ReadLine::Gnu::XS' => 0,
    },
    add_to_cleanup     => ['WWW-YoutubeViewer-*'],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
