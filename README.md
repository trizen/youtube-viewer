## youtube-viewer

### INSTALLATION

To install this application, run the following commands:

```console
    perl Build.PL
    ./Build
    ./Build test
    sudo ./Build install
```

### PACKAGING

To package this application, run the following commands:

```console
    perl Build.PL --destdir "/my/package/path" --installdirs vendor
    ./Build
    ./Build test
    ./Build install --install_path script=/usr/bin
```

## GTK-YOUTUBE-VIEWER

To install GTK Youtube Viewer, run `Build.PL` with the `--gtk-youtube-viewer` argument.

```console
    perl Build.PL --gtk-youtube-viewer
```

or:
```console
    perl Build.PL --destdir "/my/path" --installdirs vendor --gtk-youtube-viewer
```

### SUPPORT AND DOCUMENTATION

After installing, you can find documentation with the following commands:

    man youtube-viewer
    perldoc WWW::YoutubeViewer

LICENSE AND COPYRIGHT

Copyright (C) 2012-2015 Daniel "Trizen" Șuteu

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
