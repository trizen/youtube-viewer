package WWW::YoutubeViewer::Itags;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Itags - Get the YouTube itags.

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';

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
        'original' => [
            38,      # mp4 (3072p) (v-a)
            [138,    # mp4 (2160p-4320p) (v)
             266,    # mp4 (2160p-2304p) (v)
            ],
        ],

        '2160' => [
            [
             315,    # webm HFR (v)
             272,    # webm (v)
             313,    # mp4 (v)
            ],
        ],

        '1440' => [
            [
             308,    # webm HFR (v)
             271,    # webm (v)
             264,    # mp4 (v)
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
            ],
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
            ],

            120,     # flv (live) (v-a)
            95,      # ts (live) (v-a)
        ],

        '480' => [
            44,      # webm (v-a)
            35,      # flv (v-a)
            [244,    # webm (v)
             135,    # mp4 (v)
            ],
            94,      # ts (live) (v-a)
        ],

        '360' => [
            43,      # webm (v-a)
            34,      # flv (v-a)
            18,      # mp4 (v-a)
            [243,    # webm (v)
             134,    # mp4 (v)
            ],
            93,      # ts (live) (v-a)
        ],

        '240' => [
            6,       # flv (270p) (v-a)
            5,       # flv (v-a)
            36,      # 3gp (v-a)
            13,      # 3gp (v-a)
            [242,    # webm (v)
             133,    # mp4 (v)
            ],
            92,      # ts (live) (v-a)
            132,     # ts (live) (v-a)
        ],

        '144' => [
            17,      # 3gp (v-a)
            [278,    # webm (v)
             160,    # mp4 (v)
            ],
            151,     # ts (live) (v-a)
        ],

        'audio' => [172,     # webm (192 kbps)
                    171,     # webm (128 kbps)
                    140,     # m4a (128 kbps)
                    141,     # m4a (256 kbps)
                    251,     # webm (160 kbps)
                    250,     # webm (64 kbps)
                    249,     # webm (48 kbps)
                    139,     # m4a (48 kbps)
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
          original
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
    my ($self, $stream, $itags, $resolution, $dash, $mp4_audio) = @_;

    foreach my $itag (@{$itags->{$resolution}}) {
        if (ref($itag) eq 'ARRAY') {
            $dash || next;
            foreach my $i (@{$itag}) {
                if (exists $stream->{$i}) {
                    my $video_info = $stream->{$i};
                    my $audio_info = $self->_find_streaming_url($stream, $itags, 'audio', 0, $mp4_audio);
                    if (defined $audio_info) {
                        $video_info->{__AUDIO__} = $audio_info;
                        return $video_info;
                    }
                }
            }
        }
        elsif (exists $stream->{$itag}) {
            if ($resolution eq 'audio' and not $mp4_audio) {
                if ($itag == 140 or $itag == 141 or $itag == 139) {
                    next;    # skip mp4 audio URLs
                }
            }
            return $stream->{$itag};
        }
    }

    return;
}

=head2 find_streaming_url(%options)

Return the streaming URL which corresponds with the specified resolution.

    (
        urls           => \@streaming_urls,
        resolution     => 'resolution_name',     # from $obj->get_resolutions(),
        dash           => 1/0,                   # include or exclude dash itags
        dash_mp4_audio => 1/0,                   # include or exclude dash videos with MP4 audio
    )

=cut

sub find_streaming_url {
    my ($self, %args) = @_;

    my $urls_ref   = $args{urls};
    my $resolution = $args{resolution};
    my $dash       = $args{dash};
    my $mp4_audio  = $args{dash_mp4_audio};

    state $itags = $self->get_itags();

    if (defined($resolution) and $resolution =~ /^([0-9]+)/) {
        $resolution = $1;
    }

    my %stream;
    foreach my $info_ref (@{$urls_ref}) {
        if (exists $info_ref->{itag} and exists $info_ref->{url}) {
            $stream{$info_ref->{itag}} = $info_ref;
        }
    }

    my ($streaming, $found_resolution);
    if (defined($resolution) and exists $itags->{$resolution}) {
        $streaming = $self->_find_streaming_url(\%stream, $itags, $resolution, $dash, $mp4_audio);
        $found_resolution = $resolution;
    }

    if (not defined $streaming) {
        state $resolutions = $self->get_resolutions();
        foreach my $res (@{$resolutions}) {
            if (defined($streaming = $self->_find_streaming_url(\%stream, $itags, $res, $dash, $mp4_audio))) {
                $found_resolution = $res;
                last;
            }
        }
    }

    wantarray ? ($streaming, $found_resolution) : $streaming;
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


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
