package WWW::YoutubeViewer::Itags;

use 5.010;
use strict;

=head1 NAME

WWW::YoutubeViewer::Itags - Get the YouTube itags.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

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

=cut

sub get_itags {
    return
      scalar {
              'original' => {normal => 38},
              '1080'     => {normal => 37, webm => 46},
              '720'      => {normal => 22, webm => 45},
              '480'      => {normal => 35, webm => 44},
              '360'      => {normal => 34, webm => 43},
              '340'      => {normal => 18},
              '240'      => {normal => 5},
              '180'      => {normal => 36},
              '144'      => {normal => 17},
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
            map { $itags->{$res}{$_} => $res } keys %{$itags->{$_}}
          } keys %{$itags}
    };
}

=head2 find_streaming_url($urls_ref, $prefer_webm, $resolution)

Return the streaming URL based on $resolution and $prefer_webm.

=cut

sub find_streaming_url {
    my ($self, $urls_ref, $prefer_webm, $resolution) = @_;

    state $itags       = $self->get_itags();
    state $resolutions = $self->get_resolutions();
    state $webm_itags  = [map { $_->{webm} } grep { exists $_->{webm} } values %{$itags}];

    my $wanted_itag = defined $resolution ? $itags->{$resolution} : undef;

    my $streaming;
    foreach my $url_ref (@{$urls_ref}) {
        if (exists $url_ref->{itag} && exists $url_ref->{url}) {

            if (defined $wanted_itag) {
                (
                 (
                  $url_ref->{itag} == (
                                         $prefer_webm && exists $wanted_itag->{webm}
                                       ? $wanted_itag->{webm}
                                       : $wanted_itag->{normal}
                                      )
                 )
                   || ($url_ref->{itag} == $wanted_itag->{normal})
                )
                  || next;
            }

            if (not $prefer_webm) {
                if ($url_ref->{itag} ~~ $webm_itags) {
                    next;
                }
            }

            next unless exists $resolutions->{$url_ref->{itag}};
            $streaming = $url_ref;
            last;
        }
    }

    return unless defined $streaming;
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
