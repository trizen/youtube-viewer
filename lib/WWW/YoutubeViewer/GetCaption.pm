package WWW::YoutubeViewer::GetCaption;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::GetCaption - Save the YouTube closed captions as .srt files for a videoID.

=head1 SYNOPSIS

    use WWW::YoutubeViewer::GetCaption;

    my $yv_cap = WWW::YoutubeViewer::GetCaption->new(%opts);

    print $yv_cap->get_caption($videoID);

=head1 SUBROUTINES/METHODS

=head2 new(%opts)

Options:

=over 4

=item captions => []

The captions data.

 [
  # ...
    {
      baseUrl => "https://...",
      isTranslatable => '...',
      languageCode => "ru",
      name => { simpleText => "Russian" },
      vssId => ".ru",
    },
  # ...
 ]

=item captions_dir => "."

Where to save the closed captions.

=item languages => [qw(en es ro jp)]

Preferred languages. First found is saved and returned.

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = bless {}, $class;
    $self->{captions_dir}  = undef;
    $self->{captions}      = [];
    $self->{auto_captions} = 0;
    $self->{languages}     = [qw(en es)];

    foreach my $key (keys %{$self}) {
        $self->{$key} = delete $opts{$key}
          if exists $opts{$key};
    }

    foreach my $invalid_key (keys %opts) {
        warn "Invalid key: '${invalid_key}'";
    }

    return $self;
}

=head2 find_caption_data()

Find a caption data, based on the preferred languages.

=cut

sub find_caption_data {
    my ($self) = @_;

    my @found;
    foreach my $caption (@{$self->{captions}}) {
        if (defined $caption->{languageCode}) {
            foreach my $i (0 .. $#{$self->{languages}}) {
                my $lang = $self->{languages}[$i];
                if ($caption->{languageCode} =~ /^\Q$lang\E(?:\z|[_-])/i) {

                    # Automatic Speech Recognition
                    my $auto = defined($caption->{kind}) && lc($caption->{kind}) eq 'asr';

                    # Check against auto-generated captions
                    if ($auto and not $self->{auto_captions}) {
                        next;
                    }

                    # Fuzzy match or auto-generated caption
                    if (lc($caption->{languageCode}) ne lc($lang) or $auto) {
                        $found[$i + (($auto ? 2 : 1) * scalar(@{$self->{languages}}))] = $caption;
                    }

                    # Perfect match
                    else {
                        $i == 0 and return $caption;
                        $found[$i] = $caption;
                    }
                }
            }
        }
    }

    foreach my $caption (@found) {
        return $caption if defined($caption);
    }

    return;
}

=head2 sec2time(@seconds)

Convert a list of seconds to .srt times.

=cut

sub sec2time {
    my $self = shift;

    my @out;
    foreach my $sec (map { sprintf '%.3f', $_ } @_) {
        push @out,
          sprintf('%02d:%02d:%02d,%03d', ($sec / 3600 % 24, $sec / 60 % 60, $sec % 60, substr($sec, index($sec, '.') + 1)));
    }

    return @out;
}

=head2 xml2srt($xml_string)

Convert the XML data to SubRip format.

=cut

sub xml2srt {
    my ($self, $xml) = @_;

    require WWW::YoutubeViewer::ParseXML;
    my $hash = eval { WWW::YoutubeViewer::ParseXML::xml2hash($xml) } // return;

    my $sections;
    if (    exists $hash->{transcript}
        and ref($hash->{transcript}) eq 'ARRAY'
        and ref($hash->{transcript}[0]) eq 'HASH'
        and exists $hash->{transcript}[0]{text}) {
        $sections = $hash->{transcript}[0]{text};
    }
    else {
        return;
    }

    require HTML::Entities;

    my @text;
    foreach my $i (0 .. $#{$sections}) {
        my $line = $sections->[$i];

        if (not defined($line->{'-dur'})) {
            if (exists $sections->[$i + 1]) {
                $line->{'-dur'} = $sections->[$i + 1]{'-start'} - $line->{'-start'};
            }
            else {
                $line->{'-dur'} = 10;
            }
        }

        my $start = $line->{'-start'};
        my $end   = $start + $line->{'-dur'};

        push @text,
          join("\n",
               $i + 1,
               join(' --> ', $self->sec2time($start, $end)),
               HTML::Entities::decode_entities($line->{'#text'} // ''));
    }

    return join("\n\n", @text);
}

=head2 get_xml_data($caption_data)

Get the XML content for a given caption data.

=cut

sub get_xml_data {
    my ($self, $url) = @_;

    state $lwp = do {

        require LWP::UserAgent;

        my $agent = LWP::UserAgent->new(
                 timeout   => 30,
                 env_proxy => 1,
                 agent =>
                   'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.101 Safari/537.36',
        );

        require LWP::ConnCache;
        state $cache = LWP::ConnCache->new;
        $cache->total_capacity(undef);    # no limit

        state $accepted_encodings = do {
            require HTTP::Message;
            HTTP::Message::decodable();
        };

        $agent->ssl_opts(Timeout => 30);
        $agent->default_header('Accept-Encoding' => $accepted_encodings);
        $agent->conn_cache($cache);

        $agent;
    };

    my $req = $lwp->get($url);

    if ($req->is_success) {
        return $req->decoded_content;
    }

    return;
}

=head2 save_caption($video_ID)

Save the caption in a .srt file and return its file path.

=cut

sub save_caption {
    my ($self, $video_id) = @_;

    # Find one of the prefered languages
    my $info = $self->find_caption_data() // return;

    require File::Spec;
    my $filename = "${video_id}_$info->{languageCode}.srt";
    my $srt_file = File::Spec->catfile($self->{captions_dir} // File::Spec->tmpdir, $filename);

    # Return the srt file if it already exists
    return $srt_file if (-e $srt_file);

    # Get XML data, then tranform it to SubRip data
    my $xml = $self->get_xml_data($info->{baseUrl} // return) // return;
    my $srt = $self->xml2srt($xml) // return;

    # Write the SubRib data to the $srt_file
    open(my $fh, '>:utf8', $srt_file) or return;
    print {$fh} $srt, "\n";
    close $fh;

    # Return the .srt file path
    return $srt_file;
}

=head1 AUTHOR

Trizen, C<< <echo dHJpemVuQHByb3Rvbm1haWwuY29tCg== | base64 -d> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::GetCaption


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1;    # End of WWW::YoutubeViewer::GetCaption
