package WWW::YoutubeViewer::Itags;

use 5.010;
use strict;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Itags - Get the YouTube itags.

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

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
    return scalar bless {}, $class;
}

=head2 get_itags()

Get a HASH ref with the YouTube itags. {resolution => {type => itag}}.

Reference: http://en.wikipedia.org/wiki/YouTube#Quality_and_codecs

=cut

sub get_itags {
    return scalar {

        # WebM formats first
        'original' => [38],
        '1080'     => [46, 37],                    # 137 -- no audio
        '720'      => [45, 22, 120],               # 136 -- no audio
        '480'      => [44, 35],                    # 135 -- no audio
        '360'      => [43, 34, 18],                # 134 -- no audio
        '240'      => [5, 36],                     # 133 -- no audio
        '144'      => [17],                        # 160 -- no audio
        'audio'    => [141, 140, 172, 171, 139],
    };
}

=head2 get_resolutions()

Get a HASH ref with the itags as keys and resolutions as values.

=cut

sub get_resolutions {
    my ($self) = @_;

    state $itags = $self->get_itags();
    return scalar {
        map {
            my $res = $_;
            map { $itags->{$res}[$_] => $res } 0 .. $#{$itags->{$_}}
          } keys %{$itags}
    };
}

=head2 find_streaming_url($urls_ref, $resolution)

Return the streaming URL which corresponds with the $resolution.

=cut

sub find_streaming_url {
    my ($self, $urls_ref, $resolution) = @_;

    state $itags       = $self->get_itags();
    state $resolutions = $self->get_resolutions($itags);

    if (defined($resolution) and $resolution =~ /^([0-9]+)/) {
        $resolution = $1;
    }

    my $wanted_itag = defined $resolution ? $itags->{$resolution} : undef;

    my %stream;
    foreach my $info_ref (@{$urls_ref}) {
        if (exists $info_ref->{itag} and exists $info_ref->{url}) {
            $stream{$info_ref->{itag}} = $info_ref;
        }
    }

    my $streaming;
    if (defined $wanted_itag) {
        foreach my $itag (@{$wanted_itag}) {
            if (exists $stream{$itag}) {
                $streaming = $stream{$itag};
                last;
            }
        }
    }

    if (not defined $streaming) {
        foreach my $res (qw(original 1080 720 480 360 240 180 144 audio)) {
            foreach my $itag (@{$itags->{$res}}) {
                if (exists $stream{$itag}) {
                    $streaming = $stream{$itag};
                    last;
                }
            }
            last if defined $streaming;
        }
    }

    return wantarray ? ($streaming, $resolutions->{$streaming->{itag}}) : $streaming;
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Itags


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2013 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1;    # End of WWW::YoutubeViewer::Itags
