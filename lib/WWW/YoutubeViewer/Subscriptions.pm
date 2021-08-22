package WWW::YoutubeViewer::Subscriptions;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Subscriptions - Subscriptions handler.

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $videos = $obj->subscriptions_from_channelID($channel_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_subscriptions_url {
    my ($self, %opts) = @_;
    return $self->_make_feed_url('subscriptions', %opts);
}

=head2 subscribe_channel($channel_id)

Subscribe to an YouTube channel.

=cut

sub subscribe_channel {
    my ($self, $channel_id) = @_;

    $self->get_access_token() // return;

    my $resource = {
                    snippet => {
                                resourceId => {
                                               kind      => 'youtube#channel',
                                               channelId => $channel_id,
                                              }
                               }
                   };

    my $url = $self->_simple_feeds_url('subscriptions', part => 'snippet');
    return $self->post_as_json($url, $resource);
}

=head2 subscribe_channel_from_username($username)

Subscribe to an YouTube channel via username.

=cut

sub subscribe_channel_from_username {
    my ($self, $username) = @_;
    $self->subscribe_channel($self->channel_id_from_username($username) // $username);
}

=head2 unsubscribe_channel($channel_id)

Unsubscribe from an YouTube channel.

=cut

sub unsubscribe_channel {
    my ($self, $channel_id) = @_;

    $self->get_access_token() // return;

    my $info = $self->subscriptions_from_channel_id(
                                                    undef,
                                                    mine         => 'true',
                                                    part         => 'id',
                                                    forChannelId => $channel_id
                                                   );

    my $id;

    if (defined($info) and ref($info->{results}) eq 'HASH' and ref($info->{results}{items}) eq 'ARRAY') {
        ($id) = grep { defined($_) } map { ref($_) eq 'HASH' ? $_->{id} : undef } @{$info->{results}{items}};
    }

    if (defined($id)) {
        my $url = $self->_simple_feeds_url('subscriptions', id => $id);
        return $self->lwp_delete($url);
    }

    return;
}

=head2 unsubscribe_channel_from_username($username)

Unsubscribe from an YouTube channel via username.

=cut

sub unsubscribe_channel_from_username {
    my ($self, $username) = @_;
    $self->unsubscribe_channel($self->channel_id_from_username($username) // $username);
}

=head2 subscriptions(;$channel_id)

Retrieve the subscriptions for a channel ID or for the authenticated user.

=cut

sub subscriptions {
    my ($self, $channel_id) = @_;
    $self->_get_results(
        $self->_make_subscriptions_url(
            order => $self->get_subscriptions_order,
            part  => 'snippet',
            (
               ($channel_id and $channel_id ne 'mine')
             ? (channelId => $channel_id)
             : do { $self->get_access_token() // return; (mine => 'true') }
            ),
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
    my ($self, $channel_id, $order) = @_;

    my $max_results = $self->get_maxResults();

    my @subscription_items;
    my $next_page_token;

    while (1) {

        my $url = $self->_make_subscriptions_url(
                                                 order      => $self->get_subscriptions_order,
                                                 maxResults => 50,
                                                 part       => 'snippet,contentDetails',
                                                 ($channel_id and $channel_id ne 'mine')
                                                 ? (channelId => $channel_id)
                                                 : do { $self->get_access_token() // return; (mine => 'true') },
                                                 defined($next_page_token) ? (pageToken => $next_page_token) : (),
                                                );

        my $subscriptions = $self->_get_results($url)->{results};

        if (    ref($subscriptions) eq 'HASH'
            and ref($subscriptions->{items}) eq 'ARRAY') {
            push @subscription_items, @{$subscriptions->{items}};
        }

        $next_page_token = $subscriptions->{nextPageToken} || last;
    }

    my (undef, undef, undef, $mday, $mon, $year) = localtime;

    $mon  += 1;
    $year += 1900;

    my @videos;
    foreach my $channel (@subscription_items) {

        my $new_items = $channel->{contentDetails}{newItemCount};

        # Ignore channels with zero new items
        $new_items > 0 || next;

        # Set the number of results
        $self->set_maxResults(1);    # don't load more than 1 video from each channel
                                     # maybe, this value should be configurable (?)

        my $uploads = $self->uploads($channel->{snippet}{resourceId}{channelId});

        (ref($uploads) eq 'HASH' and ref($uploads->{results}) eq 'HASH' and ref($uploads->{results}{items}) eq 'ARRAY')
          || return;

        my $items = $uploads->{results}{items};

        # Get and store the video uploads from each channel
        foreach my $item (@$items) {
            my $publishedAt = $item->{snippet}{publishedAt};
            my ($p_year, $p_mon, $p_mday) = $publishedAt =~ /^(\d{4})-(\d{2})-(\d{2})/;

            my $year_diff = $year - $p_year;
            my $mon_diff  = $mon - $p_mon;
            my $mday_diff = $mday - $p_mday;

            my $days_diff = $year_diff * 365.2422 + $mon_diff * 30.436875 + $mday_diff;

            # Ignore old entries
            if ($days_diff > 3) {
                next;
            }

            push @videos, $item;
        }

        # Stop when the limit is reached
        last if (@videos >= $max_results);
    }

    # When there are no new videos, load one from each channel
    if ($#videos == -1) {
        foreach my $channel (@subscription_items) {
            $self->set_maxResults(1);
            push @videos, @{$self->uploads($channel->{snippet}{resourceId}{channelId})->{results}{items}};
            last if (@videos >= $max_results);
        }
    }

    $self->set_maxResults($max_results);

    state $yv_utils = WWW::YoutubeViewer::Utils->new;
    @videos = sort { $yv_utils->compare_published_dates($b, $a) } @videos;

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

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Subscriptions


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Subscriptions
