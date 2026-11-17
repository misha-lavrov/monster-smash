# =====================================================================================
#  Зберігає налаштування IntelliJ IDEA з ЦЬОГО ПК у файл ide-config.zip.
#  Файл кладеться до інсталяторів (сусідня папка, де лежать Git/JDK/IntelliJ) — і INSTALL.bat застосує його на інших ПК,
#  тож там не треба знову приймати угоди, довіряти проєкту й вибирати JDK.
#
#  Запускайте на ЧИСТОМУ ПК коледжу після того, як ви один раз вручну налаштували IntelliJ
#  (відкрили папку monster-smash, довірили проєкт, вибрали JDK). Не на особистому ноуті:
#  у налаштуваннях лишаються шляхи до ваших проєктів.
# =====================================================================================
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$kit  = ([string]$env:KIT_DIR).TrimEnd('\')
$root = Join-Path $env:APPDATA 'JetBrains'

$ide = Get-ChildItem -LiteralPath $root -Directory -Filter 'IntelliJIdea*' -ErrorAction SilentlyContinue |
       Where-Object { Test-Path "$($_.FullName)\options" } | Sort-Object Name -Descending | Select-Object -First 1
if (-not $ide) {
    Write-Host '[FAIL] Налаштувань IntelliJ IDEA на цьому ПК не знайдено. Спершу запусти IntelliJ і налаштуй його.' -ForegroundColor Red
    exit 1
}

$stage = Join-Path $env:TEMP 'oipz-ide-stage'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force "$stage\$($ide.Name)" | Out-Null
robocopy "$($ide.FullName)\options" "$stage\$($ide.Name)\options" /E /NFL /NDL /NJH /NJS /NP | Out-Null
if (Test-Path "$root\consentOptions") { robocopy "$root\consentOptions" "$stage\consentOptions" /E /NFL /NDL /NJH /NJS /NP | Out-Null }

$parent = Split-Path $kit -Parent
# Куди покласти файл: у першу сусідню папку, де вже лежать інсталятори (назва папки неважлива), інакше — у папку гри
$outDir = $kit
$candidates = @("$parent\installers") + @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $kit } | Select-Object -ExpandProperty FullName) + @("$kit\installers")
foreach ($candidate in $candidates) {
    if (-not (Test-Path -LiteralPath $candidate)) { continue }
    $hasInstaller = Get-ChildItem -LiteralPath $candidate -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(Git-.*\.exe|idea.*\.exe|.*jdk.*\.(msi|zip))$' }
    if ($hasInstaller) { $outDir = $candidate; break }
}
$zip = Join-Path $outDir 'ide-config.zip'
Compress-Archive -Path "$stage\*" -DestinationPath $zip -Force
Remove-Item -Recurse -Force $stage

Write-Host ''
Write-Host ('[ OK ] Налаштування «{0}» збережено:' -f $ide.Name) -ForegroundColor Green
Write-Host ('       ' + $zip)
Write-Host ('       розмір: {0} КБ' -f [math]::Round((Get-Item $zip).Length / 1KB))
Write-Host ''
Write-Host 'Файл лежить поруч з інсталяторами. Скопіюй його разом з усією папкою на інші ПК — INSTALL.bat знайде його сам.'
