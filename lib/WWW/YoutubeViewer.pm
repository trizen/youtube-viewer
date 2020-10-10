package WWW::YoutubeViewer;

use utf8;
use 5.016;
use warnings;

use Memoize;

memoize('_get_video_info');
memoize('_ytdl_is_available');
memoize('_extract_from_ytdl');
memoize('_extract_from_invidious');

use parent qw(
  WWW::YoutubeViewer::Search
  WWW::YoutubeViewer::Videos
  WWW::YoutubeViewer::Channels
  WWW::YoutubeViewer::Playlists
  WWW::YoutubeViewer::ParseJSON
  WWW::YoutubeViewer::Activities
  WWW::YoutubeViewer::Subscriptions
  WWW::YoutubeViewer::PlaylistItems
  WWW::YoutubeViewer::CommentThreads
  WWW::YoutubeViewer::Authentication
  WWW::YoutubeViewer::VideoCategories
  );

=head1 NAME

WWW::YoutubeViewer - A very easy interface to YouTube.

=cut

our $VERSION = '3.7.9';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;

    my $yv_obj = WWW::YoutubeViewer->new();
    ...

=head1 SUBROUTINES/METHODS

=cut

my %valid_options = (

    # Main options
    v               => {valid => q[],                                                    default => 3},
    page            => {valid => qr/^(?!0+\z)\d+\z/,                                     default => 1},
    http_proxy      => {valid => qr/./,                                                  default => undef},
    hl              => {valid => qr/^\w+(?:[\-_]\w+)?\z/,                                default => undef},
    maxResults      => {valid => [1 .. 50],                                              default => 10},
    topicId         => {valid => qr/./,                                                  default => undef},
    order           => {valid => [qw(relevance date rating viewCount title videoCount)], default => undef},
    publishedAfter  => {valid => qr/^\d+/,                                               default => undef},
    publishedBefore => {valid => qr/^\d+/,                                               default => undef},
    channelId       => {valid => qr/^[-\w]{2,}\z/,                                       default => undef},
    channelType     => {valid => [qw(any show)],                                         default => undef},

    # Video only options
    videoCaption    => {valid => [qw(any closedCaption none)],     default => undef},
    videoDefinition => {valid => [qw(any high standard)],          default => undef},
    videoCategoryId => {valid => qr/^\d+\z/,                       default => undef},
    videoDimension  => {valid => [qw(any 2d 3d)],                  default => undef},
    videoDuration   => {valid => [qw(any short medium long)],      default => undef},
    videoEmbeddable => {valid => [qw(any true)],                   default => undef},
    videoLicense    => {valid => [qw(any creativeCommon youtube)], default => undef},
    videoSyndicated => {valid => [qw(any true)],                   default => undef},
    eventType       => {valid => [qw(completed live upcoming)],    default => undef},
    chart           => {valid => [qw(mostPopular)],                default => undef},

    regionCode        => {valid => qr/^[A-Z]{2}\z/i,           default => undef},
    relevanceLanguage => {valid => qr/^[a-z]+(?:\-\w+)?\z/i,   default => undef},
    safeSearch        => {valid => [qw(none moderate strict)], default => undef},
    videoType         => {valid => [qw(any episode movie)],    default => undef},

    comments_order      => {valid => [qw(time relevance)],                default => 'time'},
    subscriptions_order => {valid => [qw(alphabetical relevance unread)], default => undef},

    # Misc
    debug       => {valid => [0 .. 3],   default => 0},
    timeout     => {valid => qr/^\d+\z/, default => 10},
    config_dir  => {valid => qr/^./,     default => q{.}},
    cache_dir   => {valid => qr/^./,     default => q{.}},
    cookie_file => {valid => qr/^./,     default => undef},

    # Support for youtube-dl
    ytdl     => {valid => [1, 0], default => 1},
    ytdl_cmd => {valid => qr/\w/, default => "youtube-dl"},

    # Booleans
    env_proxy   => {valid => [1, 0], default => 1},
    escape_utf8 => {valid => [1, 0], default => 0},
    prefer_mp4  => {valid => [1, 0], default => 0},
    prefer_av1  => {valid => [1, 0], default => 0},

    # API/OAuth
    key           => {valid => qr/^.{15}/, default => undef},
    client_id     => {valid => qr/^.{15}/, default => undef},
    client_secret => {valid => qr/^.{15}/, default => undef},
    redirect_uri  => {valid => qr/^.{15}/, default => 'urn:ietf:wg:oauth:2.0:oob'},
    access_token  => {valid => qr/^.{15}/, default => undef},
    refresh_token => {valid => qr/^.{15}/, default => undef},

    authentication_file => {valid => qr/^./, default => undef},

    # No input value allowed
    feeds_url        => {valid => q[], default => 'https://www.googleapis.com/youtube/v3/'},
    video_info_url   => {valid => q[], default => 'https://www.youtube.com/get_video_info'},
    oauth_url        => {valid => q[], default => 'https://accounts.google.com/o/oauth2/'},
    video_info_args  => {valid => q[], default => '?video_id=%s&el=detailpage&ps=default&eurl=&gl=US&hl=en'},
    www_content_type => {valid => q[], default => 'application/x-www-form-urlencoded'},

#<<<
    # LWP user agent
    user_agent => {valid => qr/^.{5}/, default => 'Mozilla/5.0 (Windows NT 10.0; Win64; gzip; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.0.0 Safari/537.36'},
#>>>
);

sub _our_smartmatch {
    my ($value, $arg) = @_;

    $value // return 0;

    if (not ref($arg)) {
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

        if (ref($valid_options{$key}{valid})) {

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

    foreach my $invalid_key (keys %opts) {
        warn "Invalid key: '${invalid_key}'";
    }

    return $self;
}

sub page_token {
    my ($self, $number) = @_;

    my $page = $number // $self->get_page;

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

    my $agent = $lwp->new(

        cookie_jar    => {},                      # temporary cookies
        timeout       => $self->get_timeout,
        show_progress => $self->get_debug,
        agent         => $self->get_user_agent,

        ssl_opts => {verify_hostname => 1},

        $lwp eq 'LWP::UserAgent::Cached'
        ? (
           cache_dir  => $self->get_cache_dir,
           nocache_if => sub {
               my ($response) = @_;
               my $code = $response->code;

               $code >= 300                                # do not cache any bad response
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

        env_proxy => (defined($self->get_http_proxy) ? 0 : $self->get_env_proxy),
    );

    require LWP::ConnCache;
    state $cache = LWP::ConnCache->new;
    $cache->total_capacity(undef);                               # no limit

    state $accepted_encodings = do {
        require HTTP::Message;
        HTTP::Message::decodable();
    };

    $agent->ssl_opts(Timeout => $self->get_timeout);
    $agent->default_header('Accept-Encoding' => $accepted_encodings);
    $agent->conn_cache($cache);
    $agent->proxy(['http', 'https'], $self->get_http_proxy) if defined($self->get_http_proxy);

    my $cookie_file = $self->get_cookie_file;

    if (defined($cookie_file) and -f $cookie_file) {

        if ($self->get_debug) {
            say STDERR ":: Using cookies from: $cookie_file";
        }

        ## Netscape HTTP Cookies

        # Chrome extension:
        #   https://chrome.google.com/webstore/detail/cookiestxt/njabckikapfpffapmjgojcnbfjonfjfg

        # Firefox extension:
        #   https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/

        # See also:
        #   https://github.com/ytdl-org/youtube-dl#how-do-i-pass-cookies-to-youtube-dl

        require HTTP::Cookies::Netscape;

        my $cookies = HTTP::Cookies::Netscape->new(
                                                   hide_cookie2 => 1,
                                                   autosave     => 1,
                                                   file         => $cookie_file,
                                                  );

        $cookies->load;
        $agent->cookie_jar($cookies);
    }

    push @{$agent->requests_redirectable}, 'POST';
    $self->{lwp} = $agent;
    return $agent;
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

    if (not defined($self->get_key)) {
        return undef if not $opt{simple};
    }

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

sub get_invidious_instances {
    my ($self) = @_;

    require File::Spec;
    my $instances_file = File::Spec->catfile($self->get_config_dir, 'instances.json');

    # Get the "instances.json" file when the local copy is too old or non-existent
    if ((not -e $instances_file) or (-M _) > 1 / 24) {

        require LWP::UserAgent;

        my $lwp = LWP::UserAgent->new(timeout => $self->get_timeout);
        $lwp->show_progress(1) if $self->get_debug;
        my $resp = $lwp->get("https://instances.invidio.us/instances.json");

        $resp->is_success() or return;

        my $json = $resp->decoded_content() || return;
        open(my $fh, '>', $instances_file) or return;
        print $fh $json;
        close $fh;
    }

    open(my $fh, '<', $instances_file) or return;

    my $json_string = do {
        local $/;
        <$fh>;
    };

    $self->parse_json_string($json_string);
}

sub select_good_invidious_instances {
    my ($self) = @_;

    state $instances = $self->get_invidious_instances;

    ref($instances) eq 'ARRAY' or return;

    my %ignored = (
                   'yewtu.be'                 => 1,
                   'invidiou.site'            => 1,
                   'invidious.xyz'            => 1,
                   'vid.mint.lgbt'            => 1,
                   'invidious.ggc-project.de' => 1,
                   'invidious.toot.koeln'     => 1,
                   'invidious.snopyta.org'    => 1,    # too popular == too slow
                  );

    my @candidates =
      grep { not $ignored{$_->[0]} }
      grep { ref($_->[1]{monitor}) eq 'HASH' ? ($_->[1]{monitor}{statusClass} eq 'success') : 1 }
      grep { lc($_->[1]{type} // '') eq 'https' } @$instances;

    if ($self->get_debug) {

        my @hosts = map { $_->[0] } @candidates;
        my $count = scalar(@candidates);

        print STDERR ":: Found $count invidious instances: @hosts\n";
    }

    return @candidates;
}

sub _extract_from_invidious {
    my ($self, $videoID) = @_;

    my @instances = $self->select_good_invidious_instances();

    if (@instances) {
        require List::Util;
        @instances = List::Util::shuffle(map { $_->[0] } @instances);
        push @instances, 'invidious.snopyta.org';
    }
    else {
        @instances = qw(
          invidious.tube
          invidious.site
          invidious.fdn.fr
          invidious.snopyta.org
          );
    }

    if ($self->get_debug) {
        print STDERR ":: Invidious instances: @instances\n";
    }

    my $tries      = 2 * scalar(@instances);
    my $instance   = shift(@instances);
    my $url_format = "https://%s/api/v1/videos/%s?fields=formatStreams,adaptiveFormats";
    my $url        = sprintf($url_format, $instance, $videoID);

    my $resp = $self->{lwp}->get($url);

    while (not $resp->is_success() and --$tries >= 0) {
        $url  = sprintf($url_format, shift(@instances), $videoID) if (@instances and ($tries % 2 == 0));
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

sub _ytdl_is_available {
    my ($self) = @_;
    ($self->proxy_stdout($self->get_ytdl_cmd(), '--version') // '') =~ /\d/;
}

sub _extract_from_ytdl {
    my ($self, $videoID) = @_;

    $self->_ytdl_is_available() || return;

    my @ytdl_cmd = ($self->get_ytdl_cmd(), '--all-formats', '--dump-single-json');

    my $cookie_file = $self->get_cookie_file;

    if (defined($cookie_file) and -f $cookie_file) {
        push @ytdl_cmd, '--cookies', quotemeta($cookie_file);
    }

    my $json = $self->proxy_stdout(@ytdl_cmd, quotemeta("https://www.youtube.com/watch?v=" . $videoID));
    my $ref  = $self->parse_json_string($json);

    my @formats;
    if (ref($ref) eq 'HASH' and exists($ref->{formats}) and ref($ref->{formats}) eq 'ARRAY') {
        foreach my $format (@{$ref->{formats}}) {
            if (exists($format->{format_id}) and exists($format->{url})) {

                my $entry = {
                             itag => $format->{format_id},
                             url  => $format->{url},
                             type => ((($format->{format} // '') =~ /audio only/i) ? 'audio/' : 'video/') . $format->{ext},
                            };

                push @formats, $entry;
            }
        }
    }

    return @formats;
}

sub _fallback_extract_urls {
    my ($self, $videoID) = @_;

    my @formats;

    # Use youtube-dl
    if ($self->get_ytdl and $self->_ytdl_is_available) {

        if ($self->get_debug) {
            say STDERR ":: Using youtube-dl to extract the streaming URLs...";
        }

        push @formats, $self->_extract_from_ytdl($videoID);

        if ($self->get_debug) {
            my $count = scalar(@formats);
            say STDERR ":: youtube-dl: found $count streaming URLs...";
        }

        @formats && return @formats;
    }

    # Use the API of invidio.us
    if ($self->get_debug) {
        say STDERR ":: Using invidio.us to extract the streaming URLs...";
    }

    push @formats, $self->_extract_from_invidious($videoID);

    if ($self->get_debug) {
        my $count = scalar(@formats);
        say STDERR ":: invidious: found $count streaming URLs...";
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

sub _check_streaming_urls {
    my ($self, $videoID, $results) = @_;

    foreach my $video (@$results) {

        if (   exists $video->{s}
            or exists $video->{signatureCipher}
            or exists $video->{cipher}) {    # has an encrypted signature :(

            if ($self->get_debug) {
                say STDERR ":: Detected an encrypted signature...";
            }

            my @formats = $self->_fallback_extract_urls($videoID);

            foreach my $format (@formats) {
                foreach my $ref (@$results) {
                    if (defined($ref->{itag}) and ($ref->{itag} eq $format->{itag})) {
                        $ref->{url} = $format->{url};
                        last;
                    }
                }
            }

            last;
        }
    }

    foreach my $video (@$results) {
        if (exists $video->{mimeType}) {
            $video->{type} = $video->{mimeType};
        }
    }

    return 1;
}

sub _old_extract_streaming_urls {
    my ($self, $info, $videoID) = @_;

    if ($self->get_debug) {
        say STDERR ":: Using `url_encoded_fmt_stream_map` to extract the streaming URLs...";
    }

    my %stream_map    = $self->parse_query_string($info->{url_encoded_fmt_stream_map}, multi => 1);
    my %adaptive_fmts = $self->parse_query_string($info->{adaptive_fmts},              multi => 1);

    if ($self->get_debug >= 2) {
        require Data::Dump;
        Data::Dump::pp(\%stream_map);
        Data::Dump::pp(\%adaptive_fmts);
    }

    my @results;

    push @results, $self->_group_keys_with_values(%stream_map);
    push @results, $self->_group_keys_with_values(%adaptive_fmts);

    $self->_check_streaming_urls($videoID, \@results);

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

    my $json = $self->parse_json_string($info->{player_response} // return);

    if ($self->get_debug >= 2) {
        require Data::Dump;
        Data::Dump::pp($json);
    }

    ref($json) eq 'HASH' or return;

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

    $self->_check_streaming_urls($videoID, \@results);

    # Keep only streams with contentLength > 0.
    @results = grep { $_->{itag} == 22 or (exists($_->{contentLength}) and $_->{contentLength} > 0) } @results;

    # Detect livestream
    if (!@results and exists($json->{streamingData}) and exists($json->{streamingData}{hlsManifestUrl})) {

        if ($self->get_debug) {
            say STDERR ":: Live stream detected...";
        }

        @results = $self->_fallback_extract_urls($videoID);

        if (!@results) {
            push @results,
              {
                itag => 38,
                type => "video/ts",
                url  => $json->{streamingData}{hlsManifestUrl},
              };
        }
    }

    return @results;
}

sub _get_video_info {
    my ($self, $videoID) = @_;

    my $url     = $self->get_video_info_url() . sprintf($self->get_video_info_args(), $videoID);
    my $content = $self->lwp_get($url, simple => 1) // return;
    my %info    = $self->parse_query_string($content);

    return %info;
}

=head2 get_streaming_urls($videoID)

Returns a list of streaming URLs for a videoID.
({itag=>..., url=>...}, {itag=>..., url=>....}, ...)

=cut

sub get_streaming_urls {
    my ($self, $videoID) = @_;

    my %info           = $self->_get_video_info($videoID);
    my @streaming_urls = $self->_extract_streaming_urls(\%info, $videoID);

    my @caption_urls;
    if (exists $info{player_response}) {

        my $captions_json = $info{player_response};                     # don't run uri_unescape() on this
        my $caption_data  = $self->parse_json_string($captions_json);

        if (eval { ref($caption_data->{captions}{playerCaptionsTracklistRenderer}{captionTracks}) eq 'ARRAY' }) {
            push @caption_urls, @{$caption_data->{captions}{playerCaptionsTracklistRenderer}{captionTracks}};
        }
    }

    if ($self->get_debug) {
        my $count = scalar(@streaming_urls);
        say STDERR ":: Found $count streaming URLs...";
    }

    # Try again with youtube-dl
    if (!@streaming_urls or $info{status} =~ /fail|error/i) {
        @streaming_urls = $self->_fallback_extract_urls($videoID);
    }

    if ($self->get_prefer_mp4 or $self->get_prefer_av1) {

        my @video_urls;
        my @audio_urls;

        require WWW::YoutubeViewer::Itags;
        state $itags = WWW::YoutubeViewer::Itags::get_itags();

        my %audio_itags;
        @audio_itags{map { $_->{value} } @{$itags->{audio}}} = ();

        foreach my $url (@streaming_urls) {

            if (exists($audio_itags{$url->{itag}})) {
                push @audio_urls, $url;
                next;
            }

            if ($url->{type} =~ /\bvideo\b/i) {
                if ($url->{type} =~ /\bav[0-9]+\b/i) {    # AV1
                    if ($self->get_prefer_av1) {
                        push @video_urls, $url;
                    }
                }
                elsif ($self->get_prefer_mp4 and $url->{type} =~ /\bmp4\b/i) {
                    push @video_urls, $url;
                }
            }
            else {
                push @audio_urls, $url;
            }
        }

        if (@video_urls) {
            @streaming_urls = (@video_urls, @audio_urls);
        }
    }

    # Filter out streams with `clen = 0`.
    @streaming_urls = grep { defined($_->{clen}) ? ($_->{clen} > 0) : 1 } @streaming_urls;

    # Return the YouTube URL when there are no streaming URLs
    if (!@streaming_urls) {
        push @streaming_urls,
          {
            itag => 38,
            type => "video/mp4",
            url  => "https://www.youtube.com/watch?v=$videoID",
          };
    }

    if ($self->get_debug >= 2) {
        require Data::Dump;
        Data::Dump::pp(\%info) if ($self->get_debug >= 3);
        Data::Dump::pp(\@streaming_urls);
        Data::Dump::pp(\@caption_urls);
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

sub from_page_token {
    my ($self, $url, $token) = @_;

    my $pt_url = (
                  defined($token)
                  ? (
                     ($url =~ s/[?&]pageToken=\K[^&]+/$token/)
                     ? $url
                     : $self->_append_url_args($url, pageToken => $token)
                    )
                  : ($url =~ s/[?&]pageToken=[^&]+//r)
                 );

    my $res = $self->_get_results($pt_url);
    $res->{url} = $pt_url;
    return $res;
}

# SUBROUTINE FACTORY
{
    no strict 'refs';

    # Create proxy_{exec,system} subroutines
    foreach my $name ('exec', 'system', 'stdout') {
        *{__PACKAGE__ . '::proxy_' . $name} = sub {
            my ($self, @args) = @_;

            $self->{lwp} // $self->set_lwp_useragent();

            local $ENV{http_proxy}  = $self->{lwp}->proxy('http');
            local $ENV{https_proxy} = $self->{lwp}->proxy('https');

            local $ENV{HTTP_PROXY}  = $self->{lwp}->proxy('http');
            local $ENV{HTTPS_PROXY} = $self->{lwp}->proxy('https');

            local $" = " ";

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
