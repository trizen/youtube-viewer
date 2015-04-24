## youtube-viewer

### INSTALLATION

To install this application, run the following commands:

```console
    perl Build.PL
    ./Build installdeps
    ./Build test
    sudo ./Build install
```

### PACKAGING

To package this application, run the following commands:

```console
    perl Build.PL --destdir "/my/package/path" --installdirs vendor
    ./Build test
    ./Build install --install_path script=/usr/bin
```

## gtk-youtube-viewer

To install GTK Youtube Viewer, run `Build.PL` with the `--gtk-youtube-viewer` argument.

```console
    perl Build.PL --gtk-youtube-viewer
```

or:
```console
    perl Build.PL --destdir "/my/path" --installdirs vendor --gtk-youtube-viewer
```

### Availability:

* Arch Linux (community): https://www.archlinux.org/packages/community/any/youtube-viewer/
* Arch Linux (AUR): https://aur.archlinux.org/packages/gtk-youtube-viewer/
* Fedora: https://build.opensuse.org/package/show/home:zhonghuaren/youtube-viewer
* Fresh ports: http://www.freshports.org/multimedia/gtk-youtube-viewer
* Frugalware: http://frugalware.org/packages/203103
* Gentoo: https://packages.gentoo.org/package/net-misc/youtube-viewer
* Puppy Linux: http://www.murga-linux.com/puppy/viewtopic.php?t=76835
* Slackware: http://slackbuilds.org/repository/14.1/multimedia/youtube-viewer/
* Ubuntu/Linux Mint: `sudo add-apt-repository ppa:nilarimogard/webupd8`

### SUPPORT AND DOCUMENTATION

After installing, you can find documentation with the following commands:

    man youtube-viewer
    perldoc WWW::YoutubeViewer

### LICENSE AND COPYRIGHT

Copyright (C) 2012-2015 Daniel "Trizen" Șuteu

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
