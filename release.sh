#!/bin/bash

VERSION="$(cat ESOAQR.txt  | grep "## Version:" | cut -d":" -f2 | xargs)"
sed -i "s/RELEASE_TAG:.*/RELEASE_TAG: v$VERSION/" release_config.yml
rm -f ESOAQR*.zip
zip ESOAQR.zip luaqrcode/qrencode.lua ESOAQR.txt ESOAQR.lua Bindings.xml
