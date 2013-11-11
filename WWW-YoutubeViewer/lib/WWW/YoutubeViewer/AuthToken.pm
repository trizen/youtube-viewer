package WWW::YoutubeViewer::AuthToken;

use 5.010;
use strict;
use warnings;

=head1 NAME

WWW::YoutubeViewer::AuthToken - Encode/decode the authentication tokens

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer::AuthToken;

    my $yv_token = WWW::YoutubeViewer::AuthToken->new(key => "SOME_KEY");

    my $decoded = $yv_token->decode($token);
    my $encoded = $yv_token->encode($token);

    # Encode and store the tokens inside a file
    $yv_token->to_file($access_token, $refresh_token, $file);

    # Decode and return the tokens from a file
    my ($access_token, $refresh_token) = $yv_token->from_file($file);

=head1 SUBROUTINES/METHODS

=head2 new()

Return the blessed object.

=cut

sub new {
    my $class = shift;
    bless {@_, EOL => "\0" x 3}, $class;
}

=head2 encode($token)

Encode the token with a given key and return it.

=cut

sub encode {
    my ($self, $token) = @_;

    require MIME::Base64;
    MIME::Base64::encode_base64($token ^ substr($self->{key}, -length($token)));
}

=head2 decode($token)

Decode the token with a given key and return it.

=cut

sub decode {
    my ($self, $token) = @_;

    require MIME::Base64;
    my $bin = MIME::Base64::decode_base64($token);
    $bin ^ substr($self->{key}, -length($bin));
}

=head2 to_file($acess_token, $refresh_token, $file)

Encode and save the token in a file.

=cut

sub to_file {
    my ($self, $access_token, $refresh_token, $file) = @_;

    if (open my $fh, '>:raw', $file) {
        foreach my $token ($access_token, $refresh_token) {
            print {$fh} $self->encode($token) . $self->{EOL};
        }
        close $fh;
        return 1;
    }

    return;
}

=head2 from_file($file)

Encode and save the token in a file.

=cut

sub from_file {
    my ($self, $file) = @_;

    if (-f $file) {
        local $/ = $self->{EOL};
        open my $fh, '<:raw', $file;

        my @tokens;
        foreach my $i (0 .. 1) {
            chomp(my $token = <$fh>);
            $token =~ /\S/ || last;
            push @tokens, $self->decode($token);
        }

        close $fh;
        return @tokens;
    }

    return;
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::AuthToken


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Trizen.

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

1;    # End of WWW::YoutubeViewer::AuthToken
