
echo ============================================
echo Setting up
# TODO: Need to have a standard way of getting platform.
# TODO: need to distinguish between different distros of Windows and Linux.
uname=`uname`
case ${uname} in
	Linux)  PLATFORM=Linux ;;
	MINGW*) PLATFORM=Windows;;
	MSYS_NT*) PLATFORM=Windows;;
	*)
		echo ERROR: Unknown platform: ${uname}
		exit 1
		;;
esac

echo PLATFORM=$PLATFORM
case ${PLATFORM} in
	Linux)
		exit 0
		tar zvxf r-linux.tar.gz
		RDIR="${PWD}/build-output/lib64/R"
		export PATH=${RDIR}/bin:${PATH}
		;;
	Windows)
		installDir="${PWD}/MRO-win" 
		rm -rf ${installDir}
		echo Installing MRO-win.exe to ${installDir}
        MRO-win.exe /Silent /DIR="${installDir}"
		wait
		RDIR="${PWD}/MRO-win"
		export PATH=${RDIR}/bin:${PATH}
		;;
esac

echo PATH=${PATH}
			


