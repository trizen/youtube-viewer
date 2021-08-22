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

Reference: https://en.wikipedia.org/wiki/YouTube#Quality_and_formats

=cut

sub get_itags {
    scalar {

        'best' => [{value => 38,  format => 'mp4'},               # mp4 (3072p) (v-a)
                   {value => 138, format => 'mp4', dash => 1},    # mp4 (2160p-4320p) (v)
                   {value => 266, format => 'mp4', dash => 1},    # mp4 (2160p-2304p) (v)
                  ],

        '2160' => [{value => 315, format => 'webm', dash => 1, hfr => 1},    # webm HFR (v)
                   {value => 272, format => 'webm', dash => 1},              # webm (v)
                   {value => 313, format => 'webm', dash => 1},              # webm (v)
                   {value => 401, format => 'av1',  dash => 1},              # av1 (v)
                  ],

        '1440' => [{value => 308, format => 'webm', dash => 1, hfr => 1},    # webm HFR (v)
                   {value => 271, format => 'webm', dash => 1},              # webm (v)
                   {value => 264, format => 'mp4',  dash => 1},              # mp4 (v)
                   {value => 400, format => 'av1',  dash => 1},              # av1 (v)
                  ],

        '1080' => [{value => 303, format => 'webm', dash => 1, hfr => 1},    # webm HFR (v)
                   {value => 299, format => 'mp4',  dash => 1, hfr => 1},    # mp4 HFR (v)
                   {value => 248, format => 'webm', dash => 1},              # webm (v)
                   {value => 137, format => 'mp4',  dash => 1},              # mp4 (v)
                   {value => 399, format => 'av1',  dash => 1, hfr => 1},    # av1 (v)
                   {value => 46,  format => 'webm'},                         # webm (v-a)
                   {value => 37,  format => 'mp4'},                          # mp4 (v-a)
                   {value => 301, format => 'mp4', live => 1},               # mp4 (live) (v-a)
                   {value => 96,  format => 'ts',  live => 1},               # ts (live) (v-a)
                  ],

        '720' => [{value => 302, format => 'webm', dash => 1, hfr => 1},    # webm HFR (v)
                  {value => 298, format => 'mp4',  dash => 1, hfr => 1},    # mp4 HFR (v)
                  {value => 247, format => 'webm', dash => 1},              # webm (v)
                  {value => 136, format => 'mp4',  dash => 1},              # mp4 (v)
                  {value => 398, format => 'av1',  dash => 1, hfr => 1},    # av1 (v)
                  {value => 45,  format => 'webm'},                         # webm (v-a)
                  {value => 22,  format => 'mp4'},                          # mp4 (v-a)
                  {value => 300, format => 'mp4', live => 1},               # mp4 (live) (v-a)
                  {value => 120, format => 'flv', live => 1},               # flv (live) (v-a)
                  {value => 95,  format => 'ts',  live => 1},               # ts (live) (v-a)
                 ],

        '480' => [{value => 244, format => 'webm', dash => 1},              # webm (v)
                  {value => 135, format => 'mp4',  dash => 1},              # mp4 (v)
                  {value => 397, format => 'av1',  dash => 1},              # av1 (v)
                  {value => 44,  format => 'webm'},                         # webm (v-a)
                  {value => 35,  format => 'flv'},                          # flv (v-a)
                  {value => 94,  format => 'mp4', live => 1},               # mp4 (live) (v-a)
                 ],

        '360' => [{value => 243, format => 'webm', dash => 1},              # webm (v)
                  {value => 134, format => 'mp4',  dash => 1},              # mp4 (v)
                  {value => 396, format => 'av1',  dash => 1},              # av1 (v)
                  {value => 43,  format => 'webm'},                         # webm (v-a)
                  {value => 34,  format => 'flv'},                          # flv (v-a)
                  {value => 93,  format => 'mp4', live => 1},               # mp4 (live) (v-a)
                  {value => 18,  format => 'mp4'},                          # mp4 (v-a)
                 ],

        '240' => [{value => 242, format => 'webm', dash => 1},              # webm (v)
                  {value => 133, format => 'mp4',  dash => 1},              # mp4 (v)
                  {value => 395, format => 'av1',  dash => 1},              # av1 (v)
                  {value => 6,   format => 'flv'},                          # flv (270p) (v-a)
                  {value => 5,   format => 'flv'},                          # flv (v-a)
                  {value => 36,  format => '3gp'},                          # 3gp (v-a)
                  {value => 13,  format => '3gp'},                          # 3gp (v-a)
                  {value => 92,  format => 'mp4', live => 1},               # mp4 (live) (v-a)
                  {value => 132, format => 'ts',  live => 1},               # ts (live) (v-a)
                 ],

        '144' => [{value => 278, format => 'webm', dash => 1},              # webm (v)
                  {value => 160, format => 'mp4',  dash => 1},              # mp4 (v)
                  {value => 394, format => 'av1',  dash => 1},              # av1 (v)
                  {value => 17,  format => '3gp'},                          # 3gp (v-a)
                  {value => 91,  format => 'mp4'},                          # mp4 (live) (v-a)
                  {value => 151, format => 'ts'},                           # ts (live) (v-a)
                 ],

        'audio' => [{value => 172, format => 'webm', kbps => 192},            # webm (192 kbps)
                    {value => 251, format => 'opus', kbps => 160},            # webm opus (128-160 kbps)
                    {value => 171, format => 'webm', kbps => 128},            # webm vorbis (92-128 kbps)
                    {value => 140, format => 'm4a',  kbps => 128},            # mp4a (128 kbps)
                    {value => 141, format => 'm4a',  kbps => 256},            # mp4a (256 kbps)
                    {value => 250, format => 'opus', kbps => 64},             # webm opus (64 kbps)
                    {value => 249, format => 'opus', kbps => 48},             # webm opus (48 kbps)
                    {value => 139, format => 'm4a',  kbps => 48},             # mp4a (48 kbps)
                   ],
           };
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

        next if not exists $stream->{$itag->{value}};

        my $entry = $stream->{$itag->{value}};

        if (defined($entry->{fps}) and $entry->{fps} >= 50) {
            $args{hfr} || next;    # skip high frame rate (HFR) videos
        }

        if ($itag->{format} eq 'av1') {
            $args{ignore_av1} && next;    # ignore videos in AV1 format
        }

        # Ignored video projections
        if (ref($args{ignored_projections}) eq 'ARRAY') {
            if (grep { lc($entry->{projectionType} // '') eq lc($_) } @{$args{ignored_projections}}) {
                next;
            }
        }

        if ($itag->{dash}) {

            $args{dash} || next;

            my $video_info = $stream->{$itag->{value}};
            my $audio_info = $self->_find_streaming_url(%args, resolution => 'audio', dash => 0);

            if (defined($audio_info)) {
                $video_info->{__AUDIO__} = $audio_info;
                return $video_info;
            }

            next;
        }

        if ($resolution eq 'audio' and $args{prefer_m4a}) {
            if ($itag->{format} ne 'm4a') {
                next;    # skip non-M4A audio URLs
            }
        }

        # Ignore segmented DASH URLs (they load pretty slow in mpv)
        if (not $args{dash_segmented}) {
            next if ($entry->{url} =~ m{/api/manifest/dash/});
        }

        return $entry;
    }

    return;
}

=head2 find_streaming_url(%options)

Return the streaming URL which corresponds with the specified resolution.

    (
        urls           => \@streaming_urls,
        resolution     => 'resolution_name',     # from $obj->get_resolutions(),
        dash           => 1/0,                   # include or exclude DASH itags
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

    state $resolutions = $self->get_resolutions();

    # Find the nearest available resolution
    if (defined($resolution) and not defined($streaming)) {

        my $end = $#{$resolutions} - 1;    # -1 to ignore 'audio'

        foreach my $i (0 .. $end) {
            if ($resolutions->[$i] eq $resolution) {
                for (my $k = 1 ; ; ++$k) {

                    if ($i + $k > $end and $i - $k < 0) {
                        last;
                    }

                    if ($i + $k <= $end) {    # nearest below

                        my $res = $resolutions->[$i + $k];
                        $streaming = $self->_find_streaming_url(%args, resolution => $res);

                        if (defined($streaming)) {
                            $found_resolution = $res;
                            last;
                        }
                    }

                    if ($i - $k >= 0) {       # nearest above

                        my $res = $resolutions->[$i - $k];
                        $streaming = $self->_find_streaming_url(%args, resolution => $res);

                        if (defined($streaming)) {
                            $found_resolution = $res;
                            last;
                        }
                    }
                }
                last;
            }
        }
    }

    # Otherwise, find the best resolution available
    if (not defined $streaming) {
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

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Itags
