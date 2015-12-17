parallel centos_build: {
    node('centos') {
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
},
windows_build: {
    node('windows') {
        checkout([$class: 'GitSCM', 
                branches: [[name: '*/dev']],
                doGenerateSubmoduleConfigurations: false,
                extensions: [], 
                submoduleCfg: [], 
                userRemoteConfigs: [[url: 'git://github.com/RevolutionAnalytics/RRO.git']]])
        bat 'build.bat'
    }   
}
