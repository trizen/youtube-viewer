package WWW::YoutubeViewer::CommentThreads;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::CommentThreads - Retrieve comments threads.

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $videos = $obj->comments_from_video_id($video_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_commentThreads_url {
    my ($self, %opts) = @_;
    return
      $self->_make_feed_url(
                            'commentThreads',
                            pageToken => $self->page_token,
                            %opts
                           );
}

=head2 comments_from_videoID($videoID)

Retrieve comments from a video ID.

=cut

sub comments_from_video_id {
    my ($self, $video_id) = @_;
    return
      $self->_get_results(
                          $self->_make_commentThreads_url(
                                                          videoId    => $video_id,
                                                          textFormat => 'plainText',
                                                          order      => $self->get_comments_order,
                                                          part       => 'snippet,replies'
                                                         ),
                          simple => 1,
                         );
}

=head2 comment_to_video_id($comment, $videoID)

Send a comment to a video ID.

=cut

sub comment_to_video_id {
    my ($self, $comment, $video_id) = @_;

    my $url = $self->_simple_feeds_url('commentThreads', part => 'snippet');

    my $hash = {
        "snippet" => {

            "topLevelComment" => {
                                  "snippet" => {
                                                "textOriginal" => $comment,
                                               }
                                 },
            "videoId" => $video_id,

            #"channelId"    => $channel_id,
        },
    };

    $self->post_as_json($url, $hash);
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::CommentThreads


=head1 LICENSE AND COPYRIGHT

Copyright 2015-2016 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::CommentThreads
