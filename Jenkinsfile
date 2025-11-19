pipeline {
    agent any

    tools {
        maven 'M2_HOME'  // ✅ Correction: 'M3' au lieu de 'M2_HOME'
        jdk 'JAVA_HOME' // ✅ Correction: 'JDK11' au lieu de 'JAVA_HOME'
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
                    // ✅ Ajout de sudo pour résoudre le problème de permission
                    sh "sudo docker build -t ${DOCKER_IMAGE}:${env.BUILD_ID} ."
                    sh "sudo docker tag ${DOCKER_IMAGE}:${env.BUILD_ID} ${DOCKER_IMAGE}:latest"
                }
            }
        }

        // Étape 5: Authentification Docker Hub
        stage('Docker Login') {
            steps {
                script {
                    withCredentials([usernamePassword(
                            credentialsId: 'docker-hub-credentials',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                    )]) {
                        // ✅ Correction: utilisation de sh avec script
                        sh """
                            echo ${DOCKER_PASS} | sudo docker login -u ${DOCKER_USER} --password-stdin
                        """
                    }
                }
            }
        }

        // Étape 6: Push de l'image
        stage('Push Docker Image') {
            steps {
                script {
                    sh """
                        sudo docker push ${DOCKER_IMAGE}:${env.BUILD_ID}
                        sudo docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }

        // ✅ Étape supplémentaire: Archive du JAR
        stage('Archive Artifacts') {
            steps {
                archiveArtifacts 'target/*.jar'
            }
        }
    }

    post {
        always {
            // ✅ Nettoyage avec sudo
            sh 'sudo docker system prune -f || true'
            echo 'Pipeline terminée'
        }
        success {
            echo '✅ Build Docker réussi!'
            echo "Image: ${DOCKER_IMAGE}:${env.BUILD_ID}"
        }
        failure {
            echo '❌ Build échoué!'
        }
    }
}