package WWW::YoutubeViewer::Channels;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Channels - Channels interface.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $videos = $obj->channels_from_categoryID($category_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_channels_url {
    my ($self, %opts) = @_;
    return $self->_make_feed_url('channels', %opts,);
}

=head2 channels_from_categoryID($category_id)

Return the YouTube channels associated with the specified category.

=head2 channels_info($channel_id)

Return information for the comma-separated list of the YouTube channel ID(s).

=head1 Channel details

For all functions, C<$channels->{results}{items}> contains:

    [
       {
        id => "....",
        kind => "youtube#channel",
            snippet => {
            description => "...",
            publishedAt => "2010-06-24T23:15:37.000Z",
            thumbnails => {
                default => { url => "..." },
                high    => { url => "..." },
                medium  => { url => "..." },
            },
            title => "...",
          },  # end of snippet
       },
        ...
    ];

=cut

{
    no strict 'refs';

    foreach my $method (
                        {
                         key  => 'categoryId',
                         name => 'channels_from_guide_category',
                        },
                        {
                         key  => 'id',
                         name => 'channels_info',
                        },
                        {
                         key  => 'forUsername',
                         name => 'channels_from_username',
                        },
      ) {
        *{__PACKAGE__ . '::' . $method->{name}} = sub {
            my ($self, $id) = @_;
            return $self->_get_results($self->_make_channels_url($method->{key} => $id));
        };
    }

    foreach my $part (qw(id contentDetails statistics topicDetails)) {
        *{__PACKAGE__ . '::' . 'channels_' . $part} = sub {
            my ($self, $id) = @_;
            return $self->_get_results($self->_make_channels_url(id => $id, part => $part));
        };
    }
}

=head2 channels_my_subscribers()

Retrieve a list of channels that subscribed to the authenticated user's channel.

=cut

sub channels_my_subscribers {
    my ($self) = @_;
    $self->get_access_token() // return;
    return $self->_get_results($self->_make_channels_url(mySubscribers => 'true'));
}

=head2 channels_contentDetails($channelID)

  {
    items    => [
                  {
                    contentDetails => {
                      relatedPlaylists => {
                        likes   => "LLwiIs5V6-zX8xaYgwhRhsHQ",
                        uploads => "UUwiIs5V6-zX8xaYgwhRhsHQ",
                      },
                    },
                    etag => "...",
                    id => "UCwiIs5V6-zX8xaYgwhRhsHQ",
                    kind => "youtube#channel",
                  },
                ],
    kind     => "youtube#channelListResponse",
    pageInfo => { resultsPerPage => 1, totalResults => 1 },
  },

=head2 channels_statistics($channelID);

  {
    items    => [
                  {
                    etag => "...",
                    id => "UCwiIs5V6-zX8xaYgwhRhsHQ",
                    kind => "youtube#channel",
                    statistics => {
                      commentCount    => 14,
                      subscriberCount => 313823,
                      videoCount      => 474,
                      viewCount       => 1654024,
                    },
                  },
                ],
    kind     => "youtube#channelListResponse",
    pageInfo => { resultsPerPage => 1, totalResults => 1 },
  },

=head2 channels_topicDetails($channelID)

    items    => [
                  {
                    etag => "...",
                    id => "UCwiIs5V6-zX8xaYgwhRhsHQ",
                    kind => "youtube#channel",
                    topicDetails => {
                      topicIds => [
                        "/m/027lnzs",
                        "/m/0cp07v2",
                            ...
                      ],
                    },
                  },
                ],
    kind     => "youtube#channelListResponse",
    pageInfo => { resultsPerPage => 1, totalResults => 1 },

=cut

=head1 AUTHOR

Suteu "Trizen" Daniel, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Channels


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Suteu "Trizen" Daniel.

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

1;    # End of WWW::YoutubeViewer::Channels
