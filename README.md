## youtube-viewer

A lightweight application for searching and streaming videos from YouTube.

### youtube-viewer

* command-line interface to YouTube.

![youtube-viewer](https://user-images.githubusercontent.com/614513/32416613-c3daa6a6-c254-11e7-9739-ed7bf93d188c.png)

### gtk-youtube-viewer

* GTK2 interface to YouTube.

![gtk-youtube-viewer](https://user-images.githubusercontent.com/614513/32453099-10d14b3e-c324-11e7-942b-13a38c424341.png)

### AVAILABILITY

* Arch Linux (community): https://www.archlinux.org/packages/community/any/youtube-viewer/
* Arch Linux (AUR): https://aur.archlinux.org/packages/gtk-youtube-viewer-git/
* Fedora: https://build.opensuse.org/package/show/home:zhonghuaren/youtube-viewer
* Fresh ports: http://www.freshports.org/multimedia/gtk-youtube-viewer
* Frugalware: http://frugalware.org/packages/203103
* Gentoo: https://packages.gentoo.org/package/net-misc/youtube-viewer
* Puppy Linux: http://www.murga-linux.com/puppy/viewtopic.php?t=76835
* Slackware: http://slackbuilds.org/repository/14.2/multimedia/youtube-viewer/
* Ubuntu/Linux Mint: `sudo add-apt-repository ppa:nilarimogard/webupd8`

### INSTALLATION

To install `youtube-viewer`, run:

```console
    perl Build.PL
    sudo ./Build installdeps
    sudo ./Build install
```

To install `gtk-youtube-viewer` along with `youtube-viewer`, run:

```console
    perl Build.PL --gtk
    sudo ./Build installdeps
    sudo ./Build install
```

### DEPENDENCIES

#### For youtube-viewer:

* [libwww-perl](https://metacpan.org/release/libwww-perl)
* [LWP::Protocol::https](https://metacpan.org/release/LWP-Protocol-https)
* [Data::Dump](https://metacpan.org/release/Data-Dump)
* [JSON](https://metacpan.org/release/JSON)


#### For gtk-youtube-viewer:

* [Gtk2](https://metacpan.org/release/Gtk2)
* [File::ShareDir](https://metacpan.org/release/File-ShareDir)
* \+ the dependencies required by youtube-viewer.


#### Optional dependencies:

* Local cache support: [LWP::UserAgent::Cached](https://metacpan.org/release/LWP-UserAgent-Cached)
* Better STDIN support (+ history): [Term::ReadLine::Gnu](https://metacpan.org/release/Term-ReadLine-Gnu)
* Faster JSON deserialization: [JSON::XS](https://metacpan.org/release/JSON-XS)
* Fixed-width formatting (--fixed-width, -W): [Unicode::LineBreak](https://metacpan.org/release/Unicode-LineBreak) or [Text::CharWidth](https://metacpan.org/release/Text-CharWidth)


### PACKAGING

To package this application, run the following commands:

```console
    perl Build.PL --destdir "/my/package/path" --installdirs vendor [--gtk]
    ./Build test
    ./Build install --install_path script=/usr/bin
```

### REVIEWS

* [EN] YOUTUBE VIEWER: A COMPLETE YOUTUBE CLIENT FOR LINUX [UBUNTU PPA]
    * http://www.webupd8.org/2015/02/youtube-viewer-complete-youtube-client.html
* [EN] A YouTube CLI for Mac
    * http://blog.johnkrauss.com/installing-youtube-viewer/
* [EN] Gtk Youtube Viewer
    * http://puppylinux.org/wikka/GtkYoutubeViewer
* [ES] Este es el mejor cliente de YouTube para Linux
    * http://rootear.com/ubuntu-linux/cliente-youtube-linux
* [ES] YouTube Viewer: busca, reproduce y descarga vídeos de YouTube desde el escritorio
    * http://www.linuxadictos.com/youtube-viewer-busca-reproduce-y-descarga-videos-de-youtube-desde-el-escritorio.html
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
* [TR] Youtube Viewer Nedir? Nasıl Kurulur? (Ubuntu/Linux Mint)
    * http://www.sistemlinux.org/2017/05/youtube-viewer-nedir-nasil-kurulur.html

### VIDEO REVIEWS

* [EN] Gentoo in Review - youtube-viewer CLI client
    * https://www.youtube.com/watch?v=YzN2scO025I
* [EN] Youtube-Viewer -- Search and Play Youtube Video - Linux CLI
    * https://www.youtube.com/watch?v=FnJ67oAxVQ4
* [EN] GTK Youtube Viewer : A Complete Youtube Desktop Client For Linux Mint
    * https://www.youtube.com/watch?v=R5b12tvpe3E
* [EN] GTK-YouTube Viewer for Puppy Linux
    * https://www.youtube.com/watch?v=UH3dPspqtRM

### SUPPORT AND DOCUMENTATION

After installing, you can find documentation with the following commands:

    man youtube-viewer
    perldoc WWW::YoutubeViewer

### LICENSE AND COPYRIGHT

Copyright (C) 2012-2018 Trizen

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
