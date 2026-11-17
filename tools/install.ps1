# =====================================================================================
#  МАЙСТЕР-КЛАС «Побий монстра!» — підготовка ПК одним подвійним кліком (INSTALL.bat)
#
#  Що робить:
#    1) шукає інсталятори Git, JDK і IntelliJ IDEA в сусідніх папках (поруч із папкою monster-smash; назва папки неважлива)
#    2) встановлює те, чого на ПК ще немає (потрібен адміністратор — Windows спитає про дозвіл)
#    3) гру НЕ копіює: вона працює там, де лежить (наприклад, у папці на диску D:, куди ти скопіював усе заздалегідь)
#    4) створює ярлики на робочому столі й перевіряє ПК (setup-station.bat → check.bat)
#    5) за наявності ide-config.zip — готує налаштування IntelliJ (щоб не клікати «Далі» на кожному ПК)
#
#  Те, що вже встановлено, пропускається. Лог: C:\ProgramData\monster-install-*.log
#
#  Змінні для тестів (звичайним користувачам не потрібні):
#    OIPZ_DRYRUN=1  — нічого не встановлювати, лише показати команди     OIPZ_FORCE=1 — встановлювати, навіть якщо вже є
#    OIPZ_TARGET=…  — скопіювати гру в цю папку (за замовчуванням — НЕ копіювати)   OIPZ_NOELEVATE=1 — не просити права адміністратора
#    OIPZ_NOASK=1   — не ставити запитань
# =====================================================================================

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$dry     = [bool]$env:OIPZ_DRYRUN
$force   = [bool]$env:OIPZ_FORCE
$noElev  = [bool]$env:OIPZ_NOELEVATE
$noAsk   = [bool]$env:OIPZ_NOASK
$phase   = if ($env:OIPZ_PHASE) { $env:OIPZ_PHASE } else { 'user' }
$kit     = ([string]$env:KIT_DIR).TrimEnd('\')
$target  = if ($env:OIPZ_TARGET) { $env:OIPZ_TARGET } else { $kit }       # за замовчуванням гра працює «на місці», без копіювання
$repoUrl = 'https://github.com/misha-lavrov/monster-smash.git'
$logDir  = if ($env:ProgramData -and (Test-Path $env:ProgramData)) { $env:ProgramData } else { $env:TEMP }
$logFile = Join-Path $logDir ("monster-install-{0}.log" -f $phase)

# ---------------------------------------------------------------- допоміжні функції
function Say($text, $color = 'White') {
    Write-Host $text -ForegroundColor $color
    try { Add-Content -LiteralPath $logFile -Value ("{0:HH:mm:ss} {1}" -f (Get-Date), $text) -Encoding UTF8 } catch { }
}
function Ok($text)   { Say ("  [ OK ] " + $text) 'Green' }
function Warn($text) { Say ("  [WARN] " + $text) 'Yellow' }
function Bad($text)  { Say ("  [FAIL] " + $text) 'Red' }
function Step($text) { Say ''; Say ("=== " + $text) 'Cyan' }

function Test-Admin {
    if ($env:OIPZ_FAKE_ELEVATE -and $phase -ne 'machine') { return $false }     # лише для тестів: вдаємо, що прав адміністратора немає
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Шукає інсталятор за шаблонами: у папці installers всередині гри, у папці над грою, у ВСІХ сусідніх папках
# (щоб назва папки з інсталяторами була будь-яка, наприклад «3-інсталятори») і в самій папці гри
function Find-Installer([string[]]$patterns) {
    $parent = Split-Path $kit -Parent
    $siblings = @()
    if ($parent) { $siblings = @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $kit } | Select-Object -ExpandProperty FullName) }
    $dirs = (@("$kit\installers", "$parent\installers", $parent) + $siblings + @($kit)) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
    foreach ($dir in $dirs) {
        foreach ($pattern in $patterns) {
            $found = Get-ChildItem -LiteralPath $dir -Filter $pattern -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($found) { return $found }
        }
    }
    return $null
}

function Refresh-Env {                      # щоб щойно встановлені git/java було видно в цьому ж вікні
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
    $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    if ($javaHome) { $env:JAVA_HOME = $javaHome }
}

function Test-Git {
    [bool](Get-Command git -ErrorAction SilentlyContinue) -or (Test-Path "$env:ProgramFiles\Git\cmd\git.exe")
}

# Версія JDK береться з файла release (запускати javac не треба)
function Get-JdkMajor([string]$jdkHome) {
    $release = Join-Path $jdkHome 'release'
    if (-not (Test-Path -LiteralPath $release)) { return 0 }
    $line = Get-Content -LiteralPath $release -ErrorAction SilentlyContinue | Where-Object { $_ -match '^JAVA_VERSION=' } | Select-Object -First 1
    if ($line -match 'JAVA_VERSION="(\d+)(?:\.(\d+))?') {
        if ($Matches[1] -eq '1') { return [int]$Matches[2] }       # 1.8 → 8
        return [int]$Matches[1]
    }
    return 0
}

function Find-Jdk {                          # найновіший JDK 17+ на цьому ПК (або $null)
    $roots = @("$target\jdk", $env:JAVA_HOME)
    foreach ($pattern in @("$env:ProgramFiles\Eclipse Adoptium\jdk-*", "$env:ProgramFiles\Java\jdk-*", "$env:ProgramFiles\Microsoft\jdk-*",
                           "$env:ProgramFiles\Amazon Corretto\jdk*", "$env:ProgramFiles\Zulu\zulu-*", "$env:USERPROFILE\.jdks\*", 'C:\Java\jdk*')) {
        $roots += (Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    }
    $best = $null
    foreach ($root in ($roots | Where-Object { $_ -and (Test-Path -LiteralPath "$_\bin\javac.exe") })) {
        $major = Get-JdkMajor $root
        if ($major -ge 17 -and (-not $best -or $major -gt $best.Major)) { $best = [pscustomobject]@{ Path = $root; Major = $major } }
    }
    return $best
}

function Find-Idea {
    $dirs = @()
    $dirs += Get-ChildItem -Path "$env:ProgramFiles\JetBrains\IntelliJ IDEA*" -Directory -ErrorAction SilentlyContinue
    $dirs += Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\IntelliJ IDEA*" -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $dirs) { if (Test-Path "$($dir.FullName)\bin\idea64.exe") { return "$($dir.FullName)\bin\idea64.exe" } }
    return $null
}

function Desktop-Folder { if ($env:SHORTCUT_DIR) { $env:SHORTCUT_DIR } else { [Environment]::GetFolderPath('Desktop') } }

function Run-Installer($name, $file, $arguments) {
    Say ("  -> {0}: {1}" -f $name, $file.Name)
    Say ("     команда: `"{0}`" {1}" -f $file.FullName, $arguments) 'Gray'
    if ($dry) { Warn 'пробний запуск — інсталятор не виконується'; return }
    try {
        $p = Start-Process -FilePath $file.FullName -ArgumentList $arguments -Wait -PassThru
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { Ok ("{0}: інсталятор завершився успішно (код {1})" -f $name, $p.ExitCode) }
        else { Bad ("{0}: інсталятор повернув код {1}" -f $name, $p.ExitCode) }
    } catch { Bad ("{0}: не вдалося запустити інсталятор — {1}" -f $name, $_.Exception.Message) }
}

# ---------------------------------------------------------------- що шукаємо й що вже є
$gitFile  = Find-Installer @('Git-*-64-bit.exe', 'Git-*.exe')
$jdkMsi   = Find-Installer @('*jdk*.msi', 'OpenJDK*.msi')
$jdkExe   = Find-Installer @('jdk-*_windows-x64_bin.exe')
$jdkZip   = Find-Installer @('*jdk*.zip', 'OpenJDK*.zip')
$ideaFile = Find-Installer @('idea*.exe')
$ideCfg   = Find-Installer @('ide-config.zip')

$needGit  = $force -or -not (Test-Git)
$jdkNow   = Find-Jdk
$needJdk  = $force -or -not $jdkNow
$needIdea = $force -or -not (Find-Idea)

# ================================================================ ФАЗА 1 (з правами адміністратора): встановлення програм
function Install-Machine {
    Step 'Встановлення програм'
    if (-not $dry -and -not (Test-Admin)) { Warn 'вікно запущено без прав адміністратора — встановлення може не вдатись' }

    if ($needGit) {
        if ($gitFile) { Run-Installer 'Git' $gitFile '/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS' }
        else { Warn 'Git потрібен, але інсталятор не знайдено (шукав Git-*.exe у папці installers)' }
    } else { Ok 'Git уже встановлено — пропускаю' }

    if ($needJdk) {
        if ($jdkMsi) {
            $isTemurin = $jdkMsi.Name -match 'OpenJDK|temurin'
            $features  = if ($isTemurin) { ' ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome' } else { '' }
            Run-Installer 'JDK' (Get-Item -LiteralPath 'C:\Windows\System32\msiexec.exe') ("/i `"{0}`" /qn /norestart{1}" -f $jdkMsi.FullName, $features)
        }
        elseif ($jdkExe) { Run-Installer 'JDK' $jdkExe '/s' }
        elseif ($jdkZip) { Ok 'JDK буде розпаковано з ZIP у папку гри (адміністратор не потрібен) — див. нижче' }
        else { Warn 'JDK потрібен, але інсталятор не знайдено (шукав *jdk*.msi / .exe / .zip у папці installers)' }
    } else { Ok ("JDK {0} уже є — пропускаю" -f $jdkNow.Major) }

    if ($needIdea) {
        if ($ideaFile) { Run-Installer 'IntelliJ IDEA' $ideaFile '/S /D=C:\Program Files\JetBrains\IntelliJ IDEA' }
        else { Warn 'IntelliJ IDEA потрібна, але інсталятор не знайдено (шукав idea*.exe у папці installers)' }
    } else { Ok 'IntelliJ IDEA уже встановлена — пропускаю' }
}

if ($phase -eq 'machine') {
    Say ("Фаза встановлення програм · {0:yyyy-MM-dd HH:mm}" -f (Get-Date)) 'Cyan'
    Install-Machine
    Say ''
    Say 'Готово. Це вікно можна закрити.' 'Green'
    if (-not $noAsk -and -not $dry) { Start-Sleep -Seconds 3 }
    exit 0
}

# ================================================================ ФАЗА 2 (звичайний користувач): гра, ярлики, перевірка
Say '=====================================================' 'Cyan'
Say '   ПОБИЙ МОНСТРА — підготовка комп''ютера' 'Cyan'
Say '=====================================================' 'Cyan'
if ($dry) { Say '   (ПРОБНИЙ ЗАПУСК: програми не встановлюються)' 'Yellow' }

Step '1/5  Що знайдено'
Say ("  Папка гри                   : {0}" -f $kit)
if ($target -ne $kit) { Say ("  Копіюємо гру в              : {0}" -f $target) }
foreach ($row in @(@('Git', $gitFile), @('JDK (msi)', $jdkMsi), @('JDK (exe)', $jdkExe), @('JDK (zip)', $jdkZip), @('IntelliJ IDEA', $ideaFile), @('Налаштування IDE', $ideCfg))) {
    if ($row[1]) { Say ("  {0,-17}: {1}" -f $row[0], $row[1].Name) } else { Say ("  {0,-17}: —" -f $row[0]) 'DarkGray' }
}
Say ''
Say ("  Уже є на цьому ПК:  Git — {0};  JDK — {1};  IntelliJ — {2}" -f $(if (Test-Git) { 'так' } else { 'ні' }), $(if ($jdkNow) { $jdkNow.Major } else { 'ні' }), $(if (Find-Idea) { 'так' } else { 'ні' }))

Step '2/5  Встановлення програм'
$anyInstall = ($needGit -and $gitFile) -or ($needJdk -and ($jdkMsi -or $jdkExe)) -or ($needIdea -and $ideaFile)
if (-not $anyInstall) {
    Ok 'Нічого встановлювати не потрібно'
} elseif ($dry -or $noElev -or (Test-Admin)) {
    Install-Machine                      # адміністратор уже є (або це пробний запуск / тест)
} else {
    Say '  Зараз Windows спитає дозволу (UAC). Натисни «Так» — інакше програми не встановляться.' 'Yellow'
    $script = Join-Path $kit 'tools\install.ps1'
    $command = "`$env:OIPZ_PHASE='machine'; `$env:KIT_DIR='$kit'; `$env:OIPZ_FORCE='$($env:OIPZ_FORCE)'; `$env:OIPZ_TARGET='$target'; " +
               "Get-Content -Raw -Encoding UTF8 -LiteralPath '$script' | Invoke-Expression"
    $runAs = if ($env:OIPZ_FAKE_ELEVATE) { @{} } else { @{ Verb = 'RunAs' } }     # OIPZ_FAKE_ELEVATE — лише для тестів: без запиту UAC
    try {
        $p = Start-Process powershell @runAs -Wait -PassThru -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command
        Say ("  вікно встановлення завершилось (код {0}); лог: {1}" -f $p.ExitCode, (Join-Path $logDir 'monster-install-machine.log')) 'Gray'
    } catch {
        Bad ('Дозволу адміністратора не надано — програми не встановлено (' + $_.Exception.Message + ')')
    }
}
Refresh-Env

Step '3/5  Папка гри'
$sameFolder = $false
try { $sameFolder = ((Resolve-Path -LiteralPath $kit).Path.TrimEnd('\') -ieq (Resolve-Path -LiteralPath $target -ErrorAction Stop).Path.TrimEnd('\')) } catch { }
if ($sameFolder) {
    if (Test-Path -LiteralPath "$kit\src\Main.java") { Ok ("Гра вже лежить тут — копіювати нічого не треба: {0}" -f $kit) }
    else { Bad ("У цій папці немає файлів гри (src\Main.java). Скопіюй на комп'ютер усю папку цілком і запусти INSTALL.bat звідти: {0}" -f $kit) }
    try {                                   # гра на флешці працюватиме, але повільно й ненадійно
        if ((New-Object IO.DriveInfo (Split-Path $kit -Qualifier)).DriveType -eq 'Removable') {
            Warn 'Папка лежить на змінному носії (флешці). Краще скопіювати її на диск D: і запускати звідти.'
        }
    } catch { }
    if ($kit -match '[^\u0000-\u007F]') { Say '  [INFO] У шляху є кирилиця. Зазвичай це працює, але надійніше латиницею, наприклад D:\masterclass\monster-smash' 'DarkGray' }
} elseif (Test-Path -LiteralPath "$kit\src\Main.java") {
    robocopy $kit $target /E /XD installers out jdk _original /XF STATION .server.pid .server-*.pid ide-config.zip /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -lt 8) { Ok ("Гру скопійовано в {0}" -f $target) } else { Bad ("robocopy повернув код {0}" -f $LASTEXITCODE) }
} elseif (Test-Git) {
    Say '  У папці немає файлів гри — завантажую з GitHub...'
    git clone $repoUrl $target 2>&1 | ForEach-Object { Say ("    " + $_) 'Gray' }
    if (Test-Path -LiteralPath "$target\src\Main.java") { Ok 'Гру завантажено з GitHub' } else { Bad 'не вдалося завантажити гру' }
} else {
    Bad 'Немає ні файлів гри, ні git — копіювати нічого'
}

$jdkAfter = Find-Jdk
if ((-not $jdkAfter -or $force) -and $jdkZip -and (Test-Path -LiteralPath $target)) {
    Say '  Розпаковую портативний JDK у папку гри...'
    $tmp = Join-Path $target '_jdk_unzip'
    try {
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        Expand-Archive -LiteralPath $jdkZip.FullName -DestinationPath $tmp -Force
        $jdkDir = Get-ChildItem $tmp -Recurse -Directory | Where-Object { Test-Path "$($_.FullName)\bin\javac.exe" } | Select-Object -First 1
        if ($jdkDir) {
            if (Test-Path "$target\jdk") { Remove-Item -Recurse -Force "$target\jdk" }
            Move-Item -LiteralPath $jdkDir.FullName -Destination "$target\jdk"
            Ok ("JDK розпаковано: {0}\jdk" -f $target)
        } else { Bad 'у ZIP не знайдено папки з bin\javac.exe' }
    } catch { Bad ('не вдалося розпакувати JDK: ' + $_.Exception.Message) }
    finally { if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue } }
    $jdkAfter = Find-Jdk
}

Step '4/5  Ярлики й перевірка ПК'
if (Test-Path -LiteralPath "$target\setup-station.bat") {
    $env:OIPZ_NOPAUSE = '1'
    cmd /c "`"$target\setup-station.bat`" < nul" 2>&1 | ForEach-Object { Say ("    " + $_) 'Gray' }
} else { Bad 'setup-station.bat не знайдено — ярлики не створено' }

Step '5/5  IntelliJ IDEA'
$ideaExe = Find-Idea
if ($ideCfg) {
    $jbRoot = Join-Path $env:APPDATA 'JetBrains'
    $has = Get-ChildItem -LiteralPath $jbRoot -Directory -Filter 'IntelliJIdea*' -ErrorAction SilentlyContinue | Where-Object { Test-Path "$($_.FullName)\options" }
    if ($has -and -not $force) { Warn 'Налаштування IntelliJ на цьому ПК вже існують — не перезаписую' }
    else {
        try { New-Item -ItemType Directory -Force $jbRoot | Out-Null; Expand-Archive -LiteralPath $ideCfg.FullName -DestinationPath $jbRoot -Force; Ok 'Налаштування IntelliJ застосовано (ide-config.zip)' }
        catch { Bad ('не вдалося застосувати ide-config.zip: ' + $_.Exception.Message) }
    }
} else { Say '  ide-config.zip не знайдено — перший запуск IntelliJ налаштуєш вручну (3–5 кліків, див. інструкцію)' 'Gray' }

if ($ideaExe) {
    $desk = Desktop-Folder
    if (-not (Get-ChildItem -LiteralPath $desk -Filter '*IntelliJ*.lnk' -ErrorAction SilentlyContinue)) {
        try {
            $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desk 'IntelliJ IDEA.lnk'))
            $lnk.TargetPath = $ideaExe; $lnk.WorkingDirectory = Split-Path $ideaExe -Parent; $lnk.Save()
            Ok 'Ярлик «IntelliJ IDEA» створено на робочому столі'
        } catch { Warn 'не вдалося створити ярлик IntelliJ' }
    }
}

# ---------------------------------------------------------------- підсумок
Step 'ПІДСУМОК'
$gitOk  = Test-Git
$jdkOk  = [bool]$jdkAfter
$ideaOk = [bool]$ideaExe
$gameOk = Test-Path -LiteralPath "$target\src\Main.java"
Say ("  Git ............ {0}" -f $(if ($gitOk) { 'є' } else { 'НЕМАЄ' })) $(if ($gitOk) { 'Green' } else { 'Red' })
Say ("  JDK 17+ ........ {0}" -f $(if ($jdkOk) { "є (версія $($jdkAfter.Major))" } else { 'НЕМАЄ' })) $(if ($jdkOk) { 'Green' } else { 'Red' })
Say ("  IntelliJ IDEA .. {0}" -f $(if ($ideaOk) { 'є' } else { 'НЕМАЄ' })) $(if ($ideaOk) { 'Green' } else { 'Red' })
Say ("  Гра ({0}) .. {1}" -f $target, $(if ($gameOk) { 'є' } else { 'НЕМАЄ' })) $(if ($gameOk) { 'Green' } else { 'Red' })

Say ''
if ($gitOk -and $jdkOk -and $ideaOk -and $gameOk) { Say '  ВСЕ ГОТОВО.' 'Green' } else { Say '  Є проблеми — дивись рядки [FAIL]/НЕМАЄ вище. Лог: ' 'Yellow'; Say ('  ' + $logFile) 'Yellow' }
Say ''
Say '  Що далі (перший раз на цьому ПК):' 'White'
Say ("    1. Відкрий IntelliJ IDEA → File → Open → папка {0} → «New Window» → «Trust Project»." -f $target)
Say '    2. Якщо напише «Project JDK is not defined» — натисни Setup JDK і вибери встановлений JDK.'
Say '    3. Двічі клікни на робочому столі «▶ ЗАПУСТИТИ гру» — відкриється Chrome з грою. Далі діти натискають зелений ▶ в IntelliJ.'

if ($ideaOk -and $gameOk -and -not $noAsk -and -not $dry) {
    Say ''
    $answer = Read-Host '  Відкрити IntelliJ із грою зараз? (Enter = так, N = ні)'
    if ($answer -notmatch '^[nNнН]') { Start-Process -FilePath $ideaExe -ArgumentList ('"' + $target + '"') }
}
$allOk = $gitOk -and $jdkOk -and $ideaOk -and $gameOk
exit $(if ($allOk) { 0 } else { 1 })
