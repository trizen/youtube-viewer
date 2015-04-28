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

### Reviews:

* [EN] YOUTUBE VIEWER: A COMPLETE YOUTUBE CLIENT FOR LINUX [UBUNTU PPA]
    * http://www.webupd8.org/2015/02/youtube-viewer-complete-youtube-client.html
* [EN] A YouTube CLI for Mac
    * http://blog.johnkrauss.com/installing-youtube-viewer/
* [EN] GTK YOUTUBE VIEWER - SEARCHING AND STREAMING VIDEOS FROM YOUTUBE ON LINUX MINT
    * http://mintguide.org/video/334-gtk-youtube-viewer-searching-and-streaming-videos-from-youtube-on-linux-mint.html
* [EN] Gtk Youtube Viewer
    * http://puppylinux.org/wikka/GtkYoutubeViewer
* [GR] YOUTUBE VIEWER: ΤΟ YOUTUBE ΚΥΡΙΟΛΕΚΤΙΚΑ ΣΤΟ DESKTOP ΣΑΣ
    * http://osarena.net/youyubeviewer-to-youtube-olokliro-sto-desktop-sas-se-linux 
* [HU] GTK Youtube Viewer
    * http://ubuntu.hu/node/23555
* [PT] YouTube Viewer: um completo cliente YouTube para Linux
    * http://www.edivaldobrito.com.br/youtube-viewer-um-cliente-completo/
* [RO] youtube-viewer
    * http://stressat.blogspot.ro/2012/01/youtube-viewer.html
* [RU] Установить клиент Youtube Viewer в Linux
    * http://compizomania.blogspot.com/2015/02/youtube-viewer-linux.html
* [RU] Youtube Viewer / GTK Youtube Viewer
    * http://zenway.ru/page/gtk-youtube-viewer 

### Video reviews:

* [EN] Gentoo in Review - youtube-viewer CLI client
    * https://www.youtube.com/watch?v=YzN2scO025I
* [EN] Youtube-Viewer -- Search and Play Youtube Video - Linux CLI
    * https://www.youtube.com/watch?v=FnJ67oAxVQ4
* [EN] GTK Youtube Viewer : A Complete Youtube Desktop Client For Linux Mint
    * https://www.youtube.com/watch?v=R5b12tvpe3E
* [EN] GTK-YouTube Viewer for Puppy Linux
    * https://www.youtube.com/watch?v=UH3dPspqtRM
* [FR] GTK YouTube Viewer - Client YouTube sous Linux
    * https://www.youtube.com/watch?v=6-qbdDUlBqg

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
