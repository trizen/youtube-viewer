package WWW::YoutubeViewer::GetCaption;

use strict;

=head1 NAME

WWW::YoutubeViewer::GetCaption - Get the YouTube closed captions (.srt files) for a videoID.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::YoutubeViewer::GetCaption;

    my $yv_cap = WWW::YoutubeViewer::GetCaption->new(%opts);

    print $yv_cap->get_caption($videoID);

=head1 SUBROUTINES/METHODS

=head2 new(%opts)

Options:

=over 4

=item captions_dir => ""

Where to save the closed captions.

=item gcap => ""

Full path to the gcap program.

=item languages => []

Prefered languages.

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = bless {}, $class;
    $self->{captions_dir} = q{.};
    $self->{gcap}         = "/usr/bin/gcap";
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

=head2 get_caption($video_ID)

Return the subtitle file path.

=cut

sub get_caption {
    my ($self, $code) = @_;

    require File::Spec;
    my $main_cwd = File::Spec->rel2abs(File::Spec->curdir());

    if (not -d $self->{captions_dir}) {
        require File::Path;
        File::Path::make_path($self->{captions_dir}) or do {
            warn "[!] Can't create directory $self->{captions_dir}: $!\n";
            return;
        };
    }
    elsif (not -w _) {
        warn "[!] Can't write into directory: $self->{captions_dir}\n";
    }

    chdir $self->{captions_dir};

    my $i = 0;
    my $srt_file;
    {
        foreach my $lang (@{$self->{languages}}) {
            my $name = "${code}_${lang}.srt";
            if (-e $name) {
                $srt_file = File::Spec->rel2abs($name);
                last;
            }
        }

        if (not defined $srt_file) {
            if (opendir(my $dir_h, File::Spec->curdir)) {
                while (defined(my $file = readdir $dir_h)) {
                    if ($file =~ /^\Q$code\E[\w-]*+[.](?i:srt)\z/) {
                        $srt_file = File::Spec->rel2abs($file);
                        last;
                    }
                }
                closedir $dir_h;
            }

            if (not defined $srt_file) {
                system $^X, $self->{gcap}, "http://youtube.com/v/$code";
                if ($? == 0 and not $i++) {
                    redo;
                }
            }
        }
    }

    # Change directory back to the main working directory
    chdir $main_cwd;

    return $srt_file // ();
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::GetCaption


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2013 Trizen.

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
