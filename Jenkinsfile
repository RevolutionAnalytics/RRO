parallel centos_build: {
    node('centos6') {
        checkout([$class: 'GitSCM', 
                  branches: [[name: '*/dev']],
                  doGenerateSubmoduleConfigurations: false,
                  extensions: [], 
                  submoduleCfg: [], 
                  userRemoteConfigs: [[url: 'git://github.com/RevolutionAnalytics/RRO.git']]])
        sh './build.sh'
    }
},
parallel sles11_build: {
    node('suse11') {
        checkout([$class: 'GitSCM', 
                  branches: [[name: '*/dev']],
                  doGenerateSubmoduleConfigurations: false,
                  extensions: [], 
                  submoduleCfg: [], 
                  userRemoteConfigs: [[url: 'git://github.com/RevolutionAnalytics/RRO.git']]])
        sh './build.sh'
    }
},
mac_build: {
    node('mac_os_x') {
        checkout([$class: 'GitSCM', 
                branches: [[name: '*/dev']],
                doGenerateSubmoduleConfigurations: false,
                extensions: [], 
                submoduleCfg: [], 
                userRemoteConfigs: [[url: 'git://github.com/RevolutionAnalytics/RRO.git']]])
        sh 'pushd RRO-src/OSX && ./build-OSX.sh'
    }   
}
