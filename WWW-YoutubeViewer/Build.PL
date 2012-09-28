#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Module::Build;

use Getopt::Long qw();

# Get options
my ($gtk_youtube_viewer);
{
    local @ARGV = grep /^--?(?:no-?)?gtk-youtube-viewer\z/, @ARGV;
    Getopt::Long::GetOptions('gtk-youtube-viewer!' => \$gtk_youtube_viewer,);
}

my $builder = Module::Build->new(
    module_name       => 'WWW::YoutubeViewer',
    license           => 'perl',
    dist_author       => q{Trizen <trizenx@gmail.com>},
    dist_version_from => 'lib/WWW/YoutubeViewer.pm',
    build_requires    => {'Test::More' => 0,},
    script_files      => ['bin/youtube-viewer', ($gtk_youtube_viewer ? 'bin/gtk-youtube-viewer' : ()),],
    requires          => {
        'perl'                  => '5.10.1',
        'Data::Dump'            => 0,
        'File::Spec::Functions' => 0,
        'File::Path'            => 0,
        'Getopt::Long'          => 0,
        'HTTP::Request'         => 0,
        'LWP::UserAgent'        => 0,
        'Term::ANSIColor'       => 0,
        'Term::UI'              => 0,
        'Text::ParseWords'      => 0,
        'Text::Wrap'            => 0,
        'URI::Escape'           => 0,
        'XML::Fast'             => 0,

        $gtk_youtube_viewer
        ? (
           'Gtk2'           => 0,
           'File::Basename' => 0,
          )
        : (),
    },
    recommends => {
        'List::Util'              => 0,    # to shuffle the playlists (--shuffle)
        'HTML::Entities'          => 0,    # used when searching channels
        'File::Temp'              => 0,    # for posting comments
        'LWP::Protocol::https'    => 0,    # for HTTPS protocol and login support
        'Term::ReadKey'           => 0,    # to get the terminal width
        'Term::ReadLine::Gnu::XS' => 0,    # for a better user input support

        $gtk_youtube_viewer
        ? (
           'threads'       => 0,           # threads support
           'Thread::Queue' => 0,           # threads support
          )
        : (),
    },
    add_to_cleanup     => ['WWW-YoutubeViewer-*'],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

# Intalling files for GTK YouTube Viewer
if ($gtk_youtube_viewer) {

    use File::Basename qw(dirname);
    use File::Spec::Functions qw(rel2abs catfile catdir rootdir);
    use File::Copy qw(copy);
    use File::Path qw(make_path);

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

    copy(catfile($main_dir, qw(bin youtube-viewer)) => catfile($gtk_youtube_viewer_dir, qw(youtube-viewer)))
      or die "Copy failed: $!";

    copy(catfile($main_share_dir, $desktop_file) => catfile($applications_dir,       $desktop_file)) or die "Copy failed: $!";
    copy(catfile($main_share_dir, $glade_file)   => catfile($gtk_youtube_viewer_dir, $glade_file))   or die "Copy failed: $!";

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
