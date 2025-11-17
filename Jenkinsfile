pipeline {
    agent any

    tools {
        maven 'M2_HOME'
        jdk 'JAVA_HOME'
    }

    stages {
        stage('Checkout') {
            steps {
                git(
                        url: 'https://github.com/BadrFTW/studentManagement.git',
                        branch: 'main',
                        credentialsId: 'github-token',
                        changelog: true,
                        poll: true
                )
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean compile'
            }
        }


            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Package') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts 'target/*.jar'
            }
        }
    }

    post {
        always {
            echo 'Pipeline terminée'
        }
        success {
            echo 'Build réussi!'
        }
        failure {
            echo 'Build échoué!'
        }
    }
}