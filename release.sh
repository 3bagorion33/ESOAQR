VERSION="$(cat ESOAQR.txt  | grep "## Version:" | cut -d":" -f2 | xargs)"
rm ESOAQR*.zip
mkdir ESOAQR
mkdir ESOAQR/luaqrcode
cp luaqrcode/qrencode.lua ESOAQR/luaqrcode/qrencode.lua
cp ESOAQR.txt ESOAQR.lua Bindings.xml ESOAQR
7z a -r ESOAQR-$VERSION.zip ESOAQR
rm -rf ESOAQR