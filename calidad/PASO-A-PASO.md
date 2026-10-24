# Paso a paso del laboratorio

Sigue los pasos en orden, de uno en uno. Cada paso dice qué ejecutar, qué debes ver y qué hacer si falla. Todos los comandos van en PowerShell, dentro de la carpeta `C:\Users\adbn3\OneDrive\Documents\lab-jenkins\simple-java-maven-app\calidad`. Cuando un paso diga 📸, toma esa captura para el informe.

## Paso 1. Reiniciar la base de datos de SonarQube

SonarQube se detenía porque un arranque anterior dejó su base de datos a medio crear. Como todavía no tiene nada tuyo, se borra y se crea limpia. Esto solo afecta a los volúmenes de este laboratorio.

```
docker compose stop sonarqube db
docker compose rm -f sonarqube db
docker volume rm calidad_postgresql_data calidad_sonarqube_data
```

**Debes ver** los nombres de los dos volúmenes impresos, uno por línea.

**Si falla** con "no such volume", ejecuta `docker volume ls`, busca los que terminan en `postgresql_data` y `sonarqube_data` y bórralos con su nombre exacto.

## Paso 2. Fusionar el PR

Abre https://github.com/AlfonsoDbn-314/simple-java-maven-app/pull/1 y pulsa **Merge pull request** y luego **Confirm merge**. El job construye la rama `master`, así que sin este paso Jenkins compilaría la versión vieja del proyecto.

Luego actualiza tu copia local:

```
git checkout master
git pull
```

**Debes ver** que se descargan los cambios y termina sin errores.

## Paso 3. Definir tus claves y arrancar todo

Estas variables solo viven en esta ventana de PowerShell. Si la cierras, tendrás que definirlas otra vez antes de volver a ejecutar el script.

```
$env:SONAR_ADMIN_PASSWORD = "UnaClaveSegura#2026"
$env:JENKINS_ADMIN_USER = "0900216641"
$env:JENKINS_ADMIN_PASSWORD = "elige-una-clave"
Set-ExecutionPolicy -Scope Process Bypass
.\arrancar.ps1
```

La clave de SonarQube necesita 12 caracteres o más, con mayúscula, minúscula, número y símbolo.

**Debes ver** los pasos 1/4 a 4/4 y al final las direcciones de Jenkins y SonarQube. Tarda entre 2 y 5 minutos.

**Si falla** en el paso 1/4, ejecuta `docker logs calidad-sonarqube --tail 50` y pásame la salida. Si falla en el 2/4 con un error 401, la clave de SonarQube no cumple las reglas: elige otra y repite el paso 1.

## Paso 4. Comprobar que todo está arriba

Abre http://localhost:8080 y entra con `0900216641` y tu clave de Jenkins. **Debes ver** el job `0900216641_JavaMaven1A` en la lista.

Abre http://localhost:9000 y entra con `admin` y tu clave de SonarQube.

**Si Jenkins no abre**, ejecuta `docker logs calidad-jenkins --tail 80` y pásame la salida.

## Paso 5. Capturas de la configuración del job

Entra al job y pulsa **Configure**. Ve bajando y captura cada sección:

📸 General, con la descripción y el JDK `jdk21`.
📸 Source Code Management, con la URL de tu fork y la rama `*/master`.
📸 Triggers, con "GitHub hook trigger for GITScm polling" marcado.
📸 Los tres Build Steps: los dos de Maven y el de SonarQube Scanner con sus propiedades.
📸 Las dos acciones posteriores: JUnit y Slack Notifications.

No cambies nada ni pulses Save, porque la configuración viene de la carpeta `calidad/jenkins/casc` y se vuelve a aplicar cada vez que arranca Jenkins.

## Paso 6. Primer build

En el job pulsa **Build Now**, luego abre el build #1 y entra a **Console Output**.

**Debes ver**, en este orden, el checkout de tu fork, un `BUILD SUCCESS` del empaquetado, `Tests run: 2, Failures: 0`, otro `BUILD SUCCESS` y al final `ANALYSIS SUCCESSFUL` de SonarQube. El build termina en `Finished: SUCCESS`.

📸 La consola mostrando el empaquetado, las pruebas y el análisis.

**Si falla**, busca la primera línea que diga `ERROR` y pásamela. Si el error menciona Slack, ignóralo por ahora: es normal porque aún no configuraste Slack.

## Paso 7. Resultados de pruebas y SonarQube

En la página del build pulsa **Test Result**. **Debes ver** 2 pruebas y 0 fallos.

📸 El resultado de JUnit.

En http://localhost:9000 abre el proyecto `0900216641_JavaMaven1A`.

📸 El tablero del proyecto con el análisis.

## Paso 8. Slack

En https://api.slack.com/apps pulsa **Create New App**, luego **From scratch**, nómbrala `Jenkins CI` y elige tu espacio. En **OAuth & Permissions**, dentro de **Bot Token Scopes**, agrega `chat:write`. Pulsa **Install to Workspace** y copia el **Bot User OAuth Token**, que empieza con `xoxb-`.

En Slack crea el canal `#jenkins` y escribe ahí `/invite @Jenkins CI`.

De vuelta en PowerShell, en la misma ventana del paso 3:

```
$env:SLACK_TOKEN = "xoxb-tu-token"
$env:SLACK_WORKSPACE = "tu-espacio"
.\arrancar.ps1
```

`tu-espacio` es la parte de la dirección de Slack antes de `.slack.com`.

En Jenkins ve a **Manage Jenkins**, luego **System**, baja a la sección Slack y pulsa **Test Connection**. **Debes ver** `Success` y un mensaje de prueba en `#jenkins`.

Pulsa **Build Now** otra vez. **Debes ver** en Slack el aviso de inicio y luego el de éxito.

📸 El canal de Slack con los dos avisos.

**Si falla** con `not_in_channel`, falta invitar la app al canal. Con `invalid_auth`, el token está mal copiado.

## Paso 9. ngrok y el webhook

Copia tu authtoken desde https://dashboard.ngrok.com, en la sección Your Authtoken. En la misma ventana:

```
$env:NGROK_AUTHTOKEN = "tu-token-de-ngrok"
.\arrancar.ps1
```

**Debes ver** al final una línea `Webhook para GitHub: https://xxxx.ngrok-free.app/github-webhook/`. Cópiala.

En GitHub abre tu repositorio, luego **Settings**, **Webhooks** y **Add webhook**. Pega la URL en **Payload URL**, elige `application/json` en **Content type**, deja **Just the push event** y pulsa **Add webhook**.

Entra al webhook y abre **Recent Deliveries**. **Debes ver** el ping con respuesta 200.

📸 Recent Deliveries con el 200.
📸 El panel de ngrok en http://localhost:4040 con el túnel activo y la petición recibida.

**Si falla** con un 403 o un 404, revisa que la URL termine exactamente en `/github-webhook/`, con la barra final. Si reiniciaste el script, la URL de ngrok pudo cambiar y hay que actualizar el webhook.

## Paso 10. Build automático por push

Desde la carpeta del repositorio, un nivel arriba de `calidad`:

```
cd ..
Add-Content README.md "`nPrueba de webhook"
git add README.md
git commit -m "Probar webhook"
git push
cd calidad
```

Sin tocar Jenkins, en unos segundos **debe aparecer** un build nuevo. Ábrelo: arriba debe decir `Started by GitHub push by AlfonsoDbn-314`. También debe llegar el aviso a Slack.

📸 Tu commit en GitHub.
📸 El build con "Started by GitHub push".

## Paso 11. Párrafo final del informe

El laboratorio pide un párrafo con los problemas que encontraste y cómo los resolviste. Puedes contar lo que te pasó de verdad: el nombre `sonarqube` ya lo usaba otro contenedor, y se resolvió dándole a los contenedores del laboratorio el prefijo `calidad-`. Después SonarQube se detenía porque su base de datos quedó a medio crear tras un arranque interrumpido. El log mostraba `relation "active_rule_parameters" already exists`, y se resolvió borrando el volumen de PostgreSQL para que creara el esquema limpio.

## Para apagar y volver otro día

`docker compose --profile ngrok down` apaga todo sin borrar datos. Para volver, abre PowerShell en `calidad`, define otra vez las variables del paso 3 y las de Slack y ngrok, y ejecuta `.\arrancar.ps1`. La URL de ngrok puede cambiar, así que revisa el webhook.
