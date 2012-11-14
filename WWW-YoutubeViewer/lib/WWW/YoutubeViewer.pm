package WWW::YoutubeViewer;

use utf8;
use 5.010;
use strict;

use autouse 'XML::Fast'   => qw{ xml2hash($;%) };
use autouse 'URI::Escape' => qw{ uri_escape uri_escape_utf8 uri_unescape };

=head1 NAME

WWW::YoutubeViewer - A very easy interface to YouTube.

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

    use WWW::YoutubeViewer;

    my $yv_obj = WWW::YoutubeViewer->new();
    ...

=cut

our @feeds_IDs = qw(top_rated top_favorites most_shared most_popular
  most_recent most_discussed most_responded recently_featured on_the_web);

our @movie_IDs = qw(most_popular most_recent trending);

our @categories_IDs = qw(Film Autos Music Animals Sports Travel Games
  People Comedy Entertainment News Howto Education Tech Nonprofit);

our @region_IDs = qw(
  AR AU BR CA CZ FR DE GB HK HU IN IE IL
  IT JP MX NL NZ PL RU ZA KR ES SE TW US
  );

our @feed_methods = qw(newsubscriptionvideos recommendations favorites watch_history);

my %valid_options = (

    # Main options
    v           => {valid => [],                                         default => 2},
    page        => {valid => [qr/^(?!0+\z)\d+\z/],                       default => 1},
    results     => {valid => [1 .. 50],                                  default => 10},
    hd          => {valid => [qw(true)],                                 default => undef},
    caption     => {valid => [qw(true false)],                           default => undef},
    duration    => {valid => [qw(short medium long)],                    default => undef},
    category    => {valid => \@categories_IDs,                           default => undef},
    region      => {valid => \@region_IDs,                               default => undef},
    orderby     => {valid => [qw(relevance published viewCount rating)], default => undef},
    time        => {valid => [qw(today this_week this_month all_time)],  default => undef},
    safe_search => {valid => [qw(strict moderate none)],                 default => undef},

    # Others
    debug       => {valid => [0 .. 2],                        default => 0},
    lwp_timeout => {valid => [qr/^\d+$/],                     default => 60},
    auth_key    => {valid => [qr/^.{5}/],                     default => undef},
    key         => {valid => [qr/^.{5}/],                     default => undef},
    author      => {valid => [qr{^(?:\w+(?:[-.]++\w++)*)\z}], default => undef},
    app_version => {valid => [qr/^\d/],                       default => $VERSION},
    app_name    => {valid => [qr/^./],                        default => 'Youtube Viewer'},
    config_dir  => {valid => [qr/^./],                        default => q{.}},

    categories_language => {valid => [qr/^[a-z]++-\w/], default => 'en-US'},

    # Booleans
    lwp_keep_alive => {valid => [1, 0], default => 1},
    lwp_env_proxy  => {valid => [1, 0], default => 1},
    escape_utf8    => {valid => [1, 0], default => 0},

    # No input value alowed
    categories_url    => {valid => [], default => 'http://gdata.youtube.com/schemas/2007/categories.cat'},
    educategories_url => {valid => [], default => 'http://gdata.youtube.com/schemas/2007/educategories.cat'},
    feeds_url         => {valid => [], default => 'http://gdata.youtube.com/feeds/api'},
    google_login_url  => {valid => [], default => 'https://www.google.com/accounts/ClientLogin'},
    video_info_url    => {valid => [], default => 'http://www.youtube.com/get_video_info'},
    video_info_args   => {valid => [], default => '?video_id=%s&el=detailpage&ps=default&eurl=&gl=US&hl=en'},

    # LWP user agent
    lwp_agent => {valid => [qr/^.{5}/], default => 'Mozilla/5.0 (X11; U; Linux i686; en-US) Chrome/10.0.648.45'},
);

{
    no strict 'refs';

    foreach my $key (keys %valid_options) {

        # Set the 'set_*' subroutines
        *{__PACKAGE__ . '::set_' . $key} = sub {
            my ($self, $value) = @_;
            $self->{$key} =
                $value ~~ $valid_options{$key}{valid}
              ? $value
              : $valid_options{$key}{default};
        };

        # Set the 'get_*' subroutines
        *{__PACKAGE__ . '::get_' . $key} = sub {
            my ($self) = @_;
            return $self->{$key};
        };
    }
}

sub new {
    my ($class, %opts) = @_;

    my $self = bless {}, $class;

    foreach my $key (keys %valid_options) {
        my $code = \&{"set_$key"};
        $self->$code(delete $opts{$key});
    }

    $self->{start_index} =
         delete($opts{start_index})
      || $self->get_start_index()
      || 1;

    foreach my $invalid_key (keys %opts) {
        warn "Invalid key: '${invalid_key}'";
    }

    return $self;
}

sub set_prefer_https {
    my ($self, $bool) = @_;
    $self->{prefer_https} = $bool;

    if ($self->{prefer_https}) {
        eval { require LWP::Protocol::https };
        if ($@) {
            warn "[!] LWP::Protocol::https is not installed!\n";
        }
        foreach my $key (grep /_url\z/, keys %valid_options) {
            my $url = $valid_options{$key}{default};
            $url =~ s{^http://}{https://};
            $self->{$key} = $url;
        }
    }
    else {
        foreach my $key (grep /_url\z/, keys %valid_options) {
            next if $key eq 'google_login_url';
            my $url = $valid_options{$key}{default};
            $url =~ s{^https://}{http://};
            $self->{$key} = $url;
        }
    }

    return 1;
}

sub get_prefer_https {
    my ($self) = @_;
    return $self->{prefer_https};
}

sub get_start_index_var {
    my ($self, $page, $results) = @_;
    return $results * $page - $results + 1;
}

sub get_start_index {
    my ($self) = @_;
    return $self->get_results() * $self->get_page() - $self->get_results() + 1;
}

sub back_page_is_available {
    my ($self, $url) = @_;
    $url =~ /[&?]start-index=(\d+)\b/ or return;
    return $1 > $self->get_results();
}

sub escape_string {
    my ($self, $string) = @_;

    if ($self->get_escape_utf8) {
        utf8::decode($string);
    }

    my $escaped =
      $self->get_escape_utf8()
      ? uri_escape_utf8($string)
      : uri_escape($string);

    return $escaped;
}

sub list_to_gdata_arguments {
    my ($self, %opts) = @_;

    return join(q{&} => map "$_=$opts{$_}", grep defined $opts{$_}, keys %opts);
}

sub default_gdata_arguments {
    my ($self) = @_;
    $self->list_to_gdata_arguments(
                                   'max-results' => $self->get_results,
                                   'start-index' => $self->get_start_index,
                                   'v'           => $self->get_v,
                                  );
}

sub set_lwp_useragent {
    my ($self) = @_;

    binmode *STDOUT, ":encoding(UTF-8)";

    require LWP::UserAgent;
    $self->{lwp} = 'LWP::UserAgent'->new(
                                         keep_alive    => $self->get_lwp_keep_alive,
                                         env_proxy     => $self->get_lwp_env_proxy,
                                         timeout       => $self->get_lwp_timeout,
                                         show_progress => $self->get_debug,
                                         agent         => $self->get_lwp_agent,
                                        );
    return 1;
}

sub login {
    my ($self, $email, $password) = @_;

    $self->set_lwp_useragent()
      unless defined $self->{lwp};

    my $source = join(q{ }, $self->get_app_name(), $self->get_app_version());
    my $resp = $self->{lwp}->post(
                                  $self->get_google_login_url(),
                                  [Content => 'application/x-www-form-urlencoded',
                                   Email   => $email,
                                   Passwd  => $password,
                                   service => 'youtube',
                                   source  => $source,
                                  ],
                                 );

    if ($resp->{_content} =~ /^Auth=(.+)/m) {
        my $auth = $1;
        return $auth;
    }
    else {
        warn "Unable to login: $resp->{_content}\n";
    }
    return;
}

sub prepare_key {
    my ($self) = @_;

    if (defined(my $key = $self->get_key)) {
        return "key=$key";
    }

    return;
}

sub prepare_auth_key {
    my ($self) = @_;

    if (defined(my $auth = $self->get_auth_key)) {
        return "GoogleLogin auth=$auth";
    }

    return;
}

sub _get_lwp_header {
    my ($self) = @_;

    my %lwp_header;
    if (defined $self->get_key) {
        $lwp_header{'X-GData-Key'} = $self->prepare_key;
    }

    if (defined $self->get_auth_key) {
        $lwp_header{'Authorization'} = $self->prepare_auth_key;
    }

    return %lwp_header;
}

sub lwp_get {
    my ($self, $url) = @_;

    $self->set_lwp_useragent()
      unless defined $self->{lwp};

    my %lwp_header = $self->_get_lwp_header();

    my $response = $self->{lwp}->get($url, %lwp_header);

    if ($response->is_success) {
        return $response->content;
    }
    else {
        warn '[' . $response->status_line() . "] Error occured on URL: $url\n";
    }

    return;
}

sub lwp_mirror {
    my ($self, $url, $name) = @_;

    $self->set_lwp_useragent()
      unless defined $self->{lwp};

    my %lwp_header = $self->_get_lwp_header();

    undef $self->{last_lwp_error};
    my $response = $self->{lwp}->mirror($url, $name);

    if ($response->is_success) {
        return 1;
    }
    else {
        warn '[' . ($self->{last_lwp_error} = $response->status_line()) . "] Error occured on URL: $url\n";
    }

    return;
}

sub _get_thumbnail_from_gdata {
    my ($self, $gdata) = @_;
    return (
            ref($gdata->{'media:group'}) eq 'ARRAY'
            ? $gdata->{'media:group'}[0]{'-url'}
            : ref($gdata->{'media:group'}) eq 'HASH' ? ref($gdata->{'media:group'}{'media:thumbnail'}) eq 'ARRAY'
                  ? $gdata->{'media:group'}{'media:thumbnail'}[0]{'-url'}
                  : $gdata->{'media:group'}{'media:thumbnail'}{'-url'}
              : q{}
           );
}

sub get_content {
    my ($self, $url, %opts) = @_;

    my $hash;
    eval { $hash = xml2hash($self->lwp_get($url) // return []) // return [] };

    if ($@) {
        if ($@ =~ /^Can't locate (\S+)\.pm\b/) {
            (my $module = $1) =~ s{[\\/]+}{::}g;
            warn <<"ERROR";
Error: Module $module is required.
To install it, just execute the following command:
    cpan -i $module
ERROR
            return [];
        }
        warn "XML::Fast: Error occured while parsing the XML content of: $url\n";
        return [];
    }

    if ($self->get_debug == 2) {
        require Data::Dump;
        Data::Dump::pp($hash);
    }

    my @results;
    my $index = 0;
    while (
           my $gdata =
             ref $hash->{feed}{entry} eq 'ARRAY' ? $hash->{feed}{entry}[$index]
           : ref $hash->{feed}{entry} eq 'HASH'  ? $hash->{feed}{entry}
           : $hash->{entry}
      ) {
        last unless defined $gdata;

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
             videoID     => $gdata->{'media:group'}{'yt:videoid'},
             title       => $gdata->{'media:group'}{'media:title'}{'#text'},
             name        => $gdata->{'author'}{'name'},
             author      => $gdata->{'author'}{'yt:userId'},
             rating      => $gdata->{'gd:rating'}{'-average'} || 0,
             likes       => $gdata->{'yt:rating'}{'-numLikes'} || 0,
             dislikes    => $gdata->{'yt:rating'}{'-numDislikes'} || 0,
             favorited   => $gdata->{'yt:statistics'}{'-favoriteCount'},
             duration    => $gdata->{'media:group'}{'yt:duration'}{'-seconds'} || 0,
             views       => $gdata->{'yt:statistics'}{'-viewCount'},
             published   => $gdata->{'media:group'}{'yt:uploaded'},
             description => $gdata->{'media:group'}{'media:description'}{'#text'},
             category    => ref $gdata->{'category'} eq 'ARRAY' ? ($gdata->{'category'}[1]{'-label'} || 'Unknown')
             : ($gdata->{'category'}{'-label'} || 'Unknown'),
            };
        ++$index;
        last unless ref $hash->{feed}{entry} eq 'ARRAY';
    }

    return \@results;
}

sub _url_doesnt_contain_arguments {
    my ($self, $url) = @_;
    return 1 if $url =~ m{^https?+://[\w-]++(?>\.[\w-]++)++(?>/[\w-]++)*+/?+$};
    return;
}

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

sub get_videos_from_category {
    my ($self, $cat_id) = @_;

    # http://gdata.youtube.com/feeds/api/videos?category=Comedy&v=2

    unless ($cat_id ~~ \@categories_IDs) {
        warn "Invalid cat ID: $cat_id";
        return;
    }

    my $url = $self->_make_feed_url_with_args('/videos', ('category' => $cat_id));

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

sub get_courses_from_category {
    my ($self, $cat_id) = @_;

    # http://gdata.youtube.com/feeds/api/edu/courses?category=CAT_ID

    my $url = $self->_make_feed_url_with_args('/edu/courses', ('category' => $cat_id));

    return {
            url     => $url,
            results => $self->get_content($url, courses => 1),
           };
}

sub get_video_lectures_from_course {
    my ($self, $course_id) = @_;

    # http://gdata.youtube.com/feeds/api/edu/lectures?course=COURSE_ID

    my $url = $self->_make_feed_url_with_args('/edu/lectures', ('course' => $course_id));

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

sub get_video_lectures_from_category {
    my ($self, $cat_id) = @_;

    # http://gdata.youtube.com/feeds/api/edu/lectures?category=CAT_ID

    my $url = $self->_make_feed_url_with_args('/edu/lectures', ('category' => $cat_id));

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

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
    my @categories = $self->get_categories;

    @categories_IDs = ();
    foreach my $cat (@categories) {
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
    my ($file) = $url =~ m{/([^/]+\.cat)\b};
    my $cat_file = File::Spec->catfile($self->get_config_dir(), $file);

    if (not -f $cat_file) {
        $self->lwp_mirror($url, $cat_file) or return;
    }

    my $hash = xml2hash(
        do {
            open my $fh, '<:encoding(UTF-8)', $cat_file or do { warn "Can't open file '$cat_file' for reading: $!"; return };
            local $/;
            <$fh>;
          }
    );

    my @categories;
    foreach my $cat (@{$hash->{'app:categories'}{'atom:category'}}) {
        next if exists $cat->{'yt:deprecated'};
        push @categories,
          scalar {
                  label   => $cat->{'-label'},
                  term    => $cat->{'-term'},
                  regions => (
                               exists($cat->{'yt:browsable'})
                            && exists($cat->{'yt:browsable'}{'-regions'}) ? [split(q{ }, $cat->{'yt:browsable'}{'-regions'})] : []
                  ),
                 };
    }

    return \@categories;
}

sub get_categories {
    my ($self) = @_;
    return $self->_get_categories($self->get_categories_url());
}

sub get_educategories {
    my ($self) = @_;
    return $self->_get_categories($self->get_educategories_url());
}

sub _get_pairs_from_info_data {
    my ($self, $content) = @_;

    my @array;
    my $i = 0;

    foreach my $block (split(/,/, $content)) {
        foreach my $pair (split(/&/, $block)) {
            $pair =~ s{^url_encoded_fmt_stream_map=(?=\w+=)}{}im;
            my ($key, $value) = split(/=/, $pair);
            next unless defined $key;
            $array[$i]->{$key} = uri_unescape($value);
        }
        ++$i;
    }

    foreach my $hash_ref (@array) {
        if (exists $hash_ref->{url} and exists $hash_ref->{sig}) {
            $hash_ref->{url} .= "&signature=$hash_ref->{sig}";
        }
    }

    return @array;
}

sub get_streaming_urls {
    my ($self, $videoID) = @_;

    my $url = ($self->get_video_info_url() . sprintf($self->get_video_info_args(), $videoID));

    my $content = uri_unescape($self->lwp_get($url) // return);
    my @info = $self->_get_pairs_from_info_data($content);

    if ($self->get_debug == 2) {
        require Data::Dump;
        Data::Dump::pp(\@info);
    }

    if (exists $info[0]{status} and $info[0]->{status} eq q{fail}) {
        warn "\n[!] Error occurred on getting info for video ID: $videoID\n";
        my $reason = $info[0]->{reason};
        $reason =~ tr/+/ /s;
        warn "[*] Reason: $reason\n";
        return;
    }
    return grep { (exists $_->{itag} and exists $_->{url} and exists $_->{type}) or exists $_->{has_cc} } @info;
}

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

sub search_for_playlists {
    my ($self, @keywords) = @_;

    my $keywords = $self->escape_string("@keywords");

    my $url = $self->_make_feed_url_with_args('/playlists/snippets', ('q' => $keywords));

    return {
            url     => $url,
            results => $self->get_content($url, playlists => 1),
           };
}

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

sub search {
    my ($self, @keywords) = @_;

    my $keywords = $self->escape_string("@keywords");
    my $url = $self->get_feeds_url() . '/videos?' . $self->full_gdata_arguments('keywords' => $keywords);

    return {
            url     => $url,
            results => $self->get_content($url),
           };
}

sub send_rating_to_video {
    my ($self, $code, $rating) = @_;
    my $uri = $self->get_feeds_url() . "/videos/$code/ratings";

    return $self->_save(
        'POST', $uri, <<"XML_HEADER"
<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
       xmlns:yt="http://gdata.youtube.com/schemas/2007">
<yt:rating value="$rating"/>
</entry>
XML_HEADER
                       );
}

sub send_comment_to_video {
    my ($self, $code, $comment) = @_;

    my $uri = $self->get_feeds_url() . "/videos/$code/comments";

    return $self->_save(
        'POST', $uri, <<"XML_HEADER"
<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
    xmlns:yt="http://gdata.youtube.com/schemas/2007">
  <content>$comment</content>
</entry>
XML_HEADER
                       );
}

sub subscribe_channel {
    my ($self, $user) = @_;
    my $uri = $self->get_feeds_url() . '/users/default/subscriptions';

    return $self->_save(
        'POST', $uri, <<"XML_HEADER"
<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
  xmlns:yt="http://gdata.youtube.com/schemas/2007">
    <category scheme="http://gdata.youtube.com/schemas/2007/subscriptiontypes.cat"
      term="channel"/>
    <yt:username>$user</yt:username>
</entry>
XML_HEADER
                       );
}

sub favorite_video {
    my ($self, $code) = @_;
    my $uri = $self->get_feeds_url() . '/users/default/favorites';

    return $self->_save(
        'POST', $uri, <<"XML_HEADER"
<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom">
  <id>$code</id>
</entry>
XML_HEADER
                       );
}

sub _request {
    my ($self, $req) = @_;

    $self->set_lwp_useragent()
      unless defined $self->{lwp};

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

    if (defined $self->get_auth_key) {
        $req->header('Authorization' => $self->prepare_auth_key);
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

sub like_video {
    my ($self, $code) = @_;
    return $self->send_rating_to_video($code, 'like');
}

sub dislike_video {
    my ($self, $code) = @_;
    return $self->send_rating_to_video($code, 'dislike');
}

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
                        ['playlists_from_username',        '/users/%s/playlists', {playlists => 1}],
                        ['videos_from_username',           '/users/%s/uploads',   {}],
                        ['favorited_videos_from_username', '/users/%s/favorites', {}],
                        ['videos_from_playlist',           '/playlists/%s',       {}],
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

            if (not defined $self->get_auth_key) {
                warn "\n[!] The method 'get_$method' requires authentication!\n";
                return;
            }

            my $url = $self->prepare_url($self->get_feeds_url() . "/users/$user/$method");
            return {
                    url     => $url,
                    results => $self->get_content($url),
                   };
        };
    }
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>

=head1 SUBROUTINES/METHODS

=over 2

=item new(%opts)

Returns a blessed object.

=item back_page_is_available($url)

Returns true if a previous page is available.

=item default_gdata_arguments()

Returns a string with the default gdata arguments.

=item like_video($videoID)

Like a video. Returns true on success.

=item dislike_video($videoID)

Dislike a video. Returns true on success.

=item escape_string($string)

Escapes a string with URI::Escape and returns it.

=item favorite_video($videoID)

Favorite a video. Returns true on success.

=item full_gdata_arguments()

Returns a string with all the GData arguments.

=item get_app_name()

Returns the application name.

=item get_app_version()

Returns the application version.

=item get_auth_key()

Returns the authentication key.

=item get_author()

Returns the author value.

=item get_caption()

Returns caption value.

=item get_categories()

Returns the YouTube categories.

=item get_educategories()

Returns the EDU YouTube categories.

=item get_categories_language()

Returns the categories language value.

=item get_categories_url()

Returns the YouTube categories URL.

=item get_educategories_url()

Returns the EDU YouTube categories URL.

=item get_category()

Returns the category value.

=item get_video_lectures_from_category($cat_id)

Get the video lectures from a specific category ID.
$cat_id can be any valid category ID from the EDU categories.

=item get_courses_from_category($cat_id)

Get the courses from a specific category ID.
$cat_id can be any valid category ID from the EDU categories.

=item get_video_lectures_from_course($course_id)

Get the video lectures from a specific course ID.
$course_id can be any valid course ID from the EDU categories.

=item get_content($url;%opts)

Return a hash reference containing the URL and RESULTS:
    {url => '...', results => [...]}

Valid %opts:
    playlists => 1, comments => 1, videos => 1, channels => 1

=item get_debug()

Returns the debug value.

=item get_config_dir()

Get the configuration directory.

=item get_duration()

Returns the duration value.

=item get_escape_utf8()

Returns true if escape_utf8 is used.

=item get_favorited_videos_from_username($username)

Returns the latest favorited videos by a username.

=item get_favorites(;$user)

Returns the latest favorited videos for the current logged user.

=item get_feeds_url()

Returns the GData feeds URL.

=item get_google_login_url()

Returns the Google Client login URL.

=item get_hd()

Return the hd value.

=item get_key()

Returns the developer key.

=item get_lwp_agent()

Returns the LWP user agent value.

=item get_lwp_env_proxy()

Returns the env_proxy value.

=item get_lwp_keep_alive()

Returns the keep_alive value.

=item get_lwp_timeout()

Returns the timeout value.

=item get_movies($movieID)

Returns the movie results.

=item get_newsubscriptionvideos(;$user)

Returns the latest videos from subscriptions.

=item get_orderby()

Returns the orderby value.

=item get_page()

Returns the page value.

=item get_playlists_from_username($username)

Returns a list of playlists created by $username.

=item get_recommendations()

Returns a list of videos, recommended for you by Youtube.

=item get_region()

Return the region value.

=item get_related_videos($videoID)

Returns the related videos for a videoID.

=item get_results()

Returns the results value.

=item get_safe_search()

Returns the safe_search value.

=item get_start_index()

Returns the start_index based on the page number and results.

=item get_start_index_var($page, $results)

Return the start_index value for the specific variables.

=item get_streaming_urls($videoID)

Returns a list of streaming URLs for a videoID.
({itag=>...}, {itag=>...}, {has_cc=>...})

=item get_time()

Returns the time value.

=item get_v()

Returns the current version of GData.

=item get_video_comments($videoID)

Returns a list of comments for a videoID.

=item get_video_info($videoID)

Return informations for a videoID.

=item get_video_info_url()

Return the video_info URL.

=item get_video_info_args()

Return the video_info arguments.

=item get_video_tops(%opts)

Returns the video tops for a specific feed_id.
Valid %opts:
    (feed_id=>'...',cat_id=>'...',region_id=>'...',time_id=>'...')

=item get_videos_from_category($cat_id)

Returns a list of videos from a categoryID.

=item get_videos_from_playlist($playlistID)

Returns a list of videos from playlistID.

=item get_videos_from_username($username)

Returns the latest videos uploaded by a username.

=item get_watch_history(;$user)

Returns the latest videos watched on Youtube.

=item list_to_gdata_arguments(%options)

Returns a valid string of arguments, with defined values.

=item set_prefer_https($bool)

Will use https:// protocol instead of http://.

=item get_prefer_https()

Will return the value of prefer_https.

=item login($email, $password)

Returns the authentication on success. undef otherwise.

=item lwp_get($url)

Returns the content for $url.

=item lwp_mirror($url, $output_file)

Downloads the $url into $output_file. Returns true on success.

=item next_page($url;%opts)

Returns the next page of results.
%opts are the same as for I<get_content()>.

=item previous_page($url;%opts)

Returns the previous page of results.
%opts are the same as for I<get_content()>.

=item prepare_auth_key()

Return a string used as header with the auth key.

=item prepare_key()

Returns a string used as header with developer key.

=item prepare_url($url)

Accepts a URL without arguments, appends the
I<default_arguments()> to it, and returns it.

=item search(@keywords)

Search and return the video results.

=item search_channels(@keywords)

Search and return the channel results.

=item search_for_playlists(@keywords)

Search and return the playlist results.

=item send_comment_to_video($videoID, $comment)

Send comment to a video. Returns true on success.

=item send_rating_to_video($videoID, $rating)

Send rating to a video. $rating can be either 'like' or 'dislike'.

=item set_app_name($appname)

Set the application name.

=item set_app_version($version)

Set the application version.

=item set_auth_key($auth_key)

Set the authentication key.

=item set_author($username)

Set the author value.

=item set_config_dir($dir)

Set a configuration dir, where to save the cateogires files.

=item set_caption($value)

Set the caption value. ('true', 'false' or undef)

=item set_categories_language($cat_lang)

Set the categories language. (ex: en-US)

=item set_categories_url()

Can't be changed!

=item set_feeds_url()

Can't be changed!

=item set_google_login_url()

Can't be changed!

=item set_v()

Can't be changed!

=item set_video_info_url()

Can't be changed!

=item set_video_info_args()

Can't be changed!

=item set_educategories_url()

Can't be changed!

=item set_category($cat_id)

Set a category value. (ex: 'Music')

=item set_debug($bool)

Set the debug level. (available: 0, 1, 2)

=item set_duration($duration_id)

Set duration value. (ex: 'long')

=item set_escape_utf8($bool)

If true, it escapes the keywords using uri_escape_utf8.

=item set_hd($value)

Set hd value. $value can be either 'true' or undef.

=item set_key($dev_key)

Set the developer key.

=item set_lwp_agent($agent)

Set a user agent for the LWP module.

=item set_lwp_env_proxy($bool)

Set the env_proxy value for LWP.

=item set_lwp_keep_alive($bool)

Set the keep_alive value for LWP.

=item set_lwp_timeout($sec).

Set the timeout value for LWP, in seconds. Default: 60

=item set_lwp_useragent()

Intialize the LWP::UserAgent module.

=item set_orderby()

Set the order-by value. (ex: published)

=item set_page($i)

Set the page number value.

=item set_region($region_ID)

Set the regionID value for video tops. (ex: JP)

=item set_results([1-50])

Set the number of results per page. (max 50)

=item set_safe_search($value)

Set the safe search sensitivity. (ex: strict)

=item set_time($time_id)

Set the time value. (ex: this_week)

=item subscribe_channel($username)

Subscribe to a user's channel.

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of WWW::YoutubeViewer

__END__
