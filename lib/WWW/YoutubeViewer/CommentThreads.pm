package WWW::YoutubeViewer::CommentThreads;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::CommentThreads - Retrieve comments threads.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

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
                                                          order      => 'time',
                                                          part       => 'snippet'
                                                         ),
                          1
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

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::CommentThreads


=head1 LICENSE AND COPYRIGHT

Copyright 2015-2016 Trizen.

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

1;    # End of WWW::YoutubeViewer::CommentThreads
