parallel centos_build: {
    node('centos7') {
        checkout scm
        sh './docker-build.sh'
        step([$class: 'ArtifactArchiver', artifacts: '**/r-*.tar.gz', fingerprint: true])
    }
}
