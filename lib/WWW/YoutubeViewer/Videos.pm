package WWW::YoutubeViewer::Videos;

use utf8;
use 5.014;
use warnings;

our $VERSION = '0.01';

sub _make_videos_url {
    my ($self, %opts) = @_;
    return $self->_make_feed_url('videos', %opts,);
}

{
    no strict 'refs';
    foreach my $part (
                      qw(
                      id
                      snippet
                      contentDetails
                      fileDetails
                      player
                      liveStreamingDetails
                      processingDetails
                      recordingDetails
                      statistics
                      status
                      suggestions
                      topicDetails
                      )
      ) {
        *{__PACKAGE__ . '::' . 'video_' . $part} = sub {
            my ($self, $id) = @_;
            return $self->_get_results($self->_make_videos_url(id => $id, part => $part));
        };
    }
}

=head2 videos_from_category($catID)

Get videos from a category ID.

=cut

sub videos_from_category {
    my ($self, $cat_id) = @_;
    $self->_get_results($self->_make_videos_url(chart => $self->get_chart, videoCategoryId => $cat_id));
}

=head2 my_likes()

Get the videos liked by the authenticated user.

=cut

sub my_likes {
    my ($self) = @_;
    $self->_get_results($self->_make_videos_url(myRating => 'like', pageToken => $self->page_token));
}

=head2 my_dislikes()

Get the videos disliked by the authenticated user.

=cut

sub my_dislikes {
    my ($self) = @_;
    $self->_get_results($self->_make_videos_url(myRating => 'dislike', pageToken => $self->page_token));
}

=head2 send_rating_to_video($videoID, $rating)

Send rating to a video. $rating can be either 'like' or 'dislike'.

=cut

sub send_rating_to_video {
    my ($self, $video_id, $rating) = @_;

    if ($rating eq 'none' or $rating eq 'like' or $rating eq 'dislike') {
        my $url = $self->_simple_feeds_url('videos/rate', id => $video_id, rating => $rating);
        return defined($self->lwp_post($url, $self->_get_lwp_header()));
    }

    return;
}

=head2 like_video($videoID)

Like a video. Returns true on success.

=cut

sub like_video {
    my ($self, $video_id) = @_;
    $self->send_rating_to_video($video_id, 'like');
}

=head2 dislike_video($videoID)

Dislike a video. Returns true on success.

=cut

sub dislike_video {
    my ($self, $video_id) = @_;
    $self->send_rating_to_video($video_id, 'dislike');
}

=head2 videos_details($id, $part)

Get info about a videoID, such as: channelId, title, description,
tags, and categoryId.

Available values for I<part> are: I<id>, I<snippet>, I<contentDetails>
I<player>, I<statistics>, I<status> and I<topicDetails>.

C<$part> string can contain more values, comma-separated.

Example:

    part => 'snippet,contentDetails,statistics'

When C<$part> is C<undef>, it defaults to I<snippet>.

=cut

sub video_details {
    my ($self, $id, $part) = @_;
    return $self->_get_results($self->_make_videos_url(id => $id, part => $part // 'snippet'));
}

=head2 Return details

Each function returns a HASH ref, with a key called 'results', and another key, called 'url'.

The 'url' key contains a string, which is the URL for the retrieved content.

The 'results' key contains another HASH ref with the keys 'etag', 'items' and 'kind'.
From the 'results' key, only the 'items' are relevant to us. This key contains an ARRAY ref,
with a HASH ref for each result. An example of the item array's content are shown below.

=over 4

=item video_contentDetails($videoID)

    items => [
               {
                 contentDetails => {
                   caption         => "false",
                   definition      => "sd",
                   dimension       => "2d",
                   duration        => "PT1H20M10S",
                   licensedContent => bless(do{\(my $o = 0)}, "JSON::XS::Boolean"),
                 },
                 etag => "\"5cYuq_ImPkYn_h2RKDdX8DHvM2g/KU_bqVk91zBQGXrMtEDZgkQMkhU\"",
                 id => "f6df3s3x3zo",
                 kind => "youtube#video",
               },
            ]


=item video_id($videoID)

    items => [
               {
                 etag => "\"5cYuq_ImPkYn_h2RKDdX8DHvM2g/bvAWXfDY4QPsx_UgtmMPFcxPLQc\"",
                 id => "f6df3s3x3zo",
                 kind => "youtube#video",
               },
             ],


=item video_player($videoID)

    items => [
               {
                 etag => "\"5cYuq_ImPkYn_h2RKDdX8DHvM2g/nr03GopgH8bb755ppx5BA_1VsF8\"",
                 id => "f6df3s3x3zo",
                 kind => "youtube#video",
                 player => {
                   embedHtml => "<iframe type='text/html' src='http://www.youtube.com/embed/f6df3s3x3zo' width='640' height='360' frameborder='0' allowfullscreen='true'/>",
                 },
               },
             ],


=item video_statistics($videoID)

    items => [
               {
                 etag => "\"5cYuq_ImPkYn_h2RKDdX8DHvM2g/j01_qxKqxc3BMrFBbX2eiPWkAmo\"",
                 id => "f6df3s3x3zo",
                 kind => "youtube#video",
                 statistics => {
                   commentCount  => 2,
                   dislikeCount  => 1,
                   favoriteCount => 0,
                   likeCount     => 5,
                   viewCount     => 174,
                 },
               },
             ],


=item video_status($videoID)

    items => [
               {
                 etag => "\"5cYuq_ImPkYn_h2RKDdX8DHvM2g/jaa690eVtSvHTYRSSPD3mc1mlIY\"",
                 id => "f6df3s3x3zo",
                 kind => "youtube#video",
                 status => {
                   embeddable    => bless(do{\(my $o = 1)}, "JSON::XS::Boolean"),
                   license       => "youtube",
                   privacyStatus => "public",
                   uploadStatus  => "processed",
                 },
               },
             ],


=item video_topicDetails($videoID)

    items => [
               {
                 etag => "\"5cYuq_ImPkYn_h2RKDdX8DHvM2g/XnxCuOGwiR8MNhH-iHNxHB-ROWM\"",
                 id => "f6df3s3x3zo",
                 kind => "youtube#video",
                 topicDetails => { topicIds => ["/m/0126n", "/m/0jpv", "/m/07h44"] },
               },
             ],

=back

=cut

=head1 AUTHOR

Suteu "Trizen" Daniel, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Videos


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Suteu "Trizen" Daniel.

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

1;    # End of WWW::YoutubeViewer::Videos
