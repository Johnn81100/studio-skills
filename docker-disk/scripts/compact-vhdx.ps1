# compact-vhdx.ps1 — Compacte le disque virtuel de Docker Desktop (WSL2).
# Doit être lancé dans un PowerShell EN ADMINISTRATEUR.
# Ne supprime rien : purger avec `docker system prune` AVANT, sinon sans effet.

$ErrorActionPreference = 'Stop'

# — Élévation —
$estAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $estAdmin) {
    Write-Host "X  Ce script doit tourner en administrateur." -ForegroundColor Red
    Write-Host "   Clic droit sur le menu Demarrer -> Terminal (admin), puis relancer."
    exit 1
}

# — Localisation du .vhdx —
$candidats = @(
    "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx",
    "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx",
    "$env:LOCALAPPDATA\Docker\wsl\main\ext4.vhdx"
)
$vhdx = $candidats | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $vhdx) {
    Write-Host "X  Aucun .vhdx Docker trouve. Emplacements testes :" -ForegroundColor Red
    $candidats | ForEach-Object { Write-Host "   $_" }
    exit 1
}

$avant = (Get-Item $vhdx).Length / 1GB
$libreAvant = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB
Write-Host ("Fichier      : {0}" -f $vhdx)
Write-Host ("Taille       : {0:N1} Go" -f $avant)
Write-Host ("Disque libre : {0:N1} Go" -f $libreAvant)
Write-Host ""

# — Docker Desktop doit etre quitte —
$proc = Get-Process -Name 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "X  Docker Desktop tourne encore et verrouille le fichier." -ForegroundColor Red
    Write-Host "   Clic droit sur l'icone dans la barre des taches -> Quit Docker Desktop."
    Write-Host "   Fermer la fenetre ne suffit pas."
    exit 1
}

# — Arret de WSL (toutes distributions) —
Write-Host "Arret de WSL (toutes les distributions)..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 3

$restantes = (wsl -l -v) -replace "`0","" | Select-String 'Running'
if ($restantes) {
    Write-Host "X  Des distributions tournent encore :" -ForegroundColor Red
    $restantes | ForEach-Object { Write-Host "   $_" }
    exit 1
}

# — Compactage —
$script = Join-Path $env:TEMP 'compact-vhdx-diskpart.txt'
@"
select vdisk file="$vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@ | Out-File -FilePath $script -Encoding ascii

Write-Host "Compactage en cours — plusieurs minutes, ne pas interrompre." -ForegroundColor Yellow
Write-Host ""
diskpart /s $script
$code = $LASTEXITCODE
Remove-Item $script -ErrorAction SilentlyContinue

if ($code -ne 0) {
    Write-Host ""
    Write-Host "X  diskpart a echoue (code $code)." -ForegroundColor Red
    Write-Host "   Cause la plus frequente : le fichier est encore utilise."
    Write-Host "   Verifier que Docker Desktop est quitte, relancer wsl --shutdown."
    exit 1
}

# — Bilan —
$apres = (Get-Item $vhdx).Length / 1GB
$libreApres = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB
Write-Host ""
Write-Host ("Taille       : {0:N1} Go  ->  {1:N1} Go" -f $avant, $apres) -ForegroundColor Green
Write-Host ("Disque libre : {0:N1} Go  ->  {1:N1} Go" -f $libreAvant, $libreApres) -ForegroundColor Green
Write-Host ("Recupere     : {0:N1} Go" -f ($libreApres - $libreAvant)) -ForegroundColor Green
