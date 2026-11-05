$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$runDirectory = Join-Path $projectRoot "run"

if (-not (Test-Path $runDirectory)) {
    Write-Host "Nenhuma execucao iniciada por start.ps1 foi encontrada."
    exit 0
}

Get-ChildItem -Path $runDirectory -Filter "*.pid" -File | ForEach-Object {
    $processId = [int](Get-Content -Path $_.FullName)
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
    $jarFragment = "$($_.BaseName)\target\$($_.BaseName)-1.0.0.jar"

    if ($process -and $process.CommandLine -and
        $process.CommandLine.Contains($projectRoot) -and
        $process.CommandLine.Contains($jarFragment)) {
        Stop-Process -Id $processId -Force
        Wait-Process -Id $processId -Timeout 10 -ErrorAction SilentlyContinue
        Write-Host "Processo $processId encerrado."
    }

    Remove-Item -LiteralPath $_.FullName -Force
}

Write-Host "Logs preservados em run\logs."
