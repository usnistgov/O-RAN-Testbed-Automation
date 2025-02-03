pipeline {
    agent none
    stages {
        stage('Testing Ubuntu 20') {
            agent { label 'linux && vagrant && ubuntu24'  }
            steps {
                sh '''
                pwd && hostname
                lsb_release -a
                ls -htrl
                WORK_DIR=$(pwd)
                $WORK_DIR/Additional_Scripts/update_commit_hashes.sh  
                echo y | $WORK_DIR/full_install.sh
                '''
            }
        }

        stage('Testing Ubuntu 22') {
            agent { label 'linux && vagrant && ubuntu22'  }
            steps {
                sh '''
                pwd && hostname
                lsb_release -a
                ls -htrl
                WORK_DIR=$(pwd)
                $WORK_DIR/Additional_Scripts/update_commit_hashes.sh  
                echo y | $WORK_DIR/full_install.sh
                '''
            }
        }

        stage('Testing Ubuntu 24') {
            agent { label 'linux && vagrant && ubuntu24'  }
            steps {
                sh '''
                pwd && hostname
                lsb_release -a
                ls -htrl
                WORK_DIR=$(pwd)
                $WORK_DIR/Additional_Scripts/update_commit_hashes.sh  
                echo y | $WORK_DIR/full_install.sh
                '''
            }
        }
    }
}
