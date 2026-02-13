# 📦 YouTube Automation WSL - 프로젝트 구조

## 📁 전체 파일 구조

```
youtube-automation-wsl/
│
├── README.md                       # 프로젝트 소개 (시작점)
├── .env.example                    # 환경 변수 템플릿
├── .gitignore                      # Git 제외 파일
│
├── docs/                           # 📚 문서
│   ├── ARCHITECTURE.md             # 아키텍처 상세 설명
│   ├── INSTALLATION.md             # 설치 가이드 (단계별)
│   └── TROUBLESHOOTING.md          # 문제 해결 가이드
│
├── scripts/                        # 🔧 자동화 스크립트
│   ├── setup_base.sh              # 1단계: 기본 환경 (Docker, systemd)
│   ├── setup_ai_services.sh       # 2단계: AI 서비스 (Ollama, SD, Python)
│   ├── setup_n8n.sh               # 3단계: n8n 설정
│   ├── start_all.sh               # 모든 서비스 시작
│   ├── stop_all.sh                # 모든 서비스 중지
│   └── health_check.sh            # 시스템 상태 확인
│
├── docker-compose.yml              # Docker 구성 (n8n + PostgreSQL)
│
├── ai-services/                    # 🤖 FastAPI 서버 (직접 작성 필요)
│   ├── app.py                     # 메인 API
│   ├── requirements.txt           # Python 의존성
│   ├── services/                  # 서비스 로직
│   │   ├── __init__.py
│   │   ├── tts_service.py        # Edge TTS
│   │   ├── whisper_service.py    # 오디오 분석
│   │   ├── llama_service.py      # Llama 3.1
│   │   └── video_service.py      # FFmpeg
│   └── venv/                      # Python 가상환경 (자동 생성)
│
├── stable-diffusion-webui/         # 🎨 SD WebUI (자동 클론)
│   ├── webui.sh
│   └── models/
│       └── Stable-diffusion/
│           └── sd_xl_turbo_1.0_fp16.safetensors  # 수동 다운로드
│
├── media/                          # 📁 생성 파일 (자동 생성)
│   ├── audio/                     # TTS 음성 파일
│   ├── images/                    # SDXL 생성 이미지
│   ├── videos/                    # FFmpeg 모션 비디오
│   └── final/                     # 최종 영상
│
├── logs/                           # 📝 로그 (자동 생성)
│   ├── fastapi.log
│   ├── sdwebui.log
│   └── health.log
│
├── n8n-data/                       # n8n 워크플로우 (자동 생성)
│
└── workflows/                      # n8n 워크플로우 템플릿
    └── youtube-automation.json
```

---

## 🚀 빠른 시작 가이드

### 1. 저장소 다운로드

```bash
# Windows WSL에서
cd ~
# GitHub에서 다운로드 또는 압축 해제
unzip youtube-automation-wsl.zip
cd youtube-automation-wsl
```

### 2. 설치 (3단계)

```bash
# 권한 부여
chmod +x scripts/*.sh

# 1단계: 기본 환경
./scripts/setup_base.sh
# → WSL 재시작 필요: wsl --shutdown (Windows), wsl

# 2단계: AI 서비스
./scripts/setup_ai_services.sh
# → SDXL 모델 수동 다운로드

# 3단계: n8n
./scripts/setup_n8n.sh
```

### 3. 실행

```bash
# 모든 서비스 시작
./scripts/start_all.sh

# 상태 확인
./scripts/health_check.sh

# 브라우저 접속
# http://localhost:5678 (n8n)
# http://localhost:8000/docs (FastAPI)
```

---

## 📝 주요 파일 설명

### README.md
- 프로젝트 개요
- 아키텍처 다이어그램
- 빠른 시작 가이드
- 비용 분석
- 기능 소개

### docs/ARCHITECTURE.md
- 시스템 구조 상세
- 컴포넌트별 설명
- 데이터 플로우
- 네트워크 구성
- 확장성 고려사항

### docs/INSTALLATION.md
- 단계별 설치 가이드
- 시스템 요구사항
- 각 단계별 검증 방법
- 초기 설정 (n8n, API 키)
- 자동 시작 설정

### docs/TROUBLESHOOTING.md
- 자주 발생하는 오류
- 단계별 해결 방법
- GPU 문제 해결
- 네트워크 문제 해결
- FAQ

### .env.example
- 모든 환경 변수 템플릿
- API 키 설정 방법
- 주석으로 상세 설명

---

## 🔧 스크립트 설명

### setup_base.sh (5-10분)
**목적**: 기본 환경 설정
- Docker Engine 설치
- Docker Compose 설치
- systemd 활성화
- 디렉토리 구조 생성

**실행**: `./scripts/setup_base.sh`

**확인**: `docker --version`, `systemctl --version`

### setup_ai_services.sh (10-15분)
**목적**: AI 서비스 설치
- Ollama + Llama 3.1 8B
- Stable Diffusion WebUI
- Python 환경 + FastAPI
- Whisper 모델

**실행**: `./scripts/setup_ai_services.sh`

**확인**: `ollama list`, `source ai-services/venv/bin/activate && python --version`

### setup_n8n.sh (5분)
**목적**: n8n 설정
- .env 파일 생성
- docker-compose.yml 검증
- 컨테이너 시작
- 헬스 체크

**실행**: `./scripts/setup_n8n.sh`

**확인**: `docker ps`, 브라우저 http://localhost:5678

### start_all.sh
**목적**: 모든 서비스 시작
- Docker (n8n, PostgreSQL)
- Ollama
- SD WebUI (1-2분 소요)
- FastAPI

**실행**: `./scripts/start_all.sh`

### stop_all.sh
**목적**: 모든 서비스 정상 종료
- FastAPI 종료
- SD WebUI 종료
- Docker 컨테이너 종료
- Ollama 종료 (선택)

**실행**: `./scripts/stop_all.sh`

### health_check.sh
**목적**: 시스템 상태 점검
- 서비스 가용성
- 응답 시간
- GPU 상태 (VRAM, 온도)
- 시스템 리소스
- 생성 파일 통계

**실행**: `./scripts/health_check.sh`

---

## 🔑 중요 파일 수정 필요

### 1. .env 파일

```bash
cp .env.example .env
nano .env
```

**필수 입력**:
- `N8N_BASIC_AUTH_PASSWORD`: n8n 로그인 비밀번호
- `POSTGRES_PASSWORD`: PostgreSQL 비밀번호
- `PERPLEXITY_API_KEY`: Perplexity API 키
- `AZURE_OPENAI_KEY`: Azure OpenAI API 키
- `YOUTUBE_CLIENT_ID`: Google OAuth 클라이언트 ID

### 2. ai-services/app.py

README.md의 FastAPI 코드를 복사하여 작성:

```bash
nano ~/youtube-automation-wsl/ai-services/app.py
# README.md의 "AI Services FastAPI 서버" 코드 참조
```

### 3. SDXL 모델 다운로드

```bash
cd ~/youtube-automation-wsl/stable-diffusion-webui/models/Stable-diffusion

# SDXL-Turbo (~7GB)
wget https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors
```

---

## 📊 워크플로우 예시

### n8n 워크플로우 구조

```
1. Schedule Trigger (매일 10:30)
   ↓
2. Google Sheets (Status='Planning' 조회)
   ↓
3. Perplexity AI (리서치)
   ↓
4. Azure OpenAI (대본 작성)
   ↓
5. HTTP Request → FastAPI /api/generate-audio (TTS)
   ↓
6. HTTP Request → FastAPI /api/analyze-audio (씬 분할)
   ↓
7. Loop (씬 개수만큼)
   ├─ HTTP Request → /api/generate-image-prompt
   ├─ HTTP Request → /api/generate-image
   └─ HTTP Request → /api/generate-video-motion
   ↓
8. HTTP Request → /api/merge-videos
   ↓
9. YouTube Data API (업로드)
   ↓
10. Google Sheets (Status='완료' 업데이트)
```

---

## 🛠️ 개발 가이드

### 로컬 개발

```bash
# FastAPI 개발 모드
cd ~/youtube-automation-wsl/ai-services
source venv/bin/activate
uvicorn app:app --reload --host 0.0.0.0 --port 8000

# 로그 실시간 확인
tail -f ~/youtube-automation-wsl/logs/fastapi.log
```

### API 테스트

```bash
# FastAPI Docs
http://localhost:8000/docs

# TTS 테스트
curl -X POST http://localhost:8000/api/generate-audio \
  -H "Content-Type: application/json" \
  -d '{"script":"테스트", "voice":"ko-KR-InJoonNeural"}'
```

---

## 📦 배포 체크리스트

- [ ] GPU 드라이버 설치 확인
- [ ] WSL2 업데이트
- [ ] 기본 환경 설치 (setup_base.sh)
- [ ] AI 서비스 설치 (setup_ai_services.sh)
- [ ] SDXL 모델 다운로드
- [ ] .env 파일 작성
- [ ] n8n 설정 (setup_n8n.sh)
- [ ] FastAPI 코드 작성
- [ ] 모든 서비스 시작 (start_all.sh)
- [ ] 헬스 체크 (health_check.sh)
- [ ] n8n 워크플로우 임포트
- [ ] Google API 인증 설정
- [ ] 테스트 실행

---

## 🆘 지원

- **문서**: [docs/](./docs/)
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions

---

**제작**: YouTube Automation WSL Team  
**라이선스**: MIT  
**버전**: 1.0.0  
**업데이트**: 2025-02-11
