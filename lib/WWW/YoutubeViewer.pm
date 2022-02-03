package WWW::YoutubeViewer;

use utf8;
use 5.016;
use warnings;

use Memoize;
use Memoize::Expire;

tie my %youtubei_cache => 'Memoize::Expire',
  LIFETIME             => 600,                 # in seconds
  NUM_USES             => 10;

memoize '_get_youtubei_content', SCALAR_CACHE => [HASH => \%youtubei_cache];

#memoize('_get_video_info');
memoize('_ytdl_is_available');

#memoize('_info_from_ytdl');
#memoize('_extract_from_ytdl');
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

use WWW::YoutubeViewer::Utils;

=head1 NAME

WWW::YoutubeViewer - A very easy interface to YouTube.

=cut

our $VERSION = '3.9.7';

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
    videoCaption    => {valid => [qw(closedCaption none)],      default => undef},
    videoDefinition => {valid => [qw(high standard)],           default => undef},
    videoCategoryId => {valid => qr/^\d+\z/,                    default => undef},
    videoDimension  => {valid => [qw(2d 3d)],                   default => undef},
    videoDuration   => {valid => [qw(short medium long)],       default => undef},
    videoEmbeddable => {valid => [qw(true)],                    default => undef},
    videoLicense    => {valid => [qw(creativeCommon youtube)],  default => undef},
    videoSyndicated => {valid => [qw(true)],                    default => undef},
    eventType       => {valid => [qw(completed live upcoming)], default => undef},
    chart           => {valid => [qw(mostPopular)],             default => undef},

    regionCode        => {valid => qr/^[A-Z]{2}\z/i,           default => undef},
    relevanceLanguage => {valid => qr/^[a-z]+(?:\-\w+)?\z/i,   default => undef},
    safeSearch        => {valid => [qw(none moderate strict)], default => undef},
    videoType         => {valid => [qw(episode movie)],        default => undef},

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
    env_proxy      => {valid => [1, 0], default => 1},
    escape_utf8    => {valid => [1, 0], default => 0},
    prefer_mp4     => {valid => [1, 0], default => 0},
    prefer_av1     => {valid => [1, 0], default => 0},
    force_fallback => {valid => [1, 0], default => 0},

    # API/OAuth
    key           => {valid => qr/^.{15}/, default => undef},
    client_id     => {valid => qr/^.{15}/, default => undef},
    client_secret => {valid => qr/^.{15}/, default => undef},
    redirect_uri  => {valid => qr/^.{15}/, default => 'urn:ietf:wg:oauth:2.0:oob'},
    access_token  => {valid => qr/^.{15}/, default => undef},
    refresh_token => {valid => qr/^.{15}/, default => undef},

    authentication_file => {valid => qr/^./, default => undef},

#<<<
    # No input value allowed
    feeds_url        => {valid => q[], default => 'https://www.googleapis.com/youtube/v3/'},
    video_info_url   => {valid => q[], default => 'https://www.youtube.com/get_video_info'},
    oauth_url        => {valid => q[], default => 'https://accounts.google.com/o/oauth2/'},
    video_info_args  => {valid => q[], default => '?video_id=%s&el=detailpage&ps=default&eurl=&gl=US&hl=en&html5=1&c=TVHTML5&cver=6.20180913'},
    www_content_type => {valid => q[], default => 'application/x-www-form-urlencoded'},
    youtubei_url     => {valid => q[], default => 'https://youtubei.googleapis.com/youtubei/v1/%s?key=' . reverse("8Wcq11_9Y_wliCGLHETS4Q8UqlS2JF_OAySazIA")},
#>>>

#<<<
    # LWP user agent
    user_agent => {valid => qr/^.{5}/, default => 'Mozilla/5.0 (Android 11; Tablet; rv:83.0) Gecko/83.0 Firefox/83.0,gzip(gfe)'},
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

                 # don't cache if "cache-control" specifies "max-age=0", "no-store" or "no-cache"
                 or (($response->header('cache-control') // '') =~ /\b(?:max-age=0|no-store|no-cache)\b/)

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
    $cache->total_capacity(undef);    # no limit

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

sub _warn_response_error {
    my ($resp, $url) = @_;
    warn sprintf("[%s] Error occurred on URL: %s\n", $resp->status_line, $url =~ s/([&?])key=(.*?)&/${1}key=[...]&/r);
}

sub _request_with_authorization {
    my ($self, $block, %opt) = @_;

    my $response = $opt{simple} ? $block->() : $block->($self->_auth_lwp_header);

    if ($response->is_success or $opt{simple}) {
        return $response;
    }

    if ($response->status_line() =~ /^401 / and defined($self->get_refresh_token)) {
        if (defined(my $refresh_token = $self->oauth_refresh_token())) {
            if (defined $refresh_token->{access_token}) {

                $self->set_access_token($refresh_token->{access_token});

                # Don't be tempted to use recursion here, because bad things will happen!
                $response = $block->($self->_auth_lwp_header);

                if ($response->is_success) {
                    $self->save_authentication_tokens();
                    return $response;
                }

                if ($response->status_line() =~ /^401 /) {
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

    return $response;
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

    my $response = $self->_request_with_authorization(sub { $self->{lwp}->get($url, @_) }, %opt);

    if ($response->is_success) {
        return $response->decoded_content;
    }

    $opt{depth} ||= 0;

    # Try again on 500+ HTTP errors
    if (    $opt{depth} <= 3
        and $response->code() >= 500
        and $response->status_line() =~ /(?:Temporary|Server) Error|Timeout|Service Unavailable/i) {
        return $self->lwp_get($url, %opt, depth => $opt{depth} + 1);
    }

    _warn_response_error($response, $url);
    return;
}

=head2 lwp_post($url, [@args])

Post and return the content for $url.

=cut

sub lwp_post {
    my ($self, $url, %opt) = @_;

    $self->{lwp} // $self->set_lwp_useragent();

    my $response = $self->_request_with_authorization(
        sub {
            $self->{lwp}->post($url, (exists($opt{headers}) ? $opt{headers} : ()), @_);
        },
        %opt
                                                     );

    if ($response->is_success) {
        return $response->decoded_content;
    }

    _warn_response_error($response, $url);
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

sub _send_request {
    my ($self, $method, $url, $content) = @_;

    $self->{lwp} // $self->set_lwp_useragent();

    my $response = $self->_request_with_authorization(
        sub {
            require HTTP::Request;

            my $req = HTTP::Request->new($method => $url);
            $req->header('Authorization' => $self->prepare_access_token) if defined($self->get_access_token);

            if (defined($content)) {
                $req->content_type('application/json; charset=UTF-8');
                $req->header('Content-Length' => length($content));
                $req->content($content);
            }

            $self->{lwp}->request($req);
          },
    );

    if ($response->is_success) {
        return $response->decoded_content;
    }

    _warn_response_error($response, $url);
    return;
}

=head2 post_as_json($url, $ref)

Send a C<POST> request to the given URL, with JSON content given as a Perl REF structure. Returns the response content.

=cut

sub post_as_json {
    my ($self, $url, $ref) = @_;
    my $json_str = $self->make_json_string($ref);
    $self->_send_request('POST', $url, $json_str);
}

=head2 lwp_delete($url)

Send a C<DELETE> request to the given URL. Returns the response content.

=cut

sub lwp_delete {
    my ($self, $url) = @_;
    $self->_send_request('DELETE', $url);
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
        my $resp = $lwp->get("https://api.invidious.io/instances.json");

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
    my ($self, %args) = @_;

    state $instances = $self->get_invidious_instances;

    ref($instances) eq 'ARRAY' or return;

    my %ignored = (
                   'yewtu.be'                 => 1,    # 403 Forbidden (API)
                   'invidious.tube'           => 1,    # down?
                   'invidiou.site'            => 0,
                   'invidious.site'           => 1,    # AGPL Violation + trackers
                   'invidious.zee.li'         => 1,    # uses Cloudflare // 500 read timeout
                   'invidious.048596.xyz'     => 1,    # broken API
                   'invidious.xyz'            => 1,    # 502 Bad Gateway
                   'vid.mint.lgbt'            => 0,
                   'invidious.ggc-project.de' => 1,    # broken API
                   'invidious.toot.koeln'     => 1,    # broken API
                   'invidious.kavin.rocks'    => 1,    # 403 Forbidden (API)
                   'invidious.snopyta.org'    => 0,
                   'invidious.silkky.cloud'   => 0,
                   'invidious.moomoo.me'      => 1,    # uses Cloudflare
                   'y.com.cm'                 => 1,    # uses Cloudflare
                   'invidious.exonip.de'      => 1,    # 403 Forbidden (API)
                   'invidious-us.kavin.rocks' => 1,    # 403 Forbidden (API)
                   'invidious-jp.kavin.rocks' => 1,    # 403 Forbidden (API)
                  );

#<<<
    my @candidates =
      grep { not $ignored{$_->[0]} }
      grep { $args{lax} ? 1 : eval { lc($_->[1]{monitor}{dailyRatios}[0]{label} // '') eq 'success' } }
      #~ grep { $args{lax} ? 1 : eval { lc($_->[1]{monitor}{weeklyRatio}{label} // '') eq 'success' } }
      grep { $args{lax} ? 1 : eval { lc($_->[1]{monitor}{statusClass} // '') eq 'success' } }
      #~ grep { $args{lax} ? 1 : !exists($_->[1]{stats}{error}) }
      grep { lc($_->[1]{type} // '') eq 'https' } @$instances;
#>>>

    if ($self->get_debug) {

        my @hosts = map { $_->[0] } @candidates;
        my $count = scalar(@candidates);

        print STDERR ":: Found $count invidious instances: @hosts\n";
    }

    return @candidates;
}

sub _extract_from_invidious {
    my ($self, $videoID) = @_;

    my @candidates       = $self->select_good_invidious_instances();
    my @extra_candidates = $self->select_good_invidious_instances(lax => 1);

    require List::Util;

#<<<
    my %seen;
    my @instances = grep { !$seen{$_}++ } (
        List::Util::shuffle(map { $_->[0] } @candidates),
        List::Util::shuffle(map { $_->[0] } @extra_candidates),
    );
#>>>

    if (@instances) {
        push @instances, 'invidious.snopyta.org';
    }
    else {
        @instances = qw(
          invidious.snopyta.org
          invidious.silkky.cloud
          invidious.fdn.fr
          invidious.namazso.eu
          ytprivate.com
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

sub _info_from_ytdl {
    my ($self, $videoID) = @_;

    $self->_ytdl_is_available() || return;

    my @ytdl_cmd = ($self->get_ytdl_cmd(), '--all-formats', '--dump-single-json');

    my $cookie_file = $self->get_cookie_file;

    if (defined($cookie_file) and -f $cookie_file) {
        push @ytdl_cmd, '--cookies', quotemeta($cookie_file);
    }

    my $json = $self->proxy_stdout(@ytdl_cmd, quotemeta("https://www.youtube.com/watch?v=" . $videoID));
    my $ref  = $self->parse_json_string($json // return);

    if ($self->get_debug >= 3) {
        require Data::Dump;
        Data::Dump::pp($ref);
    }

    return $ref;
}

sub _extract_from_ytdl {
    my ($self, $videoID) = @_;

    my $ref = $self->_info_from_ytdl($videoID) // return;

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

    # Use the API of invidious
    if ($self->get_debug) {
        say STDERR ":: Using invidious to extract the streaming URLs...";
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
    my ($self, $json, $videoID) = @_;

    if ($self->get_debug) {
        say STDERR ":: Using `player_response` to extract the streaming URLs...";
    }

    if ($self->get_debug >= 2) {
        require Data::Dump;
        Data::Dump::pp($json);
    }

    ref($json) eq 'HASH' or return;

    my @results;
    if (exists $json->{streamingData}) {

        my $streamingData = $json->{streamingData};

        if (defined $streamingData->{dashManifestUrl}) {
            say STDERR ":: Contains DASH manifest URL" if $self->get_debug;
            ##return;
        }

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

    # Filter out streams with "dur=0.000"
    @results = grep { $_->{url} !~ /\bdur=0\.000\b/ } grep { defined($_->{url}) } @results;

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

sub _get_youtubei_content {
    my ($self, $endpoint, $videoID, %args) = @_;

    # Valid endpoints: browse, player, next

    my $url = sprintf($self->get_youtubei_url(), $endpoint);

    require Time::Piece;

    my %android = (
                   "videoId" => $videoID,
                   "context" => {
                                 "client" => {
                                              "hl"            => "en",
                                              "gl"            => "US",
                                              "clientName"    => "ANDROID",
                                              "clientVersion" => "16.20",
                                              %args,
                                             },
                                },
                  );

    my %web = (
               "videoId" => $videoID,
               "context" => {
                             "client" => {
                                          "hl"            => "en",
                                          "gl"            => "US",
                                          "clientName"    => "WEB",
                                          "clientVersion" => sprintf("2.%s.05.00", Time::Piece->new(time)->strftime("%Y%m%d")),
                                          %args,
                                         },
                            },
              );

    local $self->{access_token} = undef;
    my $content = $self->post_as_json($url, $endpoint eq 'next' ? \%web : \%android);

    return $content;
}

sub _old_get_video_info {
    my ($self, $videoID) = @_;

    my $url     = $self->get_video_info_url() . sprintf($self->get_video_info_args(), $videoID);
    my $content = $self->lwp_get($url, simple => 1) // return;
    my %info    = $self->parse_query_string($content);

    return %info;
}

sub _get_video_info {
    my ($self, $videoID, %args) = @_;

    my $content = $self->_get_youtubei_content('player', $videoID, %args);
    my %info    = (player_response => $content);

    return %info;
}

sub _get_video_next_info {
    my ($self, $videoID) = @_;
    $self->_get_youtubei_content('next', $videoID);
}

sub _make_translated_captions {
    my ($self, $caption_urls) = @_;

    my @languages = qw(
      af am ar az be bg bn bs ca ceb co cs cy da de el en eo es et eu fa fi fil
      fr fy ga gd gl gu ha haw hi hmn hr ht hu hy id ig is it iw ja jv ka kk km
      kn ko ku ky la lb lo lt lv mg mi mk ml mn mr ms mt my ne nl no ny or pa pl
      ps pt ro ru rw sd si sk sl sm sn so sq sr st su sv sw ta te tg th tk tr tt
      ug uk ur uz vi xh yi yo zh-Hans zh-Hant zu
    );

    my %trans_languages = map { $_->{languageCode} => 1 } @$caption_urls;
    @languages = grep { not exists $trans_languages{$_} } @languages;

    my @asr;
    foreach my $caption (@$caption_urls) {
        foreach my $lang_code (@languages) {
            my %caption_copy = %$caption;
            $caption_copy{languageCode} = $lang_code;
            $caption_copy{baseUrl}      = $caption_copy{baseUrl} . "&tlang=$lang_code";
            push @asr, \%caption_copy;
        }
    }

    return @asr;
}

sub _fallback_extract_captions {
    my ($self, $videoID) = @_;

    if ($self->get_debug) {
        say STDERR ":: Extracting closed-caption URLs with `youtube-dl`...";
    }

    # Extract closed-caption URLs with youtube-dl if our code failed
    my $ytdl_info = $self->_info_from_ytdl($videoID);

    my @caption_urls;

    if (defined($ytdl_info) and ref($ytdl_info) eq 'HASH') {

        my $has_subtitles = 0;

        foreach my $key (qw(subtitles automatic_captions)) {

            my $ccaps = $ytdl_info->{$key} // next;

            ref($ccaps) eq 'HASH' or next;

            foreach my $lang_code (sort keys %$ccaps) {

                my ($caption_info) = grep { $_->{ext} eq 'srv1' } @{$ccaps->{$lang_code}};

                if (defined($caption_info) and ref($caption_info) eq 'HASH' and defined($caption_info->{url})) {

                    push @caption_urls,
                      scalar {
                              kind         => ($key eq 'automatic_captions' ? 'asr' : ''),
                              languageCode => $lang_code,
                              baseUrl      => $caption_info->{url},
                             };

                    if ($key eq 'subtitles') {
                        $has_subtitles = 1;
                    }
                }
            }

            last if $has_subtitles;
        }

        # Auto-translated captions
        if ($has_subtitles) {

            if ($self->get_debug) {
                say STDERR ":: Generating translated closed-caption URLs...";
            }

            push @caption_urls, $self->_make_translated_captions(\@caption_urls);
        }
    }

    return @caption_urls;
}

=head2 get_streaming_urls($videoID)

Returns a list of streaming URLs for a videoID.
({itag=>..., url=>...}, {itag=>..., url=>....}, ...)

=cut

sub get_streaming_urls {
    my ($self, $videoID) = @_;

    no warnings 'redefine';

    local *_get_video_info    = memoize(\&_get_video_info);
    local *_info_from_ytdl    = memoize(\&_info_from_ytdl);
    local *_extract_from_ytdl = memoize(\&_extract_from_ytdl);

    my %info = $self->_get_video_info($videoID);
    my $json = defined($info{player_response}) ? $self->parse_json_string($info{player_response}) : {};

    if (not defined $json->{streamingData}) {
        say STDERR ":: Trying to bypass age-restricted gate..." if $self->get_debug;
        %info = $self->_get_video_info($videoID, "clientScreen" => "EMBED");
        $json = defined($info{player_response}) ? $self->parse_json_string($info{player_response}) : {};
    }

    my @streaming_urls = $self->_extract_streaming_urls($json, $videoID);

    my @caption_urls;

    if (eval { ref($json->{captions}{playerCaptionsTracklistRenderer}{captionTracks}) eq 'ARRAY' }) {

        my @caption_tracks = @{$json->{captions}{playerCaptionsTracklistRenderer}{captionTracks}};
        my @human_made_cc  = grep { ($_->{kind} // '') ne 'asr' } @caption_tracks;

        push @caption_urls, @human_made_cc, @caption_tracks;

        foreach my $caption (@caption_urls) {
            $caption->{baseUrl} =~ s{\bfmt=srv[0-9]\b}{fmt=srv1}g;
        }

        push @caption_urls, $self->_make_translated_captions(\@caption_urls);
    }

    # Try again with youtube-dl
    if (   !@streaming_urls
        or (($json->{playabilityStatus}{status} // '') =~ /fail|error|unavailable|not available/i)
        or $self->get_force_fallback) {

        @streaming_urls = $self->_fallback_extract_urls($videoID);

        if (!@caption_urls) {
            push @caption_urls, $self->_fallback_extract_captions($videoID);
        }
    }

    if ($self->get_debug) {
        my $count = scalar(@streaming_urls);
        say STDERR ":: Found $count streaming URLs...";
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

sub from_page_token {
    my ($self, $url, $token) = @_;

    if (ref($token) eq 'CODE') {
        return $token->();
    }

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

L<https://www.perlfoundation.org/artistic_license_2_0>

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
