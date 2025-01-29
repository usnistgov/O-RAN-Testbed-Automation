pipeline {
    agent { label 'linux && vagrant && ubuntu24'  }

    stages {
        stage('init') {
            steps {                
                sh '''
                pwd && hostname
                lsb_release -a
                '''
            }
        }

        stage('git update') {
            steps {
                git url: 'https://gitlab.nist.gov/gitlab/kyehwanl/o-ran-testbed-init', branch: 'main'
            }
        }

    }
}
