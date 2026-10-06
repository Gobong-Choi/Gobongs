# 핸드파일럿 한 번에 설치 (설치 안내 페이지의 "설치 파일"이 내려받아 실행)
#
#   Claude 앱 확인 → Git 확인(없으면 설치) → GitHub에서 내려받기(처음이면 로그인 창) → install.ps1 → 주간 업데이트 확인(선택)
#   이미 설치돼 있으면 최신 코드를 받고 설치를 다시 확인합니다(여러 번 실행해도 안전).
#
# 원본: handpilot 저장소 web/setup.ps1. 고치면 Gobongs 저장소 handpilot/setup.ps1에도 복사(공개 — 민감 정보 금지).
# 테스트용: -Dir <폴더>, -SkipPlugin(플러그인 등록·바로가기 건너뜀), -NoPrompt(질문 없음, 주간 확인 안 켬)
#           또는 환경 변수 HANDPILOT_DIR, HANDPILOT_SETUP_TEST=1 (설치 파일 .cmd로 시험할 때)

param(
    [string]$Dir = $(if ($env:HANDPILOT_DIR) { $env:HANDPILOT_DIR } else { Join-Path $env:USERPROFILE "handpilot" }),
    [switch]$SkipPlugin,
    [switch]$NoPrompt
)

$Repo = "https://github.com/Gobong-Choi/handpilot.git"
$ErrorActionPreference = "Stop"
if ($env:HANDPILOT_SETUP_TEST -eq "1") { $SkipPlugin = $true; $NoPrompt = $true }

function Step([string]$t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Ok([string]$t) { Write-Host "   OK  $t" -ForegroundColor Green }
function Note([string]$t) { Write-Host "   ..  $t" -ForegroundColor Yellow }

function Find-Claude { Get-ChildItem "$env:APPDATA\Claude\claude-code\*\*\claude.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 }
function Find-Git {
    $g = Get-Command git -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    foreach ($p in "$env:ProgramFiles\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe") {
        if (Test-Path $p) { return $p }
    }
}

Write-Host "핸드파일럿 설치 — 설치 위치: $Dir" -ForegroundColor White
Write-Host "중간에 GitHub 로그인 창이 뜨면 로그인만 해 주세요. 나머지는 자동으로 진행됩니다."

try {
    # 1) Claude 앱 (플러그인을 등록할 Claude Code가 앱 안에 있어야 함)
    Step "1/4 Claude 데스크톱 앱"
    while (-not (Find-Claude)) {
        if ($NoPrompt) { throw "Claude 데스크톱 앱(Code 탭)이 필요합니다." }
        Note "Claude 데스크톱 앱의 Code 탭이 아직 준비되지 않았습니다."
        Note "Claude 앱을 설치·로그인하고 'Code' 탭을 한 번 연 뒤, 이 창으로 돌아와 Enter를 누르세요."
        Read-Host "   준비되면 Enter (그만두려면 창을 닫으세요)" | Out-Null
    }
    Ok "Claude Code 준비됨"

    # 2) Git (코드 받기·업데이트용. 처음 받을 때 GitHub 로그인 창도 Git이 띄움)
    Step "2/4 Git"
    $git = Find-Git
    if (-not $git) {
        Note "Git이 없어 설치합니다(무료). Windows가 권한을 물으면 '예'를 눌러 주세요."
        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements --silent
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        $git = Find-Git
        if (-not $git) { throw "Git 설치를 확인하지 못했습니다. https://git-scm.com 에서 설치한 뒤 다시 실행해 주세요." }
    }
    $gitDir = Split-Path $git
    if (($env:Path -split ";") -notcontains $gitDir) { $env:Path = "$gitDir;$env:Path" }  # 다음 단계(install.ps1)에서도 찾도록
    Ok "Git: $git"

    # 3) 내려받기
    Step "3/4 내려받기 (처음이면 GitHub 로그인 창이 뜹니다)"
    if (Test-Path (Join-Path $Dir ".git")) {
        & $git -C $Dir pull -q --ff-only
        if ($LASTEXITCODE -eq 0) { Ok "이미 설치돼 있음 — 최신 코드로 맞춤" }
        else { Note "최신 코드 받기에 실패했습니다 — 지금 있는 코드로 설치를 확인합니다" }
    } else {
        if ((Test-Path $Dir) -and (Get-ChildItem $Dir -Force | Select-Object -First 1)) {
            throw "$Dir 폴더가 이미 있고 비어 있지 않습니다. 그 폴더를 옮기거나 이름을 바꾼 뒤 다시 실행해 주세요."
        }
        & $git clone -q $Repo $Dir
        if ($LASTEXITCODE -ne 0) { throw "내려받기 실패 — 저장소 접근 권한이 있는 GitHub 계정으로 로그인했는지 확인해 주세요." }
        Ok "내려받음: $Dir"
    }

    # 4) 설치 (install.ps1 — Python·가상환경·라이브러리·경로·플러그인 등록·바로가기·점검)
    Step "4/4 설치 (Python·라이브러리·플러그인 등록 — 처음엔 몇 분 걸립니다)"
    $ia = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Dir "install.ps1"), "-Yes")
    if ($SkipPlugin) { $ia += @("-SkipPlugin", "-NoShortcut") }
    & powershell @ia
    if ($LASTEXITCODE -ne 0) { throw "설치 단계에서 멈췄습니다(위 메시지 참고)." }

    # 주간 업데이트 확인 (작업 스케줄러 — 사용자가 고름)
    if (-not $NoPrompt) {
        $a = Read-Host "`n   매주 월요일 오전 10시에 새 버전을 확인할까요? 새 버전이 있으면 설치 창만 뜹니다 (Y/n)"
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
