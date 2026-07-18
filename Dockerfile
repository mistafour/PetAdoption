FROM openjdk:11.0.8-jre-slim

COPY . /app

WORKDIR /app

ENTRYPOINT [ "java", "-jar", "spring-petclinic-2.4.2.war", "--server.port=8080"]