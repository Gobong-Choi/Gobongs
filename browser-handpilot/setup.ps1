# 브라우저 핸드파일럿 한 번에 설치 (설치 안내 페이지의 "설치 파일"이 내려받아 실행)
#
#   Claude 앱 확인 → Node.js 확인(없으면 설치) → 묶음 zip 내려받기·풀기 → tools/setup.js → 플러그인 등록
#   여러 번 실행해도 안전합니다(설정·비밀 암호는 그대로, 코드만 새것으로).
#
# 원본: Browser Hand-pilot 프로젝트 web/setup.ps1. 고치면 Gobongs 저장소 browser-handpilot/setup.ps1에도 복사(공개 — 민감 정보 금지).
# 테스트용: -InstallDir <폴더>, -SkipPlugin(플러그인 등록 건너뜀), -ZipPath <로컬 zip>(내려받기 대신)

param(
    [string]$InstallDir = $(if ($env:BHP_HOME) { $env:BHP_HOME } else { Join-Path $env:USERPROFILE "BrowserHandPilot" }),
    [switch]$SkipPlugin,
    [string]$ZipPath
)

$ZipUrl = "https://gobong-choi.github.io/Gobongs/browser-handpilot/browser-hand-pilot-market.zip"
$Market = "browser-hand-pilot-market"
$Plugin = "browser-hand-pilot"
$ErrorActionPreference = "Stop"

function Step([string]$t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Ok([string]$t) { Write-Host "   OK  $t" -ForegroundColor Green }
function Note([string]$t) { Write-Host "   ..  $t" -ForegroundColor Yellow }

function Find-Claude {
    Get-ChildItem "$env:APPDATA\Claude\claude-code\*\*\claude.exe" -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Directory.Parent.Name -replace '[^0-9.]', '') } -ErrorAction SilentlyContinue |
        Select-Object -Last 1
}
function Find-Node {
    $n = Get-Command node -ErrorAction SilentlyContinue
    if ($n) { return $n.Source }
    foreach ($p in "$env:ProgramFiles\nodejs\node.exe", "$env:LOCALAPPDATA\Programs\nodejs\node.exe") {
        if (Test-Path $p) { return $p }
    }
}

Write-Host "브라우저 핸드파일럿 설치 — 설치 위치: $InstallDir" -ForegroundColor White

try {
    # 1) Claude 앱
    Step "1/5 Claude 데스크톱 앱"
    $claude = Find-Claude
    if (-not $claude -and -not $SkipPlugin) {
        throw "Claude 데스크톱 앱을 설치·로그인하고 'Code' 탭을 한 번 연 뒤 다시 실행해 주세요."
    }
    if ($claude) { Ok "Claude Code: $($claude.FullName)" }

    # 2) Node.js (도구 서버 실행용)
    Step "2/5 Node.js"
    $node = Find-Node
    if (-not $node) {
        Note "Node.js가 없어 설치합니다(무료). Windows가 권한을 물으면 '예'를 눌러 주세요."
        winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements --silent
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        $node = Find-Node
        if (-not $node) { throw "Node.js 설치를 확인하지 못했습니다. https://nodejs.org 에서 LTS를 설치한 뒤 다시 실행해 주세요." }
    }
    Ok "Node.js: $(& $node -v)"

    # 3) 묶음 내려받기·풀기
    Step "3/5 묶음 내려받기"
    $pkgDir = Join-Path $InstallDir "package"
    New-Item -ItemType Directory -Force $pkgDir | Out-Null
    $zip = Join-Path $env:TEMP "browser-hand-pilot-market.zip"
    if ($ZipPath) { Copy-Item $ZipPath $zip -Force }
    else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing $ZipUrl -OutFile $zip
    }
    if (Test-Path (Join-Path $pkgDir $Market)) { Remove-Item (Join-Path $pkgDir $Market) -Recurse -Force }
    Expand-Archive $zip -DestinationPath $pkgDir -Force
    $marketDir = Join-Path $pkgDir $Market
    $pluginDir = Join-Path $marketDir "plugins\$Plugin"
    Ok "풀어 둔 곳: $marketDir"

    # 4) 확장·설정·비밀 암호
    Step "4/5 크롬 확장·설정·비밀 암호"
    $env:BHP_HOME = $InstallDir
    & $node (Join-Path $pluginDir "tools\setup.js")
    if ($LASTEXITCODE -ne 0) { throw "setup.js 실행 실패" }

    # 5) 플러그인 등록
    Step "5/5 Claude Code에 플러그인 등록"
    if ($SkipPlugin) { Note "건너뜀(-SkipPlugin)" }
    else {
        $exe = $claude.FullName
        $known = (& $exe plugin marketplace list 2>&1) -join "`n"
        if ($known -match [regex]::Escape($Market)) { & $exe plugin marketplace update $Market }
        else { & $exe plugin marketplace add $marketDir }
        $installed = (& $exe plugin list 2>&1) -join "`n"
        if ($installed -match [regex]::Escape("$Plugin@$Market")) { & $exe plugin update "$Plugin@$Market" }
        else { & $exe plugin install "$Plugin@$Market" }
        Ok "플러그인 등록 완료"
    }

    Write-Host "`n설치 완료! 남은 일(직접):" -ForegroundColor Green
    Write-Host "  1) 크롬 주소창에 chrome://extensions → 개발자 모드 켜기"
    Write-Host "  2) '압축해제된 확장 프로그램을 로드합니다' → $(Join-Path $InstallDir 'extension')"
    Write-Host "     (이미 올려 두었다면 카드의 새로고침만)"
    Write-Host "  3) 카드의 '세부정보' → '시크릿 모드에서 허용' 켜기"
    Write-Host "  4) Claude 앱에서 새 채팅 → '크롬 탭 목록 보여줘'"
    Start-Process explorer.exe (Join-Path $InstallDir "extension")
    exit 0
}
catch {
    Write-Host "`n설치 실패: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
