DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker run -v ${DIR}:/io -i -t nathansoz/centos:4 /io/build2.sh
