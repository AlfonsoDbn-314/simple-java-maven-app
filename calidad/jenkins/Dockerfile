# Jenkins LTS que ya trae Java 21, el mismo JDK que usa el proyecto.
FROM jenkins/jenkins:lts-jdk21

# Maven y SonarQube Scanner quedan dentro de la imagen para que el job no dependa
# de descargas en la primera ejecución. Jenkins los registra en Tools con estos nombres de carpeta.
ARG MAVEN_VERSION=3.9.11
ARG SONAR_SCANNER_VERSION=7.0.2.4839
USER root
RUN apt-get update && apt-get install -y --no-install-recommends unzip && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
    | tar -xz -C /opt && mv /opt/apache-maven-${MAVEN_VERSION} /opt/maven \
 && curl -fsSL -o /tmp/scanner.zip https://repo1.maven.org/maven2/org/sonarsource/scanner/cli/sonar-scanner-cli/${SONAR_SCANNER_VERSION}/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip \
 && unzip -q /tmp/scanner.zip -d /opt && mv /opt/sonar-scanner-${SONAR_SCANNER_VERSION} /opt/sonar-scanner && rm /tmp/scanner.zip
USER jenkins

# Plugins que pide la guía: Maven para los pasos de build, SonarQube Scanner,
# JUnit para publicar resultados, Slack para notificaciones, Git para clonar tu repositorio
# y GitHub para disparar el job con el webhook que llega por ngrok.
# Configuration as Code y Job DSL configuran Jenkins y crean el job al arrancar, sin pasar por la interfaz.
RUN jenkins-plugin-cli --plugins \
    maven-plugin \
    sonar \
    junit \
    slack \
    git \
    github \
    jacoco \
    configuration-as-code \
    job-dsl

# Sin asistente inicial: el usuario, las herramientas, los servidores y el job vienen de casc/.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc
COPY casc/ /usr/share/jenkins/ref/casc/
