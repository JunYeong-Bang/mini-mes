param(
    [string]$MySqlHome = 'C:\Program Files\MySQL\MySQL Server 8.0',
    [string]$JdkHome,
    [int]$DbPort = 13306,
    [int]$WebPort = 18080
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$mysql = Join-Path $MySqlHome 'bin/mysql.exe'
$mysqld = Join-Path $MySqlHome 'bin/mysqld.exe'
$mysqladmin = Join-Path $MySqlHome 'bin/mysqladmin.exe'
foreach ($tool in @($mysql, $mysqld, $mysqladmin)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "MySQL 도구가 없습니다: $tool" }
}
if (-not $JdkHome) {
    $JdkHome = Split-Path (Split-Path (Get-Command java).Source -Parent) -Parent
}
$java = Join-Path $JdkHome 'bin/java.exe'
foreach ($port in @($DbPort, $WebPort)) {
    $probe = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $port)
    try { $probe.Start() } finally { $probe.Stop() }
}
$runRoot = Join-Path $projectRoot ('.tools/mysql-verify-' + [guid]::NewGuid().ToString('N'))
$dataDir = Join-Path $runRoot 'data'
New-Item -ItemType Directory -Path $dataDir | Out-Null
$envNames = @('RUN_MYSQL_TESTS', 'MYSQL_TEST_URL', 'MYSQL_TEST_USERNAME', 'MYSQL_TEST_PASSWORD', 'MYSQL_PWD', 'DB_URL', 'DB_USERNAME', 'DB_PASSWORD')
$previousValues = @{}
foreach ($name in $envNames) { $previousValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$dbProcess = $null
$appProcess = $null
$rootPassword = [guid]::NewGuid().ToString('N')
$testPassword = [guid]::NewGuid().ToString('N')
$clientArgs = @('--no-defaults', '--protocol=TCP', '-h', '127.0.0.1', '-P', "$DbPort", '-u', 'root', '--default-character-set=utf8mb4', '--batch', '--skip-column-names')

function Read-Sql([string]$sql) {
    $result = & $mysql @clientArgs '--execute' $sql
    if ($LASTEXITCODE -ne 0) { throw '검증용 MySQL 쿼리가 실패했습니다.' }
    return $result
}

function Wait-Web {
    for ($i = 0; $i -lt 100; $i++) {
        if ($appProcess.HasExited) { throw "앱 실행 실패. 로그 위치: $runRoot" }
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$WebPort/items?q=DEMO-" -TimeoutSec 2
            # HTTP 리스너가 열린 직후에는 CommandLineRunner가 아직 데이터를 넣는 중일 수 있다.
            if ($response.StatusCode -eq 200 -and $response.Content.Contains('DEMO-SHAFT-001') -and $response.Content.Contains('DEMO-BRACKET-001') -and $response.Content.Contains('DEMO-BUSH-001')) { return $response }
        } catch { }
        Start-Sleep -Milliseconds 300
    }
    throw "웹 서버 준비 시간 초과. 로그 위치: $runRoot"
}

function Start-App([string]$logName) {
    $jar = Join-Path $projectRoot 'target/mini-mes-0.0.1-SNAPSHOT.jar'
    $script:appProcess = Start-Process -FilePath $java -ArgumentList @('-jar', "`"$jar`"", '--spring.profiles.active=dev', "--server.port=$WebPort") -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot "$logName.out.log") -RedirectStandardError (Join-Path $runRoot "$logName.err.log")
}

try {
    # 새 GUID 폴더만 초기화한다. 기존 설치의 설정과 데이터 디렉터리는 사용하지 않는다.
    $init = Start-Process -FilePath $mysqld -ArgumentList @('--no-defaults', '--initialize-insecure', "--basedir=`"$MySqlHome`"", "--datadir=`"$dataDir`"") -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput (Join-Path $runRoot 'init.out.log') -RedirectStandardError (Join-Path $runRoot 'init.err.log')
    if ($init.ExitCode -ne 0) { throw "MySQL 초기화 실패. 로그 위치: $runRoot" }
    $dbProcess = Start-Process -FilePath $mysqld -ArgumentList @('--no-defaults', "--basedir=`"$MySqlHome`"", "--datadir=`"$dataDir`"", '--bind-address=127.0.0.1', "--port=$DbPort", '--mysqlx=0', "--log-error=`"$(Join-Path $runRoot 'mysql.log')`"") -WindowStyle Hidden -PassThru
    $env:MYSQL_PWD = $null
    $ready = $false
    for ($i = 0; $i -lt 100; $i++) {
        if ($dbProcess.HasExited) { throw "MySQL 서버 실행 실패. 로그 위치: $runRoot" }
        $ErrorActionPreference = 'Continue'
        & $mysqladmin --no-defaults --protocol=TCP -h 127.0.0.1 -P $DbPort -u root --silent ping 2>$null | Out-Null
        $pingExitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($pingExitCode -eq 0) { $ready = $true; break }
        Start-Sleep -Milliseconds 300
    }
    if (-not $ready) { throw '검증용 MySQL 준비 시간 초과.' }
    Read-Sql "CREATE DATABASE mini_mes_verify CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; CREATE USER 'mini_mes_test'@'127.0.0.1' IDENTIFIED BY '$testPassword'; GRANT SELECT, INSERT, UPDATE, CREATE, ALTER, INDEX, REFERENCES ON mini_mes_verify.* TO 'mini_mes_test'@'127.0.0.1'; ALTER USER 'root'@'localhost' IDENTIFIED BY '$rootPassword';" | Out-Null
    $env:MYSQL_PWD = $rootPassword
    $env:RUN_MYSQL_TESTS = 'true'
    $env:MYSQL_TEST_URL = "jdbc:mysql://127.0.0.1:$DbPort/mini_mes_verify?connectionTimeZone=Asia/Seoul&characterEncoding=UTF-8&sslMode=DISABLED&allowPublicKeyRetrieval=true"
    $env:MYSQL_TEST_USERNAME = 'mini_mes_test'
    $env:MYSQL_TEST_PASSWORD = $testPassword
    $env:DB_URL = $env:MYSQL_TEST_URL
    $env:DB_USERNAME = $env:MYSQL_TEST_USERNAME
    $env:DB_PASSWORD = $testPassword
    Write-Output "검증용 MySQL: 127.0.0.1:$DbPort (기존 DB와 분리)"
    Write-Output "검증 기록: $runRoot"
    & (Join-Path $PSScriptRoot 'maven.ps1') -JdkHome $JdkHome -B -ntp verify
    if ($LASTEXITCODE -ne 0) { throw 'Maven 검증 실패.' }

    Start-App 'app-first'
    $first = Wait-Web
    if (-not $first.Content.Contains('DEMO-SHAFT-001')) { throw 'dev 예시 데이터 화면 검증 실패.' }
    $code = 'HTTP-' + [guid]::NewGuid().ToString('N').Substring(0, 12).ToUpper()
    $url = "http://127.0.0.1:$WebPort/items"
    $body = @{ itemCode = $code; itemName = '검증용 구동축'; drawingNumber = 'VERIFY-DWG'; description = '실제 HTTP 요청으로 등록'; active = 'true' }
    $created = Invoke-WebRequest -UseBasicParsing -Uri $url -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded; charset=UTF-8'
    if (-not $created.Content.Contains($code)) { throw '실제 HTTP 등록 검증 실패.' }
    $duplicate = Invoke-WebRequest -UseBasicParsing -Uri $url -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded; charset=UTF-8'
    if (-not $duplicate.Content.Contains('이미 등록된 품번')) { throw '실제 HTTP 중복 오류 검증 실패.' }
    $id = Read-Sql "SELECT id FROM mini_mes_verify.items WHERE item_code='$code';"
    $editPage = Invoke-WebRequest -UseBasicParsing -Uri "$url/$id/edit"
    $match = [regex]::Match($editPage.Content, 'name="version"[^>]*value="([0-9]+)"')
    if (-not $match.Success) { throw '수정 화면 버전 필드 확인 실패.' }
    $editBody = @{ itemCode = $code; itemName = '수정한 구동축'; version = $match.Groups[1].Value; _active = 'on' }
    Invoke-WebRequest -UseBasicParsing -Uri "$url/$id" -Method Post -Body $editBody -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' | Out-Null
    $saved = Read-Sql "SELECT CONCAT(item_name, ':', active) FROM mini_mes_verify.items WHERE id=$id;"
    if ($saved -ne '수정한 구동축:0') { throw '실제 HTTP 수정·비활성화 검증 실패.' }
    $before = Read-Sql 'SELECT COUNT(*) FROM mini_mes_verify.items;'
    Stop-Process -Id $appProcess.Id
    $appProcess.WaitForExit()
    Start-App 'app-restart'
    Wait-Web | Out-Null
    $after = Read-Sql 'SELECT COUNT(*) FROM mini_mes_verify.items;'
    if ($before -ne $after) { throw '재시작 후 데이터 건수가 변경되었습니다.' }
    $savedAfter = Read-Sql "SELECT CONCAT(item_name, ':', active) FROM mini_mes_verify.items WHERE id=$id;"
    if ($savedAfter -ne '수정한 구동축:0') { throw '재시작 후 수정 데이터 보존 검증 실패.' }
    $history = Read-Sql 'SELECT version FROM mini_mes_verify.flyway_schema_history WHERE success=1;'
    if ($history -ne '1') { throw 'Flyway 이력 검증 실패.' }
    Write-Output 'PASS: 실제 MySQL 통합 테스트, HTTP 등록·중복·수정·비활성화, 앱 재시작 후 데이터 보존, Flyway V1 이력'
} finally {
    if ($appProcess -and -not $appProcess.HasExited) { Stop-Process -Id $appProcess.Id; $appProcess.WaitForExit() }
    if ($dbProcess -and -not $dbProcess.HasExited) {
        $env:MYSQL_PWD = $rootPassword
        $ErrorActionPreference = 'Continue'
        & $mysqladmin --no-defaults --protocol=TCP -h 127.0.0.1 -P $DbPort -u root shutdown 2>$null | Out-Null
        $ErrorActionPreference = 'Stop'
        if (-not $dbProcess.WaitForExit(10000)) { Stop-Process -Id $dbProcess.Id }
    }
    foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name, $previousValues[$name], 'Process') }
    # 검증 파일은 삭제하지 않는다. .gitignore에 포함된 .tools 아래 보존한다.
}
