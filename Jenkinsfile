pipeline {
    agent any

    tools {
        maven 'M2'
        jdk 'JDK21'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean compile'
            }
        }

        stage('Tests') {
            steps {
                sh 'mvn test'
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