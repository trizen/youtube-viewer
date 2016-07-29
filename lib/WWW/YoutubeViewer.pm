package WWW::YoutubeViewer;

use utf8;
use 5.014;
use warnings;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

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

our $VERSION = '3.2.3';

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
    http_proxy      => {valid => [qr{^https?://}],                                       default => undef},
    hl              => {valid => [qr/^\w+(?:[-_]\w+)?\z/],                               default => undef},
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

    subscriptions_order => {valid => [qw(alphabetical relevance unread)], default => undef},

    # Others
    debug       => {valid => [0 .. 2],     default => 0},
    lwp_timeout => {valid => [qr/^\d+\z/], default => 1},
    key         => {valid => [qr/^.{5}/],  default => undef},
    config_dir  => {valid => [qr/^./],     default => q{.}},
    cache_dir   => {valid => [qr/^./],     default => q{.}},

    # Booleans
    lwp_env_proxy => {valid => [1, 0], default => 1},
    escape_utf8   => {valid => [1, 0], default => 0},

    # OAuth stuff
    client_id     => {valid => [qr/^.{5}/], default => undef},
    client_secret => {valid => [qr/^.{5}/], default => undef},
    redirect_uri  => {valid => [qr/^.{5}/], default => undef},
    access_token  => {valid => [qr/^.{5}/], default => undef},
    refresh_token => {valid => [qr/^.{5}/], default => undef},

    authentication_file => {valid => [qr/^./], default => undef},

    # No input value alowed
    feeds_url        => {valid => q[], default => 'https://www.googleapis.com/youtube/v3/'},
    video_info_url   => {valid => q[], default => 'https://www.youtube.com/get_video_info'},
    oauth_url        => {valid => q[], default => 'https://accounts.google.com/o/oauth2/'},
    video_info_args  => {valid => q[], default => '?video_id=%s&el=detailpage&ps=default&eurl=&gl=US&hl=en'},
    www_content_type => {valid => q[], default => 'application/x-www-form-urlencoded'},

    # LWP user agent
    lwp_agent => {valid => [qr/^.{5}/], default => 'Mozilla/5.0 (X11; U; Linux i686; gzip; en-US) Chrome/10.0.648.45'},
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

    state $x = require MIME::Base64;
    MIME::Base64::encode_base64(pack('C*', @f, 16, 0)) =~ tr/=\n//dr;
}

=head2 escape_string($string)

Escapes a string with URI::Escape and returns it.

=cut

sub escape_string {
    my ($self, $string) = @_;

    state $x = require URI::Escape;

    $self->get_escape_utf8
      ? URI::Escape::uri_escape_utf8($string)
      : URI::Escape::uri_escape($string);
}

=head2 set_lwp_useragent()

Intializes the LWP::UserAgent module and returns it.

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
                 or $response->header('cache-control') =~ /\b(?:max-age=0|no-store)\b/

                 # don't cache video or audio files
                 or $response->header('content-type') =~ /\b(?:video|audio)\b/;
           },

           recache_if => sub {
               my ($response, $path) = @_;
               not($response->is_fresh)                    # recache if the response expired
                 or ($response->code == 404 && -M $path > 1);    # recache any 404 response older than 1 day
           }
          )
        : (),

        env_proxy => (defined($self->get_http_proxy) ? 0 : $self->get_lwp_env_proxy),
    );

    require LWP::ConnCache;
    my $cache = LWP::ConnCache->new;
    $cache->total_capacity(undef);                               # no limit

    my $agent = $self->{lwp};
    $agent->ssl_opts(Timeout => 30);
    $agent->default_header('Accept-Encoding' => 'gzip');
    $agent->conn_cache($cache);
    $agent->proxy('http', $self->get_http_proxy) if (defined($self->get_http_proxy));

    my $http_proxy = $agent->proxy('http');
    if (defined($http_proxy)) {
        $agent->proxy('https', $http_proxy) if (!defined($agent->proxy('https')));
        $agent->timeout(5);
    }

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

sub _get_lwp_header {
    my ($self) = @_;

    my %lwp_header;
    if (defined $self->get_access_token) {
        $lwp_header{'Authorization'} = $self->prepare_access_token;
    }

    return %lwp_header;
}

=head2 lwp_get($url)

Get and return the content for $url.

=cut

sub lwp_get {
    my ($self, $url, $simple) = @_;

    $url // return;
    $self->{lwp} // $self->set_lwp_useragent();

    my %lwp_header = ($simple ? () : $self->_get_lwp_header);
    my $response = $self->{lwp}->get($url, %lwp_header);

    if ($response->is_success) {
        return $response->decoded_content;
    }
    else {
        my $status = $response->status_line;

        if ($status =~ /^401 / and defined($self->get_refresh_token)) {
            if (defined(my $refresh_token = $self->oauth_refresh_token())) {
                if (defined $refresh_token->{access_token}) {

                    $self->set_access_token($refresh_token->{access_token});

                    # Don't be tempted to use recursion here, because bad things will happen!
                    my $new_resp = $self->{lwp}->get($url, $self->_get_lwp_header);

                    if ($new_resp->is_success) {
                        $self->save_authentication_tokens();
                        return $new_resp->decoded_content;
                    }
                    elsif ($new_resp->status_line() =~ /^401 /) {
                        $self->set_refresh_token();    # refresh token was invalid
                        $self->set_access_token();     # access token is also broken
                        warn "[!] Can't refresh the access token! Logging out...\n";
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

    my $response = $self->{lwp}->mirror($url, $name);

    if ($response->is_success) {
        return 1;
    }
    else {
        warn '[' . $response->status_line() . "] Error occured on URL: $url\n";
    }

    return;
}

sub _get_results {
    my ($self, $url, $simple) = @_;

    return
      scalar {
              url     => $url,
              results => $self->parse_json_string($self->lwp_get($url, $simple)),
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
                    %args,
                   );

    $self->list_to_url_arguments(%defaults);
}

sub _make_feed_url {
    my ($self, $path, %args) = @_;
    $self->get_feeds_url() . $path . '?' . $self->default_arguments(%args);
}

=head2 get_courses_from_category($cat_id)

Get the courses from a specific category ID.
$cat_id can be any valid category ID from the EDU categories.

=cut

sub get_courses_from_category {
    my ($self, $cat_id) = @_;

    ...    # NEEDS WORK!!!
}

=head2 get_video_lectures_from_course($course_id)

Get the video lectures from a specific course ID.
$course_id can be any valid course ID from the EDU categories.

=cut

sub get_video_lectures_from_course {
    my ($self, $course_id) = @_;

    ...    # NEEDS WORK!!!
}

=head2 get_video_lectures_from_category($cat_id)

Get the video lectures from a specific category ID.
$cat_id can be any valid category ID from the EDU categories.

=cut

sub get_video_lectures_from_category {
    my ($self, $cat_id) = @_;

    ...    # NEEDS WORK!!!
}

=head2 get_movies($movieID)

Get movie results for C<$movieID>.

=cut

sub get_movies {
    my ($self, $movie_id) = @_;

    ...    # NEEDS WORK!!!
}

=head2 get_video_tops(%opts)

Returns the video tops for a specific feed_id.

=cut

sub get_video_tops {
    my ($self, %opts) = @_;

    ...    # NEEDS WORK!!!
}

sub _get_formats_from_ytdl {
    my ($self, $videoID) = @_;

    ((state $x = $self->proxy_system('youtube-dl', '--version')) == 0)
      || return;

    my $json = $self->proxy_stdout('youtube-dl', '--all-formats', '--dump-single-json',
                                   quotemeta("http://www.youtube.com/watch?v=" . $videoID));

    my @array;
    my $ref = $self->parse_json_string($json) // return;
    if (ref($ref) eq 'HASH' and exists($ref->{formats}) and ref($ref->{formats}) eq 'ARRAY') {
        foreach my $format (@{$ref->{formats}}) {
            if (exists($format->{format_id}) and exists($format->{url})) {

                push @array,
                  {
                    itag => $format->{format_id},
                    url  => $format->{url},
                    type => (
                             (
                              (defined($format->{format_note}) && $format->{format_note} eq 'DASH audio')
                              ? 'audio/'
                              : 'video/'
                             )
                             . $format->{ext}
                            ),
                  };
            }
        }
    }

    return @array;
}

sub _get_pairs_from_info_data {
    my ($self, $content, $videoID) = @_;

    my @array;
    my $i = 0;

    state $x = require URI::Escape;
    foreach my $block (split(/,/, URI::Escape::uri_unescape($content))) {
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

                my @formats = $self->_get_formats_from_ytdl($videoID);
                foreach my $format (@formats) {

                    my $modified;
                    foreach my $ref (@array) {
                        if (defined($ref->{itag}) && ($ref->{itag} eq $format->{itag})) {
                            $ref->{url} = $format->{url};
                            $modified = 1;
                            last;
                        }
                    }

                    if (not $modified) {
                        push @array, $format;
                    }
                }

                last;
            }
        }
        elsif (exists $hash_ref->{hlsvp}) {
            $hash_ref->{itag} = 38;
            $hash_ref->{type} = 'video/ts';
            $hash_ref->{url}  = $hash_ref->{hlsvp};
        }
    }

    return @array;
}

=head2 get_streaming_urls($videoID)

Returns a list of streaming URLs for a videoID.
({itag=>..., url=>...}, {itag=>..., url=>....}, ...)

=cut

sub get_streaming_urls {
    my ($self, $videoID) = @_;

    my $url = ($self->get_video_info_url() . sprintf($self->get_video_info_args(), $videoID));
    my $content = $self->lwp_get($url) // return;
    my @info = $self->_get_pairs_from_info_data($content, $videoID);

    if ($self->get_debug == 2) {
        state $x = require Data::Dump;
        Data::Dump::pp(\@info);
    }

    my $error = $info[0]->{errorcode};
    if (defined($error) && $error == 150) {    # sign in to confirm your age
        my @ytdl_info = $self->_get_formats_from_ytdl($videoID);
        return (@ytdl_info) if @ytdl_info;
    }

    return @info;
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

    state $x = require HTTP::Request;
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

# SOUBROUTINE FACTORY
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

                $name eq 'exec'   ? exec(@args)
              : $name eq 'system' ? system(@args)
              : $name eq 'stdout' ? qx(@args)
              :                     ();
        };
    }
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>

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
