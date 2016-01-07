{ ->
    println(commit)
    node('centos7') {
	checkout(repoConfig)
	sh './docker-build.sh'
	step([$class: 'ArtifactArchiver', artifacts: '**/r-linux.tar.gz', fingerprint: true])
    }
    
}
