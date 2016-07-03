parallel centos_build: {
    node('centos6') {
        checkout scm
        sh './build.sh'
        step([$class: 'ArtifactArchiver', artifacts: '**/*.rpm', fingerprint: true])
    }
},
centos5_build: {
    node('centos5') {
        checkout scm
        sh './build.sh'
        step([$class: 'ArtifactArchiver', artifacts: '**/*.rpm', fingerprint: true])
    }
},
sles11_build: {
    node('suse11') {
        checkout scm
        sh './build.sh'
        step([$class: 'ArtifactArchiver', artifacts: '**/*.rpm', fingerprint: true])
    }
},
mac_build: {
    node('mac_os_x') {
        checkout scm
        sh 'pushd RRO-src/OSX && ./build-OSX.sh'
        step([$class: 'ArtifactArchiver', artifacts: '**/*.pkg', fingerprint: true])
    }   
}
