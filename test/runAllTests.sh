
set +x
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

chmod +x ${DIR}/../entryPoints/*.sh
source ${DIR}/../entryPoints/setup.sh

#keep moving if tests fail
set +e

let RETVAL=0
for FILE in ${DIR}/../entryPoints/[1234567890]*.sh; do
    echo Running ${FILE} ...
    ${FILE}
    let RETVAL=${RETVAL}+$?
done

set -e

${DIR}/../entryPoints/cleanup.sh

exit ${RETVAL}

