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

    auto_features => {

        shuffle_playlists_support => {
                                      description => "To shuffle the playlists (--shuffle, -s)",
                                      requires    => {
                                                   'List::Util' => 0,
                                                  },
                                     },

        https_support => {
                          description => "HTTPS protocol support and authentication support",
                          requires    => {
                                       'MIME::Base64'         => 0,
                                       'LWP::Protocol::https' => 0,
                                      },
                         },

        post_comments_support => {
                                  description => "For posting comments to videos",
                                  requires    => {
                                               'File::Temp'           => 0,
                                               'LWP::Protocol::https' => 0,
                                              },
                                 },

        channels_support => {
                             description => "Search for YouTube channels",
                             requires    => {
                                          'HTML::Entities' => 0,
                                         },
                            },

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

$builder->recommends(
                     'Term::ReadLine::Gnu::XS' => 0,    # for a better user input support
                     'XML::Fast'               => 0,    # faster XML to HASH conversion.
                    );

$builder->requires(
    'perl'                  => '5.016',
    'Data::Dump'            => 0,
    'File::Spec::Functions' => 0,
    'File::Basename'        => 0,
    'File::Path'            => 0,
    'Getopt::Long'          => 0,
    'HTTP::Request'         => 0,
    'LWP::UserAgent'        => 0,
    'Term::ANSIColor'       => 0,
    'Term::UI'              => 0,
    'Text::ParseWords'      => 0,
    'Text::Wrap'            => 0,
    'URI::Escape'           => 0,

    $gtk_youtube_viewer
    ? ('Gtk2' => 0)
    : (),
);

$builder->script_files(['bin/youtube-viewer', ($gtk_youtube_viewer ? 'bin/gtk-youtube-viewer' : ())]);
$builder->create_build_script();

# Intalling the files for GTK YouTube Viewer
if ($gtk_youtube_viewer) {

    use autouse 'File::Basename'        => qw(dirname);
    use autouse 'File::Spec::Functions' => qw(rel2abs catfile catdir rootdir);
    use autouse 'File::Copy'            => qw(copy);
    use autouse 'File::Path'            => qw(make_path);

    my $dest_dir       = $builder->destdir // rootdir();
    my $main_dir       = dirname(rel2abs($0));
    my $main_share_dir = catdir($main_dir, qw(share));

    my $share_dir                = catdir($dest_dir,               qw(usr share));
    my $pixmaps_dir              = catdir($share_dir,              qw(pixmaps));
    my $applications_dir         = catdir($share_dir,              qw(applications));
    my $gtk_youtube_viewer_dir   = catdir($share_dir,              qw(gtk-youtube-viewer));
    my $gtk_youtube_viewer_icons = catdir($gtk_youtube_viewer_dir, qw(icons));

    if (my @dirs_to_create = grep({not -d} $gtk_youtube_viewer_icons, $applications_dir, $pixmaps_dir)) {
        make_path(
                  @dirs_to_create,
                  {
                   verbose => 1,
                   mode    => 0755,
                  }
                 )
          or die "Creating path failed: $!";
    }

    my $desktop_file = q(gtk-youtube-viewer.desktop);
    my $glade_file   = q(gtk-youtube-viewer.glade);

    foreach my $dest (
                      [catfile($main_share_dir, $desktop_file) => catfile($applications_dir, $desktop_file)],
                      [catfile($main_dir, qw(bin youtube-viewer)) => catfile($gtk_youtube_viewer_dir, qw(youtube-viewer))],
                      [catfile($main_share_dir, $glade_file) => catfile($gtk_youtube_viewer_dir, $glade_file)],
      ) {
        copy($dest->[0], $dest->[1]) or die "Can't copy `$dest->[0]' to `$dest->[1]': $!";
    }

    foreach my $copy_instructions (
                                   {
                                    icon_dir => 'icons',
                                    dest_dir => $pixmaps_dir,
                                   },
                                   {
                                    icon_dir => 'gtk-youtube-viewer-icons',
                                    dest_dir => $gtk_youtube_viewer_icons,
                                   }
      ) {
        my $main_icons_dir = catdir($main_share_dir, $copy_instructions->{icon_dir});
        opendir(my $dir_h, $main_icons_dir) or die "Can't open dir '$main_icons_dir': $!";

        while (defined(my $file = readdir($dir_h))) {

            my $full_file_path = catfile($main_icons_dir, $file);
            $full_file_path =~ /\.(?:png|jpg|gif)\z/i or next;

            my $destination = catfile($copy_instructions->{dest_dir}, $file);
            print STDERR "cp '$full_file_path' '$destination'\n";

            copy($full_file_path => $destination) or die "Copy failed: $!";
        }
        closedir $dir_h;
    }
}
