DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $NUGET_PASSWORD
rm -f ${DIR}/r-linux.tar.gz

docker run -v ${DIR}:/io -i mrsdocker.cloudapp.net:5000/mro /io/build2.sh

tar zcvf ${DIR}/r-linux.tar.gz -C ${DIR} build-output
