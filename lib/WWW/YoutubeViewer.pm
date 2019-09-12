package WWW::YoutubeViewer;

use utf8;
use 5.016;
use warnings;

use parent qw(
  WWW::YoutubeViewer::Search
  WWW::YoutubeViewer::Videos
  WWW::YoutubeViewer::Channels
  WWW::YoutubeViewer::Playlists
  WWW::YoutubeViewer::ParseJSON
  WWW::YoutubeViewer::Subscriptions
  WWW::YoutubeViewer::PlaylistItems
  WWW::YoutubeViewer::CommentThreads
  WWW::YoutubeViewer::Authentication
  WWW::YoutubeViewer::VideoCategories
  );

=head1 NAME

WWW::YoutubeViewer - A very easy interface to YouTube.

=cut

our $VERSION = '3.5.8';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;

    my $yv_obj = WWW::YoutubeViewer->new();
    ...

=head1 SUBROUTINES/METHODS

=cut

my %valid_options = (

    # Main options
    v               => {valid => q[],                                                    default => 3},
    page            => {valid => [qr/^(?!0+\z)\d+\z/],                                   default => 1},
    http_proxy      => {valid => [qr{.}],                                                default => undef},
    hl              => {valid => [qr/^\w+(?:[\-_]\w+)?\z/],                              default => undef},
    maxResults      => {valid => [1 .. 50],                                              default => 10},
    topicId         => {valid => [qr/^./],                                               default => undef},
    order           => {valid => [qw(relevance date rating viewCount title videoCount)], default => undef},
    publishedAfter  => {valid => [qr/^\d+/],                                             default => undef},
    publishedBefore => {valid => [qr/^\d+/],                                             default => undef},
    channelId       => {valid => [qr/^[-\w]{2,}\z/],                                     default => undef},
    channelType     => {valid => [qw(any show)],                                         default => undef},

    # Video only options
    videoCaption    => {valid => [qw(any closedCaption none)],     default => undef},
    videoDefinition => {valid => [qw(any high standard)],          default => undef},
    videoCategoryId => {valid => [qr/^\d+\z/],                     default => undef},
    videoDimension  => {valid => [qw(any 2d 3d)],                  default => undef},
    videoDuration   => {valid => [qw(any short medium long)],      default => undef},
    videoEmbeddable => {valid => [qw(any true)],                   default => undef},
    videoLicense    => {valid => [qw(any creativeCommon youtube)], default => undef},
    videoSyndicated => {valid => [qw(any true)],                   default => undef},
    eventType       => {valid => [qw(completed live upcoming)],    default => undef},
    chart           => {valid => [qw(mostPopular)],                default => 'mostPopular'},

    regionCode        => {valid => [qr/^[A-Z]{2}\z/i],         default => undef},
    relevanceLanguage => {valid => [qr/^[a-z](?:\-\w+)?\z/i],  default => undef},
    safeSearch        => {valid => [qw(none moderate strict)], default => undef},
    videoType         => {valid => [qw(any episode movie)],    default => undef},

    comments_order      => {valid => [qw(time relevance)],                default => 'time'},
    subscriptions_order => {valid => [qw(alphabetical relevance unread)], default => undef},

    # Others
    debug       => {valid => [0 .. 3],     default => 0},
    lwp_timeout => {valid => [qr/^\d+\z/], default => 1},
    key         => {valid => [qr/^.{5}/],  default => undef},
    config_dir  => {valid => [qr/^./],     default => q{.}},
    cache_dir   => {valid => [qr/^./],     default => q{.}},

    # Booleans
    lwp_env_proxy => {valid => [1, 0], default => 1},
    escape_utf8   => {valid => [1, 0], default => 0},
    prefer_mp4    => {valid => [1, 0], default => 0},

    use_invidious_api => {valid => [1, 0], default => 0},

    # OAuth stuff
    client_id     => {valid => [qr/^.{5}/], default => undef},
    client_secret => {valid => [qr/^.{5}/], default => undef},
    redirect_uri  => {valid => [qr/^.{5}/], default => undef},
    access_token  => {valid => [qr/^.{5}/], default => undef},
    refresh_token => {valid => [qr/^.{5}/], default => undef},

    authentication_file => {valid => [qr/^./], default => undef},

    # No input value allowed
    feeds_url        => {valid => q[], default => 'https://www.googleapis.com/youtube/v3/'},
    video_info_url   => {valid => q[], default => 'https://www.youtube.com/get_video_info'},
    oauth_url        => {valid => q[], default => 'https://accounts.google.com/o/oauth2/'},
    video_info_args  => {valid => q[], default => '?video_id=%s&el=detailpage&ps=default&eurl=&gl=US&hl=en'},
    www_content_type => {valid => q[], default => 'application/x-www-form-urlencoded'},

    # LWP user agent
    lwp_agent => {valid => [qr/^.{5}/], default => 'Mozilla/5.0 (X11; U; Linux i686; gzip; en-US) Chrome/10.0.648.45'},
);

sub _our_smartmatch {
    my ($value, $arg) = @_;

    $value // return 0;

    if (ref($arg) eq '') {
        return ($value eq $arg);
    }

    if (ref($arg) eq ref(qr//)) {
        return scalar($value =~ $arg);
    }

    if (ref($arg) eq 'ARRAY') {
        foreach my $item (@$arg) {
            return 1 if __SUB__->($value, $item);
        }
    }

    return 0;
}

{
    no strict 'refs';

    foreach my $key (keys %valid_options) {

        if (ref $valid_options{$key}{valid} eq 'ARRAY') {

            # Create the 'set_*' subroutines
            *{__PACKAGE__ . '::set_' . $key} = sub {
                my ($self, $value) = @_;
                $self->{$key} =
                  _our_smartmatch($value, $valid_options{$key}{valid})
                  ? $value
                  : $valid_options{$key}{default};
            };
        }

        # Create the 'get_*' subroutines
        *{__PACKAGE__ . '::get_' . $key} = sub {
            my ($self) = @_;

            if (not exists $self->{$key}) {
                return ($self->{$key} = $valid_options{$key}{default});
            }

            $self->{$key};
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
        if (exists $opts{$key}) {
            my $method = "set_$key";
            $self->$method(delete $opts{$key});
        }
    }

    $self->load_authentication_tokens();

    foreach my $invalid_key (keys %opts) {
        warn "Invalid key: '${invalid_key}'";
    }

    return $self;
}

sub page_token {
    my ($self) = @_;

    my $page = $self->get_page;

    # Don't generate the token for the first page
    return undef if $page == 1;

    my $index = $page * $self->get_maxResults() - $self->get_maxResults();
    my $k     = int($index / 128) - 1;
    $index -= 128 * $k;

    my @f = (8, $index);
    if ($k > 0 or $index > 127) {
        push @f, $k + 1;
    }

    require MIME::Base64;
    MIME::Base64::encode_base64(pack('C*', @f, 16, 0)) =~ tr/=\n//dr;
}

=head2 escape_string($string)

Escapes a string with URI::Escape and returns it.

=cut

sub escape_string {
    my ($self, $string) = @_;

    require URI::Escape;

    $self->get_escape_utf8
      ? URI::Escape::uri_escape_utf8($string)
      : URI::Escape::uri_escape($string);
}

=head2 set_lwp_useragent()

Initializes the LWP::UserAgent module and returns it.

=cut

sub set_lwp_useragent {
    my ($self) = @_;

    my $lwp = (
        eval { require LWP::UserAgent::Cached; 'LWP::UserAgent::Cached' }
          // do { require LWP::UserAgent; 'LWP::UserAgent' }
    );

    $self->{lwp} = $lwp->new(

        timeout       => $self->get_lwp_timeout,
        show_progress => $self->get_debug,
        agent         => $self->get_lwp_agent,

        $lwp eq 'LWP::UserAgent::Cached'
        ? (
           cache_dir  => $self->get_cache_dir,
           nocache_if => sub {
               my ($response) = @_;
               my $code = $response->code;

               $code >= 500                                # do not cache any bad response
                 or $code == 401                           # don't cache an unauthorized response
                 or $response->request->method ne 'GET'    # cache only GET requests

                 # don't cache if "cache-control" specifies "max-age=0" or "no-store"
                 or (($response->header('cache-control') // '') =~ /\b(?:max-age=0|no-store)\b/)

                 # don't cache video or audio files
                 or (($response->header('content-type') // '') =~ /\b(?:video|audio)\b/);
           },

           recache_if => sub {
               my ($response, $path) = @_;
               not($response->is_fresh)                          # recache if the response expired
                 or ($response->code == 404 && -M $path > 1);    # recache any 404 response older than 1 day
           }
          )
        : (),

        env_proxy => (defined($self->get_http_proxy) ? 0 : $self->get_lwp_env_proxy),
    );

    require LWP::ConnCache;
    state $cache = LWP::ConnCache->new;
    $cache->total_capacity(undef);                               # no limit

    state $accepted_encodings = do {
        require HTTP::Message;
        HTTP::Message::decodable();
    };

    my $agent = $self->{lwp};
    $agent->ssl_opts(Timeout => 30);
    $agent->default_header('Accept-Encoding' => $accepted_encodings);
    $agent->conn_cache($cache);
    $agent->proxy(['http', 'https'], $self->get_http_proxy) if defined($self->get_http_proxy);

    #my $http_proxy = $agent->proxy('http');
    #if (defined($http_proxy)) {
    #    $agent->proxy('https', $http_proxy) if (!defined($agent->proxy('https')));
    #    $agent->timeout(30);
    #}

    push @{$self->{lwp}->requests_redirectable}, 'POST';
    return $self->{lwp};
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

sub _auth_lwp_header {
    my ($self) = @_;

    my %lwp_header;
    if (defined $self->get_access_token) {
        $lwp_header{'Authorization'} = $self->prepare_access_token;
    }

    return %lwp_header;
}

sub _warn_reponse_error {
    my ($resp, $url) = @_;
    warn sprintf("[%s] Error occurred on URL: %s\n", $resp->status_line, $url =~ s/([&?])key=(.*?)&/${1}key=[...]&/r);
}

=head2 lwp_get($url, %opt)

Get and return the content for $url.

Where %opt can be:

    simple => [bool]

When the value of B<simple> is set to a true value, the
authentication header will not be set in the HTTP request.

=cut

sub lwp_get {
    my ($self, $url, %opt) = @_;

    $url // return;
    $self->{lwp} // $self->set_lwp_useragent();

    my %lwp_header = ($opt{simple} ? () : $self->_auth_lwp_header);
    my $response   = $self->{lwp}->get($url, %lwp_header);

    if ($response->is_success) {
        return $response->decoded_content;
    }

    if ($response->status_line() =~ /^401 / and defined($self->get_refresh_token)) {
        if (defined(my $refresh_token = $self->oauth_refresh_token())) {
            if (defined $refresh_token->{access_token}) {

                $self->set_access_token($refresh_token->{access_token});

                # Don't be tempted to use recursion here, because bad things will happen!
                $response = $self->{lwp}->get($url, $self->_auth_lwp_header);

                if ($response->is_success) {
                    $self->save_authentication_tokens();
                    return $response->decoded_content;
                }
                elsif ($response->status_line() =~ /^401 /) {
                    $self->set_refresh_token();    # refresh token was invalid
                    $self->set_access_token();     # access token is also broken
                    warn "[!] Can't refresh the access token! Logging out...\n";
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

    $opt{depth} ||= 0;

    # Try again on 500+ HTTP errors
    if (    $opt{depth} <= 3
        and $response->code() >= 500
        and $response->status_line() =~ /(?:Temporary|Server) Error|Timeout|Service Unavailable/i) {
        return $self->lwp_get($url, %opt, depth => $opt{depth} + 1);
    }

    _warn_reponse_error($response, $url);
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
        _warn_reponse_error($response, $url);
    }

    return;
}

=head2 lwp_mirror($url, $output_file)

Downloads the $url into $output_file. Returns true on success.

=cut

sub lwp_mirror {
    my ($self, $url, $output_file) = @_;
    $self->{lwp} // $self->set_lwp_useragent();
    $self->{lwp}->mirror($url, $output_file);
}

sub _get_results {
    my ($self, $url, %opt) = @_;

    return
      scalar {
              url     => $url,
              results => $self->parse_json_string($self->lwp_get($url, %opt)),
             };
}

=head2 list_to_url_arguments(\%options)

Returns a valid string of arguments, with defined values.

=cut

sub list_to_url_arguments {
    my ($self, %args) = @_;
    join(q{&}, map { "$_=$args{$_}" } grep { defined $args{$_} } sort keys %args);
}

sub _append_url_args {
    my ($self, $url, %args) = @_;
    %args
      ? ($url . ($url =~ /\?/ ? '&' : '?') . $self->list_to_url_arguments(%args))
      : $url;
}

sub _simple_feeds_url {
    my ($self, $suburl, %args) = @_;
    $self->get_feeds_url() . $suburl . '?' . $self->list_to_url_arguments(key => $self->get_key, %args);
}

=head2 default_arguments(%args)

Merge the default arguments with %args and concatenate them together.

=cut

sub default_arguments {
    my ($self, %args) = @_;

    my %defaults = (
                    key         => $self->get_key,
                    part        => 'snippet',
                    prettyPrint => 'false',
                    maxResults  => $self->get_maxResults,
                    regionCode  => $self->get_regionCode,
                    %args,
                   );

    $self->list_to_url_arguments(%defaults);
}

sub _make_feed_url {
    my ($self, $path, %args) = @_;
    $self->get_feeds_url() . $path . '?' . $self->default_arguments(%args);
}

sub _extract_from_invidious {
    my ($self, $videoID) = @_;

    my $url = sprintf("https://invidio.us/api/v1/videos/%s?fields=formatStreams,adaptiveFormats", $videoID);

    my $tries = 3;
    my $resp  = $self->{lwp}->get($url);

    while (not $resp->is_success() and $resp->status_line() =~ /read timeout/i and --$tries >= 0) {
        $resp = $self->{lwp}->get($url);
    }

    $resp->is_success() || return;

    my $json = $resp->decoded_content()        // return;
    my $ref  = $self->parse_json_string($json) // return;

    my @formats;

    # The entries are already in the format that we want.
    if (exists($ref->{adaptiveFormats}) and ref($ref->{adaptiveFormats}) eq 'ARRAY') {
        push @formats, @{$ref->{adaptiveFormats}};
    }

    if (exists($ref->{formatStreams}) and ref($ref->{formatStreams}) eq 'ARRAY') {
        push @formats, @{$ref->{formatStreams}};
    }

    return @formats;
}

sub _fallback_extract_urls {
    my ($self, $videoID) = @_;

    my @formats;

    if ($self->get_use_invidious_api) {    # use the API of invidio.us

        if ($self->get_debug) {
            say STDERR ":: Using invidio.us to extract the streaming URLs...";
        }

        push @formats, $self->_extract_from_invidious($videoID);

        if ($self->get_debug) {
            say STDERR ":: Found ", scalar(@formats), " streaming URLs.";
        }

        @formats && return @formats;
    }

    ((state $x = system('youtube-dl', '--version')) == 0) || return;

    if ($self->get_debug) {
        say STDERR ":: Using youtube-dl to extract the streaming URLs...";
    }

    my $json = $self->proxy_stdout('youtube-dl', '--all-formats', '--dump-single-json',
                                   quotemeta("https://www.youtube.com/watch?v=" . $videoID));

    my $ref = $self->parse_json_string($json) // return;

    if (ref($ref) eq 'HASH' and exists($ref->{formats}) and ref($ref->{formats}) eq 'ARRAY') {
        foreach my $format (@{$ref->{formats}}) {
            if (exists($format->{format_id}) and exists($format->{url})) {

                my $entry = {
                             itag => $format->{format_id},
                             url  => $format->{url},
                             type => ((($format->{format_note} // '') eq 'DASH audio') ? 'audio/' : 'video/') . $format->{ext},
                            };

                push @formats, $entry;
            }
        }
    }

    if ($self->get_debug) {
        my $count = scalar(@formats);
        say STDERR ":: Found $count streaming URLs...";
    }

    return @formats;
}

=head2 parse_query_string($string, multi => [0,1])

Parse a query string and return a data structure back.

When the B<multi> option is set to a true value, the function will store multiple values for a given key.

Returns back a list of key-value pairs.

=cut

sub parse_query_string {
    my ($self, $str, %opt) = @_;

    if (not defined($str)) {
        return;
    }

    require URI::Escape;

    my @pairs;
    foreach my $statement (split(/,/, $str)) {
        foreach my $pair (split(/&/, $statement)) {
            push @pairs, $pair;
        }
    }

    my %result;

    foreach my $pair (@pairs) {
        my ($key, $value) = split(/=/, $pair, 2);

        if (not defined($value) or $value eq '') {
            next;
        }

        $value = URI::Escape::uri_unescape($value =~ tr/+/ /r);

        if ($opt{multi}) {
            push @{$result{$key}}, $value;
        }
        else {
            $result{$key} = $value;
        }
    }

    return %result;
}

sub _group_keys_with_values {
    my ($self, %data) = @_;

    my @hashes;

    foreach my $key (keys %data) {
        foreach my $i (0 .. $#{$data{$key}}) {
            $hashes[$i]{$key} = $data{$key}[$i];
        }
    }

    return @hashes;
}

sub _old_extract_streaming_urls {
    my ($self, $info, $videoID) = @_;

    if ($self->get_debug) {
        say STDERR ":: Using `url_encoded_fmt_stream_map` to extract the streaming URLs...";
    }

    my %stream_map = $self->parse_query_string($info->{url_encoded_fmt_stream_map}, multi => 1);
    my %adaptive_fmts = $self->parse_query_string($info->{adaptive_fmts}, multi => 1);

    if ($self->get_debug >= 2) {
        require Data::Dump;
        Data::Dump::pp(\%stream_map);
        Data::Dump::pp(\%adaptive_fmts);
    }

    my @results;

    push @results, $self->_group_keys_with_values(%stream_map);
    push @results, $self->_group_keys_with_values(%adaptive_fmts);

    foreach my $video (@results) {
        if (exists $video->{s}) {    # has an encrypted signature :(

            if ($self->get_debug) {
                say STDERR ":: Detected an encrypted signature...";
            }

            my @formats = $self->_fallback_extract_urls($videoID);

            foreach my $format (@formats) {
                foreach my $ref (@results) {
                    if (defined($ref->{itag}) and ($ref->{itag} eq $format->{itag})) {
                        $ref->{url} = $format->{url};
                        last;
                    }
                }
            }

            last;
        }
    }

    if ($info->{livestream} or $info->{live_playback}) {

        if ($self->get_debug) {
            say STDERR ":: Live stream detected...";
        }

        if (my @formats = $self->_fallback_extract_urls($videoID)) {
            @results = @formats;
        }
        elsif (exists $info->{hlsvp}) {
            push @results,
              {
                itag => 38,
                type => 'video/ts',
                url  => $info->{hlsvp},
              };
        }
    }

    if ($self->get_debug) {
        my $count = scalar(@results);
        say STDERR ":: Found $count streaming URLs...";
    }

    return @results;
}

sub _extract_streaming_urls {
    my ($self, $info, $videoID) = @_;

    if (exists $info->{url_encoded_fmt_stream_map}) {
        return $self->_old_extract_streaming_urls($info, $videoID);
    }

    if ($self->get_debug) {
        say STDERR ":: Using `player_response` to extract the streaming URLs...";
    }

    my $json = $self->parse_json_string($info->{player_response});

    if ($self->get_debug >= 2) {
        require Data::Dump;
        Data::Dump::pp($json);
    }

    my @results;
    if (exists $json->{streamingData}) {

        my $streamingData = $json->{streamingData};

        if (exists $streamingData->{adaptiveFormats}) {
            push @results, @{$streamingData->{adaptiveFormats}};
        }

        if (exists $streamingData->{formats}) {
            push @results, @{$streamingData->{formats}};
        }
    }

    foreach my $item (@results) {

        if (exists $item->{cipher} and not exists $item->{url}) {

            my %data = $self->parse_query_string($item->{cipher});

            $item->{url} = $data{url} if defined($data{url});

            if (defined($data{s})) {    # unclear how this can be decrypted...
                require URI::Escape;
                my $sig = $data{s};
                $sig = URI::Escape::uri_escape($sig);
                $item->{url} .= "&sig=$sig";
            }
        }

        if (exists $item->{mimeType}) {
            $item->{type} = $item->{mimeType};
        }
    }

    # Cipher streaming URLs are currently unsupported, so let's filter them out.
    @results = grep { not exists $_->{cipher} } @results;

    # Keep only streams with contentLength > 0.
    @results = grep { exists($_->{contentLength}) and $_->{contentLength} > 0 } @results;

    if ($self->get_debug) {
        my $count = scalar(@results);
        say STDERR ":: Found $count streaming URLs...";
    }

    return @results;
}

=head2 get_streaming_urls($videoID)

Returns a list of streaming URLs for a videoID.
({itag=>..., url=>...}, {itag=>..., url=>....}, ...)

=cut

sub get_streaming_urls {
    my ($self, $videoID) = @_;

    my $url     = ($self->get_video_info_url() . sprintf($self->get_video_info_args(), $videoID));
    my $content = $self->lwp_get($url, simple => 1) // return;
    my %info    = $self->parse_query_string($content);

    my @streaming_urls = $self->_extract_streaming_urls(\%info, $videoID);

    my @caption_urls;
    if (exists $info{player_response}) {

        require URI::Escape;
        my $captions_json = URI::Escape::uri_unescape($info{player_response});
        my $caption_data  = $self->parse_json_string($captions_json);

        if (eval { ref($caption_data->{captions}{playerCaptionsTracklistRenderer}{captionTracks}) eq 'ARRAY' }) {
            push @caption_urls, @{$caption_data->{captions}{playerCaptionsTracklistRenderer}{captionTracks}};
        }
    }

    if ($self->get_debug >= 3) {
        require Data::Dump;
        Data::Dump::pp(\%info);
        Data::Dump::pp(\@streaming_urls);
        Data::Dump::pp(\@caption_urls);
    }

    # Try again with youtube-dl
    if (!@streaming_urls or $info{status} =~ /fail|error/i) {
        @streaming_urls = $self->_fallback_extract_urls($videoID);
    }

    if ($self->get_prefer_mp4) {

        my @mp4_urls;
        my @audio_urls;

        foreach my $url (@streaming_urls) {
            if ($url->{type} =~ /\bvideo\b/) {
                if ($url->{type} =~ /\bmp4\b/) {
                    push @mp4_urls, $url;
                }
            }
            else {
                push @audio_urls, $url;
            }
        }

        if (@mp4_urls) {
            @streaming_urls = (@mp4_urls, @audio_urls);
        }
    }

    # Filter out streams with `clen = 0`.
    @streaming_urls = grep { defined($_->{clen}) ? ($_->{clen} > 0) : 1 } @streaming_urls;

    # Return the YouTube URL when there are no streaming URLs
    if (!@streaming_urls) {
        push @streaming_urls,
          {
            itag    => 22,
            quality => "hd720",
            type    => "video/mp4",
            url     => "https://www.youtube.com/watch?v=$videoID",
          };
    }

    return (\@streaming_urls, \@caption_urls, \%info);
}

sub _request {
    my ($self, $req) = @_;

    $self->{lwp} // $self->set_lwp_useragent();

    my $res = $self->{lwp}->request($req);

    if ($res->is_success) {
        return $res->decoded_content;
    }
    else {
        warn 'Request error: ' . $res->status_line();
    }

    return;
}

sub _prepare_request {
    my ($self, $req, $length) = @_;

    $req->header('Content-Length' => $length) if ($length);

    if (defined $self->get_access_token) {
        $req->header('Authorization' => $self->prepare_access_token);
    }

    return 1;
}

sub _save {
    my ($self, $method, $uri, $content) = @_;

    require HTTP::Request;
    my $req = HTTP::Request->new($method => $uri);
    $req->content_type('application/json; charset=UTF-8');
    $self->_prepare_request($req, length($content));
    $req->content($content);

    $self->_request($req);
}

sub post_as_json {
    my ($self, $url, $ref) = @_;
    my $json_str = $self->make_json_string($ref);
    $self->_save('POST', $url, $json_str);
}

# SUBROUTINE FACTORY
{
    no strict 'refs';

    # Create {next,previous}_page subroutines
    foreach my $name ('next_page', 'previous_page') {
        *{__PACKAGE__ . '::' . $name} = sub {
            my ($self, $url, $token) = @_;

            my $pt_url = (
                            $url =~ s/[?&]pageToken=\K[^&]+/$token/
                          ? $url
                          : $self->_append_url_args($url, pageToken => $token)
                         );

            my $res = $self->_get_results($pt_url);
            $res->{url} = $pt_url;
            return $res;
        };
    }

    # Create proxy_{exec,system} subroutines
    foreach my $name ('exec', 'system', 'stdout') {
        *{__PACKAGE__ . '::proxy_' . $name} = sub {
            my ($self, @args) = @_;

            $self->{lwp} // $self->set_lwp_useragent();

            local $ENV{http_proxy}  = $self->{lwp}->proxy('http');
            local $ENV{https_proxy} = $self->{lwp}->proxy('https');

            local $ENV{HTTP_PROXY}  = $self->{lwp}->proxy('http');
            local $ENV{HTTPS_PROXY} = $self->{lwp}->proxy('https');

                $name eq 'exec'   ? exec(@args)
              : $name eq 'system' ? system(@args)
              : $name eq 'stdout' ? qx(@args)
              :                     ();
        };
    }
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>

=head1 SEE ALSO

https://developers.google.com/youtube/v3/docs/

=head1 LICENSE AND COPYRIGHT

Copyright 2012-2015 Trizen.

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
