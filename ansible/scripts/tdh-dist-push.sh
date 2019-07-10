DROP_FILE="/tmp/TDH.tar.gz"
TARGET="/tmp/TDH"
rt=0

if ! [ -e "$DROP_FILE" ]; then
    echo "TDH Drop File not available: $DROP_FILE"
    exit 0
fi

# ensure path exists
( ansible all --become -m file -a "path=${TARGET} state=directory mode=0777" )
rt=$?

echo "tmp path exists: $rt"

# copy tdh-conf
echo "( ansible all -m copy -a \"src=${DROP_FILE} dest=${TARGET}\" )"

( ansible all -m copy -a "src=${DROP_FILE} dest=${TARGET}" )
rt=$?

exit $rt
