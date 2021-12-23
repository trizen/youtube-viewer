package WWW::YoutubeViewer::Utils;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Utils - Various utils.

=head1 SYNOPSIS

    use WWW::YoutubeViewer::Utils;

    my $yv_utils = WWW::YoutubeViewer::Utils->new(%opts);

    print $yv_utils->format_time(3600);

=head1 SUBROUTINES/METHODS

=head2 new(%opts)

Options:

=over 4

=item thousand_separator => ""

Character used as thousand separator.

=item months => []

Month names for I<format_date()>

=item youtube_url_format => ""

A youtube URL format for sprintf(format, videoID).

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = bless {
                      thousand_separator => q{,},
                      youtube_url_format => 'https://www.youtube.com/watch?v=%s',
                     }, $class;

    $self->{months} = [
        qw(
          Jan Feb Mar
          Apr May Jun
          Jul Aug Sep
          Oct Nov Dec
          )
    ];

    foreach my $key (keys %{$self}) {
        $self->{$key} = delete $opts{$key}
          if exists $opts{$key};
    }

    foreach my $invalid_key (keys %opts) {
        warn "Invalid key: '${invalid_key}'";
    }

    return $self;
}

=head2 extension($type)

Returns the extension format from a given type.

From a string like 'video/webm;+codecs="vp9"', it returns 'webm'.

=cut

sub extension {
    my ($self, $type) = @_;
        $type =~ /\bflv\b/i      ? q{flv}
      : $type =~ /\bopus\b/i     ? q{opus}
      : $type =~ /\b3gpp?\b/i    ? q{3gp}
      : $type =~ m{^video/(\w+)} ? $1
      : $type =~ m{^audio/(\w+)} ? $1
      : $type =~ /\bwebm\b/i     ? q{webm}
      :                            q{mp4};
}

=head2 format_time($sec)

Returns time from seconds.

=cut

sub format_time {
    my ($self, $sec) = @_;
    $sec >= 3600
      ? join q{:}, map { sprintf '%02d', $_ } $sec / 3600 % 24, $sec / 60 % 60, $sec % 60
      : join q{:}, map { sprintf '%02d', $_ } $sec / 60 % 60, $sec % 60;
}

=head2 format_duration($duration)

Return time (01:20:10) from duration (PT1H20M10S).

=cut

# PT5M3S     -> 05:03
# PT1H20M10S -> 01:20:10
# PT16S      -> 00:16

sub format_duration {
    my ($self, $duration) = @_;

    $duration // return 0;
    my ($hour, $min, $sec) = (0, 0, 0);

    $hour = $1 if ($duration =~ /(\d+)H/);
    $min  = $1 if ($duration =~ /(\d+)M/);
    $sec  = $1 if ($duration =~ /(\d+)S/);

    $hour * 60 * 60 + $min * 60 + $sec;
}

=head2 format_date($date)

Return string "04 May 2010" from "2010-05-04T00:25:55.000Z"

=cut

sub format_date {
    my ($self, $date) = @_;

    $date // return undef;

    # 2010-05-04T00:25:55.000Z
    # to: 04 May 2010

    $date =~ s{^
    (?<year>\d{4})
           -
    (?<month>\d{2})
           -
    (?<day>\d{2})
        .*
    }
    {$+{day} $self->{months}[$+{month} - 1] $+{year}}x;

    return $date;
}

=head2 date_to_age($date)

Return the (approximated) age for a given date of the form "2010-05-04T00:25:55.000Z".

=cut

sub date_to_age {
    my ($self, $date) = @_;

    $date // return undef;

    $date =~ m{^
        (?<year>\d{4})
           -
        (?<month>\d{2})
           -
        (?<day>\d{2})
        [a-zA-Z]
        (?<hour>\d{2})
            :
        (?<min>\d{2})
            :
        (?<sec>\d{2})
    }x || return undef;

    my ($sec, $min, $hour, $day, $month, $year) = gmtime(time);

    $year  += 1900;
    $month += 1;

    my %month_days = (
                      1  => 31,
                      2  => 28,
                      3  => 31,
                      4  => 30,
                      5  => 31,
                      6  => 30,
                      7  => 31,
                      8  => 31,
                      9  => 30,
                      10 => 31,
                      11 => 30,
                      12 => 31,
                     );

    my $lambda = sub {

        if ($year == $+{year}) {
            if ($month == $+{month}) {
                if ($day == $+{day}) {
                    if ($hour == $+{hour}) {
                        if ($min == $+{min}) {
                            return join(' ', $sec - $+{sec}, 'seconds');
                        }
                        return join(' ', $min - $+{min}, 'minutes');
                    }
                    return join(' ', $hour - $+{hour}, 'hours');
                }
                return join(' ', $day - $+{day}, 'days');
            }

            if ($month - $+{month} == 1) {
                my $day_diff = $+{day} - $day;
                if ($day_diff > 0 and $day_diff < $month_days{$+{month} + 0}) {
                    return join(' ', $month_days{$+{month} + 0} - $day_diff, 'days');
                }
            }

            return join(' ', $month - $+{month}, 'months');
        }

        if ($year - $+{year} == 1) {
            my $month_diff = $+{month} - $month;
            if ($month_diff > 0) {
                return join(' ', 12 - $month_diff, 'months');
            }
        }

        return join(' ', $year - $+{year}, 'years');
    };

    my $age = $lambda->();

    if ($age =~ /^1\s/) {    # singular mode
        $age =~ s/s\z//;
    }

    return $age;
}

=head2 has_entries($result)

Returns true if a given result has entries.

=cut

sub has_entries {
    my ($self, $result) = @_;

    ref($result) eq 'HASH' or return;

    if (exists $result->{results}) {
        $result = $result->{results};
    }

    ref($result) eq 'HASH' or return;

    ($result->{pageInfo}{totalResults} // 0) > 0;
}

=head2 normalize_filename($title, $fat32safe)

Replace file-unsafe characters and trim spaces.

=cut

sub normalize_filename {
    my ($self, $title, $fat32safe) = @_;

    state $unix_like = $^O =~ /^(?:linux|freebsd|openbsd)\z/i;

    if (not $fat32safe and not $unix_like) {
        $fat32safe = 1;
    }

    if ($fat32safe) {
        $title =~ s/: / - /g;
        $title =~ tr{:"*/?\\|}{;'+%!%%};    # "
        $title =~ tr/<>//d;
    }
    else {
        $title =~ tr{/}{%};
    }

    my $basename = join(q{ }, split(q{ }, $title));
    $basename = substr($basename, 0, 200);    # make sure the filename is not too long
    return $basename;
}

=head2 format_text(%opt)

Formats a text with information from streaming and video info.

The structure of C<%opt> is:

    (
        streaming => HASH,
        info      => HASH,
        text      => STRING,
        escape    => BOOL,
        fat32safe => BOOL,
    )

=cut

sub format_text {
    my ($self, %opt) = @_;

    my $streaming = $opt{streaming};
    my $info      = $opt{info};
    my $text      = $opt{text};
    my $escape    = $opt{escape};
    my $fat32safe = $opt{fat32safe};

    my %special_tokens = (
        ID         => sub { $self->get_video_id($info) },
        AUTHOR     => sub { $self->get_channel_title($info) },
        CHANNELID  => sub { $self->get_channel_id($info) },
        DEFINITION => sub { $self->get_definition($info) },
        DIMENSION  => sub { $self->get_dimension($info) },

        VIEWS       => sub { $self->get_views($info) },
        VIEWS_SHORT => sub { $self->get_views_approx($info) },

        VIDEOS       => sub { $self->set_thousands($self->get_channel_video_count($info)) },
        VIDEOS_SHORT => sub { $self->short_human_number($self->get_channel_video_count($info)) },

        SUBS       => sub { $self->get_channel_subscriber_count($info) },
        SUBS_SHORT => sub { $self->short_human_number($self->get_channel_subscriber_count($info)) },

        ITEMS       => sub { $self->set_thousands($self->get_playlist_item_count($info)) },
        ITEMS_SHORT => sub { $self->short_human_number($self->get_playlist_item_count($info)) },

        LIKES    => sub { $self->get_likes($info) },
        DISLIKES => sub { $self->get_dislikes($info) },

        COMMENTS    => sub { $self->get_comments($info) },
        DURATION    => sub { $self->get_duration($info) },
        TIME        => sub { $self->get_time($info) },
        TITLE       => sub { $self->get_title($info) },
        FTITLE      => sub { $self->normalize_filename($self->get_title($info), $fat32safe) },
        CAPTION     => sub { $self->get_caption($info) },
        PUBLISHED   => sub { $self->get_publication_date($info) },
        AGE         => sub { $self->get_publication_age($info) },
        AGE_SHORT   => sub { $self->get_publication_age_approx($info) },
        DESCRIPTION => sub { $self->get_description($info) },

        RATING => sub {
            my $likes    = $self->get_likes($info)    // 0;
            my $dislikes = $self->get_dislikes($info) // 0;

            my $rating = 0;
            if ($likes + $dislikes > 0) {
                $rating = $likes / ($likes + $dislikes) * 5;
            }

            sprintf('%.2f', $rating);
        },

        (
         defined($streaming)
         ? (
            RESOLUTION => sub { $streaming->{resolution} },
            ITAG       => sub { $streaming->{streaming}{itag} },
            SUB        => sub { $streaming->{srt_file} },
            VIDEO      => sub { $streaming->{streaming}{url} },
            FORMAT     => sub { $self->extension($streaming->{streaming}{type}) },

            AUDIO => sub {
                ref($streaming->{streaming}{__AUDIO__}) eq 'HASH'
                  ? $streaming->{streaming}{__AUDIO__}{url}
                  : q{};
            },

            AOV => sub {
                ref($streaming->{streaming}{__AUDIO__}) eq 'HASH'
                  ? $streaming->{streaming}{__AUDIO__}{url}
                  : $streaming->{streaming}{url};
            },
           )
         : ()
        ),

        URL => sub { sprintf($self->{youtube_url_format}, $self->get_video_id($info)) },
                         );

    my $tokens_re = do {
        local $" = '|';
        qr/\*(@{[keys %special_tokens]})\*/;
    };

    my %special_escapes = (
                           a => "\a",
                           b => "\b",
                           e => "\e",
                           f => "\f",
                           n => "\n",
                           r => "\r",
                           t => "\t",
                          );

    my $escapes_re = do {
        local $" = q{};
        qr/\\([@{[keys %special_escapes]}])/;
    };

    $text =~ s/$escapes_re/$special_escapes{$1}/g;

    $escape
      ? $text =~ s/$tokens_re/\Q${\$special_tokens{$1}()}\E/gr
      : $text =~ s/$tokens_re/${\$special_tokens{$1}()}/gr;
}

=head2 set_thousands($num)

Return the number with thousand separators.

=cut

sub set_thousands {    # ugly, but fast
    my ($self, $n) = @_;

    return 0 unless $n;
    length($n) > 3 or return $n;

    my $l = length($n) - 3;
    my $i = ($l - 1) % 3 + 1;
    my $x = substr($n, 0, $i) . $self->{thousand_separator};

    while ($i < $l) {
        $x .= substr($n, $i, 3) . $self->{thousand_separator};
        $i += 3;
    }

    return $x . substr($n, $i);
}

=head2 get_video_id($info)

Get videoID.

=cut

sub get_video_id {
    my ($self, $info) = @_;

    ref($info->{id}) eq 'HASH'                        ? $info->{id}{videoId}
      : exists($info->{snippet}{resourceId}{videoId}) ? $info->{snippet}{resourceId}{videoId}
      : exists($info->{contentDetails}{videoId})      ? $info->{contentDetails}{videoId}
      : exists($info->{contentDetails}{playlistItem}{resourceId}{videoId})
      ? $info->{contentDetails}{playlistItem}{resourceId}{videoId}
      : exists($info->{contentDetails}{upload}{videoId}) ? $info->{contentDetails}{upload}{videoId}
      : do {
        my $id = $info->{id} // return undef;

        if (length($id) != 11) {
            return undef;
        }

        $id;
      };
}

sub get_playlist_id {
    my ($self, $info) = @_;
    ref($info->{id}) eq 'HASH'
      ? $info->{id}{playlistId}
      : $info->{id};
}

sub get_playlist_item_count {
    my ($self, $info) = @_;
    $info->{contentDetails}{itemCount} // 0;
}

sub get_channel_subscriber_count {
    my ($self, $info) = @_;
    $info->{statistics}{subscriberCount} // 0;
}

sub get_channel_video_count {
    my ($self, $info) = @_;
    $info->{statistics}{videoCount} // 0;
}

sub get_channel_view_count {
    my ($self, $info) = @_;
    $info->{statistics}{viewCount} // 0;
}

sub read_lines_from_file {
    my ($self, $file, $mode) = @_;

    $mode //= '<';

    open(my $fh, $mode, $file) or return;
    chomp(my @ids = <$fh>);
    close $fh;

    my %seen;

    # Keep the most recent ones
    @ids = reverse(@ids);
    @ids = grep { !$seen{$_}++ } @ids;

    return @ids;
}

sub read_channels_from_file {
    my ($self, $file, $mode) = @_;

    $mode //= '<:utf8';

    # Read channels and remove duplicates
    my %channels = map { split(/ /, $_, 2) } $self->read_lines_from_file($file, $mode);

    # Filter valid channels and pair with channel ID with title
    my @channels = map { [$_, $channels{$_}] } grep { defined($channels{$_}) } keys %channels;

    # Sort channels by channel name
    @channels = sort { CORE::fc($a->[1]) cmp CORE::fc($b->[1]) } @channels;

    return @channels;
}

sub get_local_playlist_filenames {
    my ($self, $dir) = @_;
    require Encode;
    grep { -T $_ } sort { CORE::fc($a) cmp CORE::fc($b) } map { Encode::decode_utf8($_) } glob("$dir/*");
}

sub make_local_playlist_filename {
    my ($self, $title, $playlistID) = @_;
    my $basename = $title . ' -- ' . $playlistID . '.txt';
    $basename = $self->normalize_filename($basename);
    return $basename;
}

sub local_playlist_snippet {
    my ($self, $id) = @_;

    my $first_video_id = do {
        open(my $fh, '<', $id) or return;
        chomp(my $video_id = <$fh> // '3Txcjo85lEA');
        close $fh;
        $video_id;
    };

    require File::Basename;
    my $title = File::Basename::basename($id);

    $title =~ s/\.txt\z//;
    $title =~ s/ -- PL[-\w]+\z//;
    $title =~ s/_/ /g;
    $title = ucfirst($title);

    scalar {
            id             => {kind => "youtube#playlist", playlistId => $id},
            contentDetails => {
                               itemCount => scalar $self->read_lines_from_file($id),
                              },
            snippet => {
                        channelId    => "mine",
                        channelTitle => "<local playlist>",
                        description  => $id,
                        thumbnails   => {
                                       default => {
                                                   height => 90,
                                                   url    => "https://i.ytimg.com/vi/$first_video_id/default.jpg",
                                                   width  => 120,
                                                  },
                                       high => {
                                                height => 360,
                                                url    => "https://i.ytimg.com/vi/$first_video_id/hqdefault.jpg",
                                                width  => 480,
                                               },
                                       medium => {
                                                  height => 180,
                                                  url    => "https://i.ytimg.com/vi/$first_video_id/mqdefault.jpg",
                                                  width  => 320,
                                                 },
                                      },
                        title => $title,
                       },
           };
}

sub local_video_snippet {
    my ($self, $id) = @_;
    scalar {id => {kind => "youtube#video", videoId => $id}};
}

sub local_channel_snippet {
    my ($self, $id, $title) = @_;

    scalar {
            id      => {channelId => $id, kind => "youtube#channel"},
            snippet => {
                        channelId    => $id,
                        channelTitle => $title,
                        description  => "<local channel>",
                        title        => $title,
                       },
           };
}

=head2 get_description($info)

Get description.

=cut

sub get_description {
    my ($self, $info) = @_;
    my $desc = $info->{snippet}{description};
    (defined($desc) and $desc =~ /\S/) ? $desc : 'No description available...';
}

=head2 get_title($info)

Get title.

=cut

sub get_title {
    my ($self, $info) = @_;
    $info->{snippet}{title} || $self->get_video_id($info);
}

=head2 get_thumbnail_url($info;$type='default')

Get thumbnail URL.

=cut

sub get_thumbnail_url {
    my ($self, $info, $type) = @_;
    $info->{snippet}{thumbnails}{$type}{url} // $info->{snippet}{thumbnails}{default}{url}
      // $info->{snippet}{thumbnails}{medium}{url} // $info->{snippet}{thumbnails}{high}{url};
}

sub get_channel_title {
    my ($self, $info) = @_;
    $info->{snippet}{channelTitle} // $info->{title} // $self->get_channel_id($info);
}

sub get_id {
    my ($self, $info) = @_;
    $info->{id};
}

sub get_country {
    my ($self, $info) = @_;
    $info->{snippet}{country};
}

sub get_channel_id {
    my ($self, $info) = @_;
    eval      { $info->{snippet}{resourceId}{channelId} }
      // eval { $info->{snippet}{channelId} }
      // eval { ref($info->{id}) eq 'HASH' ? $info->{id}{channelId} : undef } // $info->{id};
}

sub get_category_id {
    my ($self, $info) = @_;
    $info->{snippet}{resourceId}{categoryId} // $info->{snippet}{categoryId};
}

sub get_category_name {
    my ($self, $info) = @_;

    state $categories = {
                         1  => 'Film & Animation',
                         2  => 'Autos & Vehicles',
                         10 => 'Music',
                         15 => 'Pets & Animals',
                         17 => 'Sports',
                         19 => 'Travel & Events',
                         20 => 'Gaming',
                         22 => 'People & Blogs',
                         23 => 'Comedy',
                         24 => 'Entertainment',
                         25 => 'News & Politics',
                         26 => 'Howto & Style',
                         27 => 'Education',
                         28 => 'Science & Technology',
                         29 => 'Nonprofits & Activism',
                        };

    $categories->{$self->get_category_id($info) // ''} // 'Unknown';
}

sub get_publication_date {
    my ($self, $info) = @_;
    $self->format_date($info->{snippet}{publishedAt});
}

sub get_publication_age {
    my ($self, $info) = @_;
    $self->date_to_age($info->{snippet}{publishedAt});
}

sub get_publication_age_approx {
    my ($self, $info) = @_;

    my $age = $self->date_to_age($info->{snippet}{publishedAt}) // return undef;

    if ($age =~ /hour|min|sec/) {
        return "0d";
    }

    if ($age =~ /^(\d+) day/) {
        return "$1d";
    }

    if ($age =~ /^(\d+) month/) {
        return "$1m";
    }

    if ($age =~ /^(\d+) year/) {
        return "$1y";
    }

    return $age;
}

sub get_duration {
    my ($self, $info) = @_;
    $self->format_duration($info->{contentDetails}{duration});
}

sub get_time {
    my ($self, $info) = @_;

    if (($info->{snippet}{liveBroadcastContent} // '') eq 'live') {
        return 'LIVE';
    }

    $self->format_time($self->get_duration($info));
}

sub get_definition {
    my ($self, $info) = @_;
    uc($info->{contentDetails}{definition} // '-');
}

sub get_dimension {
    my ($self, $info) = @_;
    uc($info->{contentDetails}{dimension});
}

sub get_caption {
    my ($self, $info) = @_;
    $info->{contentDetails}{caption};
}

sub get_views {
    my ($self, $info) = @_;
    $info->{statistics}{viewCount} // 0;
}

sub short_human_number {
    my ($self, $int) = @_;

    if ($int < 1000) {
        return $int;
    }

    if ($int >= 10 * 1e9) {    # ten billions
        return sprintf("%dB", int($int / 1e9));
    }

    if ($int >= 1e9) {         # billions
        return sprintf("%.2gB", $int / 1e9);
    }

    if ($int >= 10 * 1e6) {    # ten millions
        return sprintf("%dM", int($int / 1e6));
    }

    if ($int >= 1e6) {         # millions
        return sprintf("%.2gM", $int / 1e6);
    }

    if ($int >= 10 * 1e3) {    # ten thousands
        return sprintf("%dK", int($int / 1e3));
    }

    if ($int >= 1e3) {         # thousands
        return sprintf("%.2gK", $int / 1e3);
    }

    return $int;
}

sub get_views_approx {
    my ($self, $info) = @_;
    my $views = $self->get_views($info);
    $self->short_human_number($views);
}

sub get_likes {
    my ($self, $info) = @_;
    $info->{statistics}{likeCount};
}

sub get_dislikes {
    my ($self, $info) = @_;
    $info->{statistics}{dislikeCount};
}

sub get_rating {
    my ($self, $info) = @_;

    my $likes    = $self->get_likes($info);
    my $dislikes = $self->get_dislikes($info);
    my $views    = $self->get_views($info);

    my $rating = "1.00";

    if (defined($likes) and defined($dislikes)) {
        if ($likes > 0) {
            $rating = sprintf('%.2f', $likes / ($likes + $dislikes) * 4 + 1);
        }
        elsif ($dislikes == 0) {
            $rating = "0.00";
        }
    }
    elsif ($likes and $views and $views >= $likes) {
        ##$rating = sprintf("%.2g%%", $likes / $views * 100);
        $rating = sprintf("%.2g%%", log($likes + 1) / log($views + 1) * 100);    # log(l^(1/log(v))) * 100
    }
    else {
        $rating = "N/A";
    }

    return $rating;
}

sub get_comments {
    my ($self, $info) = @_;
    $info->{statistics}{commentCount};
}

{
    no strict 'refs';
    foreach my $pair (
                      [playlist     => {'youtube#playlist'     => 1}],
                      [channel      => {'youtube#channel'      => 1}],
                      [video        => {'youtube#video'        => 1, 'youtube#playlistItem' => 1}],
                      [subscription => {'youtube#subscription' => 1}],
                      [activity     => {'youtube#activity'     => 1}],
      ) {

        *{__PACKAGE__ . '::' . 'is_' . $pair->[0]} = sub {
            my ($self, $item) = @_;

            if (ref($item->{id}) eq 'HASH') {
                if (exists $pair->[1]{$item->{id}{kind}}) {
                    return 1;
                }
            }
            elsif (exists $item->{kind}) {
                if (exists $pair->[1]{$item->{kind}}) {
                    return 1;
                }
            }

            return;
        };

    }
}

sub is_channelID {
    my ($self, $id) = @_;
    $id || return;
    $id eq 'mine' or $id =~ /^UC[-a-zA-Z0-9_]{22}\z/;
}

sub is_videoID {
    my ($self, $id) = @_;
    $id || return;
    $id =~ /^[-a-zA-Z0-9_]{11}\z/;
}

sub period_to_date {
    my ($self, $amount, $period) = @_;

    state $day   = 60 * 60 * 24;
    state $week  = $day * 7;
    state $month = $day * 30.4368;
    state $year  = $day * 365.242;

    my $time = $amount * (
                            $period =~ /^d/i ? $day
                          : $period =~ /^w/i ? $week
                          : $period =~ /^m/i ? $month
                          : $period =~ /^y/i ? $year
                          : 0
                         );

    my $now  = time;
    my @time = gmtime($now - $time);
    join('-', $time[5] + 1900, sprintf('%02d', $time[4] + 1), sprintf('%02d', $time[3])) . 'T'
      . join(':', sprintf('%02d', $time[2]), sprintf('%02d', $time[1]), sprintf('%02d', $time[0])) . 'Z';
}

sub compare_published_dates {
    my ($self, $info_1, $info_2) = @_;

    state $parse_time_re = qr/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/;

    my @published_dates;

    foreach my $info ($info_1, $info_2) {
        if (exists($info->{contentDetails}) and exists($info->{contentDetails}{videoPublishedAt})) {
            push @published_dates, $info->{contentDetails}{videoPublishedAt};
        }
        else {
            push @published_dates, $info->{snippet}{publishedAt};
        }
    }

    my ($y1, $M1, $d1, $h1, $m1, $s1) = $published_dates[0] =~ $parse_time_re;
    my ($y2, $M2, $d2, $h2, $m2, $s2) = $published_dates[1] =~ $parse_time_re;

    ($y1 <=> $y2) || ($M1 <=> $M2) || ($d1 <=> $d2) || ($h1 <=> $h2) || ($m1 <=> $m2) || ($s1 <=> $s2);
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Utils


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2020 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Utils
