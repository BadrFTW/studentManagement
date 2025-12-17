pipeline {
    agent any
    tools {
        maven 'M2_HOME'
        jdk 'JAVA_HOME'
    }

    environment {
        DOCKER_IMAGE = 'badrftw/student-management'
        DOCKER_REGISTRY = 'docker.io'
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_TOKEN = credentials('sonarqube-token')
    }

    stages {
        stage('Checkout Git') {
            steps {
                git branch: 'main',
                        url: 'https://github.com/BadrFTW/studentManagement.git',
                        credentialsId: 'github-token'
            }
        }

        stage('Build Maven') {
            steps {
                sh 'mvn clean compile'
            }
        }

        stage('Package JAR') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        // NOUVEAU STAGE SONARQUBE AJOUTÉ ICI

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn clean org.sonarsource.scanner.maven:sonar-maven-plugin:3.9.0.2155:sonar'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
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
                            passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin
                        """
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    sh """
                        docker push ${DOCKER_IMAGE}:${env.BUILD_ID}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts 'target/*.jar'
            }
        }
    }

    post {
        always {
            sh 'docker system prune -f || true'
            echo 'Pipeline terminée'
        }
        success {
            echo '✅ Build Docker réussi!'
            echo "Image: ${DOCKER_IMAGE}:${env.BUILD_ID}"
            echo "Rapport SonarQube: ${SONAR_HOST_URL}/dashboard?id=student-management"
        }
        failure {
            echo '❌ Build échoué!'
        }
    }
}