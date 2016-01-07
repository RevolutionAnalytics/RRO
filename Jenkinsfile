{ ->
    println(commit)
    node('centos7') {
        deleteDir()
	checkout(repoConfig)
	sh './docker-build.sh'
	step([$class: 'ArtifactArchiver', artifacts: '**/r-linux.tar.gz', fingerprint: true])
    }
    
}
