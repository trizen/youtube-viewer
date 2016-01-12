package WWW::YoutubeViewer::VideoCategories;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::VideoCategories - videoCategory resource handler.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    my $videos = $obj->videos_from_categoryID($category_id);

=head1 SUBROUTINES/METHODS

=cut

sub _make_videoCategories_url {
    my ($self, %opts) = @_;

    if (not exists $opts{id}) {
        $opts{regionCode} //= $self->get_regionCode;
    }

    $self->_make_feed_url(
                          'videoCategories',
                          hl => $self->get_hl,
                          %opts,
                         );
}

=head2 video_categories(;$region_id)

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
    my ($self, $code) = @_;

    state $x = require File::Spec;

    my $url = $self->_make_videoCategories_url(regionCode => $code);
    my $file = File::Spec->catfile($self->get_config_dir, "categories-$code-" . $self->get_hl() . ".json");

    my $json;
    if (open(my $fh, '<:utf8', $file)) {
        local $/;
        $json = <$fh>;
        close $fh;
    }
    else {
        $json = $self->lwp_get($url);
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

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::VideoCategories


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

1;    # End of WWW::YoutubeViewer::VideoCategories
