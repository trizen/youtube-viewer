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
    return $self->_make_feed_url('videos', %opts);
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

=head2 videos_from_category($category_id)

Get videos from a category ID.

=cut

sub videos_from_category {
    my ($self, $cat_id) = @_;

    state $yv_utils = WWW::YoutubeViewer::Utils->new;

    if (defined($cat_id) and $cat_id eq 'popular') {
        local $self->{publishedAfter} = do {
            $yv_utils->period_to_date(1, 'd');
        } if !defined($self->get_publishedAfter);
        return $self->popular_videos;
    }

    my $videos = $self->_get_results(
                                     $self->_make_videos_url(chart           => 'mostPopular',
                                                             videoCategoryId => $cat_id,)
                                    );

    if (not $yv_utils->has_entries($videos)) {
        $videos = $self->trending_videos_from_category($cat_id);
    }

    return $videos;
}

=head2 trending_videos_from_category($category_id)

Get popular videos from a category ID.

=cut

sub trending_videos_from_category {
    my ($self, $cat_id) = @_;

    state $yv_utils = WWW::YoutubeViewer::Utils->new;

    my $results = do {
        local $self->{publishedAfter} = do {
            $yv_utils->period_to_date(1, 'w');
        } if !defined($self->get_publishedAfter);
        local $self->{videoCategoryId} = $cat_id;
        local $self->{regionCode}      = "US" if !defined($self->get_regionCode);
        $self->search_videos(undef);
    };

    return $results;
}

=head2 popular_videos($channel_id)

Get the most popular videos for a given channel ID.

=cut

sub popular_videos {
    my ($self, $id) = @_;

    my $results = do {
        local $self->{channelId} = $id;
        local $self->{order}     = 'viewCount';
        $self->search_videos("");
    };

    return $results;
}

=head2 my_likes()

Get the videos liked by the authenticated user.

=cut

sub my_likes {
    my ($self) = @_;
    $self->get_access_token() // return;
    $self->_get_results($self->_make_videos_url(myRating => 'like', pageToken => $self->page_token));
}

=head2 my_dislikes()

Get the videos disliked by the authenticated user.

=cut

sub my_dislikes {
    my ($self) = @_;
    $self->get_access_token() // return;
    $self->_get_results($self->_make_videos_url(myRating => 'dislike', pageToken => $self->page_token));
}

=head2 send_rating_to_video($videoID, $rating)

Send rating to a video. $rating can be either 'like' or 'dislike'.

=cut

sub send_rating_to_video {
    my ($self, $video_id, $rating) = @_;

    $self->get_access_token() // return;

    if ($rating eq 'none' or $rating eq 'like' or $rating eq 'dislike') {
        my $url = $self->_simple_feeds_url('videos/rate', id => $video_id, rating => $rating);
        return defined($self->lwp_post($url));
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
    my ($self, $ids, $part) = @_;

    my $info = $self->_get_results($self->_make_videos_url(id => $ids, part => $part // 'snippet'));

    state $yv_utils = WWW::YoutubeViewer::Utils->new;

    if ($yv_utils->has_entries($info)) {
        return $info;
    }

    if ($self->get_debug) {
        say STDERR ":: Extracting video info using the fallback method...";
    }

    my @items;

    foreach my $id (split(/,/, $ids)) {

        # Fallback using the `get_video_info` URL
        my %video_info = $self->_get_video_info($id);
        my $video      = $self->parse_json_string($video_info{player_response} // next);

        if (exists $video->{videoDetails}) {
            $video = $video->{videoDetails};
        }
        else {
            next;
        }

        my $length   = $video->{lengthSeconds};
        my $duration = sprintf("PT%dH%dM%dS", int($length / 3600), int($length / 60) % 60, $length % 60);

        my %details = (

            contentDetails => {
                               definition => "hd",
                               dimension  => "2d",
                               duration   => $duration,
                               projection => "rectangular",
                              },

            id   => $id,
            kind => "youtube#video",

            snippet => {
                channelId    => $video->{channelId},
                channelTitle => $video->{author},
                description  => $video->{shortDescription},
                title        => $video->{title},
                tags         => $video->{keywords},

                liveBroadcastContent => ($video->{isLiveContent} ? 'live' : 'no'),

                thumbnails => [default  => $video->{thumbnail}{thumbnails}[0],
                               medium   => $video->{thumbnail}{thumbnails}[1],
                               standard => $video->{thumbnail}{thumbnails}[2],
                               high     => $video->{thumbnail}{thumbnails}[3],
                               maxres   => $video->{thumbnail}{thumbnails}[4],
                              ],
                       },

            statistics => {
                           viewCount => $video->{viewCount},
                          },
                      );

        push @items, \%details;
    }

    my %results = (
                   items    => \@items,
                   kind     => "youtube#videoListResponse",
                   pageInfo => {resultsPerPage => scalar(@items), totalResults => scalar(@items)},
                  );

    return scalar {results => \%results};
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
                   embedHtml => "<iframe type='text/html' src='https://www.youtube.com/embed/f6df3s3x3zo' width='640' height='360' frameborder='0' allowfullscreen='true'/>",
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

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Videos


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Videos
