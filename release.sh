for f in $(find . -name "*.lua"); do
    if [ $(cat $f | grep logger | grep -v "^ *--" | wc -l) -gt 0 ]; then
        echo -e "Attention! There are loggers in the source code\n"
        read
    fi
done
VERSION="$(cat ESOAQR.txt  | grep "## Version:" | cut -d":" -f2 | xargs)"
rm ESOAQR*.zip
mkdir ESOAQR
mkdir ESOAQR/luaqrcode
cp luaqrcode/qrencode.lua ESOAQR/luaqrcode/qrencode.lua
cp ESOAQR.txt ESOAQR.lua Bindings.xml ESOAQR
7z a -r ESOAQR-$VERSION.zip ESOAQR
rm -rf ESOAQR
