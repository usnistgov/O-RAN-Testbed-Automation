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

        stage('running') {
            steps {
                sh '''
                ls -htrl
                WORK_DIR=$(pwd)
                $WORK_DIR/Additional_Scripts/update_commit_hashes.sh  
                echo y | $WORK_DIR/full_install.sh
                '''
            }
        }

    }
}
