package WWW::YoutubeViewer::Authentication;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Authentication - OAuth login support.

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

Refresh the access_token using the refresh_token. Returns a HASH ref with the `access_token` or undef.

=cut

sub oauth_refresh_token {
    my ($self) = @_;

    my $json_data = $self->lwp_post(
                                    $self->_get_token_oauth_url(),
                                    headers => [Content       => $self->get_www_content_type,
                                                client_id     => $self->get_client_id()     // return,
                                                client_secret => $self->get_client_secret() // return,
                                                refresh_token => $self->get_refresh_token() // return,
                                                grant_type    => 'refresh_token',
                                               ],
                                    simple => 1,
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
                                      client_id     => $self->get_client_id()    // return,
                                      redirect_uri  => $self->get_redirect_uri() // return,
                                      scope         => 'https://www.googleapis.com/auth/youtube.force-ssl',
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
                                    headers => [Content       => $self->get_www_content_type,
                                                client_id     => $self->get_client_id()     // return,
                                                client_secret => $self->get_client_secret() // return,
                                                redirect_uri  => $self->get_redirect_uri()  // return,
                                                grant_type    => 'authorization_code',
                                                code          => $code,
                                               ],
                                    simple => 1,
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

    my $file = $self->get_authentication_file() // return;
    my $key  = $self->get_key()                 // return;

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

=head2 load_credentials($file)

Load the API key and the client ID/SECRET values from a given JSON file having the following format:

    {
        "key":           "API_KEY",
        "client_id":     "CLIENT_ID",
        "client_secret": "CLIENT_SECRET"
    }

Returns true on success and false otherwise.

=cut

sub load_credentials {
    my ($self, $api_file) = @_;

    open(my $fh, '<', $api_file) or do {
        warn "[!] Can't open file <<$api_file>> for reading: $!\n";
        return;
    };

    my $content = do { local $/; <$fh> };
    my $api     = $self->parse_json_string($content);

    if (ref($api) ne 'HASH') {
        warn "[!] Invalid format inside file: $api_file\n";
        return;
    }

    my $orig_key           = $self->get_key;
    my $orig_client_id     = $self->get_client_id;
    my $orig_client_secret = $self->get_client_secret;

    my $key           = $api->{key};
    my $client_id     = $api->{client_id};
    my $client_secret = $api->{client_secret};

    if (defined($key)) {
        $self->set_key($key) // do {
            warn "[!] Invalid key: $key\n" if $key ne 'API_KEY';
            $self->set_key($orig_key);
        };
    }
    if (defined($client_id)) {
        $self->set_client_id($client_id) // do {
            warn "[!] Invalid client_id: $client_id\n" if $client_id ne 'CLIENT_ID';
            $self->set_client_id($orig_client_id);
        };
    }
    if (defined($client_secret)) {
        $self->set_client_secret($client_secret) // do {
            warn "[!] Invalid client_secret: $client_secret\n" if $client_secret ne 'CLIENT_SECRET';
            $self->set_client_secret($orig_client_secret);
        };
    }

    return 1;
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Authentication


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Authentication
