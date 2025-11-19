pipeline {
    agent any
    tools {
        maven 'M2'
        jdk 'JAVA_HOME'
    }

    environment {
        DOCKER_IMAGE = 'badrftw/student-management'
        DOCKER_REGISTRY = 'docker.io'
    }

    stages {
        // Étape 1: Récupération du code
        stage('Checkout Git') {
            steps {
                git branch: 'main',
                        url: 'https://github.com/BadrFTW/studentManagement.git',
                        credentialsId: 'github-token'
            }
        }

        // Étape 2: Compilation
        stage('Build Maven') {
            steps {
                sh 'mvn clean compile'
            }
        }

        // Étape 3: Packaging
        stage('Package JAR') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        // Étape 4: Construction image Docker
        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKER_IMAGE}:${BUILD_ID} ."
                    sh "docker tag ${DOCKER_IMAGE}:${BUILD_ID} ${DOCKER_IMAGE}:latest"
                }
            }
        }

        // Étape 5: Authentification Docker Hub
        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                        credentialsId: 'docker-hub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh "echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin"
                }
            }
        }

        // Étape 6: Push de l'image
        stage('Push Docker Image') {
            steps {
                sh """
                    docker push ${DOCKER_IMAGE}:${BUILD_ID}
                    docker push ${DOCKER_IMAGE}:latest
                """
            }
        }
    }

    post {
        always {
            sh 'docker system prune -f'
        }
        success {
            echo '✅ Build Docker réussi!'
        }
    }
}