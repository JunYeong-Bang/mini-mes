param(
    [string]$JdkHome,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$MavenArgs = @('test')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$previousJavaHome = $env:JAVA_HOME
$previousMavenUserHome = $env:MAVEN_USER_HOME
try {
    if (-not $JdkHome) {
        $javaCommand = Get-Command java -ErrorAction Stop
        $JdkHome = Split-Path (Split-Path $javaCommand.Source -Parent) -Parent
    }
    $javaPath = Join-Path $JdkHome 'bin/java.exe'
    $javacPath = Join-Path $JdkHome 'bin/javac.exe'
    if (-not (Test-Path -LiteralPath $javacPath)) {
        throw 'JDK를 찾지 못했습니다. -JdkHome으로 Java 21 JDK 경로를 지정해 주세요.'
    }
    $javaVersion = & $javaPath --version
    if (($javaVersion | Select-Object -First 1) -notmatch '^(openjdk|java) 21[. ]') {
        throw '이 프로젝트는 Java 21을 사용합니다. -JdkHome으로 Java 21 JDK 경로를 지정해 주세요.'
    }
    # 현재 PowerShell 프로세스에서만 변경하고 종료 시 원래 값으로 복원한다.
    $env:JAVA_HOME = $JdkHome
    $env:MAVEN_USER_HOME = Join-Path $projectRoot '.m2-local'
    Push-Location $projectRoot
    try {
        # Windows PowerShell 5.1은 리다이렉트된 native stderr 경고도 오류로 취급한다.
        # Maven의 실제 성공 여부는 경고 유무가 아니라 종료 코드로 판단한다.
        $ErrorActionPreference = 'Continue'
        & (Join-Path $projectRoot 'mvnw.cmd') @MavenArgs
        $mavenExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
        Pop-Location
    }
} finally {
    $env:JAVA_HOME = $previousJavaHome
    $env:MAVEN_USER_HOME = $previousMavenUserHome
}
exit $mavenExitCode
