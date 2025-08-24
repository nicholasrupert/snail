#!/bin/sh

cp ./snail.pl /usr/local/bin/snail
chmod +x /usr/local/bin/snail
mkdir ~/.config
cp ./.snailrc ~/.config/snailrc
cp ./.snailrc.example ~/.config/snailrc.example
