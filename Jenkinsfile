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
        KUBE_NAMESPACE = 'devops'
        K8S_DIR = 'k8s'  // Dossier contenant vos fichiers YAML
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

        stage('SonarQube Analysis') {
            steps {
                script {
                    withSonarQubeEnv('SonarQube') {
                        sh 'mvn compile'
                        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN_SECURE')]) {
                            sh '''
                        mvn sonar:sonar \
                            -Dsonar.java.binaries=target/classes \
                            -Dsonar.host.url=${SONAR_HOST_URL} \
                            -Dsonar.token=${SONAR_TOKEN_SECURE}
                    '''
                        }
                    }
                }
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



        // ========== STAGES KUBERNETES AVEC FICHIERS YAML ==========

        stage('Create Kubernetes Namespace') {
            steps {
                script {
                    // Créer le namespace devops s'il n'existe pas
                    sh """
                    cat <<EOF | kubectl apply -f -
                    apiVersion: v1
                    kind: Namespace
                    metadata:
                    name: ${KUBE_NAMESPACE}
                    EOF
                    """
                }
            }
        }


        stage('Deploy MySQL') {
            steps {
                script {
                    echo "Déploiement de MySQL..."

                    // Appliquer le YAML
                    sh "kubectl apply -f ${K8S_DIR}/mysql-deployment.yaml -n ${KUBE_NAMESPACE}"

                    // Attendre que MySQL soit prêt
                    sh """
            kubectl wait --for=condition=ready pod -l app=mysql -n ${KUBE_NAMESPACE} --timeout=180s
            """

                    echo "✅ MySQL déployé avec succès"
                }
            }
        }

        stage('Deploy SonarQube') {
            steps {
                script {
                    echo "Déploiement de SonarQube..."

                    // Vérifier rapidement que MySQL est prêt
                    sh """
            kubectl get pods -l app=mysql -n ${KUBE_NAMESPACE} | grep Running || echo "⚠️ Vérifiez l'état de MySQL"
            """

                    // Appliquer le YAML
                    sh "kubectl apply -f ${K8S_DIR}/sonarqube-deployment.yaml -n ${KUBE_NAMESPACE}"

                    // Attendre que SonarQube soit prêt
                    sh """
            kubectl wait --for=condition=ready pod -l app=sonarqube -n ${KUBE_NAMESPACE} --timeout=240s
            """

                    echo "✅ SonarQube déployé avec succès"
                }
            }
        }

        stage('Deploy Spring Application') {
            steps {
                script {
                    echo "Déploiement de l'application Spring..."

                    // Appliquer le YAML
                    sh "kubectl apply -f ${K8S_DIR}/spring-deployment.yaml -n ${KUBE_NAMESPACE}"

                    // Attendre que Spring soit prêt avec timeout plus long
                    sh """
            kubectl wait --for=condition=ready pod -l app=spring -n ${KUBE_NAMESPACE} --timeout=300s
            """

                    // Vérification rapide
                    sh """
            echo "📊 État des pods Spring:"
            kubectl get pods -l app=spring -n ${KUBE_NAMESPACE}
            """

                    echo "✅ Application Spring déployée avec succès"
                }
            }
        }




        stage('Archive Artifacts') {
            steps {
                archiveArtifacts 'target/*.jar'
                // Archivez aussi vos fichiers YAML si nécessaire
                archiveArtifacts "${K8S_DIR}/*.yaml"
            }
        }
    }

    post {
        always {
            sh 'docker system prune -f || true'

            // Nettoyage des ressources temporaires
            script {
                echo "=== Nettoyage ==="
                sh """
                # Nettoyer les images Docker intermédiaires
                docker image prune -f || true
                
                # Afficher l'état final
                echo "\\n=== État final du namespace ${KUBE_NAMESPACE} ==="
                kubectl get all -n ${KUBE_NAMESPACE} || true
                """
            }
        }
        success {
            echo '✅ Build et déploiement Kubernetes réussis!'
            echo "📦 Image Docker: ${DOCKER_IMAGE}:${env.BUILD_ID}"
            echo "📊 Rapport SonarQube: ${SONAR_HOST_URL}/dashboard?id=student-management"
            echo "🌀 Namespace Kubernetes: ${KUBE_NAMESPACE}"

            script {
                // Afficher les informations d'accès
                sh """
                echo "\\n🌐 ACCÈS À L'APPLICATION:"
                echo "1. Via NodePort: http://\$(minikube ip):30080"
                echo "2. Via minikube service: minikube service spring-service -n ${KUBE_NAMESPACE}"
                echo "\\n📋 Commandes utiles:"
                echo "kubectl get pods -n ${KUBE_NAMESPACE}"
                echo "kubectl logs -l app=spring-app -n ${KUBE_NAMESPACE}"
                echo "kubectl describe svc spring-service -n ${KUBE_NAMESPACE}"
                """
            }
        }
        failure {
            echo '❌ Pipeline échouée!'

            script {
                // Aide au débogage en cas d'échec
                sh """
                echo "\\n🔍 DEBUG:"
                echo "Derniers événements du namespace:"
                kubectl get events -n ${KUBE_NAMESPACE} --sort-by='.lastTimestamp' | tail -20 || true
                
                echo "\\nLogs des pods Spring Boot:"
                kubectl logs -l app=spring-app -n ${KUBE_NAMESPACE} --tail=50 || true
                
                echo "\\nLogs MySQL:"
                kubectl logs -l app=mysql -n ${KUBE_NAMESPACE} --tail=20 || true
                """
            }
        }
        cleanup {
            // Nettoyage optionnel
            echo '🧹 Nettoyage des ressources...'
        }
    }
}