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
                    // Créer le namespace (ignore l'erreur s'il existe déjà)
                    sh "kubectl create namespace ${KUBE_NAMESPACE} || true"
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
                    echo "🚀 Déploiement de SonarQube..."

                    // Appliquer la configuration
                    sh "kubectl apply -f ${K8S_DIR}/sonarqube-deployment.yaml -n ${KUBE_NAMESPACE}"

                    // Augmenter le timeout pour SonarQube (il démarre lentement)
                    timeout(time: 5, unit: 'MINUTES') {
                        waitUntil {
                            try {
                                // Vérifier l'état du pod
                                def podStatus = sh(
                                        script: """
                            kubectl get pods -l app=sonarqube -n ${KUBE_NAMESPACE} -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo 'Pending'
                            """,
                                        returnStdout: true
                                ).trim()

                                if (podStatus == 'Running') {
                                    echo "✅ SonarQube est en cours d'exécution"
                                    return true
                                } else {
                                    echo "⏳ SonarQube n'est pas encore prêt (statut: ${podStatus})"

                                    // Afficher les logs pour diagnostic
                                    if (podStatus == 'Pending' || podStatus == 'ContainerCreating') {
                                        echo "🔍 Vérification des événements..."
                                        sh """
                                kubectl get events -n ${KUBE_NAMESPACE} --field-selector involvedObject.name=sonarqube --sort-by='.lastTimestamp' | tail -3 || true
                                """
                                    }

                                    sleep 30
                                    return false
                                }
                            } catch (Exception e) {
                                echo "⚠️ Erreur de vérification: ${e.message}"
                                sleep 30
                                return false
                            }
                        }
                    }

                    echo "🎉 SonarQube est déployé (peut être en cours d'initialisation)"
                }
            }
        }

        stage('Deploy Spring Application') {
            steps {
                script {
                    echo "🚀 Déploiement de l'application Spring Boot..."

                    // Appliquer la configuration
                    sh "kubectl apply -f ${K8S_DIR}/spring-deployment.yaml -n ${KUBE_NAMESPACE}"

                    // Spring Boot peut être lent (JVM, connexions DB, cache, etc.)

                    }

                    // Vérification finale
                    sh """
                echo "📊 État final:"
                kubectl get pods -l app=spring -n ${KUBE_NAMESPACE} -o wide
                echo "🎉 Application Spring Boot déployée"
            """
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