package WWW::YoutubeViewer::VideoCategories;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::VideoCategories - videoCategory resource handler.

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $cats = $obj->video_categories();

=head1 SUBROUTINES/METHODS

=cut

sub _make_videoCategories_url {
    my ($self, %opts) = @_;

    $self->_make_feed_url(
                          'videoCategories',
                          hl => $self->get_hl,
                          %opts,
                         );
}

=head2 video_categories()

Return video categories for a specific region ID.

                {
                   etag => "\"IHLB7Mi__JPvvG2zLQWAg8l36UU/Xb5JLhtyNRN3AQq021Ds-OV50Jk\"",
                   id => 35,
                   kind => "youtube#videoCategory",
                   snippet => {
                     assignable => 'fix',
                     channelId => "UCBR8-60-B28hp2BmDPdntcQ",
                     title => "Documentary",
                   },
                 },

=cut

sub video_categories {
    my ($self) = @_;

    if (not defined $self->get_key) {
        warn "[!] No API key has been set...\n";
        return {};
    }

    require File::Spec;

    my $region = $self->get_regionCode() // 'US';
    my $url    = $self->_make_videoCategories_url(regionCode => $region);
    my $file   = File::Spec->catfile($self->get_config_dir, "categories-$region-" . $self->get_hl() . ".json");

    my $json;
    if (-f $file and not -z _ and open(my $fh, '<:utf8', $file)) {
        local $/;
        $json = <$fh>;
        close $fh;
    }
    else {
        $json = $self->lwp_get($url, simple => 1) // return {};
        open my $fh, '>:utf8', $file;
        print {$fh} $json;
        close $fh;
    }

    return $self->parse_json_string($json);
}

=head2 video_category_id_info($cagegory_id)

Return info for the comma-separated specified category ID(s).

=cut

sub video_category_id_info {
    my ($self, $id) = @_;
    return $self->_get_results($self->_make_videoCategories_url(id => $id));
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::VideoCategories


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::VideoCategories
