package WWW::YoutubeViewer::Activities;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Activities - list of channel activity events that match the request criteria.

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $activities = $obj->activities($channel_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_activities_url {
    my ($self, %opts) = @_;
    $self->_make_feed_url('activities', part => 'snippet,contentDetails', %opts);
}

=head2 activities($channel_id)

Get activities for channel ID.

=cut

sub activities {
    my ($self, $channel_id) = @_;

    if ($channel_id eq 'mine') {
        return $self->my_activities;
    }

    if ($channel_id !~ /^UC/) {
        $channel_id = $self->channel_id_from_username($channel_id) // $channel_id;
    }

    $self->_get_results($self->_make_activities_url(channelId => $channel_id));
}

=head2 activities_from_username($username)

Get activities for username.

=cut

sub activities_from_username {
    my ($self, $username) = @_;
    return $self->activities($username);
}

=head2 my_activities()

Get authenticated user's activities.

=cut

sub my_activities {
    my ($self) = @_;
    $self->get_access_token() // return;
    $self->_get_results($self->_make_activities_url(mine => 'true'));
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Activities


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Activities
