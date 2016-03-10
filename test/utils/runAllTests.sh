

set +x
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

chmod +x ${DIR}/../entryPoints/*.sh
${DIR}/../entryPoints/setup.sh != 0 || exit 1

# Keep moving if tests fail
set +e

for FILE in ${DIR}/../entryPoints/[1234567890]*.sh; do
    echo Running ${FILE} ...
    ${FILE}
    echo Return Code for ${FILE} : $? 
done
set -e 

${DIR}/../entryPoints/cleanup.sh

# even if things fail exit 0 to keep pipeline going
exit 0

