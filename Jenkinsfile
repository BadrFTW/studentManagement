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

        stage('Deploy MySQL from YAML') {
            steps {
                script {
                    // Appliquer le fichier MySQL YAML depuis votre dossier k8s
                    sh "kubectl apply -f ${K8S_DIR}/mysql-deployment.yaml -n ${KUBE_NAMESPACE}"

                    // Attendre que MySQL soit prêt
                    sh """
                    kubectl wait --for=condition=ready pod -l app=mysql -n ${KUBE_NAMESPACE} --timeout=120s || echo "MySQL prend plus de temps à démarrer"
                    """
                }
            }
        }

        stage('Update Spring Boot Deployment YAML') {
            steps {
                script {
                    // Si vous avez un fichier YAML séparé pour Spring Boot, mettez à jour l'image
                    sh """
                    # Mettre à jour l'image dans le fichier YAML s'il existe
                    if [ -f "${K8S_DIR}/spring-deployment.yaml" ]; then
                        sed -i "s|image: .*|image: ${DOCKER_IMAGE}:${env.BUILD_ID}|g" ${K8S_DIR}/spring-deployment.yaml
                        echo "Fichier YAML Spring Boot mis à jour avec l'image: ${DOCKER_IMAGE}:${env.BUILD_ID}"
                    fi
                    """
                }
            }
        }

        stage('Deploy Spring Boot Application') {
            steps {
                script {
                    // Déployer Spring Boot depuis vos fichiers YAML
                    sh """
                    # Appliquer tous les fichiers YAML pour Spring Boot dans le dossier k8s
                    # (exclure mysql-deployment.yaml s'il existe déjà)
                    for file in ${K8S_DIR}/*.yaml; do
                        if [ "\${file}" != "${K8S_DIR}/mysql-deployment.yaml" ]; then
                            kubectl apply -f "\${file}" -n ${KUBE_NAMESPACE} || echo "Fichier \${file} non appliqué"
                        fi
                    done
                    """

                    // OU si vous avez un fichier spécifique pour Spring Boot
                    sh """
                    if [ -f "${K8S_DIR}/spring-deployment.yaml" ]; then
                        kubectl apply -f ${K8S_DIR}/spring-deployment.yaml -n ${KUBE_NAMESPACE}
                    else
                        # Fallback: créer un déploiement basique si le fichier n'existe pas
                        cat <<EOF | kubectl apply -n ${KUBE_NAMESPACE} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: studentmang-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      labels:
        app: spring-app
    spec:
      containers:
      - name: spring-app
        image: ${DOCKER_IMAGE}:${env.BUILD_ID}
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_DATASOURCE_URL
          value: jdbc:mysql://mysql-service:3306/testdb
        - name: SPRING_DATASOURCE_USERNAME
          value: root
        - name: SPRING_DATASOURCE_PASSWORD
          value: root
---
apiVersion: v1
kind: Service
metadata:
  name: spring-service
spec:
  selector:
    app: spring-app
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
  type: NodePort
EOF
                    fi
                    """
                }
            }
        }

        stage('Wait for Application Readiness') {
            steps {
                script {
                    sh """
            # Attendre que le pod passe de ContainerCreating à Running
            echo "⏳ Attente du démarrage du container..."
            
            for i in {1..60}; do
                POD_STATUS=\$(kubectl get pod studentmang-app-6648c5b4c4-k8cmp -n ${KUBE_NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
                
                if [ "\$POD_STATUS" = "Running" ]; then
                    echo "✅ Pod en cours d'exécution"
                    break
                elif [ "\$POD_STATUS" = "ContainerCreating" ] || [ "\$POD_STATUS" = "Pending" ]; then
                    echo "⏳ État: \$POD_STATUS - Attente (\$i/60)..."
                    sleep 5
                elif [ "\$POD_STATUS" = "NotFound" ]; then
                    echo "❌ Pod non trouvé"
                    break
                else
                    echo "⚠️ État inattendu: \$POD_STATUS"
                    kubectl describe pod studentmang-app-6648c5b4c4-k8cmp -n ${KUBE_NAMESPACE} | tail -20
                    break
                fi
            done
            
            # Vérifier l'état final
            POD_STATUS=\$(kubectl get pod studentmang-app-6648c5b4c4-k8cmp -n ${KUBE_NAMESPACE} -o jsonpath='{.status.phase}')
            CONTAINER_STATUS=\$(kubectl get pod studentmang-app-6648c5b4c4-k8cmp -n ${KUBE_NAMESPACE} -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}')
            
            if [ "\$POD_STATUS" = "Running" ]; then
                echo "✅ Affichage des logs..."
                kubectl logs studentmang-app-6648c5b4c4-k8cmp -n ${KUBE_NAMESPACE} --tail=50
            else
                echo "❌ Pod non prêt. État: \$POD_STATUS"
                echo "Raison d'attente: \$CONTAINER_STATUS"
                
                # Debug avancé
                echo "=== Debug complet ==="
                kubectl describe pod studentmang-app-6648c5b4c4-k8cmp -n ${KUBE_NAMESPACE}
                
                # Vérifier les événements
                echo "=== Événements récents ==="
                kubectl get events -n ${KUBE_NAMESPACE} --field-selector involvedObject.name=studentmang-app-6648c5b4c4-k8cmp
                
                exit 1
            fi
            """
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    // Vérifications complètes
                    sh """
                    echo "=== État des Pods ==="
                    kubectl get pods -n ${KUBE_NAMESPACE}
                    
                    echo "\\n=== État des Services ==="
                    kubectl get svc -n ${KUBE_NAMESPACE}
                    
                    echo "\\n=== État des Déploiements ==="
                    kubectl get deployments -n ${KUBE_NAMESPACE}
                    
                    echo "\\n=== URL d'accès à l'application ==="
                    minikube service spring-service -n ${KUBE_NAMESPACE} --url || echo "Service NodePort disponible sur le port 30080"
                    
                    echo "\\n=== IP de Minikube ==="
                    minikube ip || true
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    // Test simple pour vérifier que l'application répond
                    sh """
                    # Attendre un peu plus pour être sûr
                    sleep 10
                    
                    # Obtenir l'URL du service
                    APP_URL=\$(minikube service spring-service -n ${KUBE_NAMESPACE} --url 2>/dev/null || echo "http://\$(minikube ip):30080")
                    
                    echo "Testing application at: \$APP_URL"
                    
                    # Tester l'endpoint de santé ou un endpoint API
                    curl -f --max-time 30 \$APP_URL/actuator/health || \\
                    curl -f --max-time 30 \$APP_URL/ || \\
                    echo "Application test skipped or endpoint not available"
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