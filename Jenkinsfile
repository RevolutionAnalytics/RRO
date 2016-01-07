{ ->
    println(commit)
    parallel linux_build: {
	node('centos7') {
	    checkout(repoConfig)
	    sleep(5)
	}
    }
}
