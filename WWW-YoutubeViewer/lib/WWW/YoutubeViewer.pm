package WWW::YoutubeViewer;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

use utf8;
use strict;

=encoding utf8

=head1 NAME

WWW::YoutubeViewer - A very easy interface to YouTube.

=head1 VERSION

Version 0.06

=cut

our $VERSION = '0.05';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;

    my $yv_obj = WWW::YoutubeViewer->new();
    ...

=head1 SUBROUTINES/METHODS

=cut

our @feeds_IDs = qw(top_rated top_favorites most_shared most_popular
  most_recent most_discussed most_responded recently_featured on_the_web);

our @movie_IDs = qw(most_popular most_recent trending);

our @categories_IDs = qw(Film Autos Music Animals Sports Travel Games
  People Comedy Entertainment News Howto Education Tech Nonprofit Movies Trailers);

our @region_IDs = qw(
  AR AU BR CA CZ FR DE GB HK HU IN IE IL
  IT JP MX NL NZ PL RU ZA KR ES SE TW US
  );

our @feed_methods = qw(newsubscriptionvideos recommendations favorites watch_history watch_later);

my %valid_options = (

    # Main options
    v           => {valid => q[],                                        default => 2},
    page        => {valid => [qr/^(?!0+\z)\d+\z/],                       default => 1},
    results     => {valid => [1 .. 50],                                  default => 10},
    hd          => {valid => [qw(true)],                                 default => undef},
    http_proxy  => {valid => [qr{^http://}],                             default => undef},
    caption     => {valid => [qw(true false)],                           default => undef},
    duration    => {valid => [qw(short medium long)],                    default => undef},
    category    => {valid => \@categories_IDs,                           default => undef},
    region      => {valid => \@region_IDs,                               default => undef},
    orderby     => {valid => [qw(relevance published viewCount rating)], default => undef},
    time        => {valid => [qw(today this_week this_month all_time)],  default => undef},
    safe_search => {valid => [qw(strict moderate none)],                 default => undef},

    # Others
    debug       => {valid => [0 .. 2],               default => 0},
    lwp_timeout => {valid => [qr/^\d+$/],            default => 30},
    key         => {valid => [qr/^.{5}/],            default => undef},
    author      => {valid => [qr{^[\-\w.]{2,64}\z}], default => undef},
    config_dir  => {valid => [qr/^./],               default => q{.}},

    use_internal_xml_parser => {valid => [1, 0], default => 0},

    authentication_file => {valid => [qr/^./],         default => undef},
    categories_language => {valid => [qr/^[a-z]+-\w/], default => 'en-US'},

    # Booleans
    lwp_env_proxy => {valid => [1, 0], default => 1},
    escape_utf8   => {valid => [1, 0], default => 0},

    # OAuth stuff
    client_id     => {valid => [qr/^.{5}/], default => undef},
    client_secret => {valid => [qr/^.{5}/], default => undef},
    redirect_uri  => {valid => [qr/^.{5}/], default => undef},
    access_token  => {valid => [qr/^.{5}/], default => undef},
    refresh_token => {valid => [qr/^.{5}/], default => undef},

    # No input value alowed
    categories_url    => {valid => q[], default => 'http://gdata.youtube.com/schemas/2007/categories.cat'},
    educategories_url => {valid => q[], default => 'http://gdata.youtube.com/schemas/2007/educategories.cat'},
    feeds_url         => {valid => q[], default => 'http://gdata.youtube.com/feeds/api'},
    video_info_url    => {valid => q[], default => 'http://www.youtube.com/get_video_info'},
    oauth_url         => {valid => q[], default => 'https://accounts.google.com/o/oauth2/'},
    video_info_args   => {valid => q[], default => '?video_id=%s&el=detailpage&ps=default&eurl=&gl=US&hl=en'},
    www_content_type  => {valid => q[], default => 'application/x-www-form-urlencoded'},

    # LWP user agent
    lwp_agent => {valid => [qr/^.{5}/], default => 'Mozilla/5.0 (X11; U; Linux i686; en-US) Chrome/10.0.648.45'},
);

{
    no strict 'refs';

    foreach my $key (keys %valid_options) {

        if (ref $valid_options{$key}{valid} eq 'ARRAY') {

            # Create the 'set_*' subroutines
            *{__PACKAGE__ . '::set_' . $key} = sub {
                my ($self, $value) = @_;
                $self->{$key} =
                    $value ~~ $valid_options{$key}{valid}
                  ? $value
                  : $valid_options{$key}{default};
            };
        }

        # Create the 'get_*' subroutines
        *{__PACKAGE__ . '::get_' . $key} = sub {
            return $_[0]->{$key};
        };
    }
}

=head2 new(%opts)

Returns a blessed object.

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = bless {}, $class;

    foreach my $key (keys %valid_options) {
        if (ref $valid_options{$key}{valid} ne 'ARRAY') {
            $self->{$key} = $valid_options{$key}{default};
        }
        else {
            my $code = \&{"set_$key"};
            $self->$code(delete $opts{$key});
        }
    }

    $self->load_authentication_tokens();

    foreach my $invalid_key (keys %opts) {
        warn "Invalid key: '${invalid_key}'";
    }

    return $self;
}

=head2 set_prefer_https($bool)

Will use https:// protocol instead of http://.

=cut

sub set_prefer_https {
    my ($self, $bool) = @_;
    $self->{prefer_https} = $bool;

    foreach my $key (grep /_url\z/, keys %valid_options) {
        next if $key ~~ [qw(oauth_url)];
        my $url = $valid_options{$key}{default};
        $self->{prefer_https} ? ($url =~ s{^http://}{https://}) : ($url =~ s{^https://}{http://});
        $self->{$key} = $url;
    }

    return $bool;
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

=head2 get_prefer_https()

Will return the value of prefer_https.

=cut

sub get_prefer_https {
    my ($self) = @_;
    return $self->{prefer_https};
}

=head2 get_start_index_var($page, $results)

Returns the start_index value for the specific variables.

=cut

sub get_start_index_var {
    my ($self, $page, $results) = @_;
    return $results * $page - $results + 1;
}

=head2 get_start_index()

Returns the start_index based on the page number and results.

=cut

sub get_start_index {
    my ($self) = @_;
    return $self->get_results() * $self->get_page() - $self->get_results() + 1;
}

=head2 back_page_is_available($url)

Returns true if a previous page is available.

=cut

sub back_page_is_available {
    my ($self, $url) = @_;
    $url =~ /[&?]start-index=(\d+)\b/ or return;
    return $1 > $self->get_results();
}

=head2 escape_string($string)

Escapes a string with URI::Escape and returns it.

=cut

sub escape_string {
    my ($self, $string) = @_;

    require URI::Escape;

    if ($self->get_escape_utf8) {
        utf8::decode($string);
    }

    my $escaped =
      $self->get_escape_utf8()
      ? URI::Escape::uri_escape_utf8($string)
      : URI::Escape::uri_escape($string);

    return $escaped;
}

=head2 list_to_gdata_arguments(%options)

Returns a valid string of arguments, with defined values.

=cut

sub list_to_gdata_arguments {
    my ($self, %opts) = @_;

    return join(q{&} => map "$_=$opts{$_}", grep defined $opts{$_}, keys %opts);
}

=head2 default_gdata_arguments()

Returns a string with the default gdata arguments.

=cut

sub default_gdata_arguments {
    my ($self) = @_;
    $self->list_to_gdata_arguments(
                                   'max-results' => $self->get_results,
                                   'start-index' => $self->get_start_index,
                                   'v'           => $self->get_v,
                                  );
}

=head2 set_lwp_useragent()

Intializes the LWP::UserAgent module and returns it.

=cut

sub set_lwp_useragent {
    my ($self) = @_;

    binmode *STDOUT, ":encoding(UTF-8)";

    require LWP::UserAgent;
    $self->{lwp} = 'LWP::UserAgent'->new(
                                         env_proxy => (defined($self->get_http_proxy) ? 0 : $self->get_lwp_env_proxy),
                                         timeout => $self->get_lwp_timeout,
                                         show_progress => $self->get_debug,
                                         agent         => $self->get_lwp_agent,
                                        );

    push @{$self->{lwp}->requests_redirectable}, 'POST';
    $self->{lwp}->proxy('http', $self->get_http_proxy) if (defined($self->get_http_proxy));
    return $self->{lwp};
}

sub _get_token_oauth_url {
    my ($self) = @_;
    return $self->get_oauth_url() . 'token';
}

=head2 get_accounts_oauth_url()

Creates an OAuth URL with the 'code' response type. (Google's authorization server)

=cut

sub get_accounts_oauth_url {
    my ($self) = @_;

    my $url = $self->_concat_args(
                                  ($self->get_oauth_url() . 'auth'),
                                  response_type => 'code',
                                  client_id     => $self->get_client_id() // return,
                                  redirect_uri  => $self->get_redirect_uri() // return,
                                  scope         => 'https://gdata.youtube.com',
                                 );

    return $url;
}

=head2 oauth_refresh_token()

Refresh the access_token using the refresh_token. Returns a JSON string or undef.

=cut

sub oauth_refresh_token {
    my ($self) = @_;

    return
      $self->lwp_post(
                      $self->_get_token_oauth_url(),
                      [Content       => $self->get_www_content_type,
                       client_id     => $self->get_client_id() // return,
                       client_secret => $self->get_client_secret() // return,
                       refresh_token => $self->get_refresh_token() // return,
                       grant_type    => 'refresh_token',
                      ]
                     );
}

=head2 oauth_login($code)

Returns a JSON string with the access_token, refresh_token and some other info.

The $code can be obtained by going to the URL returned by the C<get_accounts_oauth_url()> method.

=cut

sub oauth_login {
    my ($self, $code) = @_;

    length($code) < 20 and return;

    return
      $self->lwp_post(
                      $self->_get_token_oauth_url(),
                      [Content       => $self->get_www_content_type,
                       client_id     => $self->get_client_id() // return,
                       client_secret => $self->get_client_secret() // return,
                       redirect_uri  => $self->get_redirect_uri() // return,
                       grant_type    => 'authorization_code',
                       code          => $code,
                      ]
                     );
}

=head2 prepare_key()

Returns a string, used as header, with the developer's key.

=cut

sub prepare_key {
    my ($self) = @_;

    if (defined(my $key = $self->get_key)) {
        return "key=$key";
    }

    return;
}

=head2 prepare_access_token()

Returns a string. used as header, with the access token.

=cut

sub prepare_access_token {
    my ($self) = @_;

    if (defined(my $auth = $self->get_access_token)) {
        return "Bearer $auth";
    }

    return;
}

sub _get_lwp_header {
    my ($self) = @_;

    my %lwp_header;
    if (defined $self->get_key) {
        $lwp_header{'X-GData-Key'} = $self->prepare_key;
    }

    if (defined $self->get_access_token) {
        $lwp_header{'Authorization'} = $self->prepare_access_token;
    }

    return %lwp_header;
}

=head2 lwp_get($url)

Get and return the content for $url.

=cut

sub lwp_get {
    my ($self, $url) = @_;

    $self->{lwp} // $self->set_lwp_useragent();

    my %lwp_header = $self->_get_lwp_header();
    my $response = $self->{lwp}->get($url, %lwp_header);

    if ($response->is_success) {
        return $response->decoded_content;
    }
    else {
        my $status = $response->status_line;

        if ($status eq '401 Token invalid' and defined($self->get_refresh_token)) {
            if (defined(my $json = $self->oauth_refresh_token())) {
                if ($json =~ m{^\h*"access_token"\h*:\h*"(.{10,}?)"}m) {

                    $self->set_access_token($1);

                    # Don't be tempted to use recursion here, because bad things will happen!
                    my $new_resp = $self->{lwp}->get($url, $self->_get_lwp_header);

                    if ($new_resp->is_success) {
                        $self->save_authentication_tokens();
                        return $new_resp->decoded_content;
                    }
                    elsif ($new_resp->status_line() eq '401 Token invalid') {
                        $self->set_refresh_token();    # refresh token was invalid
                        $self->set_access_token();     # access token is also broken
                        warn "[!] Can't refresh the access token!\n";
                    }
                    else {
                        warn '[' . $new_resp->status_line . "] Error occured on URL: $url\n";
                    }
                }
                else {
                    warn "[!] Can't get the access_token! Logging out...\n";
                    $self->set_refresh_token();
                    $self->set_access_token();
                }
            }
            else {
                warn "[!] Invalid refresh_token! Logging out...\n";
                $self->set_refresh_token();
                $self->set_access_token();
            }
        }

        warn '[' . $response->status_line . "] Error occured on URL: $url\n";
    }

    return;
}

=head2 lwp_post($url, [@args])

Post and return the content for $url.

=cut

sub lwp_post {
    my ($self, $url, @args) = @_;

    $self->{lwp} // $self->set_lwp_useragent();

    my $response = $self->{lwp}->post($url, @args);

    if ($response->is_success) {
        return $response->decoded_content;
    }
    else {
        warn '[' . $response->status_line() . "] Error occurred on URL: $url\n";
    }

    return;
}

=head2 lwp_mirror($url, $output_file)

Downloads the $url into $output_file. Returns true on success.

=cut

sub lwp_mirror {
    my ($self, $url, $name) = @_;

    $self->{lwp} // $self->set_lwp_useragent();

    my %lwp_header = $self->_get_lwp_header();

    if (not $self->get_debug) {
        $self->{lwp}->show_progress(1);
    }

    my $response = $self->{lwp}->mirror($url, $name);

    if (not $self->get_debug) {
        $self->{lwp}->show_progress(0);
    }

    if ($response->is_success) {
        return 1;
    }
    else {
        warn '[' . $response->status_line() . "] Error occured on URL: $url\n";
    }

    return;
}

sub _get_thumbnail_from_gdata {
    my ($self, $gdata) = @_;
    return (
            ref($gdata->{'media:group'}) eq 'ARRAY' && exists $gdata->{'media:group'}[0]{'-url'}
            ? $gdata->{'media:group'}[0]{'-url'}
            : ref($gdata->{'media:group'}) eq 'HASH' ? ref($gdata->{'media:group'}{'media:thumbnail'}) eq 'ARRAY'
                  ? $gdata->{'media:group'}{'media:thumbnail'}[0]{'-url'}
                  : $gdata->{'media:group'}{'media:thumbnail'}{'-url'}
              : ref $gdata->{'media:group'} eq 'ARRAY' && ref $gdata->{'media:group'}[0]{'media:thumbnail'} eq 'ARRAY'
            ? $gdata->{'media:group'}[0]{'media:thumbnail'}[0]{'-url'}
            : q{}
           );
}

sub _xml2hash_pp {
    my ($self, $hash, %opts) = @_;

    my @results;
    my $index = 0;
    while (
           defined(
                   my $gdata =
                     exists $hash->{feed}
                   ? $hash->{feed}[0]{entry}[$index++]
                   : $hash->{entry}[$index++]
                  )
      ) {

        push @results, $opts{playlists}

          # Playlists
          ? {
             playlistID => $gdata->{'yt:playlistId'},
             title      => $gdata->{'title'},
             name       => $gdata->{'author'}[0]{'name'},
             author     => $gdata->{'author'}[0]{'yt:userId'},
             count      => $gdata->{'yt:countHint'},
             summary    => $gdata->{'summary'},
             published  => $gdata->{'published'},
             updated    => $gdata->{'updated'},
             thumbnail  => $self->_get_thumbnail_from_gdata($gdata),
            }

          : $opts{shows}

          # Shows
          ? {
             showID  => (split(/:/, $gdata->{'id'}))[-1],
             title   => $gdata->{'title'},
             name    => $gdata->{'author'}[0]{'name'},
             author  => $gdata->{'author'}[0]{'yt:userId'},
             count   => $gdata->{'yt:countHint'},
             summary => $gdata->{'summary'},
             seasons => $gdata->{'gd:feedLink'}[0]{'-countHint'},
            }

          : $opts{shows_content}

          # Seasons of a show
          ? {
             seasonID  => (split(/:/, $gdata->{'id'}))[-1],
             title     => $gdata->{'title'},
             published => $gdata->{'published'},
             updated   => $gdata->{'updated'},
             name      => $gdata->{'author'}[0]{'name'},
             author    => $gdata->{'author'}[0]{'yt:userId'},
             clips     => $gdata->{'gd:feedLink'}[0]{'-countHint'},
             episodes  => $gdata->{'gd:feedLink'}[1]{'-countHint'},
            }

          : $opts{comments}

          # Comments
          ? {
             name      => $gdata->{'author'}[0]{'name'},
             author    => $gdata->{'author'}[0]{'yt:userId'},
             content   => $gdata->{'content'},
             published => $gdata->{'published'},
            }

          : $opts{channels}

          # Channels
          ? {
             title       => $gdata->{'title'},
             name        => $gdata->{'author'}[0]{'name'},
             author      => $gdata->{'author'}[0]{'yt:userId'},
             summary     => $gdata->{'summary'},
             thumbnail   => $gdata->{'media:thumbnail'}[0]{'-url'},
             updated     => $gdata->{'updated'},
             subscribers => $gdata->{'yt:channelStatistics'}[0]{'-subscriberCount'},
             views       => $gdata->{'yt:channelStatistics'}[0]{'-viewCount'},
            }

          : $opts{channel_suggestions}

          # Channel suggestions
          ? {
             title       => $gdata->{'content'}[0]{'entry'}[0]{'title'},
             name        => $gdata->{'content'}[0]{'entry'}[0]{'author'}[0]{'name'},
             author      => $gdata->{'content'}[0]{'entry'}[0]{'author'}[0]{'yt:userId'},
             summary     => $gdata->{'content'}[0]{'entry'}[0]{'summary'},
             thumbnail   => $gdata->{'content'}[0]{'entry'}[0]{'media:thumbnail'}[0]{'-url'},
             updated     => $gdata->{'content'}[0]{'entry'}[0]{'updated'},
             subscribers => $gdata->{'content'}[0]{'entry'}[0]{'yt:channelStatistics'}[0]{'-subscriberCount'},
             videos      => $gdata->{'content'}[0]{'entry'}[0]{'yt:channelStatistics'}[0]{'-videoCount'},
            }

          : $opts{courses}

          # Courses
          ? {
             title     => $gdata->{'title'},
             updated   => $gdata->{'updated'},
             courseID  => $gdata->{'yt:playlistId'},
             summary   => $gdata->{'summary'},
             thumbnail => $self->_get_thumbnail_from_gdata($gdata),
            }

          # Videos
          : {
             videoID     => $gdata->{'media:group'}[0]{'yt:videoid'},
             title       => $gdata->{'media:group'}[0]{'media:title'}[0]{'#text'},
             author      => $gdata->{'media:group'}[0]{'media:credit'}[0]{'#text'},
             rating      => $gdata->{'gd:rating'}[0]{'-average'} || 0,
             likes       => $gdata->{'yt:rating'}[0]{'-numLikes'} || 0,
             dislikes    => $gdata->{'yt:rating'}[0]{'-numDislikes'} || 0,
             favorited   => $gdata->{'yt:statistics'}[0]{'-favoriteCount'},
             duration    => $gdata->{'media:group'}[0]{'yt:duration'}[0]{'-seconds'} || 0,
             views       => $gdata->{'yt:statistics'}[0]{'-viewCount'},
             published   => $gdata->{'media:group'}[0]{'yt:uploaded'},
             description => $gdata->{'media:group'}[0]{'media:description'}[0]{'#text'},
             category    => $gdata->{'media:group'}[0]{'media:category'}[0]{'-label'},
            };
    }

    return \@results;
}

sub _xml2hash {
    my ($self, $hash, %opts) = @_;

    my @results;
    my $index = 0;
    while (
           my $gdata =
             ref $hash->{feed}{entry} eq 'ARRAY' ? $hash->{feed}{entry}[$index++]
           : ref $hash->{feed}{entry} eq 'HASH'  ? $hash->{feed}{entry}
           :                                       $hash->{entry}
      ) {
        $gdata // last;

        push @results, $opts{playlists}

          # Playlists
          ? {
             playlistID => $gdata->{'yt:playlistId'},
             title      => $gdata->{'title'},
             name       => $gdata->{'author'}{'name'},
             author     => $gdata->{'author'}{'yt:userId'},
             count      => $gdata->{'yt:countHint'},
             summary    => $gdata->{'summary'},
             published  => $gdata->{'published'},
             updated    => $gdata->{'updated'},
             thumbnail  => $self->_get_thumbnail_from_gdata($gdata),
            }

          : $opts{shows}

          # Shows
          ? {
             showID  => (split(/:/, $gdata->{'id'}))[-1],
             title   => $gdata->{'title'},
             name    => $gdata->{'author'}{'name'},
             author  => $gdata->{'author'}{'yt:userId'},
             count   => $gdata->{'yt:countHint'},
             summary => $gdata->{'summary'},
             seasons => $gdata->{'gd:feedLink'}{'-countHint'},
            }

          : $opts{shows_content}

          # Seasons of a show
          ? {
             seasonID  => (split(/:/, $gdata->{'id'}))[-1],
             title     => $gdata->{'title'},
             published => $gdata->{'published'},
             updated   => $gdata->{'updated'},
             name      => $gdata->{'author'}{'name'},
             author    => $gdata->{'author'}{'yt:userId'},
             clips     => $gdata->{'gd:feedLink'}[0]{'-countHint'},
             episodes  => $gdata->{'gd:feedLink'}[1]{'-countHint'},
            }

          : $opts{comments}

          # Comments
          ? {
             name      => $gdata->{'author'}{'name'},
             author    => $gdata->{'author'}{'yt:userId'},
             content   => $gdata->{'content'},
             published => $gdata->{'published'},
            }

          : $opts{channels}

          # Channels
          ? {
             title       => $gdata->{'title'},
             name        => $gdata->{'author'}{'name'},
             author      => $gdata->{'author'}{'yt:userId'},
             summary     => $gdata->{'summary'},
             thumbnail   => $gdata->{'media:thumbnail'}{'-url'},
             updated     => $gdata->{'updated'},
             subscribers => $gdata->{'yt:channelStatistics'}{'-subscriberCount'},
             views       => $gdata->{'yt:channelStatistics'}{'-viewCount'},
            }

          : $opts{channel_suggestions}

          # Channel suggestions
          ? {
             title     => $gdata->{'content'}{'entry'}{'title'},
             name      => $gdata->{'content'}{'entry'}{'author'}{'name'},
             author    => $gdata->{'content'}{'entry'}{'author'}{'yt:userId'},
             summary   => $gdata->{'content'}{'entry'}{'summary'},
             thumbnail => (
                           ref $gdata->{'content'}{'entry'}{'media:thumbnail'} eq 'HASH'
                           ? $gdata->{'content'}{'entry'}{'media:thumbnail'}{'-url'}
                           : ref $gdata->{'content'}{'entry'}{'media:thumbnail'} eq 'ARRAY'
                           ? $gdata->{'content'}{'entry'}{'media:thumbnail'}[0]{'-url'}
                           : q{}
                          ),
             updated     => $gdata->{'content'}{'entry'}{'updated'},
             subscribers => $gdata->{'content'}{'entry'}{'yt:channelStatistics'}{'-subscriberCount'},
             videos      => $gdata->{'content'}{'entry'}{'yt:channelStatistics'}{'-videoCount'},
            }

          : $opts{courses}

          # Courses
          ? {
             title     => $gdata->{'title'},
             updated   => $gdata->{'updated'},
             courseID  => $gdata->{'yt:playlistId'},
             summary   => $gdata->{'summary'},
             thumbnail => $self->_get_thumbnail_from_gdata($gdata),
            }

          # Videos
          : {
             videoID => $gdata->{'media:group'}{'yt:videoid'},
             title   => $gdata->{'media:group'}{'media:title'}{'#text'},
             author  => (
                   ref $gdata->{'media:group'}{'media:credit'} eq 'ARRAY' ? $gdata->{'media:group'}{'media:credit'}[0]{'#text'}
                   : $gdata->{'media:group'}{'media:credit'}{'#text'}
             ),
             rating   => $gdata->{'gd:rating'}{'-average'}     || 0,
             likes    => $gdata->{'yt:rating'}{'-numLikes'}    || 0,
             dislikes => $gdata->{'yt:rating'}{'-numDislikes'} || 0,
             favorited   => $gdata->{'yt:statistics'}{'-favoriteCount'},
             duration    => $gdata->{'media:group'}{'yt:duration'}{'-seconds'} || 0,
             views       => $gdata->{'yt:statistics'}{'-viewCount'},
             published   => $gdata->{'media:group'}{'yt:uploaded'},
             description => $gdata->{'media:group'}{'media:description'}{'#text'},
             category    => (
                          ref $gdata->{'media:group'}{'media:category'} eq 'ARRAY'
                          ? $gdata->{'media:group'}{'media:category'}[0]{'-label'}
                          : $gdata->{'media:group'}{'media:category'}{'-label'}
                         ),
            };

        last unless ref $hash->{feed}{entry} eq 'ARRAY';
    }

    return \@results;
}

=head2 get_content($url;%opts)

Returns a hash reference containing the URL and RESULTS:
    {url => '...', results => [...]}

Valid %opts:
    playlists => 1, comments => 1, videos => 1,
    channels  => 1, channel_suggestions => 1,
    courses   => 1,

=cut

sub get_content {
    my ($self, $url, %opts) = @_;

    my $hash;
    my $xml_fast = !($self->get_use_internal_xml_parser);
    my $xml_content = $self->lwp_get($url) // return [];

    if ($xml_fast) {
        eval { require XML::Fast; $hash = XML::Fast::xml2hash($xml_content) // return [] };
        if ($@) {
            if ($@ =~ /^Can't locate (\S+)\.pm\b/) {
                warn "[WARN] XML::Fast is not installed!\n" if $self->get_debug;
                $self->set_use_internal_xml_parser(1);
                $xml_fast = 0;
            }
            else {
                warn $@ if $self->get_debug;
                warn "[XML::Fast] Error occured while parsing the XML content of: $url\n";
                return [];
            }
        }
    }

    if (not $xml_fast) {
        if ($self->get_debug()) {
            print STDERR "** Using WWW::YoutubeViewer::ParseXML to parse the GData XML.\n";
        }

        require WWW::YoutubeViewer::ParseXML;
        eval { $hash = WWW::YoutubeViewer::ParseXML::xml2hash($xml_content) // return [] };
        if ($@) {
            warn $@ if $self->get_debug;
            warn "[WWW::YoutubeViewer::ParseXML] Error occured while parsing the XML content of: $url\n";
            return [];
        }
    }

    if ($self->get_debug() == 2) {
        require Data::Dump;
        Data::Dump::pp($hash);
    }

    return $xml_fast ? $self->_xml2hash($hash, %opts) : $self->_xml2hash_pp($hash, %opts);
}

sub _url_doesnt_contain_arguments {
    my ($self, $url) = @_;
    return 1 if $url =~ m{^https?+://[\w-]++(?>\.[\w-]++)++(?>/[\w-]++)*+/?+$};
    return;
}

=head2 prepare_url($url)

Accepts a URL without arguments, appends the
C<default_arguments()> to it, and returns it.

=cut

sub prepare_url {
    my ($self, $url) = @_;

    # If the URL doesn't contain any arguments, set defaults
    if ($self->_url_doesnt_contain_arguments($url)) {
        $url .= '?' . $self->default_gdata_arguments();
    }
    else {
        warn "Invalid url: $url";
    }

    return $url;
}

sub _make_feed_url_with_args {
    my ($self, $suburl, @args) = @_;

    my $url = $self->prepare_url($self->get_feeds_url() . $suburl);
    return $self->_concat_args($url, @args);
}

=head2 get_videos_from_category($cat_id)

Returns a list of videos from a categoryID.

=cut

sub get_videos_from_category {
    my ($self, $cat_id) = @_;

    # http://gdata.youtube.com/feeds/api/videos?category=Comedy&v=2

    unless ($cat_id ~~ \@categories_IDs) {
        warn "Invalid cat ID: $cat_id";
        return {
                url     => undef,
                results => [],
               };
    }

    my $url = $self->_make_feed_url_with_args('/videos', ('category' => $cat_id));

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

=head2 get_courses_from_category($cat_id)

Get the courses from a specific category ID.
$cat_id can be any valid category ID from the EDU categories.

=cut

sub get_courses_from_category {
    my ($self, $cat_id) = @_;

    # http://gdata.youtube.com/feeds/api/edu/courses?category=CAT_ID

    my $url = $self->_make_feed_url_with_args('/edu/courses', ('category' => $cat_id));

    return {
            url     => $url,
            results => $self->get_content($url, courses => 1),
           };
}

=head2 get_video_lectures_from_course($course_id)

Get the video lectures from a specific course ID.
$course_id can be any valid course ID from the EDU categories.

=cut

sub get_video_lectures_from_course {
    my ($self, $course_id) = @_;

    # http://gdata.youtube.com/feeds/api/edu/lectures?course=COURSE_ID

    my $url = $self->_make_feed_url_with_args('/edu/lectures', ('course' => $course_id));

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

=head2 get_video_lectures_from_category($cat_id)

Get the video lectures from a specific category ID.
$cat_id can be any valid category ID from the EDU categories.

=cut

sub get_video_lectures_from_category {
    my ($self, $cat_id) = @_;

    # http://gdata.youtube.com/feeds/api/edu/lectures?category=CAT_ID

    my $url = $self->_make_feed_url_with_args('/edu/lectures', ('category' => $cat_id));

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

=head2 get_movies($movieID)

Get movie results for C<$movieID>.

=cut

sub get_movies {
    my ($self, $movie_id) = @_;

    unless ($movie_id ~~ \@movie_IDs) {
        warn "Invalid movie ID: $movie_id";
        return;
    }

    # http://gdata.youtube.com/feeds/api/charts/movies/most_popular

    my $url = $self->_make_feed_url_with_args("/charts/movies/$movie_id");

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

=head2 get_video_tops(%opts)

Returns the video tops for a specific feed_id.
Valid %opts:
    (feed_id=>'...',cat_id=>'...',region_id=>'...',time_id=>'...')

=cut

sub get_video_tops {
    my ($self, %opts) = @_;

    my $cat_id    = delete($opts{cat_id})    // $self->get_category();
    my $region_id = delete($opts{region_id}) // $self->get_region();
    my $time_id   = delete($opts{time_id})   // $self->get_time();
    my $feed_id   = delete($opts{feed_id});

    foreach my $key (keys %opts) {
        warn "Invalid hash key: '${key}'";
    }

    # https://gdata.youtube.com/feeds/api/standardfeeds/top_rated?time=today
    # https://gdata.youtube.com/feeds/api/standardfeeds/JP/top_rated_Comedy?v=2

    unless ($feed_id ~~ \@feeds_IDs) {
        warn "Invalid feed ID: $feed_id";
        return;
    }

    if (defined($region_id) and defined($cat_id)) {

        unless (defined($self->{_category_regions})) {
            $self->_populate_category_regions() or do {
                warn "No category has been found!";
                return;
            };
        }

        unless ($region_id ~~ $self->{_category_regions}{$cat_id}) {
            if ($self->get_debug) {
                warn "Invalid region ID: $region_id";
            }
            $region_id = 'US' ~~ $self->{_category_regions}{$cat_id} ? 'US' : undef;
        }
    }
    elsif (defined($region_id)) {
        unless ($region_id ~~ \@region_IDs) {
            warn "Invalid region ID: $region_id";
            undef $region_id;
        }
    }

    my $url =
        $self->get_feeds_url()
      . '/standardfeeds/'
      . (defined($region_id) ? qq{$region_id/} : q{})
      . $feed_id
      . (defined($cat_id) ? qq{_$cat_id} : q{}) . '?'
      . $self->full_gdata_arguments('ignore' => [qw(q time category)]);

    if ($time_id ~~ $valid_options{time}{valid}) {
        $url = $self->_concat_args($url, ('time' => $time_id));
    }
    elsif (defined($time_id) and $time_id ne q{}) {
        warn "Invalid time ID: $time_id";
    }

    if ($cat_id ~~ \@categories_IDs) {
        $url = $self->_concat_args($url, ('category' => $cat_id));
    }
    elsif (defined($cat_id) and $cat_id ne q{}) {
        warn "Invalid category ID: $cat_id";
    }

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

sub _populate_category_regions {
    my ($self) = @_;
    my $categories = $self->get_categories;

    @categories_IDs = ();
    foreach my $cat (@{$categories}) {
        $self->{_category_regions}{$cat->{term}} = $cat->{regions};
        push @categories_IDs, $cat->{term};
    }

    return scalar(@categories_IDs);
}

sub _concat_args {
    my ($self, $url, @args) = @_;

    return $url if scalar(@args) == 0;
    my $args = $self->list_to_gdata_arguments(@args);

    if (not defined($args) or $args eq q{}) {
        return $url;
    }

    $url =~ s/[&?]+$//;
    $url .= ($url =~ /&/ ? '&' : '?') . $args;
    return $url;
}

sub _get_categories {
    my ($self, $url) = @_;

    $url = $self->_concat_args($url, 'hl' => $self->get_categories_language(), 'v' => $self->get_v());

    require File::Spec;
    my ($file) = $url =~ m{/(\w+\.cat)\b};
    my $cat_file = File::Spec->catfile($self->get_config_dir(), $file);

    if (not -f $cat_file) {
        $self->lwp_mirror($url, $cat_file) or return;
    }

    require WWW::YoutubeViewer::ParseXML;
    my $hash = WWW::YoutubeViewer::ParseXML::xml2hash(
        do {
            open my $fh, '<:encoding(UTF-8)', $cat_file
              or do { warn "Can't open file '$cat_file' for reading: $!"; return };
            local $/;
            <$fh>;
          }
    );

    my @categories;
    foreach my $cat (@{$hash->{'app:categories'}[0]{'atom:category'}}) {
        next if exists $cat->{'yt:deprecated'};
        push @categories,
          scalar {
                  label   => $cat->{'-label'},
                  term    => $cat->{'-term'},
                  regions => (
                              exists($cat->{'yt:browsable'})
                                && ref $cat->{'yt:browsable'} eq 'ARRAY' && exists($cat->{'yt:browsable'}[0]{'-regions'})
                              ? [split(q{ }, $cat->{'yt:browsable'}[0]{'-regions'})]
                              : []
                             ),
                 };
    }

    return \@categories;
}

=head2 get_categories()

Returns the YouTube categories.

=cut

sub get_categories {
    my ($self) = @_;
    return $self->_get_categories($self->get_categories_url());
}

=head2 get_educategories()

Returns the EDU YouTube categories.

=cut

sub get_educategories {
    my ($self) = @_;
    return $self->_get_categories($self->get_educategories_url());
}

sub _get_pairs_from_info_data {
    my ($self, $content, $videoID) = @_;

    my @array;
    my $i = 0;

    require URI::Escape;
    foreach my $block (split(/,/, $content)) {
        foreach my $pair (split(/&/, $block)) {
            $pair =~ s{^url_encoded_fmt_stream_map=(?=\w+=)}{}im;
            my ($key, $value) = split(/=/, $pair);
            $key // next;
            $array[$i]->{$key} = URI::Escape::uri_unescape($value);
        }
        ++$i;
    }

    foreach my $hash_ref (@array) {
        if (exists $hash_ref->{url}) {

            # Add signature
            if (exists $hash_ref->{sig}) {
                $hash_ref->{url} .= "&signature=$hash_ref->{sig}";
            }
            elsif (exists $hash_ref->{s}) {    # has an encrypted signature :(
                if (system('youtube-dl', '--version') == 0) {    # check if youtube-dl is installed

                    # Unfortunately, this streaming URL doesn't work with 'mplayer', but it works with 'mpv' and 'vlc'
                    chomp(my $url = `youtube-dl --get-url "http://www.youtube.com/watch?v=$videoID"`);
                    foreach my $item (@array) {
                        if (exists $item->{url}) {
                            $item->{url} = $url;
                        }
                    }
                    last;
                }
            }

            # Add proxy (if defined http_proxy)
            if (defined(my $proxy_url = $self->get_http_proxy)) {
                $proxy_url =~ s{^http://}{http_proxy://};
                $hash_ref->{url} = $proxy_url . $hash_ref->{url};
            }

        }
    }

    return @array;
}

=head2 get_streaming_urls($videoID)

Returns a list of streaming URLs for a videoID.
({itag=>...}, {itag=>...}, {has_cc=>...})

=cut

sub get_streaming_urls {
    my ($self, $videoID) = @_;

    my $url = ($self->get_video_info_url() . sprintf($self->get_video_info_args(), $videoID));

    require URI::Escape;
    my $content = URI::Escape::uri_unescape($self->lwp_get($url) // return);
    my @info = $self->_get_pairs_from_info_data($content, $videoID);

    if ($self->get_debug == 2) {
        require Data::Dump;
        Data::Dump::pp(\@info);
    }

    if (exists $info[0]->{status} and $info[0]->{status} eq q{fail}) {
        warn "\n[!] Error occurred on getting info for video ID: $videoID\n";
        my $reason = $info[0]->{reason};
        $reason =~ tr/+/ /s;
        warn "[*] Reason: $reason\n";
        return;
    }
    return grep { (exists $_->{itag} and exists $_->{url} and exists $_->{type}) or exists $_->{has_cc} } @info;
}

=head2 get_channel_suggestions()

Returns a list of channel suggestions for the current logged user.

=cut

sub get_channel_suggestions {
    my ($self) = @_;

    if (not defined $self->get_access_token) {
        warn "\n[!] The method 'get_channel_suggestions' requires authentication!\n";
        return;
    }

    my $url = $self->_make_feed_url_with_args('/users/default/suggestion', (type => 'channel', inline => 'true'));

    return {
            url     => $url,
            results => $self->get_content($url, channel_suggestions => 1),
           };
}

=head2 search(@keywords)

Search and return the video results.

=cut

sub search {
    my ($self, @keywords) = @_;

    my $keywords = $self->escape_string("@keywords");
    my $url = $self->get_feeds_url() . '/videos?' . $self->full_gdata_arguments('keywords' => $keywords);

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

=head2 search_channels(@keywords)

Search and return the channel results.

=cut

sub search_channels {
    my ($self, @keywords) = @_;

    # https://gdata.youtube.com/feeds/api/channels?q=soccer&v=2

    my $keywords = $self->escape_string("@keywords");
    my $url = $self->_make_feed_url_with_args('/channels', ('q' => $keywords));

    return {
            url     => $url,
            results => $self->get_content($url, channels => 1),
           };
}

=head2 search_for_playlists(@keywords)

Search and return the playlist results.

=cut

sub search_for_playlists {
    my ($self, @keywords) = @_;

    my $keywords = $self->escape_string("@keywords");

    my $url = $self->_make_feed_url_with_args('/playlists/snippets', ('q' => $keywords));

    return {
            url     => $url,
            results => $self->get_content($url, playlists => 1),
           };
}

=head2 full_gdata_arguments(;%opts)

Returns a string with all the GData arguments.

Optional, you can specify in C<$opts{ignore}>
an ARRAY_REF with the keys that should be ignored.

=cut

sub full_gdata_arguments {
    my ($self, %opts) = @_;

    my %hash = (
                'q' => $opts{keywords} // q{},
                'max-results' => $self->get_results,
                'category'    => $self->get_category,
                'time'        => $self->get_time,
                'orderby'     => $self->get_orderby,
                'start-index' => $self->get_start_index,
                'safeSearch'  => $self->get_safe_search,
                'hd'          => $self->get_hd,
                'caption'     => $self->get_caption,
                'duration'    => $self->get_duration,
                'author'      => $self->get_author,
                'v'           => $self->get_v,
               );

    if (ref $opts{ignore} eq 'ARRAY') {
        delete @hash{@{$opts{ignore}}};
    }

    return $self->list_to_gdata_arguments(%hash);
}

=head2 send_rating_to_video($videoID, $rating)

Send rating to a video. $rating can be either 'like' or 'dislike'.

=cut

sub send_rating_to_video {
    my ($self, $code, $rating) = @_;
    my $uri = $self->get_feeds_url() . "/videos/$code/ratings";

    return $self->_save('POST', $uri, <<"XML_HEADER");
<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
       xmlns:yt="http://gdata.youtube.com/schemas/2007">
<yt:rating value="$rating"/>
</entry>
XML_HEADER
}

=head2 send_comment_to_video($videoID, $comment)

Send comment to a video. Returns true on success.

=cut

sub send_comment_to_video {
    my ($self, $code, $comment) = @_;

    my $uri = $self->get_feeds_url() . "/videos/$code/comments";

    return $self->_save('POST', $uri, <<"XML_HEADER");
<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
    xmlns:yt="http://gdata.youtube.com/schemas/2007">
  <content>$comment</content>
</entry>
XML_HEADER
}

=head2 subscribe_channel($username)

Subscribe to a user's channel.

=cut

sub subscribe_channel {
    my ($self, $user) = @_;
    my $uri = $self->get_feeds_url() . '/users/default/subscriptions';

    return $self->_save('POST', $uri, <<"XML_HEADER");
<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
  xmlns:yt="http://gdata.youtube.com/schemas/2007">
    <category scheme="http://gdata.youtube.com/schemas/2007/subscriptiontypes.cat"
      term="channel"/>
    <yt:username>$user</yt:username>
</entry>
XML_HEADER
}

=head2 favorite_video($videoID)

Favorite a video. Returns true on success.

=cut

sub favorite_video {
    my ($self, $code) = @_;
    my $uri = $self->get_feeds_url() . '/users/default/favorites';

    return $self->_save('POST', $uri, <<"XML_HEADER");
<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom">
  <id>$code</id>
</entry>
XML_HEADER
}

sub _request {
    my ($self, $req) = @_;

    $self->{lwp} // $self->set_lwp_useragent();

    my $res = $self->{lwp}->request($req);

    if ($res->is_success) {
        return $res->content();
    }
    else {
        warn 'Request error: ' . $res->status_line();
    }

    return;
}

sub _prepare_request {
    my ($self, $req, $length) = @_;

    $req->header('GData-Version' => $self->get_v);
    $req->header('Content-Length' => $length) if ($length);

    if (defined $self->get_access_token) {
        $req->header('Authorization' => $self->prepare_access_token);
    }
    if (defined $self->get_key) {
        $req->header('X-GData-Key' => $self->prepare_key);
    }

    return 1;
}

sub _save {
    my ($self, $method, $uri, $content) = @_;

    require HTTP::Request;
    my $req = HTTP::Request->new($method => $uri);
    $req->content_type('application/atom+xml; charset=UTF-8');
    $self->_prepare_request($req, length($content));
    $req->content($content);

    return $self->_request($req);
}

=head2 like_video($videoID)

Like a video. Returns true on success.

=cut

sub like_video {
    my ($self, $code) = @_;
    return $self->send_rating_to_video($code, 'like');
}

=head2 dislike_video($videoID)

Dislike a video. Returns true on success.

=cut

sub dislike_video {
    my ($self, $code) = @_;
    return $self->send_rating_to_video($code, 'dislike');
}

=head2 get_video_comments($videoID)

Returns a list of comments for a videoID.

=cut

sub get_video_comments {
    my ($self, $code) = @_;

    my $url =
      $self->_concat_args(
                          $self->get_feeds_url() . "/videos/$code/comments",
                          (
                           'max-results' => $self->get_results,
                           'v'           => $self->get_v,
                           'start-index' => 1,
                          )
                         );
    return {
            url     => $url,
            results => $self->get_content($url, comments => 1),
           };
}

sub _next_or_back {
    my ($self, $next, $url) = @_;
    $url =~ s{[&?]start-index=\K(\d++)\b}{
        $next
            ? $1 + $self->get_results()
            : $1 - $self->get_results();
    }e;
    return $url;
}

=head2 get_disco_videos(\@keywords)

Search for a disco playlist and return its videos, if any. Undef otherwise.

=cut

sub get_disco_videos {
    my ($self, $keywords) = @_;

    @{$keywords} || return;

    my $url  = 'http://www.youtube.com/disco?action_search=1&query=';
    my $json = $self->lwp_get($url . $self->escape_string("@{$keywords}"));

    if ($json =~ /list=(?<playlist_id>[\w\-]+)/) {
        my $hash_ref = $self->get_videos_from_playlist($+{playlist_id});
        $hash_ref->{playlistID} = $+{playlist_id};
        return $hash_ref;
    }

    return;
}

=head2 get_video_info($videoID)

Returns informations for a videoID.

=cut

sub get_video_info {
    my ($self, $id) = @_;

    my $url = $self->_concat_args($self->get_feeds_url() . "/videos/$id", v => $self->get_v);

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

# SOUBROUTINE FACTORY
{
    no strict 'refs';

    # Create some simple subroutines
    foreach my $method (
                        ['related_videos', '/videos/%s/related', {}],
                        ['playlists_from_username',        '/users/%s/playlists',  {playlists     => 1}],
                        ['shows_from_username',            '/users/%s/shows',      {shows         => 1}],
                        ['shows_content_from_id',          '/shows/%s/content',    {shows_content => 1}],
                        ['clips_from_season_id',           '/seasons/%s/clips',    {}],
                        ['episodes_from_season_id',        '/seasons/%s/episodes', {}],
                        ['videos_from_username',           '/users/%s/uploads',    {}],
                        ['favorited_videos_from_username', '/users/%s/favorites',  {}],
                        ['videos_from_playlist',           '/playlists/%s',        {}],
      ) {

        *{__PACKAGE__ . '::get_' . $method->[0]} = sub {
            my ($self, $id) = @_;
            my $url = $self->prepare_url($self->get_feeds_url() . sprintf($method->[1], $id));
            return {
                    url     => $url,
                    results => $self->get_content($url, %{$method->[2]}),
                   };
        };
    }

    # Create {next,previous}_page subroutines
    foreach my $pair (['next_page' => 1], ['previous_page' => 0]) {

        *{__PACKAGE__ . '::' . $pair->[0]} = sub {
            my ($self, $url, %opts) = @_;

            $url = $self->_next_or_back($pair->[1], $url);
            return {
                    url     => $url,
                    results => $self->get_content($url, %opts),
                   };
        };

    }

    # Create subroutines that require authentication
    foreach my $method (@feed_methods) {

        *{__PACKAGE__ . '::get_' . $method} = sub {

            my ($self, $user) = @_;
            $user ||= 'default';

            if (not defined $self->get_access_token) {
                if ($user ne 'default' and $method ~~ [qw(newsubscriptionvideos favorites)]) {
                    ## ok
                }
                else {
                    warn "\n[!] The method 'get_$method' requires authentication!\n";
                    return;
                }
            }

            my $url = $self->prepare_url($self->get_feeds_url() . "/users/$user/$method");
            return {
                    url     => $url,
                    results => $self->get_content($url),
                   };
        };
    }
}

=head2 next_page($url;%opts)

Returns the next page of results.
%opts are the same as for I<get_content()>.

=head2 previous_page($url;%opts)

Returns the previous page of results.
%opts are the same as for I<get_content()>.

=head2 get_related_videos($videoID)

Returns the related videos for a videoID.

=head2 get_favorites(;$user)

Returns the latest favorited videos for the current logged user.

=head2 get_recommendations()

Returns a list of videos, recommended for you by Youtube.

=head2 get_watch_history(;$user)

Returns the latest videos watched on Youtube.

=head2 get_watch_later(;$user)

Returns the saved videos to watch a later time.

=head2 get_newsubscriptionvideos(;$user)

Returns the videos from the subscriptions for the current logged user.

=head2 get_favorited_videos_from_username($username)

Returns the latest favorited videos for a given username.

=head2 get_playlists_from_username($username)

Returns a list of playlists created by $username.

=head2 get_shows_from_username($username)

Returns a list of shows belonging to a user.

=head2 get_shows_content_from_id($showID)

Returns a list of seasons for a given show ID.

=head2 get_clips_from_season_id($seasonID)

Retruns a list of videos (clips) from a season ID.

=head2 get_episodes_from_season_id($seasonID)

Returns a list of videos (episodes) from a season ID.

=head2 get_videos_from_playlist($playlistID)

Returns a list of videos from playlistID.

=head2 get_videos_from_username($username)

Returns the latest videos uploaded by a username.

=head2 get_v()

Returns the current version of GData implementation.

=head2 set_key($dev_key)

Set the developer key.

=head2 get_key()

Returns the developer key.

=head2 set_client_id($client_id)

Set the OAuth 2.0 client ID for your application.

=head2 get_client_id()

Returns the I<client_id>.

=head2 set_client_secret($client_secret)

Set the client secret associated with your I<client_id>.

=head2 get_client_secret()

Returns the I<client_secret>.

=head2 set_redirect_uri($redirect_uri)

A registered I<redirect_uri> for your client ID.

=head2 get_redirect_uri()

Returns the I<redirect_uri>.

=head2 set_access_token($token)

Set the 'Bearer' token type key.

=head2 get_access_token()

Get the 'Bearer' access token.

=head2 set_refresh_token($refresh_token)

Set the I<refresh_token>. This value is used to
refresh the I<access_token> after it expires.

=head2 get_refresh_token()

Returns the I<refresh_token>

=head2 get_www_content_type()

Returns the B<Content-Type> header value used for GData.

=head2 set_author($username)

Set the author value.

=head2 get_author()

Returns the author value.

=head2 set_duration($duration_id)

Set duration value. (ex: long)

=head2 get_duration()

Returns the duration value.

=head2 set_orderby()

Set the order-by value. (ex: published)

=head2 get_orderby()

Returns the orderby value.

=head2 set_hd($value)

Set hd value. $value can be either 'true' or undef.

=head2 get_hd()

Returns the hd value.

=head2 set_caption($value)

Set the caption value. ('true', 'false' or undef)

=head2 get_caption()

Returns caption value.

=head2 set_category($cat_id)

Set a category value. (ex: 'Music')

=head2 get_category()

Returns the category value.

=head2 set_safe_search($value)

Set the safe search sensitivity. (ex: strict)

=head2 get_safe_search()

Returns the safe_search value.

=head2 set_region($region_ID)

Set the regionID value for video tops. (ex: JP)

=head2 get_region()

Returns the region value.

=head2 set_time($time_id)

Set the time value. (ex: this_week)

=head2 get_time()

Returns the time value.

=head2 set_results([1-50])

Set the number of results per page. (max 50)

=head2 get_results()

Returns the results value.

=head2 set_page($i)

Set the page number value.

=head2 get_page()

Returns the page value.

=head2 set_categories_language($cat_lang)

Set the categories language. (ex: en-US)

=head2 get_categories_language()

Returns the categories language value.

=head2 get_categories_url()

Returns the YouTube categories URL.

=head2 get_educategories_url()

Returns the EDU YouTube categories URL.

=head2 set_debug($level_num)

Set the debug level. (valid: 0, 1, 2)

=head2 get_debug()

Returns the debug value.

=head2 set_config_dir($dir)

Set a configuration directory.

=head2 get_config_dir()

Get the configuration directory.

=head2 set_use_internal_xml_parser($bool)

By default, WWW::YoutubeViewer will try to use the XML::Fast module first.
A true value will make WWW::YoutubeViewer to always use the internal XML parser.

=head2 get_use_internal_xml_parser()

Returns true if the internal XML parser is in use.

=head2 set_authentication_file($filename)

File from where to get and save the encoded authentication token everytime when is needed.

=cut

=head2 get_authentication_file()

Returns the authentication file's name.

=cut

=head2 set_escape_utf8($bool)

If true, it escapes the keywords using uri_escape_utf8.

=head2 get_escape_utf8()

Returns true if escape_utf8 is used.

=head2 get_feeds_url()

Returns the GData feeds URL.

=head2 set_http_proxy($value)

Set http_proxy value. $value must be a valid URL or undef.

=head2 get_http_proxy()

Returns the http_proxy value.

=head2 set_lwp_agent($agent)

Set a user agent for the LWP module.

=head2 get_lwp_agent()

Returns the user agent value.

=head2 set_lwp_env_proxy($bool)

Set the env_proxy value for LWP.

=head2 get_lwp_env_proxy()

Returns the env_proxy value.

=head2 set_lwp_timeout($sec).

Set the timeout value for LWP, in seconds. Default: 60

=head2 get_lwp_timeout()

Returns the timeout value.

=head2 get_oauth_url()

Returns the OAuth URL.

=head2 get_video_info_url()

Returns the video_info URL.

=head2 get_video_info_args()

Returns the video_info arguments.

=head1 AUTHOR

Daniel "Trizen" Șuteu, C<< <trizenx at gmail.com> >>

=head1 SEE ALSO

https://developers.google.com/youtube/2.0/developers_guide_protocol_api_query_parameters

=head1 LICENSE AND COPYRIGHT

Copyright 2012-2014 Daniel "Trizen" Șuteu.

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

1;    # End of WWW::YoutubeViewer

__END__
