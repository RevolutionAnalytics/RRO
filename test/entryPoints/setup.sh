
echo ============================================
echo Setting up
# TODO: Need to have a standard way of getting platform.
# TODO: need to distinguish between different distros of Windows and Linux.
uname=`uname`
case ${uname} in
	Linux)  PLATFORM=Linux ;;
	MINGW*) PLATFORM=Windows;;
	MSYS_NT*) PLATFORM=Windows;;
	WindowsNT*) PLATFORM=Windows;;
	*)
		echo ERROR: Unknown platform: ${uname}
		exit 1
		;;
esac
export PLATFORM
echo PLATFORM=$PLATFORM
case ${PLATFORM} in
	Linux)
		tar zvxf r-linux.tar.gz
		RDIR="${PWD}/build-output/lib64/R"
		export PATH=${RDIR}/bin:${PATH}
		;;
	Windows)
		basedir=$(pwd -W)
        ls ${basedir}
		echo basedir: $basedir
		RDIR="$(pwd -W)/R"
		rm -vrf ${RDIR}
		echo Installing MRO-win.exe to ${RDIR}
		ls ..
		ls $basedir
        cmd.exe /c "${basedir}/MRO-win.exe /Silent /DIR=${RDIR}"
		wait
		export PATH=${RDIR}/bin:${PATH}
		;;
esac

echo End Setup.sh



