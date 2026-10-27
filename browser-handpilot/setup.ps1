# 브라우저파일럿 한 번에 설치 (설치 안내 페이지의 "설치 파일"이 내려받아 실행)
#
#   Claude 앱 확인 → Node.js 확인(없으면 설치) → 묶음 zip 내려받기·풀기 → tools/setup.js → 플러그인 등록
#   여러 번 실행해도 안전합니다(설정·비밀 암호는 그대로, 코드만 새것으로).
#
# 원본: Browser Hand-pilot 프로젝트 web/setup.ps1. 고치면 Gobongs 저장소 browser-handpilot/setup.ps1에도 복사(공개 — 민감 정보 금지).
# 테스트용: -InstallDir <폴더>, -SkipPlugin(플러그인 등록 건너뜀), -ZipPath <로컬 zip>(내려받기 대신)

param(
    [string]$InstallDir = $(if ($env:BHP_HOME) { $env:BHP_HOME } else { Join-Path $env:USERPROFILE "BrowserHandPilot" }),
    [switch]$SkipPlugin,
    [string]$ZipPath,
    [switch]$NoOpenFolder  # 자동 업데이트(update.ps1)가 쓸 때: 끝나고 탐색기 창을 열지 않음
)

$ZipUrl = "https://gobong-choi.github.io/Gobongs/browser-handpilot/browser-hand-pilot-market.zip"
$Market = "browser-hand-pilot-market"
$Plugin = "browser-hand-pilot"
$ErrorActionPreference = "Stop"

function Step([string]$t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Ok([string]$t) { Write-Host "   OK  $t" -ForegroundColor Green }
function Note([string]$t) { Write-Host "   ..  $t" -ForegroundColor Yellow }

# 일반 설치판은 %APPDATA%\Claude, 스토어(MSIX)판은 %LOCALAPPDATA%\Claude-Data\<패키지>\ 아래에 있다(2026-10-26 노트북에서 확인).
# 앱 안(MSIX 컨테이너)에서 실행하면 이 경로들이 앱 전용 사본으로 바뀌므로, 설치는 앱 밖 PowerShell에서 한다.
function Find-Claude {
    Get-ChildItem "$env:APPDATA\Claude\claude-code\*\*\claude.exe", "$env:LOCALAPPDATA\Claude-Data\*\claude-code\*\*\claude.exe" -ErrorAction SilentlyContinue |
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

Write-Host "브라우저파일럿 설치 — 설치 위치: $InstallDir" -ForegroundColor White

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

    Write-Host "`n설치 완료! 남은 일(처음 한 번). 이 PC에서 쓰는 크롬은 두 가지입니다:" -ForegroundColor Green
    Write-Host "  - 평소 사용하는 크롬: 사용자가 늘 쓰는 크롬(북마크·로그인 있음)"
    Write-Host "  - Claude 작업용 크롬: 평소 크롬과 별도로 실행되는 크롬 창. Claude가 화면 오른쪽 아래에 띄웁니다(북마크·로그인 없음, 첫 탭 제목 '브라우저파일럿 전용 크롬')"
    Write-Host "  1) 사용자가 Claude 앱에서 새 채팅을 열고 '크롬으로 구글 열어줘'라고 말합니다."
    Write-Host "  2) Claude가 화면 오른쪽 아래에 Claude 작업용 크롬 창을 띄우고, 그 창에 확장 프로그램 관리 화면(chrome://extensions)을 엽니다. 평소 사용하는 크롬에는 아무것도 열리지 않습니다."
    Write-Host "  3) 사용자가 그 Claude 작업용 크롬 창에서 오른쪽 위 '개발자 모드'를 켜고 '압축해제된 확장 프로그램을 로드합니다'를 눌러 이 폴더를 고릅니다: $(Join-Path $InstallDir 'extension')"
    Write-Host "  4) 사용자가 같은 Claude 작업용 크롬 창에서 브라우저파일럿 확장 프로그램 카드의 '세부정보'를 열고 '시크릿 모드에서 허용'을 켠 뒤, 카드의 ID가 kheofijbolmhdnfmplopdgkfcfbmkohn 인지 확인합니다."
    Write-Host "  5) 사용자가 채팅에서 다시 '크롬으로 구글 열어줘'라고 말하면, Claude가 Claude 작업용 크롬에서 작업을 시작합니다."
    Write-Host "  - Claude 작업용 크롬에 확장 프로그램을 이미 올려 두었다면 할 일이 없습니다(새 버전은 확장 프로그램이 스스로 다시 불러옵니다)."
    Write-Host "  - (선택) 평소 사용하는 크롬에 로그인된 상태로도 일을 시키려면, 사용자가 평소 사용하는 크롬에서도 3)~4)를 똑같이 합니다."
    if (-not $NoOpenFolder) { Start-Process explorer.exe (Join-Path $InstallDir "extension") }
    exit 0
}
catch {
    Write-Host "`n설치 실패: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
