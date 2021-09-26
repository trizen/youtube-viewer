package WWW::YoutubeViewer::Playlists;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Playlists - Youtube playlists handle.

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $info = $obj->playlist_from_id($playlist_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_playlists_url {
    my ($self, %opts) = @_;

    if (not exists $opts{'part'}) {
        $opts{'part'} = 'snippet,contentDetails';
    }

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

    ref($res->{results}{items}) eq 'ARRAY' || return;
    @{$res->{results}{items}}              || return;

    my $id = $res->{results}{items}[0]{contentDetails}{relatedPlaylists}{$playlist_name};

    return $id if defined($id);

    # Fallback method

    $playlist_name eq 'favorites' or return undef;    # currently, only "favorites" require the fallback method

    if (defined($fields{forUsername})) {
        my $channel_id = $self->channel_id_from_username(delete $fields{forUsername});
        $fields{channelId} = $channel_id;
    }

    if (defined($fields{id})) {
        $fields{channelId} = delete $fields{id};
    }

    state $yv_utils = WWW::YoutubeViewer::Utils->new;

    for (1 .. 10) {

        my $playlists =
          $self->_get_results($self->_make_feed_url('playlists', part => 'contentDetails', maxResults => 50, %fields));

        $yv_utils->has_entries($playlists) or last;

        my $results = $playlists->{results};

        ref($results) eq 'HASH'           or last;
        ref($results->{items}) eq 'ARRAY' or last;

        my @page_playlists = @{$results->{items}};

        foreach my $playlist (@page_playlists) {
            ref($playlist) eq 'HASH' or next;
            if ($playlist_name eq 'favorites' and $playlist->{id} =~ /^FL/) {
                return $playlist->{id};
            }
        }

        if (defined($results->{nextPageToken})) {
            $fields{pageToken} = $results->{nextPageToken};
        }
        else {
            last;
        }
    }

    return undef;
}

=head2 playlist_from_id($playlist_id, $part = "snippet")

Return info for one or more playlist IDs.

Multiple playlist IDs can be separated by commas.

=cut

sub playlist_from_id {
    my ($self, $id, $part) = @_;
    $self->_get_results($self->_make_playlists_url(id => $id, part => ($part // 'snippet')));
}

=head2 playlists($channel_id)

Get and return playlists from a channel ID.

=cut

sub playlists {
    my ($self, $channel_id) = @_;
    $self->_get_results(
        $self->_make_playlists_url(
              ($channel_id and $channel_id ne 'mine')
            ? (channelId => $channel_id)
            : do { $self->get_access_token() // return; (mine => 'true') }
        )
    );
}

=head2 playlists_from_username($username)

Get and return the playlists created for a given username.

=cut

sub playlists_from_username {
    my ($self, $username) = @_;
    my $channel_id = $self->channel_id_from_username($username) // $username;
    $self->playlists($channel_id);
}

=head2 my_playlists()

Get and return your playlists.

=cut

sub my_playlists {
    my ($self) = @_;
    $self->get_access_token() // return;
    $self->_get_results($self->_make_playlists_url(mine => 'true'));
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Playlists


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Playlists
