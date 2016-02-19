
#keep moving if tests fail
set +e

set +x
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

chmod +x ${DIR}/../entryPoints/*.sh
${DIR}/../entryPoints/setup.sh != 0 || exit 1

let RETVAL=0
for FILE in ${DIR}/../entryPoints/[1234567890]*.sh; do
    ${FILE}
    let RETVAL=${RETVAL}+$?
done

${DIR}/../entryPoints/cleanup.sh

exit ${RETVAL}

