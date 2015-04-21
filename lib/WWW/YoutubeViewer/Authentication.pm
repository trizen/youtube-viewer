package WWW::YoutubeViewer::Authentication;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Authentication - OAuth login support.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $hash_ref = WWW::YoutubeViewer->oauth_login($code);

=head1 SUBROUTINES/METHODS

=cut

sub _get_token_oauth_url {
    my ($self) = @_;
    return $self->get_oauth_url() . 'token';
}

=head2 oauth_refresh_token()

Refresh the access_token using the refresh_token. Returns a JSON string or undef.

=cut

sub oauth_refresh_token {
    my ($self) = @_;

    my $json_data = $self->lwp_post(
                                    $self->_get_token_oauth_url(),
                                    [Content       => $self->get_www_content_type,
                                     client_id     => $self->get_client_id() // return,
                                     client_secret => $self->get_client_secret() // return,
                                     refresh_token => $self->get_refresh_token() // return,
                                     grant_type    => 'refresh_token',
                                    ]
                                   );

    return $self->parse_json_string($json_data);
}

=head2 get_accounts_oauth_url()

Creates an OAuth URL with the 'code' response type. (Google's authorization server)

=cut

sub get_accounts_oauth_url {
    my ($self) = @_;

    my $url = $self->_append_url_args(
                                      ($self->get_oauth_url() . 'auth'),
                                      response_type => 'code',
                                      client_id     => $self->get_client_id() // return,
                                      redirect_uri  => $self->get_redirect_uri() // return,
                                      scope         => 'https://www.googleapis.com/auth/youtube',
                                      access_type   => 'offline',
                                     );
    return $url;
}

=head2 oauth_login($code)

Returns a HASH ref with the access_token, refresh_token and some other info.

The $code can be obtained by going to the URL returned by the C<get_accounts_oauth_url()> method.

=cut

sub oauth_login {
    my ($self, $code) = @_;

    length($code) < 20 and return;

    my $json_data = $self->lwp_post(
                                    $self->_get_token_oauth_url(),
                                    [Content       => $self->get_www_content_type,
                                     client_id     => $self->get_client_id() // return,
                                     client_secret => $self->get_client_secret() // return,
                                     redirect_uri  => $self->get_redirect_uri() // return,
                                     grant_type    => 'authorization_code',
                                     code          => $code,
                                    ]
                                   );

    return $self->parse_json_string($json_data);
}

sub __AUTH_EOL__() { "\0\0\0" }

=head2 load_authentication_tokens()

Will try to load the access and refresh tokens from I<authentication_file>.

=cut

sub load_authentication_tokens {
    my ($self) = @_;

    if (defined $self->get_access_token and defined $self->get_refresh_token) {
        return 1;
    }

    if (defined(my $file = $self->get_authentication_file) and defined(my $key = $self->get_key)) {
        if (-f $file) {
            local $/ = __AUTH_EOL__;
            open my $fh, '<:raw', $file or return;

            my @tokens;
            foreach my $i (0 .. 1) {
                chomp(my $token = <$fh>);
                $token =~ /\S/ || last;
                push @tokens, $self->decode_token($token);
            }

            $self->set_access_token($tokens[0])  // return;
            $self->set_refresh_token($tokens[1]) // return;

            close $fh;
            return 1;
        }

    }

    return;
}

=head2 encode_token($token)

Encode the token with the I<key> and return it.

=cut

sub encode_token {
    my ($self, $token) = @_;

    if (defined(my $key = $self->get_key)) {
        require MIME::Base64;
        return MIME::Base64::encode_base64($token ^ substr($key, -length($token)));
    }

    return;
}

=head2 decode_token($token)

Decode the token with the I<key> and return it.

=cut

sub decode_token {
    my ($self, $token) = @_;

    if (defined(my $key = $self->get_key)) {
        require MIME::Base64;
        my $bin = MIME::Base64::decode_base64($token);
        return $bin ^ substr($key, -length($bin));
    }

    return;
}

=head2 save_authentication_tokens()

Encode and save the access and refresh into the I<authentication_file>.

=cut

sub save_authentication_tokens {
    my ($self) = @_;

    my $file          = $self->get_authentication_file() // return;
    my $access_token  = $self->get_access_token()        // return;
    my $refresh_token = $self->get_refresh_token()       // return;

    if (open my $fh, '>:raw', $file) {
        foreach my $token ($access_token, $refresh_token) {
            print {$fh} $self->encode_token($token) . __AUTH_EOL__;
        }
        close $fh;
        return 1;
    }

    return;
}

=head1 AUTHOR

Suteu "Trizen" Daniel, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Authentication


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

1;    # End of WWW::YoutubeViewer::Authentication
