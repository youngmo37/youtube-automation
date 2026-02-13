# 설치 가이드 (Installation Guide)

## 목차

1. [사전 준비](#사전-준비)
2. [1단계: 기본 환경 설정](#1단계-기본-환경-설정)
3. [2단계: AI 서비스 설치](#2단계-ai-서비스-설치)
4. [3단계: n8n 설정](#3단계-n8n-설정)
5. [4단계: 검증 및 테스트](#4단계-검증-및-테스트)
6. [초기 설정](#초기-설정)

---

## 사전 준비

### 시스템 요구사항

| 구성요소 | 최소 사양 | 권장 사양 |
|---------|----------|----------|
| **OS** | Windows 11 | Windows 11 Pro |
| **CPU** | 4코어 | 6코어 이상 |
| **RAM** | 16GB | 32GB |
| **GPU** | NVIDIA GTX 1060 6GB | RTX 3060 12GB 이상 |
| **디스크** | SSD 50GB 여유 | SSD 100GB 여유 |
| **네트워크** | 인터넷 연결 | 광대역 인터넷 |

### 필수 소프트웨어

#### 1. WSL2 설치

```powershell
# Windows PowerShell (관리자 권한)

# WSL 설치
wsl --install -d Ubuntu-22.04

# 설치 확인
wsl --list --verbose
# 출력: Ubuntu-22.04 Running 2
```

#### 2. NVIDIA GPU 드라이버 (WSL CUDA 지원)

1. **Windows용 NVIDIA 드라이버 설치**
   - [NVIDIA 공식 사이트](https://www.nvidia.com/Download/index.aspx)에서 최신 드라이버 다운로드
   - 설치 후 재부팅

2. **WSL에서 GPU 확인**
```bash
# WSL 터미널
wsl

nvidia-smi
# GPU 정보가 정상 출력되면 성공
```

#### 3. Git 설치 (WSL)

```bash
# WSL 터미널
sudo apt update
sudo apt install -y git
```

---

## 1단계: 기본 환경 설정

**예상 소요 시간**: 5-10분

이 단계에서는 Docker, systemd, 기본 패키지를 설치합니다.

### 1-1. 저장소 클론

```bash
# WSL 터미널
cd ~
git clone https://github.com/yourusername/youtube-automation-wsl.git
cd youtube-automation-wsl
```

### 1-2. 스크립트 실행

```bash
# 실행 권한 부여
chmod +x scripts/*.sh

# 기본 환경 설정
./scripts/setup_base.sh
```

**스크립트가 수행하는 작업**:
- ✅ 시스템 업데이트
- ✅ Docker Engine 설치
- ✅ Docker Compose 설치
- ✅ systemd 활성화
- ✅ 기본 디렉토리 생성

### 1-3. WSL 재시작

```powershell
# Windows PowerShell
wsl --shutdown

# 다시 시작
wsl
cd ~/youtube-automation-wsl
```

### 1-4. 검증

```bash
# Docker 버전 확인
docker --version
# 출력 예: Docker version 24.0.7, build afdd53b

docker-compose --version
# 출력 예: Docker Compose version v2.23.0

# systemd 확인
systemctl --version
# 정상 출력되면 성공
```

**❌ 오류 발생 시**:
- [문제 해결 가이드](./TROUBLESHOOTING.md#1단계-오류) 참조

---

## 2단계: AI 서비스 설치

**예상 소요 시간**: 10-15분

이 단계에서는 Ollama, Stable Diffusion, Python 환경을 설치합니다.

### 2-1. 스크립트 실행

```bash
# WSL 터미널
cd ~/youtube-automation-wsl
./scripts/setup_ai_services.sh
```

**스크립트가 수행하는 작업**:
- ✅ Ollama 설치 및 Llama 3.1 8B 다운로드 (~5GB)
- ✅ Stable Diffusion WebUI 클론
- ✅ Python 가상환경 생성
- ✅ FastAPI 의존성 설치
- ✅ Whisper 모델 다운로드 (~150MB)

### 2-2. SDXL 모델 수동 다운로드

```bash
# 모델 디렉토리로 이동
cd ~/youtube-automation-wsl/stable-diffusion-webui/models/Stable-diffusion

# SDXL-Turbo 다운로드 (~7GB, 10-20분 소요)
wget https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors

# 다운로드 확인
ls -lh
# 출력: sd_xl_turbo_1.0_fp16.safetensors 약 7GB
```

**대안: 다른 SDXL 모델 사용**
```bash
# SDXL-Lightning (더 빠름)
wget https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_4step_unet.safetensors

# FLUX-schnell (품질 최고, 느림)
wget https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors
```

### 2-3. 검증

```bash
# Ollama 확인
ollama list
# 출력: llama3.1:8b

# Python 환경 확인
source ~/youtube-automation-wsl/ai-services/venv/bin/activate
python --version
# 출력: Python 3.10.x

# 의존성 확인
pip list | grep fastapi
# 출력: fastapi 0.104.x

deactivate
```

**❌ 오류 발생 시**:
- Ollama 설치 실패: `curl -fsSL https://ollama.com/install.sh | sh` 재실행
- Python 오류: `./scripts/setup_ai_services.sh` 재실행

---

## 3단계: n8n 설정

**예상 소요 시간**: 5분

이 단계에서는 n8n과 PostgreSQL을 Docker Compose로 실행합니다.

### 3-1. 환경 변수 설정

```bash
# .env 파일 복사
cp .env.example .env

# .env 파일 편집
nano .env
```

**.env 파일 내용**:
```bash
# n8n 인증
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password_here

# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=your_db_password_here
POSTGRES_DB=n8n

# 외부 API (나중에 설정 가능)
PERPLEXITY_API_KEY=
AZURE_OPENAI_KEY=
AZURE_OPENAI_ENDPOINT=
YOUTUBE_CLIENT_ID=
YOUTUBE_CLIENT_SECRET=
```

저장: `Ctrl+O`, `Enter`, 종료: `Ctrl+X`

### 3-2. 스크립트 실행

```bash
cd ~/youtube-automation-wsl
./scripts/setup_n8n.sh
```

**스크립트가 수행하는 작업**:
- ✅ docker-compose.yml 검증
- ✅ Docker 컨테이너 시작 (n8n, PostgreSQL)
- ✅ 서비스 헬스 체크

### 3-3. 검증

```bash
# Docker 컨테이너 확인
docker ps

# 출력 예시:
# CONTAINER ID   IMAGE              STATUS         PORTS
# abc123         n8nio/n8n:latest  Up 30 seconds  0.0.0.0:5678->5678/tcp
# def456         postgres:15       Up 30 seconds  5432/tcp

# n8n 로그 확인
docker logs n8n
# "Editor is now accessible via: http://localhost:5678" 출력되면 성공
```

### 3-4. 웹 브라우저 접속

```
Windows 브라우저에서 접속:
http://localhost:5678

초기 계정:
- Username: admin
- Password: (위에서 설정한 비밀번호)
```

**❌ 접속 안될 때**:
```bash
# 포트 확인
sudo lsof -i :5678

# n8n 재시작
docker-compose restart n8n
```

---

## 4단계: 검증 및 테스트

**예상 소요 시간**: 5-10분

### 4-1. 모든 서비스 시작

```bash
cd ~/youtube-automation-wsl
./scripts/start_all.sh
```

**출력 예시**:
```
🚀 YouTube Automation 시스템 시작...
✅ Docker 시작 완료
✅ Ollama 시작 완료
🎨 Stable Diffusion WebUI 시작 중... (1-2분 소요)
✅ SD WebUI 준비 완료
🤖 FastAPI 시작 완료

📊 서비스 상태:
   Ollama:    ✅ OK
   SD WebUI:  ✅ OK
   FastAPI:   ✅ OK
   n8n:       ✅ OK
```

### 4-2. 헬스 체크

```bash
./scripts/health_check.sh
```

**정상 출력**:
```
📊 서비스 헬스 체크
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Ollama:      OK
✅ SD WebUI:    OK
✅ FastAPI:     OK
✅ PostgreSQL:  OK
✅ n8n:         OK

📈 리소스 사용률:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GPU: 15% | VRAM: 1234MB / 6144MB (20%)
RAM: 8.2GB / 16GB
Disk: 25GB / 100GB (25%)
```

### 4-3. API 테스트

```bash
# 1. FastAPI 헬스 체크
curl http://localhost:8000/health

# 정상 출력:
# {"status":"healthy","services":{"ollama":"http://localhost:11434",...}}

# 2. TTS 테스트
curl -X POST http://localhost:8000/api/generate-audio \
  -H "Content-Type: application/json" \
  -d '{
    "script": "안녕하세요, 테스트입니다",
    "voice": "ko-KR-InJoonNeural"
  }'

# 정상 출력:
# {"status":"success","audio_path":"/home/.../media/audio/xxx.mp3",...}

# 3. Ollama 테스트
curl http://localhost:11434/api/tags

# 정상 출력:
# {"models":[{"name":"llama3.1:8b",...}]}
```

### 4-4. 웹 UI 접속 확인

| 서비스 | URL | 계정 |
|--------|-----|------|
| n8n | http://localhost:5678 | admin / (설정한 비밀번호) |
| FastAPI Docs | http://localhost:8000/docs | 인증 없음 |
| SD WebUI | http://localhost:7860 | 인증 없음 |

---

## 초기 설정

### n8n 워크플로우 임포트

1. **n8n 접속**
   - http://localhost:5678 접속
   - 로그인

2. **워크플로우 임포트**
   - 좌측 메뉴 → Workflows → + New Workflow
   - 우측 상단 `...` 메뉴 → Import from File
   - `~/youtube-automation-wsl/workflows/youtube-automation.json` 선택

3. **Credentials 설정**

#### Google Sheets 연동
```
Settings → Credentials → + New Credential
→ Google Sheets OAuth2 API

1. Google Cloud Console에서 OAuth 2.0 클라이언트 ID 생성
2. Redirect URI 추가: http://localhost:5678/rest/oauth2-credential/callback
3. Client ID, Client Secret 입력
4. Connect 클릭하여 인증
```

#### Azure OpenAI 연동
```
Settings → Credentials → + New Credential
→ OpenAI API

Base URL: https://your-resource.openai.azure.com/
API Key: (Azure Portal에서 복사)
```

#### YouTube API 연동
```
Settings → Credentials → + New Credential
→ YouTube OAuth2 API

1. Google Cloud Console에서 YouTube Data API v3 활성화
2. OAuth 2.0 클라이언트 ID 생성
3. 인증 진행
```

### Google Sheets 템플릿 설정

1. **시트 생성**
   - Google Sheets에서 새 스프레드시트 생성
   - 이름: "YouTube 콘텐츠 관리"

2. **컬럼 추가**
```
| ID | Status | Target | Keyword | Format | Title | Script | VideoURL |
|----|--------|--------|---------|--------|-------|--------|----------|
| 1  | Planning | 20대 | AI 트렌드 | Shorts |     |        |          |
```

3. **Status 값**
   - `Planning`: 기획 단계 (n8n이 이 상태인 행을 처리)
   - `제작중`: 대본 작성 완료
   - `완료`: 영상 업로드 완료

---

## 자동 시작 설정 (선택)

### systemd 서비스 등록

```bash
# Docker 자동 시작
sudo systemctl enable docker

# Ollama 자동 시작
sudo systemctl enable ollama

# 부팅 시 스크립트 실행
sudo tee /etc/systemd/system/youtube-automation.service > /dev/null <<EOF
[Unit]
Description=YouTube Automation Services
After=network.target docker.service ollama.service

[Service]
Type=oneshot
User=$USER
WorkingDirectory=/home/$USER/youtube-automation-wsl
ExecStart=/home/$USER/youtube-automation-wsl/scripts/start_all.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable youtube-automation.service
```

### WSL 부팅 시 자동 시작 (Windows)

```powershell
# Windows PowerShell (관리자)

# Task Scheduler에 작업 추가
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d Ubuntu-22.04 -- sudo systemctl start youtube-automation"

$trigger = New-ScheduledTaskTrigger -AtLogon
$trigger.Delay = "PT1M"  # 1분 지연

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest

Register-ScheduledTask -TaskName "WSL YouTube Automation" `
  -Action $action -Trigger $trigger -Principal $principal
```

---

## 다음 단계

설치가 완료되었습니다! 🎉

1. **첫 영상 제작**
   - Google Sheets에 기획 입력
   - n8n 워크플로우 실행
   - 생성 과정 모니터링

2. **추가 설정**
   - [API 참조 문서](./API_REFERENCE.md)
   - [문제 해결 가이드](./TROUBLESHOOTING.md)

3. **커뮤니티**
   - GitHub Discussions 참여
   - 이슈 제출 시 로그 첨부

---

## 제거 (Uninstall)

```bash
# 서비스 중지
cd ~/youtube-automation-wsl
./scripts/stop_all.sh

# Docker 컨테이너 삭제
docker-compose down -v

# systemd 서비스 제거
sudo systemctl disable youtube-automation
sudo rm /etc/systemd/system/youtube-automation.service

# 프로젝트 삭제
cd ~
rm -rf youtube-automation-wsl

# Ollama 제거 (선택)
sudo systemctl stop ollama
sudo systemctl disable ollama
sudo rm /usr/local/bin/ollama
sudo rm -rf ~/.ollama
```

---

## 문의

설치 중 문제가 발생하면:
1. [문제 해결 가이드](./TROUBLESHOOTING.md) 참조
2. [GitHub Issues](https://github.com/yourusername/youtube-automation-wsl/issues)에 질문
3. 로그 파일 첨부: `~/youtube-automation-wsl/logs/`
