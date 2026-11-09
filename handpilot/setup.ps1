# 핸드파일럿 한 번에 설치 (설치 안내 페이지의 "설치 파일"이 내려받아 실행)
#
#   Claude 앱 확인 → 설치 안내 사이트에서 공개 묶음(zip) 받기(확인값 검사, GitHub·Git 필요 없음) → install.ps1 → 주간 업데이트 확인(선택)
#   이미 설치돼 있으면 최신으로 맞추고 설치를 다시 확인합니다(여러 번 실행해도 안전).
#   예전 방식(GitHub clone, 폴더에 .git 있음)으로 설치된 PC는 지금처럼 git으로 받습니다.
#
# 원본: handpilot 저장소 web/setup.ps1. 고치면 Gobongs 저장소 handpilot/setup.ps1에도 복사(공개 — 민감 정보 금지).
# 테스트용: -Dir <폴더>, -SkipPlugin(플러그인 등록·바로가기 건너뜀), -NoPrompt(질문 없음, 주간 확인 안 켬)
#           또는 환경 변수 HANDPILOT_DIR, HANDPILOT_SETUP_TEST=1 (설치 파일 .cmd로 시험할 때), HANDPILOT_SITE_URL(가짜 사이트)

param(
    [string]$Dir = $(if ($env:HANDPILOT_DIR) { $env:HANDPILOT_DIR } else { Join-Path $env:USERPROFILE "handpilot" }),
    [switch]$SkipPlugin,
    [switch]$NoPrompt
)

$Site = if ($env:HANDPILOT_SITE_URL) { $env:HANDPILOT_SITE_URL.TrimEnd("/") } else { "https://gobong-choi.github.io/Gobongs/handpilot" }
$ErrorActionPreference = "Stop"
if ($env:HANDPILOT_SETUP_TEST -eq "1") { $SkipPlugin = $true; $NoPrompt = $true }

function Step([string]$t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Ok([string]$t) { Write-Host "   OK  $t" -ForegroundColor Green }
function Note([string]$t) { Write-Host "   ..  $t" -ForegroundColor Yellow }

function Find-Claude {
    # Claude 앱 안의 Claude Code(플러그인 등록에 씀). 앱 업데이트로 자리가 바뀌어 와서 여러 곳을 본다 — scripts/common.ps1 Find-ClaudeExe와 같은 순서
    #  ① 환경 변수 HANDPILOT_CLAUDE(직접 지정) ② 실행 중인 claude.exe 중 claude-code 경로(프로세스 목록 — 앱 폴더 전환과 상관없음)
    #  ③ %LOCALAPPDATA%\Claude-Data\claude_*\claude-code (2026-11 앱 4.23118에서 확인) ④ %APPDATA%\Claude\claude-code (예전)
    #  ⑤ %LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\claude-code (예전 스토어판을 앱 밖에서 볼 때)
    if ($env:HANDPILOT_CLAUDE -and (Test-Path $env:HANDPILOT_CLAUDE)) { return $env:HANDPILOT_CLAUDE }
    $paths = @()
    try {
        $paths += Get-CimInstance Win32_Process -Filter "Name='claude.exe'" -ErrorAction Stop |
            Where-Object { $_.ExecutablePath -like '*\claude-code\*' } | ForEach-Object { $_.ExecutablePath }
    } catch {}
    foreach ($pat in @("$env:LOCALAPPDATA\Claude-Data\claude_*\claude-code\*\*\claude.exe",
                       "$env:APPDATA\Claude\claude-code\*\*\claude.exe",
                       "$env:LOCALAPPDATA\Packages\Claude_*\LocalCache\Roaming\Claude\claude-code\*\*\claude.exe")) {
        $paths += Get-ChildItem $pat -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    }
    $paths | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique |
        Sort-Object { if ($_ -match '\\claude-code\\([\d.]+)\\') { try { [version]$Matches[1] } catch { [version]"0.0" } } else { [version]"0.0" } } |
        Select-Object -Last 1
}
function Get-Site([string]$url, [string]$outFile = "") {
    # 사이트에서 받기(캐시 피하기) — scripts/common.ps1 Invoke-SiteGet과 같은 방식
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = "SilentlyContinue"
    $u = $url + "?nc=" + [DateTime]::UtcNow.Ticks
    if ($outFile) { Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 300 -OutFile $outFile; return }
    [Text.Encoding]::UTF8.GetString((Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 30).RawContentStream.ToArray())
}
function Install-SiteBundle([string]$dir) {
    # 공개 묶음을 받아 확인값을 맞춰 보고 설치 폴더에 풀기 — scripts/common.ps1 Install-Bundle과 같은 방식(설정·가상환경은 그대로)
    $v = Get-Site "$Site/version.json" | ConvertFrom-Json
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("handpilot-setup-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        $zip = Join-Path $tmp $v.file
        Get-Site "$Site/$($v.file)" $zip
        if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() -ne ([string]$v.sha256).ToLower()) {
            throw "내려받은 파일의 확인값이 맞지 않습니다(받는 중 손상). 잠시 뒤 다시 실행해 주세요."
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $x = Join-Path $tmp "x"
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $x)
        Get-ChildItem $x -Recurse -File | ForEach-Object {
            $dst = Join-Path $dir $_.FullName.Substring($x.Length + 1)
            New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
            Copy-Item $_.FullName $dst -Force
        }
        return $v.version
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
function Find-Git {
    $g = Get-Command git -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    foreach ($p in "$env:ProgramFiles\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe") {
        if (Test-Path $p) { return $p }
    }
}

Write-Host "핸드파일럿 설치 — 설치 위치: $Dir" -ForegroundColor White
Write-Host "설치 안내 사이트에서 최신 버전을 받아 자동으로 설치합니다(처음엔 몇 분)."

try {
    # 1) Claude 앱 (플러그인을 등록할 Claude Code가 앱 안에 있어야 함)
    Step "1/3 Claude 데스크톱 앱"
    while (-not (Find-Claude)) {
        if ($NoPrompt) { throw "Claude 데스크톱 앱(Code 탭)이 필요합니다." }
        Note "Claude 데스크톱 앱 안의 Claude Code를 찾지 못했습니다."
        Note "Claude 앱을 설치·로그인하고 'Code' 탭에서 채팅을 하나 연 채로, 이 창으로 돌아와 Enter를 누르세요."
        Note "계속 안 되면 이 창을 캡처해 Claude에게 보여 주세요(Claude 앱 안의 claude.exe 경로를 환경 변수 HANDPILOT_CLAUDE로 지정하면 됩니다)."
        Read-Host "   준비되면 Enter (그만두려면 창을 닫으세요)" | Out-Null
    }
    Ok "Claude Code 준비됨"

    # 2) 내려받기
    Step "2/3 내려받기"
    if (Test-Path (Join-Path $Dir ".git")) {
        # 예전 방식(GitHub clone)으로 설치된 PC: 지금처럼 git으로 최신 코드
        $git = Find-Git
        if (-not $git) { throw "이 폴더는 GitHub로 설치돼 있는데 Git을 찾지 못했습니다. https://git-scm.com 에서 설치한 뒤 다시 실행해 주세요." }
        & $git -C $Dir pull -q --ff-only
        if ($LASTEXITCODE -eq 0) { Ok "이미 설치돼 있음(GitHub) — 최신 코드로 맞춤" }
        else { Note "최신 코드 받기에 실패했습니다 — 지금 있는 코드로 설치를 확인합니다" }
    } else {
        $isHandpilot = Test-Path (Join-Path $Dir "handpilot\.claude-plugin\plugin.json")
        if ((Test-Path $Dir) -and (Get-ChildItem $Dir -Force | Select-Object -First 1) -and -not $isHandpilot) {
            throw "$Dir 폴더가 이미 있고 핸드파일럿 폴더가 아닙니다. 그 폴더를 옮기거나 이름을 바꾼 뒤 다시 실행해 주세요."
        }
        New-Item -ItemType Directory -Force $Dir | Out-Null
        $ver = Install-SiteBundle $Dir
        Ok ($(if ($isHandpilot) { "이미 설치돼 있음 — 최신 $ver 로 맞춤" } else { "내려받음: 버전 $ver → $Dir" }))
    }

    # 3) 설치 (install.ps1 — Python·가상환경·라이브러리·경로·플러그인 등록·바로가기·점검)
    Step "3/3 설치 (Python·라이브러리·플러그인 등록 — 처음엔 몇 분 걸립니다)"
    $ia = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Dir "install.ps1"), "-Yes")
    if ($SkipPlugin) { $ia += @("-SkipPlugin", "-NoShortcut") }
    & powershell @ia
    if ($LASTEXITCODE -ne 0) { throw "설치 단계에서 멈췄습니다(위 메시지 참고)." }

    # 주간 업데이트 확인 (작업 스케줄러 — 사용자가 고름)
    if (-not $NoPrompt) {
        $a = Read-Host "`n   매주 월요일 오전 10시에 새 버전을 확인할까요? 새 버전이 있으면 핸드파일럿을 안 쓸 때 자동으로 설치합니다 (Y/n)"
        if ($a -notmatch "^[nN]") {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir "scripts\update-check-task.ps1") -Register
        } else {
            Note "나중에 켜려면: 시작 메뉴 '핸드파일럿 관리' → 정보 탭 → [켜기]"
        }
    }

    Write-Host "`n설치 완료!" -ForegroundColor Green
    Write-Host "Claude 앱에서 새 채팅창을 열고  /handpilot:handpilot 지금 화면 봐줘  라고 입력해 보세요."
    Write-Host "(이미 열려 있던 채팅창에는 안 보일 수 있습니다 — 새 채팅창을 열거나, 앱을 트레이에서 종료 후 다시 실행)"
} catch {
    Write-Host "`n설치를 끝내지 못했습니다: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "설치 안내 페이지의 '문제 해결'을 보거나, 이 창을 캡처해 Claude에게 보여 주세요."
    exit 1
}
