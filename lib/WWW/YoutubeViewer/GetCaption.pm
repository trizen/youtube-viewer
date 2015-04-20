package WWW::YoutubeViewer::GetCaption;

use utf8;
use 5.014;
use warnings;

=head1 NAME

WWW::YoutubeViewer::GetCaption - Save the YouTube closed captions as .srt files for a videoID.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

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
    lc => "da",
    n  => "Danish",
    t  => 1,
    u  => 'https://...',
    v  => ".da",
  },
  # ...
 ]

=item captions_dir => "."

Where to save the closed captions.

=item languages => [qw(en es ro jp)]

Prefered languages. First found is saved and returned.

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = bless {}, $class;
    $self->{captions_dir} = undef;
    $self->{captions}     = [];
    $self->{languages}    = [qw(en es ro jp)];

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

Find a caption data, based on the prefered languages.

=cut

sub find_caption_data {
    my ($self) = @_;

    my @found;
    foreach my $caption (@{$self->{captions}}) {
        if (exists $caption->{lc} and exists $caption->{u}) {
            foreach my $i (0 .. $#{$self->{languages}}) {
                my $lang = $self->{languages}[$i];
                if (lc($caption->{lc}) eq lc($lang)) {
                    if (exists $caption->{k}) {    # auto-generated
                        $found[$i + @{$self->{languages}}] = $caption;
                    }
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
        my $line  = $sections->[$i];
        my $start = $line->{'-start'};
        my $end   = $start + $line->{'-dur'};

        push @text,
          join("\n", $i + 1, join(' --> ', $self->sec2time($start, $end)), HTML::Entities::decode_entities($line->{'#text'}));
    }

    return join("\n\n", @text);
}

=head2 get_xml_data($caption_data)

Get the XML content for a given caption data.

=cut

sub get_xml_data {
    my ($self, $info) = @_;

    require LWP::UserAgent;
    my $lwp = LWP::UserAgent->new(
          timeout   => 30,
          env_proxy => 1,
          agent => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.101 Safari/537.36',
    );

    my $req = $lwp->get($info->{u});
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
    my $filename = "${video_id}_$info->{lc}.srt";
    my $srt_file = File::Spec->catfile($self->{captions_dir} // File::Spec->tmpdir, $filename);

    # Return the srt file if it already exists
    return $srt_file if (-e $srt_file);

    # Get XML data, then tranform it to SubRip data
    my $xml = $self->get_xml_data($info) // return;
    my $srt = $self->xml2srt($xml)       // return;

    # Write the SubRib data to the $srt_file
    open(my $fh, '>:utf8', $srt_file) or return;
    print {$fh} $srt, "\n";
    close $fh;

    # Return the .srt file path
    return $srt_file;
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::GetCaption


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

1;    # End of WWW::YoutubeViewer::GetCaption
