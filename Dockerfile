# Étape de build
FROM maven:3.8.6-openjdk-11 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Étape d'exécution
FROM openjdk:11-jre-slim
RUN groupadd -r spring && useradd -r -g spring spring
USER spring
WORKDIR /app
COPY --from=builder --chown=spring:spring /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app.jar"]