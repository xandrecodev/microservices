$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$runDirectory = Join-Path $projectRoot "run"
$logDirectory = Join-Path $runDirectory "logs"
$services = @(
    @{ Name = "discovery-server"; Port = 8761 },
    @{ Name = "product-service"; Port = 8101 },
    @{ Name = "order-service"; Port = 8201 },
    @{ Name = "api-gateway"; Port = 8700 }
)
$startedProcesses = [System.Collections.Generic.List[int]]::new()

function Stop-StartedServices {
    foreach ($processId in $startedProcesses) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
        if ($process -and $process.CommandLine -and $process.CommandLine.Contains($projectRoot)) {
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        }
    }
}

function Wait-ForHttpResponse {
    param(
        [string]$Uri,
        [string]$ExpectedText
    )

    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 3
            if (-not $ExpectedText -or $response.Content -match $ExpectedText) {
                return
            }
        }
        catch {
            Start-Sleep -Seconds 2
        }

        if ($ExpectedText) {
            Start-Sleep -Seconds 2
        }
    }

    throw "O servico nao ficou pronto dentro do tempo esperado: $Uri"
}

if (Test-Path $runDirectory) {
    foreach ($pidFile in Get-ChildItem -Path $runDirectory -Filter "*.pid" -File -ErrorAction SilentlyContinue) {
        $processId = [int](Get-Content -Path $pidFile.FullName)
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
        if ($process -and $process.CommandLine -and $process.CommandLine.Contains($projectRoot)) {
            throw "Ja existe uma execucao ativa. Execute stop.ps1 antes de iniciar novamente."
        }

        Remove-Item -LiteralPath $pidFile.FullName -Force
    }
}

foreach ($service in $services) {
    $listener = Get-NetTCPConnection -State Listen -LocalPort $service.Port -ErrorAction SilentlyContinue
    if ($listener) {
        throw "A porta $($service.Port) do servico $($service.Name) ja esta em uso."
    }
}

New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

try {
    Push-Location $projectRoot
    try {
        & mvn -B -ntp -DskipTests package
        if ($LASTEXITCODE -ne 0) {
            throw "A compilacao Maven falhou (codigo $LASTEXITCODE)."
        }
    }
    finally {
        Pop-Location
    }

    foreach ($service in $services) {
        $jarPath = Join-Path $projectRoot "$($service.Name)\target\$($service.Name)-1.0.0.jar"
        $stdoutPath = Join-Path $logDirectory "$($service.Name).out.log"
        $stderrPath = Join-Path $logDirectory "$($service.Name).err.log"
        $process = Start-Process -FilePath "java" `
            -ArgumentList @("-jar", "`"$jarPath`"") `
            -WorkingDirectory $projectRoot `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -PassThru

        $startedProcesses.Add($process.Id)
        Set-Content -Path (Join-Path $runDirectory "$($service.Name).pid") -Value $process.Id

        switch ($service.Name) {
            "discovery-server" {
                Wait-ForHttpResponse -Uri "http://localhost:8761/eureka/apps"
            }
            "product-service" {
                Wait-ForHttpResponse -Uri "http://localhost:8101/produtos"
                Wait-ForHttpResponse -Uri "http://localhost:8761/eureka/apps" -ExpectedText "PRODUCT-SERVICE"
            }
            "order-service" {
                Wait-ForHttpResponse -Uri "http://localhost:8761/eureka/apps" -ExpectedText "ORDER-SERVICE"
            }
            "api-gateway" {
                Wait-ForHttpResponse -Uri "http://localhost:8700/produtos"
            }
        }

        Write-Host "$($service.Name) iniciado na porta $($service.Port)."
    }

    Write-Host "Tudo pronto. Gateway: http://localhost:8700"
    Write-Host "Para encerrar os servicos, execute: .\stop.ps1"
}
catch {
    Stop-StartedServices
    Get-ChildItem -Path $runDirectory -Filter "*.pid" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    throw
}
