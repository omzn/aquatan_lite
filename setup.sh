#!/bin/sh
sudo apt-get -y install libconfig-pit-perl libencode-perl libmoose-perl libnet-twitter-perl libsub-exporter-perl libanyevent-perl libanyevent-http-perl libyaml-perl libcrypt-ssleay-perl libio-socket-ssl-perl libcarp-clan-perl libtest-warn-perl
sudo apt-get -y remove libnet-twitter-perl
sudo LANG=C cpan install Net::Twitter
