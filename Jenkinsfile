pipeline {
    agent any

    tools {
        maven 'M2_HOME'
        jdk 'JAVA_HOME'
    }

    environment {
        DOCKER_IMAGE = 'badrftw/student-management'
        DOCKER_REGISTRY = 'docker.io'
        SONAR_HOST_URL = 'http://sonarqube-service:9000'
        SONAR_TOKEN = credentials('sonar-token')
        KUBE_NAMESPACE = 'devops'
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

        stage('Analyse SonarQube') {
            steps {
                script {
                    echo "🔧 Configuration de l'accès à SonarQube..."

                    // Option 1: Essayer d'accéder directement via le service
                    def sonarUrl = "http://sonarqube-service:9000"
                    def sonarNamespace = "devops"  // ou votre namespace

                    try {
                        // Tester l'accès direct
                        sh """
                            timeout 10 kubectl exec -i -n ${sonarNamespace} \
                                \$(kubectl get pods -n ${sonarNamespace} -l app=sonarqube -o jsonpath='{.items[0].metadata.name}') \
                                -- curl -s http://localhost:9000/api/system/status || echo "Test direct échoué"
                        """
                        echo "✅ Accès direct possible"
                    } catch (Exception e) {
                        echo "⚠️ Accès direct impossible, configuration du port-forward..."

                        // Option 2: Configurer un port-forward
                        sh '''
                            # Démarrer le port-forward en arrière-plan
                            kubectl port-forward svc/sonarqube-service -n devops 9000:9000 > /tmp/sonar-portforward.log 2>&1 &
                            echo $! > /tmp/sonar-pid.txt
                            sleep 15  # Attendre que le port-forward soit établi
                        '''

                        sonarUrl = "http://localhost:9000"
                    }

                    // Exécuter l'analyse avec l'URL déterminée
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN_SECURE')]) {
                        sh """
                            mvn sonar:sonar \
                                -Dsonar.projectKey=student-management \
                                -Dsonar.projectName='Student Management' \
                                -Dsonar.host.url=${sonarUrl} \
                                -Dsonar.login=\${SONAR_TOKEN_SECURE} \
                                -Dsonar.java.source=11 \
                                -Dsonar.sourceEncoding=UTF-8
                        """
                    }
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
        // ==================== ÉTAPES KUBERNETES À AJOUTER ====================

        stage('Update Deployment Image') {
            steps {
                script {
                    // Mettre à jour l'image Docker dans le fichier de déploiement Spring Boot
                    sh """
                        sed -i 's|image: .*/student-management:.*|image: ${DOCKER_IMAGE}:${env.BUILD_ID}|' spring-deployment.yaml
                    """
                    echo "✅ Image mise à jour dans spring-deployment.yaml : ${DOCKER_IMAGE}:${env.BUILD_ID}"
                }
            }
        }

        stage('Create Kubernetes Namespace') {
            steps {
                script {
                    // Créer le namespace s'il n'existe pas (mode idempotent)
                    sh """
                        kubectl create namespace ${KUBE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                    """
                    echo "✅ Namespace ${KUBE_NAMESPACE} créé/vérifié"
                }
            }
        }

        stage('Deploy MySQL to Kubernetes') {
            steps {
                script {
                    sh """
                        kubectl apply -f mysql-deployment.yaml -n ${KUBE_NAMESPACE}
                    """
                    echo "✅ MySQL déployé dans ${KUBE_NAMESPACE}"

                    // Attendre que MySQL soit prêt
                    sh """
                        kubectl wait --for=condition=available --timeout=180s deployment/mysql -n ${KUBE_NAMESPACE} || true
                    """
                }
            }
        }

        stage('Deploy SonarQube to Kubernetes') {
            steps {
                script {
                    sh """
                        kubectl apply -f sonarqube-deployment.yaml -n ${KUBE_NAMESPACE}
                    """
                    echo "✅ SonarQube déployé dans ${KUBE_NAMESPACE}"
                }
            }
        }

        stage('Deploy Spring Boot to Kubernetes') {
            steps {
                script {
                    sh """
                        kubectl apply -f spring-deployment.yaml -n ${KUBE_NAMESPACE}
                    """
                    echo "✅ Spring Boot déployé dans ${KUBE_NAMESPACE}"
                }
            }
        }

        stage('Verify Kubernetes Deployments') {
            steps {
                script {
                    sh """
                        echo "=== État des Pods ==="
                        kubectl get pods -n ${KUBE_NAMESPACE} -o wide
                        
                        echo ""
                        echo "=== État des Services ==="
                        kubectl get svc -n ${KUBE_NAMESPACE}
                        
                        echo ""
                        echo "=== Vérification des déploiements ==="
                        kubectl rollout status deployment/spring-app -n ${KUBE_NAMESPACE} --timeout=120s || echo "Vérification du déploiement Spring Boot"
                    """
                }
            }
        }

        stage('Test Spring Boot Application') {
            steps {
                script {
                    sh """
                        # Attendre que l'application soit complètement déployée
                        sleep 20
                        
                        # Obtenir l'URL du service Spring Boot
                        echo "=== Test de l'application Spring Boot ==="
                        APP_URL=\$(minikube service spring-service -n ${KUBE_NAMESPACE} --url 2>/dev/null || echo "")
                        
                        if [ -z "\$APP_URL" ]; then
                            # Alternative: utiliser NodePort directement
                            NODE_IP=\$(minikube ip)
                            NODE_PORT=\$(kubectl get svc spring-service -n ${KUBE_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30080")
                            APP_URL="http://\${NODE_IP}:\${NODE_PORT}"
                        fi
                        
                        echo "URL de test: \$APP_URL"
                        
                        # Tester l'application avec plusieurs endpoints
                        MAX_RETRIES=10
                        RETRY_COUNT=0
                        
                        while [ \$RETRY_COUNT -lt \$MAX_RETRIES ]; do
                            HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" \$APP_URL/actuator/health 2>/dev/null || echo "000")
                            
                            if [ "\$HTTP_CODE" = "200" ] || [ "\$HTTP_CODE" = "404" ]; then
                                echo "✅ Application répond (HTTP Code: \$HTTP_CODE)"
                                break
                            else
                                echo "⏳ Tentative \$(expr \$RETRY_COUNT + 1)/\$MAX_RETRIES - Application non disponible (HTTP Code: \$HTTP_CODE)"
                                RETRY_COUNT=\$((RETRY_COUNT + 1))
                                sleep 10
                            fi
                        done
                        
                        if [ \$RETRY_COUNT -eq \$MAX_RETRIES ]; then
                            echo "⚠️ Application non accessible après \$MAX_RETRIES tentatives"
                        fi
                    """
                }
            }
        }

        stage('Show Access URLs') {
            steps {
                script {
                    sh """
                        echo "=== URLs d'accès ==="
                        echo "Spring Boot:"
                        minikube service spring-service -n ${KUBE_NAMESPACE} --url || echo "  URL non disponible"
                        
                        echo ""
                        echo "SonarQube:"
                        minikube service sonarqube-service -n ${KUBE_NAMESPACE} --url || echo "  URL non disponible"
                        
                        echo ""
                        echo "=== Commandes de vérification ==="
                        echo "kubectl get all -n ${KUBE_NAMESPACE}"
                        echo "kubectl logs -l app=spring-app -n ${KUBE_NAMESPACE} --tail=20"
                    """
                }
            }
        }
        // ==================== FIN DES ÉTAPES KUBERNETES ====================

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