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
        SONAR_TOKEN = credentials('sonar-token')
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

        stage('Déployer MySQL sur Kubernetes') {
            steps {
                sh """
                
                 kubectl apply -f k8s/mysql-deployment.yaml -n ${KUBE_NAMESPACE}
        
                """
            }
        }
        stage('Déployer Spring Boot sur Kubernetes') {
            steps {
                sh """
                sed -i 's|<dockerhub-user>/spring-app:1.0|${DOCKER_IMAGE}|g' kubernetes/spring-deployment.yaml
              
                kubectl apply -f k8s/spring-deployment.yaml -n ${KUBE_NAMESPACE}
                
                """
            }
        }
        stage('Déployer sonar sur Kubernetes') {
            steps {
                sh """
                
                 kubectl apply -f k8s/sonarqube-deployment.yaml -n ${KUBE_NAMESPACE}
        
                """
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