param(
    [string]$MySqlHome = 'C:\Program Files\MySQL\MySQL Server 8.0',
    [string]$JdkHome = 'C:\Program Files\Zulu\zulu-21',
    [ValidateRange(1024, 65535)][int]$DbPort = 13307,
    [ValidateRange(1024, 65535)][int]$WebPort = 8080,
    [ValidatePattern('^mysql-dev(?:-[a-zA-Z0-9-]+)?$')][string]$DataName = 'mysql-dev',
    [Security.SecureString]$DatabasePassword,
    [switch]$SmokeTest
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$runRoot = Join-Path $projectRoot ".tools/$DataName"
$dataDir = Join-Path $runRoot 'data'
$marker = Join-Path $runRoot 'ready.txt'
$mysql = Join-Path $MySqlHome 'bin/mysql.exe'
$mysqld = Join-Path $MySqlHome 'bin/mysqld.exe'
$mysqladmin = Join-Path $MySqlHome 'bin/mysqladmin.exe'
$java = Join-Path $JdkHome 'bin/java.exe'
foreach ($tool in @($mysql, $mysqld, $mysqladmin, $java, (Join-Path $JdkHome 'bin/javac.exe'))) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "실행 파일이 없습니다: $tool" }
}
$javaVersion = & $java --version
if (($javaVersion | Select-Object -First 1) -notmatch '^(openjdk|java) 21[. ]') { throw 'Java 21 JDK 경로를 지정해 주세요.' }
if ($DbPort -eq 3306 -or $DbPort -eq $WebPort) { throw 'DB 포트는 기존 3306 및 웹 포트와 달라야 합니다.' }
foreach ($port in @($DbPort, $WebPort)) {
    $probe = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $port)
    try { $probe.Start() } catch { throw "포트 $port 사용 중입니다. 기존 프로세스를 종료하지 말고 다른 포트를 지정하세요." } finally { $probe.Stop() }
}
$isNew = -not (Test-Path -LiteralPath $runRoot)
if (-not $isNew) {
    if (-not (Test-Path -LiteralPath $marker) -or (Get-Content -LiteralPath $marker -Raw).Trim() -ne 'mini-mes-local-db-v1') {
        throw "기존 폴더를 초기화하지 않습니다: $runRoot. 최초 준비가 중단됐다면 -DataName mysql-dev-2로 새 폴더를 사용하세요."
    }
}

if (-not $DatabasePassword) {
    $prompt = if ($isNew) { '새 Mini MES 개발 DB 비밀번호를 정하세요 (영문+숫자, 6자 이상)' } else { '처음 정한 Mini MES 개발 DB 비밀번호를 입력하세요' }
    $DatabasePassword = Read-Host $prompt -AsSecureString
    if ($isNew) {
        $confirmation = Read-Host '새 비밀번호를 한 번 더 입력하세요' -AsSecureString
        $confirmationText = (New-Object System.Net.NetworkCredential('', $confirmation)).Password
    }
}
$passwordText = (New-Object System.Net.NetworkCredential('', $DatabasePassword)).Password
if ($passwordText -notmatch '^[\x21-\x7e]{6,72}$' -or $passwordText -notmatch '[A-Za-z]' -or $passwordText -notmatch '[0-9]') {
    throw '영문과 숫자를 포함한 6~72자 비밀번호를 사용하세요. 공백과 한글은 사용하지 않고 기호는 사용할 수 있습니다.'
}
if ($null -ne $confirmationText -and $passwordText -cne $confirmationText) { throw '입력한 두 비밀번호가 다릅니다. 다시 실행해 주세요.' }
$confirmationText = $null

# SQL과 비밀번호를 명령 인자나 파일에 쓰지 않는다. 자식 클라이언트에만 환경변수를 전달한다.
function Invoke-LocalSql([string]$UserName, [string]$Password, [string]$Sql) {
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $mysql
    $startInfo.Arguments = "--no-defaults --protocol=TCP -h 127.0.0.1 -P $DbPort -u $UserName --connect-timeout=2 --default-character-set=utf8mb4 --batch --skip-column-names --skip-reconnect"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['MYSQL_PWD'] = $Password
    $client = New-Object Diagnostics.Process
    $client.StartInfo = $startInfo
    try {
        $null = $client.Start()
        # .NET Framework의 ProcessStartInfo에는 StandardInputEncoding이 없으므로 바이트로 전송한다.
        $sqlBytes = [Text.Encoding]::UTF8.GetBytes($Sql + "`n")
        $client.StandardInput.BaseStream.Write($sqlBytes, 0, $sqlBytes.Length)
        $client.StandardInput.BaseStream.Flush()
        $client.StandardInput.Close()
        $output = $client.StandardOutput.ReadToEnd()
        $errorOutput = $client.StandardError.ReadToEnd()
        $client.WaitForExit()
        if ($client.ExitCode -ne 0) { throw "개발 DB 접속/SQL 실행 실패: $errorOutput" }
        return $output.Trim()
    } finally { $client.Dispose() }
}

$dbProcess = $null
$appProcess = $null
$sessionLock = $null
$shutdownPassword = ''
$envNames = @('DB_URL', 'DB_USERNAME', 'DB_PASSWORD', 'SERVER_PORT', 'SPRING_PROFILES_ACTIVE')
$previousValues = @{}
foreach ($name in $envNames) { $previousValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    if ($isNew) {
        New-Item -ItemType Directory -Path $runRoot | Out-Null
        New-Item -ItemType Directory -Path $dataDir | Out-Null
    }
    $sessionLock = [IO.File]::Open((Join-Path $runRoot 'session.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $logRoot = Join-Path $runRoot ('run-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $logRoot | Out-Null
    if ($isNew) {
        Write-Output 'Mini MES 전용 새 DB 폴더를 준비합니다. 비밀번호를 기억해 두세요.'
        $init = Start-Process -FilePath $mysqld -ArgumentList @('--no-defaults', '--initialize-insecure', "--basedir=`"$MySqlHome`"", "--datadir=`"$dataDir`"", "--log-error=`"$(Join-Path $logRoot 'init.mysql.log')`"") -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot 'init.out.log') -RedirectStandardError (Join-Path $logRoot 'init.err.log')
        # Windows PowerShell 5.1では先にハンドルを取得しないと終了コードがnullになることがある。
        $null = $init.Handle
        if (-not $init.WaitForExit(60000)) { Stop-Process -Id $init.Id; throw "DB 초기화 시간 초과. 로그: $logRoot" }
        if ($init.ExitCode -ne 0) { throw "DB 초기화 실패. 로그: $logRoot" }
    } else { $shutdownPassword = $passwordText }
    $dbProcess = Start-Process -FilePath $mysqld -ArgumentList @('--no-defaults', '--no-monitor', "--basedir=`"$MySqlHome`"", "--datadir=`"$dataDir`"", '--bind-address=127.0.0.1', "--port=$DbPort", '--mysqlx=0', '--general-log=OFF', '--slow-query-log=OFF', "--log-error=`"$(Join-Path $logRoot 'mysql.log')`"") -WindowStyle Hidden -PassThru
    $ready = $false
    for ($i = 0; $i -lt 100; $i++) {
        if ($dbProcess.HasExited) { throw "DB 실행 실패. 로그: $logRoot" }
        try {
            $loginPassword = if ($isNew) { '' } else { $passwordText }
            Invoke-LocalSql 'root' $loginPassword 'SELECT 1;' | Out-Null
            $ready = $true
            break
        } catch {
            if ($_.Exception.Message -match 'Access denied') { throw '개발 DB 비밀번호가 다릅니다. 처음 정한 비밀번호로 다시 실행하세요. 데이터를 초기화하지 않습니다.' }
            if ($_.Exception.Message -notmatch "Can't connect") { throw }
        }
        Start-Sleep -Milliseconds 300
    }
    if (-not $ready) { throw "DB 준비 시간 초과. 로그: $logRoot" }
    if ($isNew) {
        $passwordSql = $passwordText.Replace('\', '\\').Replace("'", "''")
        Invoke-LocalSql 'root' '' "CREATE DATABASE mini_mes CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; CREATE USER 'mini_mes_app'@'127.0.0.1' IDENTIFIED BY '$passwordSql'; GRANT SELECT, INSERT, UPDATE, CREATE, ALTER, INDEX, REFERENCES ON mini_mes.* TO 'mini_mes_app'@'127.0.0.1'; ALTER USER 'root'@'localhost' IDENTIFIED BY '$passwordSql';" | Out-Null
        $shutdownPassword = $passwordText
        $passwordSql = $null
        # 준비를 마친 전용 폴더만 다음 실행에서 재사용한다.
        Set-Content -LiteralPath $marker -Value 'mini-mes-local-db-v1' -Encoding ASCII
    }
    Invoke-LocalSql 'mini_mes_app' $passwordText 'USE mini_mes; SELECT 1;' | Out-Null
    $env:DB_URL = "jdbc:mysql://127.0.0.1:$DbPort/mini_mes?connectionTimeZone=Asia/Seoul&characterEncoding=UTF-8&sslMode=DISABLED&allowPublicKeyRetrieval=true"
    $env:DB_USERNAME = 'mini_mes_app'
    $env:DB_PASSWORD = $passwordText
    $env:SERVER_PORT = "$WebPort"
    $env:SPRING_PROFILES_ACTIVE = 'dev'
    Write-Output "개발 DB: 127.0.0.1:$DbPort/mini_mes"
    Write-Output "데이터 보존 위치: $dataDir"
    Write-Output "웹 화면: http://127.0.0.1:$WebPort/items"
    if ($SmokeTest) {
        & (Join-Path $PSScriptRoot 'maven.ps1') -JdkHome $JdkHome -B -ntp '-DskipTests' package
        if ($LASTEXITCODE -ne 0) { throw '패키징 실패.' }
        $jar = Join-Path $projectRoot 'target/mini-mes-0.0.1-SNAPSHOT.jar'
        $appProcess = Start-Process -FilePath $java -ArgumentList @('-jar', "`"$jar`"") -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot 'app.out.log') -RedirectStandardError (Join-Path $logRoot 'app.err.log')
        $webReady = $false
        for ($i = 0; $i -lt 150; $i++) {
            if ($appProcess.HasExited) { throw "앱 실행 실패. 로그: $logRoot" }
            try {
                $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$WebPort/items?q=DEMO-" -TimeoutSec 2
                if ($response.StatusCode -eq 200 -and $response.Content.Contains('DEMO-SHAFT-001') -and $response.Content.Contains('DEMO-BRACKET-001') -and $response.Content.Contains('DEMO-BUSH-001')) { $webReady = $true; break }
            } catch { }
            Start-Sleep -Milliseconds 300
        }
        if (-not $webReady) { throw "화면 확인 시간 초과. 로그: $logRoot" }
        $count = Invoke-LocalSql 'mini_mes_app' $passwordText 'SELECT COUNT(*) FROM mini_mes.items;'
        $history = Invoke-LocalSql 'mini_mes_app' $passwordText 'SELECT version FROM mini_mes.flyway_schema_history WHERE success=1;'
        Write-Output "PASS: 실제 MySQL 접속, HTTP 품목 화면, dev 예시, Flyway 이력($history), 보존된 품목 $count 건"
    } else {
        Write-Output '중지: Ctrl+C. 다음 실행에는 처음 정한 개발 DB 비밀번호를 입력하세요.'
        & (Join-Path $PSScriptRoot 'maven.ps1') -JdkHome $JdkHome -B -ntp spring-boot:run '-Dspring-boot.run.profiles=dev'
        if ($LASTEXITCODE -ne 0) { throw '앱 실행에 실패했습니다. 위쪽의 첫 오류 로그를 확인하세요.' }
    }
} finally {
    if ($appProcess -and -not $appProcess.HasExited) { Stop-Process -Id $appProcess.Id; $appProcess.WaitForExit() }
    if ($dbProcess -and -not $dbProcess.HasExited) {
        # 직접 시작한 DB를 정상 종료한다. SQL은 이 전용 포트에만 전달한다.
        try { Invoke-LocalSql 'root' $shutdownPassword 'SHUTDOWN;' | Out-Null } catch { Write-Warning '전용 DB의 정상 종료가 실패해 직접 시작한 프로세스만 종료합니다.' }
        if (-not $dbProcess.WaitForExit(10000)) { Stop-Process -Id $dbProcess.Id; $dbProcess.WaitForExit() }
    }
    if ($sessionLock) { $sessionLock.Dispose() }
    foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name, $previousValues[$name], 'Process') }
    $passwordText = $null
    # 데이터 폴더는 삭제하지 않는다. 기존 3306 서버에는 접속하지 않는다.
}
