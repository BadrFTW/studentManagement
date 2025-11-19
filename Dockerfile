# OPTION 1: Tag standard (fonctionne toujours)
FROM openjdk:11
COPY target/*.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]