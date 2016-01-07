{ ->
    println(commit)
    node('centos7') {
	    checkout(repoConfig)
	    sh './docker-build.sh'
	    sleep(5)
    }
    
}
