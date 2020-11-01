## youtube-viewer

A lightweight application for searching and playing videos from YouTube.

### youtube-viewer

* command-line interface to YouTube.

![youtube-viewer](https://user-images.githubusercontent.com/614513/97738550-6d0faf00-1ad6-11eb-84ec-d37f28073d9d.png)

### gtk-youtube-viewer

* GTK+ interface to YouTube.

![gtk-youtube-viewer](https://user-images.githubusercontent.com/614513/73046878-5cae1200-3e7c-11ea-87ac-9d769831026e.png)

### AVAILABILITY

* Arch Linux (community): https://www.archlinux.org/packages/community/any/youtube-viewer/
* Arch Linux (AUR): https://aur.archlinux.org/packages/gtk-youtube-viewer-git/
* Fedora: https://copr.fedorainfracloud.org/coprs/itsuki/Youtube-viewer/
* FreeBSD: http://www.freshports.org/multimedia/gtk-youtube-viewer
* Frugalware: http://frugalware.org/packages/203103
* Gentoo: https://packages.gentoo.org/package/net-misc/youtube-viewer
* OSX: `brew install thekevjames/youtube-viewer/youtube-viewer`
* Puppy Linux: http://www.murga-linux.com/puppy/viewtopic.php?t=76835
* Slackware: http://slackbuilds.org/repository/14.2/multimedia/youtube-viewer/
* Solus: `sudo eopkg it youtube-viewer`
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

Replace `--gtk` with `--gtk2` or `--gtk3` to install only the Gtk2 or Gtk3 version.


### TRY

For trying the latest commit of `youtube-viewer`, without installing it, execute the following commands:

```console
    cd /tmp
    wget https://github.com/trizen/youtube-viewer/archive/master.zip -O youtube-viewer-master.zip
    unzip -n youtube-viewer-master.zip
    cd youtube-viewer-master/bin
    perl -pi -ne 's{DEVEL = 0}{DEVEL = 1}' {gtk2-,gtk3-,}youtube-viewer
    ./youtube-viewer
```


### DEPENDENCIES

#### For youtube-viewer:

* [libwww-perl](https://metacpan.org/release/libwww-perl)
* [LWP::Protocol::https](https://metacpan.org/release/LWP-Protocol-https)
* [Data::Dump](https://metacpan.org/release/Data-Dump)
* [JSON](https://metacpan.org/release/JSON)


#### For gtk2-youtube-viewer:

* [Gtk2](https://metacpan.org/release/Gtk2)
* [File::ShareDir](https://metacpan.org/release/File-ShareDir)
* \+ the dependencies required by youtube-viewer.

#### For gtk3-youtube-viewer:

* [Gtk3](https://metacpan.org/release/Gtk3)
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

### LOGGING IN

Starting with version 3.7.4, youtube-viewer provides the `~/.config/youtube-viewer/api.json` file, which allows setting an YouTube API key and the client ID/SECRET values:

```json
{
    "key":           "API_KEY",
    "client_id":     "CLIENT_ID",
    "client_secret": "CLIENT_SECRET"
}
```

* Prerequisite: you must create a Google Platform project. Following the below steps should prompt you to create one if you do not already have one.
* Enable the YouTube Data v3 API on your project: [navigate here](https://console.developers.google.com/apis/library/youtube.googleapis.com) and click "Enable" (if you see a blue "Manage" button, it's already enabled).
* Replace `API_KEY` with your YouTube API key. Create a new key [here](https://console.developers.google.com/apis/credentials) by clicking on "Create Credentials" > "API Key".
* Optionally, in order to log in, replace `CLIENT_ID` and `CLIENT_SECRET` with your native client ID and client secret values, by creating a new OAuth 2.0 Client ID [here](https://console.developers.google.com/apis/api/youtube.googleapis.com/credentials): click "Create Credentials" > "OAuth client ID", then select "Desktop app".

See also: [#285](https://github.com/trizen/youtube-viewer/issues/285), [#308](https://github.com/trizen/youtube-viewer/issues/308).

### STRAW-VIEWER

[straw-viewer](https://github.com/trizen/straw-viewer) is a fork of `youtube-viewer`, which uses the [API](https://github.com/omarroth/invidious/wiki/API) of [invidio.us](https://invidio.us/), and thus it does not require an YouTube API key.

### PIPE-VIEWER

[pipe-viewer](https://github.com/trizen/pipe-viewer) is an experimental fork of `straw-viewer`, which parses the YouTube website directly.

### REVIEWS

* [EN] YOUTUBE VIEWER: A COMPLETE YOUTUBE CLIENT FOR LINUX [UBUNTU PPA]
    * http://www.webupd8.org/2015/02/youtube-viewer-complete-youtube-client.html
* [EN] YOUTUBE-VIEWER – ALTERNATIVE WAY TO INTERACT WITH YOUTUBE
    * https://www.ossblog.org/youtube-viewer-alternative-way-watch-youtube/
* [EN] A YouTube CLI for Mac
    * https://blog.johnkrauss.com/installing-youtube-viewer/
* [EN] Gtk Youtube Viewer (for lots of pups)
    * http://www.murga-linux.com/puppy/viewtopic.php?t=76835
* [ES] Este es el mejor cliente de YouTube para Linux
    * https://rootear.com/ubuntu-linux/cliente-youtube-linux
* [ES] YouTube Viewer: busca, reproduce y descarga vídeos de YouTube desde el escritorio
    * https://www.linuxadictos.com/youtube-viewer-busca-reproduce-y-descarga-videos-de-youtube-desde-el-escritorio.html
* [HU] GTK Youtube Viewer
    * https://linuxmint.hu/blog/2018/09/gtk-youtube-viewer
* [JP] GTK Youtube Viewer 試してみた
    * https://tamahamster.blogspot.com/2016/06/type-p-debiandog-gtk-youtube-viewer.html
* [PT] YouTube Viewer: um completo cliente YouTube para Linux
    * https://www.edivaldobrito.com.br/youtube-viewer-um-cliente-completo/
* [RO] youtube-viewer
    * https://stressat.blogspot.com/2012/01/youtube-viewer.html
* [RU] Установить клиент Youtube Viewer в Linux
    * http://compizomania.blogspot.com/2015/02/youtube-viewer-linux.html
* [RU] Youtube Viewer / GTK Youtube Viewer
    * https://zenway.ru/page/gtk-youtube-viewer
* [TR] Youtube Viewer Nedir? Nasıl Kurulur? (Ubuntu/Linux Mint)
    * https://www.sistemlinux.org/2017/05/youtube-viewer-nedir-nasil-kurulur.html

### VIDEO REVIEWS

* [EN] Youtube-Viewer -- Search and Play Youtube Video - Linux CLI
    * https://www.youtube.com/watch?v=FnJ67oAxVQ4
* [EN] youtube-viewer - Watch, Read and Post Youtube Comments - Linux CLI
    * https://www.youtube.com/watch?v=3CNRRdyFwsY
* [EN] Gentoo in Review - youtube-viewer CLI client
    * https://www.youtube.com/watch?v=YzN2scO025I
* [EN] GTK Youtube Viewer : A Complete Youtube Desktop Client For Linux Mint
    * https://www.youtube.com/watch?v=R5b12tvpe3E
* [EN] GTK-YouTube Viewer for Puppy Linux
    * https://www.youtube.com/watch?v=UH3dPspqtRM

### SUPPORT AND DOCUMENTATION

After installing, you can find documentation with the following commands:

    man youtube-viewer
    perldoc WWW::YoutubeViewer

### LICENSE AND COPYRIGHT

Copyright (C) 2012-2020 Trizen

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
