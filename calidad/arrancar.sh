#!/usr/bin/env bash
# Levanta todo el pipeline de calidad con un solo comando.
# Antes de ejecutarlo define en esta terminal SONAR_ADMIN_PASSWORD y, si los usas,
# SLACK_TOKEN, SLACK_WORKSPACE y NGROK_AUTHTOKEN. Ningún token se guarda en archivos.
set -euo pipefail
cd "$(dirname "$0")"

: "${SONAR_ADMIN_PASSWORD:?Define SONAR_ADMIN_PASSWORD: 12 caracteres o más con mayúscula, minúscula, número y símbolo}"
SONAR=http://localhost:9000

if [ "$(uname)" = "Linux" ] && [ "$(sysctl -n vm.max_map_count)" -lt 262144 ]; then
  echo "SonarQube necesita vm.max_map_count=262144, se pedirá sudo"
  sudo sysctl -w vm.max_map_count=262144
fi

echo "1/4 Levantando PostgreSQL y SonarQube"
docker compose up -d db sonarqube
for i in $(seq 1 60); do
  curl -fs "$SONAR/api/system/status" | grep -q '"status":"UP"' && break
  if [ "$(docker inspect -f '{{.State.Running}}' calidad-sonarqube)" != "true" ]; then
    echo "SonarQube se detuvo. Revisa: docker logs calidad-sonarqube --tail 50"; exit 1
  fi
  [ "$i" = 60 ] && { echo "SonarQube no arrancó en 5 minutos"; exit 1; }
  sleep 5
done

echo "2/4 Generando token de SonarQube"
# La primera vez cambia la contraseña por defecto; las siguientes falla en silencio porque ya cambió.
curl -fs -u admin:admin -X POST "$SONAR/api/users/change_password" \
  --data-urlencode login=admin --data-urlencode previousPassword=admin \
  --data-urlencode "password=$SONAR_ADMIN_PASSWORD" >/dev/null || true
curl -fs -u "admin:$SONAR_ADMIN_PASSWORD" -X POST "$SONAR/api/user_tokens/revoke" -d name=jenkins >/dev/null || true
SONAR_TOKEN=$(curl -fs -u "admin:$SONAR_ADMIN_PASSWORD" -X POST "$SONAR/api/user_tokens/generate" \
  -d name=jenkins -d type=GLOBAL_ANALYSIS_TOKEN | sed -E 's/.*"token":"([^"]+)".*/\1/')
export SONAR_TOKEN

echo "3/4 Abriendo túnel ngrok"
if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
  docker compose --profile ngrok up -d --no-deps ngrok
  until JENKINS_PUBLIC_URL=$(curl -fs http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | cut -d'"' -f4); do sleep 2; done
  export JENKINS_PUBLIC_URL="$JENKINS_PUBLIC_URL/"
else
  echo "   Sin NGROK_AUTHTOKEN, se omite. El job solo se ejecutará con Build Now."
fi

echo "4/4 Construyendo y levantando Jenkins ya configurado"
docker compose up -d --build jenkins
until curl -fs -o /dev/null http://localhost:8080/login; do sleep 5; done

echo
echo "Jenkins:   http://localhost:8080   usuario ${JENKINS_ADMIN_USER:-admin}"
echo "SonarQube: $SONAR   usuario admin"
if [ -n "${JENKINS_PUBLIC_URL:-}" ]; then
  echo "Webhook para GitHub: ${JENKINS_PUBLIC_URL}github-webhook/"
fi
