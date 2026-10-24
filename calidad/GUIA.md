# Pipeline de calidad con Docker, Jenkins, Maven y SonarQube

Este paquete levanta un entorno de aseguramiento de calidad en tu máquina y lo conecta con tu repositorio `AlfonsoDbn-314/simple-java-maven-app`. Cada push a GitHub llega a Jenkins a través de ngrok, Jenkins descarga el código, Maven lo compila y ejecuta las pruebas, SonarQube revisa la calidad del código y Slack te avisa del resultado.

## Arranque rápido

Si quieres saltarte la configuración manual, la carpeta `calidad` de tu repositorio trae Jenkins configurado como código. Al arrancar ya existen tu usuario, el JDK `jdk21`, Maven `maven2026A`, el scanner `sonar-scanner`, el servidor `sonarqube`, las credenciales y el job `0900216641_JavaMaven1A` con los tres pasos y las dos acciones. Primero fusiona el PR, luego, con Docker Desktop abierto, ejecuta en PowerShell:

```
git clone https://github.com/AlfonsoDbn-314/simple-java-maven-app.git
cd simple-java-maven-app\calidad
$env:SONAR_ADMIN_PASSWORD = "UnaClaveSegura#2026"
$env:JENKINS_ADMIN_USER = "0900216641"
$env:JENKINS_ADMIN_PASSWORD = "tu-clave-de-jenkins"
$env:SLACK_TOKEN = "xoxb-..."
$env:SLACK_WORKSPACE = "tu-espacio"
$env:NGROK_AUTHTOKEN = "tu-token-de-ngrok"
.\arrancar.ps1
```

El script cambia la contraseña inicial de SonarQube, genera el token de análisis, abre el túnel de ngrok, le pasa todo a Jenkins por variables de entorno y al final te imprime la URL del webhook. Ningún token queda escrito en archivos. Usar tu carné como usuario de Jenkins hace que aparezca en tus capturas, como pide la entrega. Si PowerShell bloquea el script, ejecuta antes `Set-ExecutionPolicy -Scope Process Bypass`.

Las secciones siguientes explican a mano lo mismo que hace el script, para que entiendas cada pieza y puedas responder si te preguntan.

## 1. Qué hay en el paquete

`docker-compose.yml` define tres contenedores en una misma red llamada `calidad`. Jenkins es el orquestador que ejecuta el job. SonarQube es el servidor que analiza el código y guarda los resultados. PostgreSQL es la base de datos de SonarQube; se usa porque la base embebida que trae SonarQube solo sirve para pruebas y pierde datos al actualizar. ngrok crea un túnel desde internet hasta tu Jenkins, porque GitHub no puede enviar un webhook a `localhost` de tu computadora.

`jenkins/Dockerfile` parte de la imagen oficial `jenkins/jenkins:lts-jdk21`, que ya trae Java 21, e instala los plugins que pide la guía: Maven, SonarQube Scanner, JUnit, Slack, Git y GitHub, este último para recibir el webhook. Así no tienes que instalarlos a mano desde la interfaz.

`cambios-repo.patch` contiene los cambios que preparé para tu repositorio. Están en la rama `calidad-sonarqube` y todavía no los he subido a GitHub. Explico qué hacen en la sección 3.

## 2. Levantar el entorno

SonarQube usa Elasticsearch por dentro, y Elasticsearch exige que el sistema permita muchas áreas de memoria mapeada. Si no lo configuras, el contenedor de SonarQube se cae a los pocos segundos. En Windows con Docker Desktop ejecuta esto en PowerShell, y repítelo cada vez que reinicies el equipo:

```
wsl -d docker-desktop sysctl -w vm.max_map_count=262144
```

En Linux el comando es `sudo sysctl -w vm.max_map_count=262144`.

ngrok necesita tu authtoken, que encuentras en dashboard.ngrok.com, en la sección Your Authtoken. No lo escribas en ningún archivo del proyecto, porque si lo subes a GitHub cualquiera podría usar tu cuenta. Ponlo como variable de entorno en la misma terminal donde vas a levantar el entorno. En PowerShell:

```
$env:NGROK_AUTHTOKEN = "tu-token"
```

En Linux o Git Bash es `export NGROK_AUTHTOKEN=tu-token`. Docker Compose lee esa variable y se la pasa al contenedor de ngrok. Si cierras la terminal tendrás que definirla otra vez.

Luego, desde la misma terminal y en la carpeta del paquete:

```
docker compose up -d --build
```

La primera vez tarda unos minutos porque construye la imagen de Jenkins con sus plugins. Cuando termine tendrás Jenkins en http://localhost:8080, SonarQube en http://localhost:9000 y el panel de ngrok en http://localhost:4040. Ese panel muestra la URL pública que ngrok le asignó a tu Jenkins, algo como `https://xxxx.ngrok-free.app`, y también cada petición que entra, lo que sirve mucho para comprobar si GitHub está llegando.

Para entrar a Jenkins por primera vez necesitas la contraseña inicial, que se genera dentro del contenedor:

```
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Elige "Instalar plugins sugeridos" y crea tu usuario administrador. En SonarQube entra con admin y admin; te pedirá cambiar la contraseña.

Un detalle importante: dentro de la red de Docker, Jenkins no ve a SonarQube como `localhost`, porque `localhost` dentro de un contenedor es el propio contenedor. Lo ve por el nombre del servicio, es decir `http://sonarqube:9000`. Tú desde el navegador sí usas `localhost:9000`.

## 3. Cambios en tu repositorio y por qué

Tu proyecto venía del tutorial oficial de Jenkins con Java 1.8 y JUnit 4.11. Lo actualicé a Java 21 con `maven.compiler.release`, que es la forma moderna de fijar la versión y además impide usar por error APIs de una versión más nueva.

Migré `AppTest` a JUnit 5. La prueba hace lo mismo que antes, pero ahora restaura `System.out` al terminar en lugar de dejarlo en `null`, que podía romper otras pruebas que se ejecutaran después.

Agregué `maven-surefire-plugin` 3.5.2 porque es el plugin que ejecuta las pruebas en la fase `test` y deja los reportes XML en `target/surefire-reports`. Esos XML son los que lee Jenkins para mostrarte la gráfica de pruebas.

Agregué JaCoCo, que mide qué líneas ejecutaron las pruebas. Está enganchado a la fase `test`, así que tu segundo paso de Maven ya genera `target/site/jacoco/jacoco.xml`. Sin ese archivo SonarQube mostraría cobertura de 0 %.

`sonar-project.properties` es una copia de referencia de las propiedades del análisis. `Jenkinsfile5` es la misma idea del job pero escrita como pipeline, por si después quieres compararla con el job freestyle que pide la guía. También subí el workflow de GitHub Actions a JDK 21, porque con JDK 17 dejaría de compilar.

Lo verifiqué en local: `mvn -B clean package -DskipTests` compila y `mvn -B test` ejecuta 2 pruebas sin fallos y genera los reportes de Surefire y JaCoCo.

## 4. Preparar SonarQube

En SonarQube entra a tu avatar, luego My Account, luego Security, y genera un token de tipo Global Analysis Token. Cópialo, porque solo se muestra una vez. El token sirve para que Jenkins se identifique ante SonarQube sin usar tu contraseña.

## 5. Configurar Jenkins

En Manage Jenkins, Credentials, agrega una credencial de tipo Secret text con el token de SonarQube y ponle el ID `sonar-token`.

En Manage Jenkins, System, busca la sección SonarQube servers. Marca la opción de variables de entorno, agrega un servidor con nombre `sonarqube`, URL `http://sonarqube:9000` y la credencial `sonar-token`. Este es el servidor que luego eliges en "SonarQube Installation".

En Manage Jenkins, Tools, registra dos herramientas. En Maven installations crea una llamada `maven2026A` con instalación automática desde Apache; el laboratorio pide un nombre con el año y una letra. En SonarQube Scanner installations crea una llamada `sonar-scanner`, también con instalación automática. Jenkins las descarga la primera vez que el job las necesite.

## 6. Crear el job paso a paso

Crea un New Item de tipo Freestyle project llamado `0900216641_JavaMaven1A`, que es el formato `<carné>_JavaMaven1A` del laboratorio. En General escribe la descripción `Proyecto Java con Maven para Integración Continua` y en JDK elige `jdk21`.

En Source Code Management elige Git, con URL `https://github.com/AlfonsoDbn-314/simple-java-maven-app.git`. En la rama escribe `*/master`, que es la rama principal de tu fork. Por eso necesitas fusionar el PR antes de construir.

En Build Triggers marca GitHub hook trigger for GITScm polling. Con eso el job deja de depender de que pulses Build Now y se ejecuta solo cuando GitHub avisa que hubo un push.

En Build Steps agrega tres pasos en este orden. El orden importa porque SonarQube analiza el bytecode y necesita que las clases ya estén compiladas.

El primero es Invoke top-level Maven targets con la versión `maven2026A` y estas metas:

```
-B clean package -DskipTests
```

`clean` borra lo que quedó de compilaciones anteriores para que el resultado no dependa de basura vieja. `package` compila y arma el jar. `-B` activa el modo batch, que quita los mensajes interactivos y las barras de progreso, algo necesario cuando nadie está mirando la consola. `-DskipTests` salta las pruebas, porque las vamos a correr en su propio paso para que una falla de pruebas se distinga claramente de una falla de compilación.

El segundo es otro Invoke top-level Maven targets con la misma versión y la meta:

```
-B test
```

`test` es la fase del ciclo de vida que ejecuta las pruebas unitarias con Surefire, y gracias a JaCoCo también deja el reporte de cobertura.

El tercero es Execute SonarQube Scanner. En SonarQube Installation elige `sonarqube`, el JDK déjalo heredado del job, en SonarQube Scanner elige `sonar-scanner`, y en Analysis properties pega:

```
sonar.projectKey=0900216641_JavaMaven1A
sonar.projectName=0900216641_JavaMaven1A
sonar.sources=src/main/java
sonar.java.binaries=target/classes
sonar.tests=src/test/java
sonar.junit.reportPaths=target/surefire-reports
sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
sonar.sourceEncoding=UTF-8
```

Las cuatro primeras son las que exige la guía. `projectKey` es el identificador único del proyecto dentro de SonarQube y `projectName` el nombre que ves en pantalla. `sources` dice dónde está el código fuente. `java.binaries` dice dónde están las clases compiladas, y es `target/classes` porque ahí deja Maven el bytecode del código principal. Las demás son opcionales y sirven para que SonarQube muestre también pruebas y cobertura.

## 7. Acciones para ejecutar después

Agrega Publish JUnit test result report. En Test report XMLs escribe:

```
target/surefire-reports/*.xml
```

`surefire-reports` es la carpeta del plugin de Maven que corre las pruebas, y cada clase de prueba deja ahí un XML. Deja el resto de opciones por defecto, con Health report amplification factor en 1.0.

Agrega Slack Notifications y marca exactamente Notify Build Start, Notify Success, Notify Every Failure y Notify Back To Normal, dejando sin marcar Aborted, Not Built, Unstable y Regression. Así te enteras cuando empieza, cuando sale bien, cada vez que falla y cuando vuelve a funcionar tras una falla.

## 8. Conectar Slack

El plugin Slack Notification ya viene instalado en la imagen de Jenkins. Lo que falta es darle a Jenkins permiso para escribir en tu espacio de Slack, y eso se hace con una app de Slack y su token.

Entra a api.slack.com/apps, pulsa Create New App, elige From scratch, ponle un nombre como `Jenkins CI` y selecciona tu espacio de trabajo. En OAuth & Permissions, dentro de Bot Token Scopes, agrega el permiso `chat:write`, que es lo único que Jenkins necesita para publicar mensajes. Luego pulsa Install to Workspace y copia el Bot User OAuth Token, que empieza con `xoxb-`.

En Slack crea o elige el canal donde quieres los avisos, por ejemplo `#jenkins`, y escribe `/invite @Jenkins CI`. Sin este paso el bot tiene permiso para escribir pero no está dentro del canal, y Slack rechaza el mensaje con el error `not_in_channel`.

El token no va en el Jenkinsfile, en el docker-compose ni en ningún archivo del repositorio, porque quien lo tenga puede escribir en tu Slack en nombre de la app. Se guarda como credencial cifrada dentro de Jenkins. En Manage Jenkins, Credentials, agrega una de tipo Secret text, pega el token en Secret y ponle el ID `slack-token`.

En Manage Jenkins, System, busca la sección Slack. En Workspace escribe el subdominio de tu espacio, la parte antes de `.slack.com`. En Credential elige `slack-token`, en Default channel escribe `#jenkins` y marca Custom slack app bot user, que le dice al plugin que usas una app con token de bot. Pulsa Test Connection; si todo está bien aparece Success y llega un mensaje de prueba al canal.

Con eso funciona la acción Slack Notifications del job que configuraste en la sección 7. Si más adelante usas `Jenkinsfile5`, los pasos `slackSend` usan esta misma configuración global, por eso no llevan token.

## 9. Conectar GitHub con ngrok

Copia la URL pública del panel de ngrok. En Jenkins, Manage Jenkins, System, pon esa URL en Jenkins URL, para que los enlaces que Jenkins genera, como los de Slack, apunten a una dirección que funcione fuera de tu máquina.

En GitHub abre tu repositorio, Settings, Webhooks, Add webhook. En Payload URL pon la URL de ngrok seguida de `/github-webhook/`, con la barra final incluida, por ejemplo `https://xxxx.ngrok-free.app/github-webhook/`. En Content type elige `application/json` y deja seleccionado Just the push event. Al guardar, GitHub manda un ping; en Recent Deliveries debe aparecer con una marca verde y en el panel de ngrok verás la petición.

En el plan gratuito de ngrok la URL puede cambiar cada vez que reinicias el contenedor. Si cambia, actualiza el webhook y la Jenkins URL. Para evitarlo, ngrok te da gratis un dominio fijo en la sección Domains del dashboard; si lo reclamas, cambia el comando del servicio en `docker-compose.yml` a `http jenkins:8080 --url=tu-dominio.ngrok-free.app`.

## 10. Ejecutar y revisar

Haz un push a la rama que configuraste en el job, o pulsa Build Now para la primera prueba. En la consola deberías ver la compilación, luego `Tests run: 2, Failures: 0`, y al final el enlace al análisis en SonarQube. En la página del job aparece la tendencia de pruebas, y en http://localhost:9000 el proyecto con su Quality Gate, bugs, code smells y cobertura.

Para apagar todo usa `docker compose down`. Los datos quedan guardados en volúmenes, así que al volver a levantarlo conservas la configuración. Si quieres borrar todo y empezar de cero usa `docker compose down -v`.
