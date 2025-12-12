pipeline {
    agent any

    tools {
        maven 'M2_HOME'
        jdk 'JAVA_HOME'
    }

    environment {
        DOCKER_IMAGE = 'your-dockerhub/student-management'
        KUBE_NAMESPACE = 'devops'
        SONAR_HOST_URL = 'http://sonarqube-service:9000'
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {
        // Étape 1 : Récupération du code
        stage('Git Checkout') {
            steps {
                git branch: 'main',
                        url: 'https://github.com/your-repo/student-management.git',
                        credentialsId: 'github-credentials'
            }
        }

        // Étape 2 : Build Maven
        stage('Maven Build') {
            steps {
                sh 'mvn clean compile'
            }
        }

        // Étape 3 : Analyse SonarQube
        stage('SonarQube Analysis') {
            steps {
                sh """
                    mvn sonar:sonar \
                        -Dsonar.projectKey=student-management \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.login=${SONAR_TOKEN}
                """
            }
        }

        // Étape 4 : Packaging JAR
        stage('Package JAR') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        // Étape 5 : Build Docker Image
        stage('Docker Build') {
            steps {
                script {
                    sh "docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} ."
                    sh "docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest"
                }
            }
        }

        // Étape 6 : Push vers Docker Hub
        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }

        // Étape 7 : Mettre à jour l'image dans spring-deployment.yaml
        stage('Update Kubernetes Image Tag') {
            steps {
                script {
                    // Mettre à jour l'image dans le fichier YAML avec le numéro de build
                    sh """
                        sed -i 's|image: .*|image: ${DOCKER_IMAGE}:${BUILD_NUMBER}|' spring-deployment.yaml
                    """
                }
            }
        }

        // Étape 8 : Déploiement sur Kubernetes
        stage('Kubernetes Deploy') {
            steps {
                script {
                    // Création du namespace si inexistant
                    sh """
                        kubectl create namespace ${KUBE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                    """

                    // Déploiement dans l'ordre
                    sh """
                        kubectl apply -f mysql-deployment.yaml -n ${KUBE_NAMESPACE}
                        kubectl apply -f sonarqube-deployment.yaml -n ${KUBE_NAMESPACE}
                        kubectl apply -f spring-deployment.yaml -n ${KUBE_NAMESPACE}
                    """
                }
            }
        }

        // Étape 9 : Vérification des déploiements
        stage('Verify Deployments') {
            steps {
                script {
                    sh """
                        echo "=== Pods dans le namespace ${KUBE_NAMESPACE} ==="
                        kubectl get pods -n ${KUBE_NAMESPACE} -o wide
                        
                        echo "=== Services ==="
                        kubectl get svc -n ${KUBE_NAMESPACE}
                        
                        echo "=== Vérification des déploiements ==="
                        kubectl rollout status deployment/mysql -n ${KUBE_NAMESPACE} --timeout=120s || true
                        kubectl rollout status deployment/sonarqube -n ${KUBE_NAMESPACE} --timeout=120s || true
                        kubectl rollout status deployment/spring-app -n ${KUBE_NAMESPACE} --timeout=120s
                    """
                }
            }
        }

        // Étape 10 : Test de l'application
        stage('Test Application') {
            steps {
                script {
                    sh """
                        # Attendre que le service soit disponible
                        sleep 10
                        
                        # Récupérer l'URL du service Spring Boot
                        APP_URL=\$(minikube service spring-service -n ${KUBE_NAMESPACE} --url 2>/dev/null || echo "")
                        
                        if [ -z "\$APP_URL" ]; then
                            echo "Service non trouvé, tentative avec NodePort direct"
                            NODE_IP=\$(minikube ip)
                            NODE_PORT=\$(kubectl get svc spring-service -n ${KUBE_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
                            APP_URL="http://\${NODE_IP}:\${NODE_PORT}"
                        fi
                        
                        echo "URL de l'application: \$APP_URL"
                        
                        # Tester l'endpoint
                        curl -f -s -o /dev/null -w "HTTP Code: %{http_code}\n" \${APP_URL}/actuator/health || \
                        curl -f -s -o /dev/null -w "HTTP Code: %{http_code}\n" \${APP_URL}/department/getAllDepartment
                    """
                }
            }
        }
    }

    post {
        always {
            // Nettoyage
            sh 'docker system prune -f || true'
            echo 'Pipeline terminée.'

            // Restaurer le fichier YAML original
            sh '''
                git checkout -- spring-deployment.yaml 2>/dev/null || true
            '''
        }
        success {
            echo '✅ Déploiement réussi !'
            echo "Pour accéder à l'application :"
            sh '''
                echo "Spring Boot: $(minikube service spring-service -n ${KUBE_NAMESPACE} --url || echo 'Service non disponible')"
                echo "SonarQube: $(minikube service sonarqube-service -n ${KUBE_NAMESPACE} --url || echo 'Service non disponible')"
            '''
            echo "Pour vérifier l'état : kubectl get all -n ${KUBE_NAMESPACE}"
        }
        failure {
            echo '❌ Échec du pipeline.'
            echo "Logs des pods en échec :"
            sh '''
                kubectl get pods -n ${KUBE_NAMESPACE} --field-selector=status.phase!=Running -o name | xargs -r kubectl logs -n ${KUBE_NAMESPACE} --tail=20
            '''
        }
    }
}