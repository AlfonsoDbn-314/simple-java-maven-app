// Job freestyle de la guía, creado con Job DSL. Mismo orden de pasos que harías a mano.
// El nombre sigue el formato del laboratorio: <carné>_JavaMaven1A.
// Slack solo se agrega cuando hay token; sin él, el aviso de inicio abortaría el build antes de Maven.
def slackToken = System.getenv('SLACK_TOKEN') ?: ''
def slackListo = slackToken && slackToken != 'sin-token'

job(System.getenv('JOB_NAME_LAB') ?: '0900216641_JavaMaven1A') {
    description('Proyecto Java con Maven para Integración Continua')
    jdk('jdk21')
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
            mavenInstallation('maven2026A')
            goals('-B clean package -DskipTests')
        }
        maven {
            mavenInstallation('maven2026A')
            goals('-B test')
        }
        sonarRunnerBuilder {
            installationName('sonarqube')
            sonarScannerName('sonar-scanner')
            properties('''sonar.projectKey=0900216641_JavaMaven1A
sonar.projectName=0900216641_JavaMaven1A
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
        if (slackListo) {
            slackNotifier {
                startNotification(true)
                notifySuccess(true)
                notifyEveryFailure(true)
                notifyBackToNormal(true)
                notifyAborted(false)
                notifyNotBuilt(false)
                notifyUnstable(false)
                notifyRepeatedFailure(false)
                includeTestSummary(false)
                includeCustomMessage(false)
                commitInfoChoice('AUTHORS_AND_TITLES')
            }
        }
    }
}
