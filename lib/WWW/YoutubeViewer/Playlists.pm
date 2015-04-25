package WWW::YoutubeViewer::Playlists;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Playlists - Youtube playlists handle.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $info = $obj->playlist_from_id($playlist_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_playlists_url {
    my ($self, %opts) = @_;
    $self->_make_feed_url(
                          'playlists',
                          pageToken => $self->page_token,
                          %opts,
                         );
}

sub get_playlist_id {
    my ($self, $playlist_name, %fields) = @_;

    my $url = $self->_simple_feeds_url('channels', qw(part contentDetails), %fields);
    my $res = $self->_get_results($url);

    @{$res->{results}{items}} || return;

    return $res->{results}{items}[0]{contentDetails}{relatedPlaylists}{$playlist_name};
}

=head2 playlist_from_id($playlist_id)

Return info for one or more playlists.
PlaylistIDs can be separated by commas.

=cut

sub playlist_from_id {
    my ($self, $id) = @_;
    $self->_get_results($self->_make_playlists_url(id => $id));
}

=head2 playlists_from_channel_id($channel_id)

Get and return the specified channel's playlists.

=cut

sub playlists_from_channel_id {
    my ($self, $id) = @_;
    $self->_get_results($self->_make_playlists_url(channelId => $id));
}

=head2 playlists_from_username($username)

Get and return the playlists created for a given username.

=cut

sub playlists_from_username {
    my ($self, $username) = @_;
    my $channel_id = $self->channel_id_from_username($username);
    $self->playlists_from_channel_id($channel_id);
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Playlists


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

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

1;    # End of WWW::YoutubeViewer::Playlists
