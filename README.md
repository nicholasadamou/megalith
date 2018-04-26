Megalith [![Build Status](https://travis-ci.org/nicholasadamou/Megalith.svg?branch=master)](https://travis-ci.org/nicholasadamou/Megalith)
========
![license](https://img.shields.io/apm/l/vim-mode.svg)
[![Say Thanks](https://img.shields.io/badge/say-thanks-ff69b4.svg)](https://saythanks.io/to/NicholasAdamou)

Megalith turns your Raspberry Pi into a functional TorrentBox.

What it Sets Up
------------
* Transmission WebUI
* Samba: Drive Sharing

Requirements
------------

* Two WiFi Cards (e.g. On-board chip + [TL-WN725N](https://www.amazon.com/gp/product/B008IFXQFU/ref=oh_aui_detailpage_o03_s00?ie=UTF8&psc=1))
* Micro-USB to USB 2.0/3.0 converter (e.g. [USB to Micro-USB Charge & Sync Cable](https://www.amazon.com/gp/product/B00SVVY844/ref=oh_aui_detailpage_o05_s00?ie=UTF8&psc=1))
* Portable Battery Bank (e.g. [Anker PowerCore 5000](https://www.amazon.com/gp/product/B01CU1EC6Y/ref=oh_aui_detailpage_o02_s00?ie=UTF8&psc=1))

Older versions may work but aren't regularly tested. Bug reports for older
versions are welcome.

Install
-------

Download, review, then execute the script:

```
git clone git://github.com/NicholasAdamou/Megalith.git && cd Megalith && ./src/setup.sh
```

Follow the on-screen directions.

It should take less than a minute to install.

More Information
-------

* [DIY How To Turn Your Raspberry Pi Into An Always-On Downloading Megalith](http://www.makeuseof.com/tag/how-to-turn-your-raspberry-pi-into-an-always-on-downloading-megalith/)
* [Raspberry Pi seedbox with Transmission and TorGuard](https://www.convalesco.org/articles/2015/06/08/raspberry-pi-seedbox-with-transmission-and-torguard.html)
* [Tip: ExFat HDD With Raspberry Pi](http://miqu.me/blog/2015/01/14/tip-exfat-hdd-with-raspberry-pi/)
* [jq](https://stedolan.github.io/jq/)

License
-------

Megalith is © 2018 Nicholas Adamou.

It is free software, and may be redistributed under the terms specified in the [LICENSE] file.

[LICENSE]: LICENSE
