#!/bin/sh

sudo apt-get install libconfig-pit-perl libencode-perl libmoose-perl libnet-twitter-perl libsub-exporter-perl libanyevent-perl libanyevent-http-perl libyaml-perl libcrypt-ssleay-perl libio-socket-ssl-perl libcarp-clan-perl libtest-warn-perl
sudo apt-get remove libnet-twitter-perl
echo It will take much time to install Net::Twitter...
sudo LANG=C cpan install Net::Twitter
