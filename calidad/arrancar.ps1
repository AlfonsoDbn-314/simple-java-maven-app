# Levanta todo el pipeline de calidad con un solo comando en Windows.
# Antes de ejecutarlo define en esta terminal $env:SONAR_ADMIN_PASSWORD y, si los usas,
# $env:SLACK_TOKEN, $env:SLACK_WORKSPACE y $env:NGROK_AUTHTOKEN. Ningún token se guarda en archivos.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not $env:SONAR_ADMIN_PASSWORD) {
    throw "Define `$env:SONAR_ADMIN_PASSWORD: 12 caracteres o más con mayúscula, minúscula, número y símbolo"
}
$sonar = "http://localhost:9000"

function Get-Basic($user, $pass) {
    $b = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${pass}"))
    @{ Authorization = "Basic $b" }
}

# SonarQube necesita este ajuste del kernel de WSL; se pierde al reiniciar el equipo.
wsl -d docker-desktop sysctl -w vm.max_map_count=262144 | Out-Null

Write-Host "1/4 Levantando PostgreSQL y SonarQube"
docker compose up -d db sonarqube
do {
    Start-Sleep 5
    try { $estado = (Invoke-RestMethod "$sonar/api/system/status").status } catch { $estado = "" }
} until ($estado -eq "UP")

Write-Host "2/4 Generando token de SonarQube"
# La primera vez cambia la contraseña por defecto; las siguientes falla en silencio porque ya cambió.
try {
    Invoke-RestMethod -Method Post "$sonar/api/users/change_password" -Headers (Get-Basic "admin" "admin") `
        -Body @{ login = "admin"; previousPassword = "admin"; password = $env:SONAR_ADMIN_PASSWORD } | Out-Null
} catch {}
$auth = Get-Basic "admin" $env:SONAR_ADMIN_PASSWORD
try { Invoke-RestMethod -Method Post "$sonar/api/user_tokens/revoke" -Headers $auth -Body @{ name = "jenkins" } | Out-Null } catch {}
$env:SONAR_TOKEN = (Invoke-RestMethod -Method Post "$sonar/api/user_tokens/generate" -Headers $auth `
    -Body @{ name = "jenkins"; type = "GLOBAL_ANALYSIS_TOKEN" }).token

Write-Host "3/4 Abriendo túnel ngrok"
if ($env:NGROK_AUTHTOKEN) {
    docker compose --profile ngrok up -d --no-deps ngrok
    do {
        Start-Sleep 2
        try { $url = (Invoke-RestMethod "http://localhost:4040/api/tunnels").tunnels[0].public_url } catch { $url = $null }
    } until ($url)
    $env:JENKINS_PUBLIC_URL = "$url/"
} else {
    Write-Host "   Sin NGROK_AUTHTOKEN, se omite. El job solo se ejecutará con Build Now."
}

Write-Host "4/4 Construyendo y levantando Jenkins ya configurado"
docker compose up -d --build jenkins
do {
    Start-Sleep 5
    try { $ok = (Invoke-WebRequest "http://localhost:8080/login" -UseBasicParsing).StatusCode -eq 200 } catch { $ok = $false }
} until ($ok)

$usuario = if ($env:JENKINS_ADMIN_USER) { $env:JENKINS_ADMIN_USER } else { "admin" }
Write-Host ""
Write-Host "Jenkins:   http://localhost:8080   usuario $usuario"
Write-Host "SonarQube: $sonar   usuario admin"
if ($env:JENKINS_PUBLIC_URL) { Write-Host "Webhook para GitHub: $($env:JENKINS_PUBLIC_URL)github-webhook/" }
