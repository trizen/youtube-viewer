package WWW::YoutubeViewer::Activities;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Activities - ...

=head1 SYNOPSIS

    use WWW::YoutubeViewer::Activities;
    my $obj = WWW::YoutubeViewer::Activities->new(%opts);

=head1 SUBROUTINES/METHODS

=cut

sub _make_activities_url {
    my ($self, %opts) = @_;
    $self->_make_feed_url('activities', %opts,);
}

=head2 activities_for_channel_id($channel_id)

Get activities for channel ID.

=cut

sub activities_for_channel_id {
    my ($self, $channel_id) = @_;
    $self->_get_results($self->_make_feed_url(channelId => $channel_id));
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Activities


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Activities
