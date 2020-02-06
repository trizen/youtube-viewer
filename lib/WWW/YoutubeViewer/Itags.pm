package WWW::YoutubeViewer::Itags;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Itags - Get the YouTube itags.

=head1 SYNOPSIS

    use WWW::YoutubeViewer::Itags;

    my $yv_itags = WWW::YoutubeViewer::Itags->new();

    my $itags = $yv_itags->get_itags();
    my $res = $yv_itags->get_resolutions();

=head1 SUBROUTINES/METHODS

=head2 new()

Return the blessed object.

=cut

sub new {
    my ($class) = @_;
    bless {}, $class;
}

=head2 get_itags()

Get a HASH ref with the YouTube itags. {resolution => [itags]}.

Reference: http://en.wikipedia.org/wiki/YouTube#Quality_and_formats

=cut

sub get_itags {
#<<<
    scalar {
        'best' => [
            38,      # mp4 (3072p) (v-a)
            [138,    # mp4 (2160p-4320p) (v)
             266,    # mp4 (2160p-2304p) (v)
            ],
        ],

        '2160' => [
            [
             315,    # webm HFR (v)
             272,    # webm (v)
             313,    # webm (v)
             401,    # av1 (v)
            ],
        ],

        '1440' => [
            [
             308,    # webm HFR (v)
             271,    # webm (v)
             264,    # mp4 (v)
             400,    # av1 (v)
            ],
        ],

        '1080' => [
            [303,    # webm HFR (v)
             299,    # mp4 HFR (v)
            ],
            46,      # webm (v-a)
            37,      # mp4 (v-a)
            [248,    # webm (v)
             137,    # mp4 (v)
             399,    # av1 (v)
            ],
            301,     # mp4 (live) (v-a)
            96,      # ts (live) (v-a)
        ],

        '720' => [
            [302,    # webm HFR (v)
             298,    # mp4 HFR (v)
            ],
            45,      # webm (v-a)
            22,      # mp4 (v-a)
            [247,    # webm (v)
             136,    # mp4 (v)
             398,    # av1 (v)
            ],
            300,     # mp4 (live) (v-a)
            120,     # flv (live) (v-a)
            95,      # ts (live) (v-a)
        ],

        '480' => [
            44,      # webm (v-a)
            35,      # flv (v-a)
            [244,    # webm (v)
             135,    # mp4 (v)
             397,    # av1 (v)
            ],
            94,      # mp4 (live) (v-a)
        ],

        '360' => [
            43,      # webm (v-a)
            34,      # flv (v-a)
            [243,    # webm (v)
             134,    # mp4 (v)
             396,    # av1 (v)
            ],
            93,      # mp4 (live) (v-a)
            18,      # mp4 (v-a)
        ],

        '240' => [
            6,       # flv (270p) (v-a)
            5,       # flv (v-a)
            36,      # 3gp (v-a)
            13,      # 3gp (v-a)
            [242,    # webm (v)
             133,    # mp4 (v)
             395,    # av1 (v)
            ],
            92,      # mp4 (live) (v-a)
            132,     # ts (live) (v-a)
        ],

        '144' => [
            17,      # 3gp (v-a)
            [278,    # webm (v)
             160,    # mp4 (v)
             394,    # av1 (v)
            ],
            91,      # mp4 (live) (v-a)
            151,     # ts (live) (v-a)
        ],

        'audio' => [172,     # webm (192 kbps)
                    251,     # webm opus (128-160 kbps)
                    171,     # webm vorbis (92-128 kbps)
                    140,     # mp4a (128 kbps)
                    141,     # mp4a (256 kbps)
                    250,     # webm opus (64 kbps)
                    249,     # webm opus (48 kbps)
                    139,     # mp4a (48 kbps)
                   ],
           };
#>>>
}

=head2 get_resolutions()

Get an ARRAY ref with the supported resolutions ordered from highest to lowest.

=cut

sub get_resolutions {
    my ($self) = @_;

    state $itags = $self->get_itags();
    return [
        grep { exists $itags->{$_} }
          qw(
          best
          2160
          1440
          1080
          720
          480
          360
          240
          144
          audio
          )
    ];
}

sub _find_streaming_url {
    my ($self, %args) = @_;

    my $stream     = $args{stream}     // return;
    my $resolution = $args{resolution} // return;

    foreach my $itag (@{$args{itags}->{$resolution}}) {

        if (ref($itag) eq 'ARRAY') {

            $args{dash} || next;

            foreach my $i (@{$itag}) {

                next if not exists $stream->{$i};

                my $video_info = $stream->{$i};
                my $audio_info = $self->_find_streaming_url(%args, resolution => 'audio', dash => 0);

                if (defined $audio_info) {
                    $video_info->{__AUDIO__} = $audio_info;
                    return $video_info;
                }
            }

            next;
        }

        if (exists $stream->{$itag}) {
            if ($resolution eq 'audio' and not $args{dash_mp4_audio}) {
                if ($itag == 140 or $itag == 141 or $itag == 139) {
                    next;    # skip mp4 audio URLs
                }
            }

            my $entry = $stream->{$itag};

            # Ignore segmented DASH URLs (they load pretty slow in mpv)
            if (not $args{dash_segmented}) {
                next if ($entry->{url} =~ m{^https://manifest\.googlevideo\.com/api/manifest/dash/});
            }

            return $entry;
        }
    }

    return;
}

=head2 find_streaming_url(%options)

Return the streaming URL which corresponds with the specified resolution.

    (
        urls           => \@streaming_urls,
        resolution     => 'resolution_name',     # from $obj->get_resolutions(),
        dash           => 1/0,                   # include or exclude DASH itags
        dash_mp4_audio => 1/0,                   # include or exclude DASH videos with MP4 audio
        dash_segmented => 1/0,                   # include or exclude segmented DASH videos
    )

=cut

sub find_streaming_url {
    my ($self, %args) = @_;

    my $urls_array = $args{urls};
    my $resolution = $args{resolution};

    state $itags = $self->get_itags();

    if (defined($resolution) and $resolution =~ /^([0-9]+)/) {
        $resolution = $1;
    }

    my %stream;
    foreach my $info_ref (@{$urls_array}) {
        if (exists $info_ref->{itag} and exists $info_ref->{url}) {
            $stream{$info_ref->{itag}} = $info_ref;
        }
    }

    $args{stream}     = \%stream;
    $args{itags}      = $itags;
    $args{resolution} = $resolution;

    my ($streaming, $found_resolution);

    # Try to find the wanted resolution
    if (defined($resolution) and exists $itags->{$resolution}) {
        $streaming        = $self->_find_streaming_url(%args);
        $found_resolution = $resolution;
    }

    # Otherwise, find the best resolution available
    if (not defined $streaming) {

        state $resolutions = $self->get_resolutions();

        foreach my $res (@{$resolutions}) {

            $streaming = $self->_find_streaming_url(%args, resolution => $res);

            if (defined($streaming)) {
                $found_resolution = $res;
                last;
            }
        }
    }

    wantarray ? ($streaming, $found_resolution) : $streaming;
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Itags


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Itags
