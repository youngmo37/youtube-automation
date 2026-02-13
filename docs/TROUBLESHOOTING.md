# 문제 해결 가이드 (Troubleshooting)

## 목차

1. [설치 단계 오류](#설치-단계-오류)
2. [서비스 시작 오류](#서비스-시작-오류)
3. [GPU 관련 문제](#gpu-관련-문제)
4. [네트워크 연결 문제](#네트워크-연결-문제)
5. [성능 문제](#성능-문제)
6. [로그 확인 방법](#로그-확인-방법)

---

## 설치 단계 오류

### 1단계: setup_base.sh 오류

#### 문제: "nvidia-smi: command not found"

**원인**: NVIDIA GPU 드라이버가 설치되지 않았습니다.

**해결**:
```powershell
# Windows에서 NVIDIA 드라이버 확인
nvidia-smi

# 출력 없으면 드라이버 설치 필요
# https://www.nvidia.com/Download/index.aspx
```

WSL CUDA 드라이버 설치:
```powershell
# https://developer.nvidia.com/cuda/wsl
# Windows용 CUDA Toolkit 설치
```

#### 문제: "Docker 설치 실패"

**원인**: 저장소 접근 문제 또는 권한 오류

**해결**:
```bash
# 수동 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 사용자 그룹 추가
sudo usermod -aG docker $USER

# WSL 재시작 (Windows PowerShell)
wsl --shutdown
wsl
```

#### 문제: "systemd not found"

**원인**: WSL 2.0.0 이전 버전

**해결**:
```powershell
# Windows PowerShell
wsl --update
wsl --shutdown
wsl
```

### 2단계: setup_ai_services.sh 오류

#### 문제: "Ollama 모델 다운로드 실패"

**원인**: 네트워크 문제 또는 디스크 공간 부족

**해결**:
```bash
# 디스크 공간 확인
df -h ~

# 수동 다운로드
ollama pull llama3.1:8b

# 프록시 사용 시
export HTTPS_PROXY=http://your-proxy:port
ollama pull llama3.1:8b
```

#### 문제: "SDXL 모델 다운로드 느림"

**원인**: 대용량 파일 (7GB)

**해결**:
```bash
# aria2로 빠른 다운로드 (멀티 커넥션)
sudo apt install aria2

cd ~/youtube-automation-wsl/stable-diffusion-webui/models/Stable-diffusion

aria2c -x 16 -s 16 \
  https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors

# 또는 토렌트 사용
# https://huggingface.co/stabilityai/sdxl-turbo/tree/main
```

#### 문제: "Python 의존성 설치 오류"

**원인**: pip 버전 또는 빌드 도구 부족

**해결**:
```bash
# pip 업그레이드
source ~/youtube-automation-wsl/ai-services/venv/bin/activate
pip install --upgrade pip setuptools wheel

# 빌드 도구 설치
sudo apt install -y build-essential python3-dev

# 재시도
pip install -r ~/youtube-automation-wsl/ai-services/requirements.txt
```

### 3단계: setup_n8n.sh 오류

#### 문제: "포트 5678 이미 사용 중"

**원인**: 다른 프로세스가 포트 점유

**해결**:
```bash
# 포트 사용 확인
sudo lsof -i :5678

# 프로세스 종료
sudo kill -9 <PID>

# 또는 docker-compose.yml에서 포트 변경
ports:
  - "5679:5678"  # 5679로 변경
```

#### 문제: "PostgreSQL 컨테이너 시작 실패"

**원인**: 기존 데이터 볼륨 충돌

**해결**:
```bash
# 기존 볼륨 삭제 (데이터 손실 주의!)
docker-compose down -v

# 재시작
docker-compose up -d

# 로그 확인
docker logs n8n-postgres
```

---

## 서비스 시작 오류

### Ollama 시작 실패

#### 문제: "Ollama 서비스 시작 안됨"

**해결**:
```bash
# 서비스 상태 확인
sudo systemctl status ollama

# 재시작
sudo systemctl restart ollama

# 로그 확인
sudo journalctl -u ollama -f

# 수동 실행 (디버깅)
ollama serve
```

### Stable Diffusion WebUI 시작 실패

#### 문제: "webui.sh 실행 오류"

**해결**:
```bash
# 실행 권한 부여
chmod +x ~/youtube-automation-wsl/stable-diffusion-webui/webui.sh

# 수동 실행 (로그 확인)
cd ~/youtube-automation-wsl/stable-diffusion-webui
./webui.sh --listen --api --xformers

# VRAM 부족 시
./webui.sh --listen --api --medvram --lowvram
```

#### 문제: "모델 로딩 실패"

**해결**:
```bash
# 모델 파일 확인
ls -lh ~/youtube-automation-wsl/stable-diffusion-webui/models/Stable-diffusion/

# 모델 경로 확인
# WebUI 실행 후 http://localhost:7860 접속
# Settings → Stable Diffusion → SD Model 확인
```

### FastAPI 시작 실패

#### 문제: "ModuleNotFoundError"

**해결**:
```bash
# 가상환경 활성화 확인
cd ~/youtube-automation-wsl/ai-services
source venv/bin/activate

# 의존성 재설치
pip install -r requirements.txt

# Python 경로 확인
which python  # venv 경로여야 함
```

---

## GPU 관련 문제

### CUDA 오류

#### 문제: "CUDA out of memory"

**원인**: VRAM 부족 (GTX 1060 6GB 한계)

**해결**:
```bash
# 실행 중인 GPU 프로세스 확인
nvidia-smi

# SD WebUI 메모리 최적화
cd ~/youtube-automation-wsl/stable-diffusion-webui
./webui.sh --listen --api --medvram --opt-sdp-attention

# Ollama 메모리 제한
# /etc/systemd/system/ollama.service
[Service]
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_NUM_PARALLEL=1"

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

#### 문제: "GPU not detected"

**해결**:
```bash
# WSL에서 GPU 확인
nvidia-smi

# 출력 없으면
# 1. Windows NVIDIA 드라이버 재설치
# 2. WSL 업데이트: wsl --update
# 3. WSL 재시작: wsl --shutdown (Windows)
```

---

## 네트워크 연결 문제

### n8n → FastAPI 통신 실패

#### 문제: "Connection refused"

**원인**: Docker 컨테이너가 WSL 호스트 접근 불가

**해결**:
```bash
# 1. FastAPI가 0.0.0.0으로 바인딩되었는지 확인
netstat -tulpn | grep 8000
# 0.0.0.0:8000이어야 함

# 2. n8n에서 올바른 주소 사용
# docker-compose.yml에 extra_hosts 확인:
extra_hosts:
  - "host.docker.internal:172.17.0.1"

# n8n HTTP Request에서:
# http://host.docker.internal:8000/api/...
```

### 외부 접근 불가

#### 문제: "Windows 브라우저에서 localhost:5678 접속 안됨"

**해결**:
```bash
# WSL IP 확인
hostname -I
# 예: 172.20.224.1

# Windows 브라우저에서:
http://172.20.224.1:5678

# 또는 포트 포워딩 (선택)
# Windows PowerShell (관리자)
netsh interface portproxy add v4tov4 `
  listenport=5678 listenaddress=0.0.0.0 `
  connectport=5678 connectaddress=<WSL_IP>
```

---

## 성능 문제

### 느린 이미지 생성

**증상**: SDXL 이미지 생성에 30초 이상 소요

**원인**: GPU 성능 한계 또는 설정 문제

**해결**:
```bash
# 1. SDXL-Turbo 사용 확인 (4 steps)
# n8n HTTP Request:
{
  "steps": 4,  # 1-4 사용
  "sampler_name": "DPM++ SDE",
  "cfg_scale": 2
}

# 2. xformers 활성화 확인
cd ~/youtube-automation-wsl/stable-diffusion-webui
./webui.sh --listen --api --xformers

# 3. GPU 클럭 확인
nvidia-smi -q -d CLOCK
```

### 메모리 부족

**증상**: "Out of memory" 또는 시스템 멈춤

**해결**:
```bash
# 1. WSL 메모리 제한 설정
# C:\Users\<사용자>\.wslconfig (Windows)
[wsl2]
memory=12GB
processors=6
swap=4GB

# 2. Docker 메모리 제한
# docker-compose.yml에 추가:
services:
  n8n:
    mem_limit: 2g

# 3. 서비스 순차 시작 (동시 실행 방지)
./scripts/stop_all.sh
# SD WebUI 먼저 시작
cd ~/youtube-automation-wsl/stable-diffusion-webui
./webui.sh --listen --api --xformers &
sleep 60

# 그 다음 FastAPI
cd ~/youtube-automation-wsl/ai-services
source venv/bin/activate
uvicorn app:app --host 0.0.0.0 --port 8000 &
```

---

## 로그 확인 방법

### 각 서비스별 로그 위치

```bash
# n8n
docker logs -f n8n
docker logs -f n8n-postgres

# Ollama
sudo journalctl -u ollama -f

# Stable Diffusion WebUI
tail -f ~/youtube-automation-wsl/logs/sdwebui.log

# FastAPI
tail -f ~/youtube-automation-wsl/logs/fastapi.log

# 전체 로그 디렉토리
ls -lh ~/youtube-automation-wsl/logs/
```

### 디버그 모드 실행

```bash
# FastAPI 디버그 모드
cd ~/youtube-automation-wsl/ai-services
source venv/bin/activate
uvicorn app:app --host 0.0.0.0 --port 8000 --log-level debug --reload

# n8n 환경 변수 추가 (docker-compose.yml)
environment:
  - N8N_LOG_LEVEL=debug
```

---

## 자주 묻는 질문 (FAQ)

### Q1: WSL 재시작 후 서비스가 자동으로 시작되지 않습니다

**A**: systemd 서비스 활성화:
```bash
sudo systemctl enable docker
sudo systemctl enable ollama

# 또는 자동 시작 스크립트 등록
# 설치 가이드의 "자동 시작 설정" 참조
```

### Q2: GPU 온도가 너무 높습니다 (85도 이상)

**A**: 
```bash
# 1. 쿨링 확인 (노트북 쿨링 패드 사용)
# 2. GPU 팬 속도 조절
# 3. 성능 제한
nvidia-smi -pl 100  # 전력 제한 100W (예시)

# 4. 사용 빈도 조절
# n8n 워크플로우 스케줄 간격 증가
```

### Q3: 디스크 공간이 부족합니다

**A**:
```bash
# 오래된 미디어 파일 삭제
rm -rf ~/youtube-automation-wsl/media/audio/*
rm -rf ~/youtube-automation-wsl/media/images/*
rm -rf ~/youtube-automation-wsl/media/videos/*

# Docker 정리
docker system prune -a

# 로그 정리
find ~/youtube-automation-wsl/logs -name "*.log" -mtime +7 -delete
```

---

## 추가 지원

문제가 해결되지 않으면:

1. **GitHub Issues**: 
   - https://github.com/yourusername/youtube-automation-wsl/issues
   - 로그 파일 첨부
   - 시스템 정보 제공 (GPU, RAM, WSL 버전)

2. **Discussions**:
   - https://github.com/yourusername/youtube-automation-wsl/discussions

3. **로그 수집**:
```bash
# 디버깅용 로그 수집
./scripts/health_check.sh > debug_info.txt
docker-compose logs >> debug_info.txt
cat ~/youtube-automation-wsl/logs/*.log >> debug_info.txt
```
