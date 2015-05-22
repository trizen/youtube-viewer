package WWW::YoutubeViewer::PlaylistItems;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::PlaylistItems - ...

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $videos = $obj->videos_from_playlistID($playlist_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_playlistItems_url {
    my ($self, %opts) = @_;
    return
      $self->_make_feed_url(
                            'playlistItems',
                            pageToken => $self->page_token,
                            %opts
                           );
}

=head2 add_video_to_playlist($playlistID, $videoID; $position=1)

Add a video to given playlist ID, at position 1 (by default)

=cut

sub add_video_to_playlist {
    my ($self, $playlist_id, $video_id, $position) = @_;

    $playlist_id // return;
    $video_id    // return;
    $position //= 0;

    my $hash = {
                "snippet" => {
                              "playlistId" => $playlist_id,
                              "resourceId" => {
                                               "videoId" => $video_id,
                                               "kind"    => "youtube#video"
                                              },
                              "position" => $position,
                             }
               };

    my $url = $self->_make_playlistItems_url(page_token => undef);
    $self->post_as_json($url, $hash);
}

=head2 favorite_video($videoID)

Favorite a video. Returns true on success.

=cut

sub favorite_video {
    my ($self, $video_id) = @_;
    $video_id // return;
    my $playlist_id = $self->get_playlist_id('favorites', mine => 'true');
    $self->add_video_to_playlist($playlist_id, $video_id);
}

=head2 videos_from_playlist_id($playlist_id)

Get videos from a specific playlistID.

=cut

sub videos_from_playlist_id {
    my ($self, $id) = @_;
    return $self->_get_results($self->_make_playlistItems_url(playlistId => $id, part => 'contentDetails,snippet'));
}

=head2 videos_from_id($playlist_id)

Get videos from a specific playlistID.

=cut

sub playlists_from_id {
    my ($self, $id) = @_;
    return $self->_get_results($self->_make_playlistItems_url(id => $id));
}

=head2 favorited_videos(;$username)

Get favorited videos for a given username or from the current user.

=cut

{
    no strict 'refs';
    foreach my $name (qw(favorites uploads likes)) {
        *{__PACKAGE__ . '::' . $name . '_from_username'} = sub {
            my ($self, $username) = @_;
            my $playlist_id = $self->get_playlist_id($name, $username ? (forUsername => $username) : (mine => 'true'));
            $self->videos_from_playlist_id($playlist_id);
        };

        *{__PACKAGE__ . '::' . $name} = sub {
            my ($self, $channel_id) = @_;
            my $playlist_id = $self->get_playlist_id($name, $channel_id ? (id => $channel_id) : (mine => 'true'));
            $self->videos_from_playlist_id($playlist_id);
        };
    }
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::PlaylistItems


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

1;    # End of WWW::YoutubeViewer::PlaylistItems
