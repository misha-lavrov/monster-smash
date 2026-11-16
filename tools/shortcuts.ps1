# Створює ярлики на робочому столі. Запускається з setup-station.bat (робоча папка = папка проєкту).
# Для тестів можна задати змінну SHORTCUT_DIR — тоді ярлики створяться там, а не на робочому столі.
#
# Чому "створити з ASCII-назвою, а потім перейменувати": COM-об'єкт WScript.Shell псує у назві файлу
# символи, яких немає в ANSI-кодуванні Windows (▶ ↺ ■). Перейменування ж через .NET працює з Unicode.

$ErrorActionPreference = 'Stop'

$root = (Get-Location).Path
$desktop = if ($env:SHORTCUT_DIR) { $env:SHORTCUT_DIR } else { [Environment]::GetFolderPath('Desktop') }
$shell = New-Object -ComObject WScript.Shell

$items = @(
    @{ temp = 'oipz-start'; name = '▶ ЗАПУСТИТИ гру'; target = 'start.bat' },
    @{ temp = 'oipz-reset'; name = '↺ СКИНУТИ гру';   target = 'reset.bat' },
    @{ temp = 'oipz-stop';  name = '■ Зупинити гру';  target = 'stop.bat'  }
)

foreach ($item in $items) {
    $tempPath  = Join-Path $desktop ($item.temp + '.lnk')
    $finalPath = Join-Path $desktop ($item.name + '.lnk')

    $lnk = $shell.CreateShortcut($tempPath)
    $lnk.TargetPath       = Join-Path $root $item.target
    $lnk.WorkingDirectory = $root
    $lnk.WindowStyle      = 7        # згорнуте вікно, щоб не закривати браузер
    $lnk.Save()

    try {
        if (Test-Path -LiteralPath $finalPath) { Remove-Item -LiteralPath $finalPath -Force }
        Move-Item -LiteralPath $tempPath -Destination $finalPath -Force
    } catch {
        # не вийшло дати гарну назву — лишаємо ASCII-назву (oipz-start.lnk), ярлик усе одно працює
    }
}
