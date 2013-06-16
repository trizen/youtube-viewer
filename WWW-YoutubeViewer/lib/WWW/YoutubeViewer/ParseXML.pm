package WWW::YoutubeViewer::ParseXML;

use 5.014;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

=head1 NAME

WWW::YoutubeViewer::ParseXML - Convert XML to a HASH ref structure.

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

Parse XML content and return an HASH ref structure.

Usage:

    use WWW::YoutubeViewer::ParseXML;

    my $hash_ref = WWW::YoutubeViewer::ParseXML::xml2hash($xml_string);

=head1 SUBROUTINES/METHODS

=head2 xml2hash($xml_string)

Parse XML and return an HASH ref.

=cut

sub xml2hash {
    my $xml_ref = {};

    given (shift() // return) {

        my %args = (
                    attr  => '-',
                    text  => '#text',
                    empty => q{},
                    @_
                   );

        my %ctags;
        my $ref = $xml_ref;
        state $inv_chars = q{!"#$@%&'()*+,/;\\<=>?\]\[^`{|}~};
        state $valid_tag = qr{[^\-.\s0-9$inv_chars][^$inv_chars\s]*};

        {
            when (/\G<\?/gc) {
                /\G.*?\?>\s*/gcs or die "Invalid XML!";
                redo
            }
            when (/\G<!--/gc) {
                /\G.*?-->\s*/gcs or die "Comment not closed!";
                redo
            }
            when (/\G<!DOCTYPE\s+/gc) {
                /\G(?>$valid_tag|\s+|".*?"|'.*?')*\[.*?\]>\s*/sgco
                  or /\G.*?>\s*/sgc
                  or die "DOCTYPE not closed!";
                redo
            }
            when (
                m{\G< \s*
                        ($valid_tag)  \s*
                        ((?>$valid_tag\s*=\s*(?>".*?"|'.*?')|\s+)+)? \s*
                        (/)?\s*> \s*
                    }gcsxo
              ) {

                my ($tag, $attrs, $closed) = ($1, $2, $3);

                if (defined $attrs) {
                    push @{$ctags{$tag}}, $ref;

                    $ref =
                        ref $ref eq 'HASH'
                      ? ref $ref->{$tag}
                          ? $ref->{$tag}
                          : (
                           defined $ref->{$tag}
                           ? ($ref->{$tag} = [$ref->{$tag}])
                           : ($ref->{$tag} //= [])
                          )
                      : ref $ref eq 'ARRAY' ? ref $ref->[-1]{$tag}
                          ? $ref->[-1]{$tag}
                          : (
                           defined $ref->[-1]{$tag}
                           ? ($ref->[-1]{$tag} = [$ref->[-1]{$tag}])
                           : ($ref->[-1]{$tag} //= [])
                          )
                      : [];

                    ++$#{$ref} if ref $ref eq 'ARRAY';

                    while (
                        $attrs =~ m{\G
                        ($valid_tag) \s*=\s*
                        (?>
                            "(.*?)"
                                    |
                            '(.*?)'
                        ) \s*
                        }gsxo
                      ) {
                        my ($key, $value) = ($1, $+);
                        $key = join(q{}, $args{attr}, $key);
                        if (ref $ref eq 'ARRAY') {
                            $ref->[-1]{$key} = _decode_entities($value);
                        }
                        elsif (ref $ref eq 'HASH') {
                            $ref->{$key} = $value;
                        }
                    }

                    if (defined $closed) {
                        $ref = pop @{$ctags{$tag}};
                    }

                    if (m{\G<\s*/\s*\Q$tag\E\s*>\s*}gc) {
                        $ref = pop @{$ctags{$tag}};
                    }
                    elsif (m{\G([^<]+)(?=<)}gsc) {
                        if (ref $ref eq 'ARRAY') {
                            $ref->[-1]{$args{text}} .= _decode_entities($1);
                            $ref = pop @{$ctags{$tag}};
                        }
                        elsif (ref $ref eq 'HASH') {
                            $ref->{$args{text}} .= $1;
                            $ref = pop @{$ctags{$tag}};
                        }
                    }
                }
                elsif (defined $closed) {
                    if (ref $ref eq 'ARRAY') {
                        if (exists $ref->[-1]{$tag}) {
                            if (ref $ref->[-1]{$tag} ne 'ARRAY') {
                                $ref->[-1]{$tag} = [$ref->[-1]{$tag}];
                            }
                            push @{$ref->[-1]{$tag}}, $args{empty};
                        }
                        else {
                            $ref->[-1]{$tag} = $args{empty};
                        }
                    }
                }
                else {
                    if (/\G(?=<(?!!))/) {
                        push @{$ctags{$tag}}, $ref;

                        $ref =
                            ref $ref eq 'HASH'
                          ? ref $ref->{$tag}
                              ? $ref->{$tag}
                              : (
                               defined $ref->{$tag}
                               ? ($ref->{$tag} = [$ref->{$tag}])
                               : ($ref->{$tag} //= [])
                              )
                          : ref $ref eq 'ARRAY' ? ref $ref->[-1]{$tag}
                              ? $ref->[-1]{$tag}
                              : (
                               defined $ref->[-1]{$tag}
                               ? ($ref->[-1]{$tag} = [$ref->[-1]{$tag}])
                               : ($ref->[-1]{$tag} //= [])
                              )
                          : [];

                        ++$#{$ref} if ref $ref eq 'ARRAY';
                        redo;
                    }
                    elsif (/\G<!\[CDATA\[(.*?)\]\]>\s*/gcs or /\G([^<]+)(?=<)/gsc) {
                        my ($text) = $1;

                        if (m{\G<\s*/\s*\Q$tag\E\s*>\s*}gc) {
                            if (ref $ref eq 'ARRAY') {
                                if (exists $ref->[-1]{$tag}) {
                                    if (ref $ref->[-1]{$tag} ne 'ARRAY') {
                                        $ref->[-1]{$tag} = [$ref->[-1]{$tag}];
                                    }
                                    push @{$ref->[-1]{$tag}}, $text;
                                }
                                else {
                                    $ref->[-1]{$tag} .= _decode_entities($text);
                                }
                            }
                            elsif (ref $ref eq 'HASH') {
                                $ref->{$tag} .= $text;
                            }
                        }
                        else {
                            push @{$ctags{$tag}}, $ref;

                            $ref =
                                ref $ref eq 'HASH'
                              ? ref $ref->{$tag}
                                  ? $ref->{$tag}
                                  : (
                                   defined $ref->{$tag}
                                   ? ($ref->{$tag} = [$ref->{$tag}])
                                   : ($ref->{$tag} //= [])
                                  )
                              : ref $ref eq 'ARRAY' ? ref $ref->[-1]{$tag}
                                  ? $ref->[-1]{$tag}
                                  : (
                                   defined $ref->[-1]{$tag}
                                   ? ($ref->[-1]{$tag} = [$ref->[-1]{$tag}])
                                   : ($ref->[-1]{$tag} //= [])
                                  )
                              : [];

                            ++$#{$ref} if ref $ref eq 'ARRAY';

                            if (ref $ref eq 'ARRAY') {
                                if (exists $ref->[-1]{$tag}) {
                                    if (ref $ref->[-1]{$tag} ne 'ARRAY') {
                                        $ref->[-1] = [$ref->[-1]{$tag}];
                                    }
                                    push @{$ref->[-1]}, {$args{text} => $text};
                                }
                                else {
                                    $ref->[-1]{$args{text}} .= $text;
                                }
                            }
                            elsif (ref $ref eq 'HASH') {
                                $ref->{$tag} .= $text;
                            }
                        }
                    }
                }

                if (m{\G<\s*/\s*\Q$tag\E\s*>\s*}gc) {
                    ## tag closed - ok
                }

                redo
            }
            when (m{\G<\s*/\s*($valid_tag)\s*>\s*}gco) {
                if (exists $ctags{$1} and @{$ctags{$1}}) {
                    $ref = pop @{$ctags{$1}};
                }
                redo
            }
            when (/\G<!\[CDATA\[(.*?)\]\]>\s*/gcs or m{\G([^<]+)(?=<)}gsc) {
                if (ref $ref eq 'ARRAY') {
                    $ref->[-1]{$args{text}} .= $1;
                }
                elsif (ref $ref eq 'HASH') {
                    $ref->{$args{text}} .= $1;
                }
                redo
            }
            when (/\G\z/gc) {
                break;
            }
            when (/\G\s+/gc) {
                redo
            }
            default {
                die "Syntax error near: --> ", [split(/\n/, substr($_, pos(), 2**6))]->[0], " <--\n";
            }
        }
    }

    return $xml_ref;
}

sub _decode_entities {
    $_[0] =~ s{&amp;}{&}gr =~ s{&quot;}{"}gr =~ s{&apos;}{'}gr =~ s{&gt;}{>}gr =~ s{&lt;}{<}gr;
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::ParseXML


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

1;    # End of WWW::YoutubeViewer::ParseXML
