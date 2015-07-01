package WWW::YoutubeViewer::Subscriptions;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Subscriptions - Subscriptions handler.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $videos = $obj->subscriptions_from_channelID($channel_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_subscriptions_url {
    my ($self, %opts) = @_;
    return $self->_make_feed_url('subscriptions', %opts,);
}

=head2 subscribe_channel($username)

Subscribe to an user's channel.

=cut

sub subscribe_channel {
    my ($self, $user) = @_;
    ...    # NEEDS WORK!!!
}

=head2 subscriptions(;$channel_id)

Retrieve the subscriptions for a channel ID or for the authenticated user.

=cut

sub subscriptions {
    my ($self, $channel_id) = @_;
    $self->get_access_token() // return;
    return
      $self->_get_results(
                          $self->_make_subscriptions_url(
                                                         order => 'relevance',
                                                         defined($channel_id)
                                                         ? (channelId => $channel_id)
                                                         : (mine => 'true'),
                                                         , part => 'snippet'
                                                        )
                         );
}

=head2 subscriptions_from_username($username)

Retrieve subscriptions for a given YouTube username.

=cut

sub subscriptions_from_username {
    my ($self, $username) = @_;
    $self->subscriptions($self->channel_id_from_username($username) // $username);
}

=head2 subscription_videos(;$channel_id)

Retrieve the video subscriptions for a channel ID or for the current authenticated user.

=cut

sub subscription_videos {
    my ($self, $channel_id) = @_;

    my $url = $self->_make_subscriptions_url(
                                             order      => 'relevance',
                                             maxResults => 50,
                                             part       => 'snippet,contentDetails',
                                             defined($channel_id)
                                             ? (channelId => $channel_id)
                                             : (mine => 'true'),
                                            );

    my $max_results   = $self->get_maxResults();
    my $subscriptions = $self->_get_results($url)->{results};

    my @videos;
    foreach my $channel (@{$subscriptions->{items}}) {

        my $new_items = $channel->{contentDetails}{newItemCount};

        # Ignore channels with zero new items
        $new_items > 0 || next;

        # Set the number of results
        $self->set_maxResults(1);    # don't load more than 1 video from each channel
                                     # maybe, this value should be configurable (?)

        # Get and store the video uploads from each channel
        push @videos, @{$self->uploads($channel->{snippet}{resourceId}{channelId})->{results}{items}};

        # Stop when the limit is reached
        last if (@videos >= $max_results);
    }

    # When there are no new videos, load one from each channel
    if ($#videos == -1) {
        foreach my $channel (@{$subscriptions->{items}}) {
            $self->set_maxResults(1);
            push @videos, @{$self->uploads($channel->{snippet}{resourceId}{channelId})->{results}{items}};
            last if (@videos >= $max_results);
        }
    }

    $self->set_maxResults($max_results);
    return {results => {pageInfo => {totalResults => $#videos + 1}, items => \@videos}};
}

=head2 subscription_videos_from_username($username)

Retrieve the video subscriptions for a username.

=cut

sub subscription_videos_from_username {
    my ($self, $username) = @_;
    $self->subscription_videos($self->channel_id_from_username($username) // $username);
}

=head2 subscriptions_from_channelID(%args)

Get subscriptions for the specified channel ID.

=head2 subscriptions_info($subscriptionID, %args)

Get details for the comma-separated subscriptionID(s).

=head3 HASH '%args' supports the following pairs:

    %args = (
        part         => {contentDetails,id,snippet},
        forChannelId => $channelID,
        maxResults   => [0-50],
        order        => {alphabetical, relevance, unread},
        pageToken    => {$nextPageToken, $prevPageToken},
    );

=cut

{
    no strict 'refs';
    foreach my $method (
                        {
                         key  => 'id',
                         name => 'subscriptions_info',
                        },
                        {
                         key  => 'channelId',
                         name => 'subscriptions_from_channel_id',
                        }
      ) {
        *{__PACKAGE__ . '::' . $method->{name}} = sub {
            my ($self, $id, %args) = @_;
            return $self->_get_results($self->_make_subscriptions_url($method->{key} => $id, %args));
        };
    }
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Subscriptions


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

1;    # End of WWW::YoutubeViewer::Subscriptions
