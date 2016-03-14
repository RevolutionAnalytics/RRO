
set -x

# stop if setup fails
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPOROOT="$(dirname ${DIR})"

chmod +x ${REPOROOT}/test/entryPoints/*.sh
source ${REPOROOT}/test/entryPoints/setup.sh

#keep moving if tests fail
set +e

let RETVAL=0
for FILE in ${REPOROOT}/test/entryPoints/[1234567890]*.sh; do
    echo Running ${FILE} ...
    ${FILE}
    let RETVAL=${RETVAL}+$?
done

set -e

${REPOROOT}/test/entryPoints/cleanup.sh

exit ${RETVAL}

