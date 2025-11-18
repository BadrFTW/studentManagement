pipeline {
    agent any

    tools {
        maven 'M2_HOME'
        jdk 'JAVA_HOME'
    }

    environment {
        DOCKER_IMAGE = 'badrftw/student-management'
        DOCKER_REGISTRY = 'docker.io'
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

        stage('Package') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Vérifier que le JAR existe
                    sh 'ls -la target/*.jar'

                    // Construire l'image Docker
                    sh "docker build -t ${DOCKER_IMAGE}:${env.BUILD_ID} ."
                    sh "docker tag ${DOCKER_IMAGE}:${env.BUILD_ID} ${DOCKER_IMAGE}:latest"
                }
            }
        }

        stage('Docker Login') {
            steps {
                script {
                    withCredentials([usernamePassword(
                            credentialsId: 'docker-hub-credentials',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh """
                            docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${DOCKER_REGISTRY}
                        """
                    }
                }
            }
        }

        stage('Docker Push') {
            steps {
                script {
                    sh """
                        docker push ${DOCKER_IMAGE}:${env.BUILD_ID}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
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
            // Nettoyage Docker
            script {
                sh 'docker logout || true'
                sh 'docker system prune -f || true'
            }
        }
        success {
            echo 'Build et déploiement Docker réussis!'
            echo "Images disponibles: ${DOCKER_IMAGE}:${env.BUILD_ID} et ${DOCKER_IMAGE}:latest"
        }
        failure {
            echo 'Build échoué!'
        }
    }
}