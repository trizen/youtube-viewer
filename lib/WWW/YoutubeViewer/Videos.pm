package WWW::YoutubeViewer::Videos;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Videos - videos handler.

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $info = $obj->video_details($videoID);

=head1 SUBROUTINES/METHODS

=cut

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

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Videos


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Videos
