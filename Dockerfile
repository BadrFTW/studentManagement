# Version corrigée avec tags valides
FROM openjdk:11-jre-slim
COPY target/*.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]