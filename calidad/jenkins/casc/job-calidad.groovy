// Job freestyle de la guía, creado con Job DSL. Mismo orden de pasos que harías a mano.
job('calidad-simple-java-maven-app') {
    description('Compila, prueba, analiza con SonarQube y notifica a Slack')
    scm {
        git {
            remote {
                url(System.getenv('REPO_URL') ?: 'https://github.com/AlfonsoDbn-314/simple-java-maven-app.git')
            }
            branch(System.getenv('REPO_BRANCH') ?: '*/master')
        }
    }
    triggers {
        githubPush()
    }
    steps {
        maven {
            mavenInstallation('mavenjenkins')
            goals('-B clean package -DskipTests')
        }
        maven {
            mavenInstallation('mavenjenkins')
            goals('-B test')
        }
        sonarRunnerBuilder {
            installationName('sonarqube')
            sonarScannerName('sonar-scanner')
            properties('''sonar.projectKey=simple-java-maven-app
sonar.projectName=simple-java-maven-app
sonar.sources=src/main/java
sonar.java.binaries=target/classes
sonar.tests=src/test/java
sonar.junit.reportPaths=target/surefire-reports
sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
sonar.sourceEncoding=UTF-8''')
        }
    }
    publishers {
        archiveJunit('target/surefire-reports/*.xml') {
            healthScaleFactor(1.0)
        }
        slackNotifier {
            startNotification(true)
            notifySuccess(true)
            notifyEveryFailure(true)
            notifyBackToNormal(true)
            notifyAborted(false)
            notifyNotBuilt(false)
            notifyUnstable(false)
            notifyRepeatedFailure(false)
            includeTestSummary(true)
            includeCustomMessage(false)
            commitInfoChoice('AUTHORS_AND_TITLES')
        }
    }
}
