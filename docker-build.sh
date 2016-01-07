DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

rm -f ${DIR}/r-linux.tar.gz

docker run -v ${DIR}:/io -i nathansoz/centos:4 /io/build2.sh

tar zcvf ${DIR}/r-linux.tar.gz ${DIR}/build-output
