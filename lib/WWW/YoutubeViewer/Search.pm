package WWW::YoutubeViewer::Search;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::Search - Search functions for Youtube API v3

=head1 SYNOPSIS

    use WWW::YoutubeViewer;
    my $obj = WWW::YoutubeViewer->new(%opts);
    $obj->search_videos(@keywords);

=head1 SUBROUTINES/METHODS

=cut

sub _make_search_url {
    my ($self, %opts) = @_;

    return $self->_make_feed_url(
        'search',

        topicId    => $self->get_topicId,
        regionCode => $self->get_regionCode,

        maxResults        => $self->get_maxResults,
        order             => $self->get_order,
        publishedAfter    => $self->get_publishedAfter,
        publishedBefore   => $self->get_publishedBefore,
        regionCode        => $self->get_regionCode,
        relevanceLanguage => $self->get_relevanceLanguage,
        safeSearch        => $self->get_safeSearch,
        channelId         => $self->get_channelId,
        channelType       => $self->get_channelType,
        pageToken         => $self->page_token,

        (
         $opts{type} eq 'video'
         ? (
            videoCaption    => $self->get_videoCaption,
            videoCategoryId => $self->get_videoCategoryId,
            videoDefinition => $self->get_videoDefinition,
            videoDimension  => $self->get_videoDimension,
            videoDuration   => $self->get_videoDuration,
            videoEmbeddable => $self->get_videoEmbeddable,
            videoLicense    => $self->get_videoLicense,
            videoSyndicated => $self->get_videoSyndicated,
            videoType       => $self->get_videoType,
            eventType       => $self->get_eventType,
           )
         : ()
        ),

        %opts,
    );

}

=head2 search_for($types,$keywords;\%args)

Search for a list of types (comma-separated).

=cut

sub search_for {
    my ($self, $type, $keywords, $args) = @_;

    if (ref($args) ne 'HASH') {
        $args = {part => 'snippet'};
    }

    if (defined($keywords)) {

        if (ref($keywords) ne 'ARRAY') {
            $keywords = [split ' ', $keywords];
        }

        $keywords = $self->escape_string(join(' ', @{$keywords}));
    }

    my $url = $self->_make_search_url(
                                      type => $type,
                                      q    => $keywords,
                                      %$args,
                                     );

    return $self->_get_results($url);
}

{
    no strict 'refs';

    foreach my $pair (
                      {
                       name => 'videos',
                       type => 'video',
                      },
                      {
                       name => 'playlists',
                       type => 'playlist',
                      },
                      {
                       name => 'channels',
                       type => 'channel',
                      },
                      {
                       name => 'all',
                       type => 'video,channel,playlist',
                      }
      ) {
        *{__PACKAGE__ . '::' . "search_$pair->{name}"} = sub {
            my $self = shift;
            $self->search_for($pair->{type}, @_);
        };
    }
}

=head2 search_videos($keywords;\%args)

Search and return the found video results.

=cut

=head2 search_playlists($keywords;\%args)

Search and return the found playlists.

=cut

=head2 search_channels($keywords;\%args)

Search and return the found channels.

=cut

=head2 search_all($keywords;\%args)

Search and return the results.

=cut

=head2 related_to_videoID($id)

Retrieves a list of videos that are related to the video
that the parameter value identifies. The parameter value must
be set to a YouTube video ID.

=cut

sub related_to_videoID {
    my ($self, $videoID) = @_;

    # Feature deprecated and removed in August 2023
    # return $self->search_for('video', undef, {relatedToVideoId => $id});

    my $watch_next_response = $self->parse_json_string($self->_get_video_next_info($videoID) // return {results => []});
    my $related = eval { $watch_next_response->{contents}{twoColumnWatchNextResults}{secondaryResults}{secondaryResults}{results} } // return {results => []};

    my @results;

    foreach my $entry (@$related) {

        my $info  = $entry->{compactVideoRenderer} // next;
        my $title = $info->{title}{simpleText}     // next;

        my $viewCount = 0;

        if (($info->{viewCountText}{simpleText} // '') =~ /^([\d,]+) views/) {
            $viewCount = ($1 =~ tr/,//dr);
        }
        elsif (($info->{viewCountText}{simpleText} // '') =~ /Recommended for you/i) {
            next;    # filter out recommended videos from related videos
        }

        my $lengthSeconds = 0;

        if (($info->{lengthText}{simpleText} // '') =~ /([\d:]+)/) {
            my $time   = $1;
            my @fields = split(/:/, $time);

            my $seconds = pop(@fields) // 0;
            my $minutes = pop(@fields) // 0;
            my $hours   = pop(@fields) // 0;

            $lengthSeconds = 3600 * $hours + 60 * $minutes + $seconds;
        }

        my $published = 0;
        if (exists $info->{publishedTimeText} and $info->{publishedTimeText}{simpleText} =~ /(\d+)\s+(\w+)\s+ago/) {

            my $quantity = $1;
            my $period   = $2;

            $period =~ s/s\z//;    # make it singural

            my %table = (
                         year   => 31556952,      # seconds in a year
                         month  => 2629743.83,    # seconds in a month
                         week   => 604800,        # seconds in a week
                         day    => 86400,         # seconds in a day
                         hour   => 3600,          # seconds in a hour
                         minute => 60,            # seconds in a minute
                         second => 1,             # seconds in a second
                        );

            if (exists $table{$period}) {
                $published = int(time - $quantity * $table{$period});
            }
            else {
                warn "BUG: cannot parse: <<$quantity $period>>";
            }
        }

        my $length   = $lengthSeconds;
        my $duration = sprintf("PT%dH%dM%dS", int($length / 3600), int($length / 60) % 60, $length % 60);

        my %details = (

            contentDetails => {
                               definition => "hd",
                               dimension  => "2d",
                               duration   => $duration,
                               projection => "rectangular",
                              },

            id   => $info->{videoId},
            kind => "youtube#video",

            snippet => {
                channelId    => $info->{longBylineText}{runs}[0]{navigationEndpoint}{browseEndpoint}{browseId},
                channelTitle => $info->{longBylineText}{runs}[0]{text},
                description  => $info->{accessibility}{accessibilityData}{label},
                title        => $title,

                liveBroadcastContent => (($lengthSeconds == 0) ? 'live' : 'no'),

                published     => $published,
                publishedText => $info->{publishedTimeText}{simpleText},

                statistics => {
                               viewCount => $viewCount,
                              },

                thumbnails => {
                    map {
                        (
                         medium => scalar {
                                           quality => 'medium',
                                           url     => ($_->{url} =~ s{/hqdefault\.jpg}{/mqdefault.jpg}r),
                                           width   => $_->{width},
                                           height  => $_->{height},
                                          }
                        )
                    } @{$info->{thumbnail}{thumbnails}}
                },
            }
        );

        push @results, \%details;
    }

    my %results = (
                   items    => \@results,
                   kind     => "youtube#videoListResponse",
                   pageInfo => {resultsPerPage => scalar(@results), totalResults => scalar(@results)},
                  );

    return scalar {results => \%results};
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Search


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<https://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::Search
