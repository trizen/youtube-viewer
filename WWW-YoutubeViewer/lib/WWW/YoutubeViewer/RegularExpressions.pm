package WWW::YoutubeViewer::RegularExpressions;

use strict;

require Exporter;
our @ISA = qw(Exporter);

=head1 NAME

WWW::YoutubeViewer::RegularExpressions - Various utils.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer::RegularExpressions;
    use WWW::YoutubeViewer::RegularExpressions ($get_video_id_re);

=cut

my $opt_begin_chars = q{:;=};    # stdin option valid begin chars

# Options
our $range_num_re        = qr{^([0-9]{1,2}+)(?>-|\.\.)([0-9]{1,2}+)\z};
our $digit_or_equal_re   = qr{(?(?=[1-9])|=)};
our $non_digit_or_opt_re = qr{^(?!$range_num_re)(?>[0-9]{1,2}[^0-9]|[0-9]{3}|[^0-9$opt_begin_chars])};

# Generic name
my $generic_name_re = qr{[a-zA-Z0-9_.\-]{16,34}};
our $valid_username_re = qr{^(?:\w+(?:[-.]++\w++)*|$generic_name_re)\z};

# Video ID
my $video_id_re = qr{[0-9A-Za-z_\-]{11}};
our $valid_video_id_re = qr{^$video_id_re\z};
our $get_video_id_re   = qr{(?:%3F|\b)(?>v|embed|youtu[.]be)(?>[=/]|%3D)(?<video_id>$video_id_re)};

# Course ID
my $course_id_re = qr{EC(?<course_id>$generic_name_re)|(?<course_id>$generic_name_re)};
our $valid_course_id_re = qr{^$course_id_re\z};
our $get_course_id_re   = qr{/course\?list=$course_id_re};

# Playlist ID
our $valid_playlist_id_re = qr{^$generic_name_re\z};
our $get_playlist_id_re   = qr{(?:(?:(?>playlist\?list|view_play_list\?p)=)|\w#p/c/)(?<playlist_id>$generic_name_re)\b};

our $valid_opt_re = qr{^[$opt_begin_chars]([A-Za-z]++(?:-[A-Za-z]++)?(?>${digit_or_equal_re}.*)?)$};

our @EXPORT = qw(
  $range_num_re
  $digit_or_equal_re
  $non_digit_or_opt_re
  $valid_username_re
  $valid_video_id_re
  $get_video_id_re
  $valid_course_id_re
  $get_course_id_re
  $valid_playlist_id_re
  $get_playlist_id_re
  $valid_opt_re
  );

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::RegularExpressions


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2013 Trizen.

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

1;    # End of WWW::YoutubeViewer::RegularExpressions
