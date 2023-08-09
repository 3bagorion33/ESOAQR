#!/bin/bash

VERSION="$(cat ESOAQR.txt  | grep "## Version:" | cut -d":" -f2 | xargs)"
sed -i "s/RELEASE_TAG:.*/RELEASE_TAG: v$VERSION/" release_config.yml
rm -f ESOAQR*.zip
mkdir ESOAQR
mkdir ESOAQR/luaqrcode
cp luaqrcode/qrencode.lua ESOAQR/luaqrcode/qrencode.lua
cp ESOAQR.txt ESOAQR.lua Bindings.xml ESOAQR
zip -r ESOAQR.zip ESOAQR/*
rm -rf ESOAQR
