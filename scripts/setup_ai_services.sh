#!/bin/bash

################################################################################
# YouTube Automation - 2단계: AI 서비스 설치
# 
# 이 스크립트는 다음을 설치합니다:
# - Ollama (Llama 3.1 8B)
# - Stable Diffusion WebUI
# - Python 가상환경 및 FastAPI
# - Whisper
#
# 실행: ./scripts/setup_ai_services.sh
################################################################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 프로젝트 루트
PROJECT_ROOT="$HOME/youtube-automation-wsl"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   YouTube Automation - 2단계: AI 서비스 설치"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# systemd 확인
if ! systemctl --version &> /dev/null; then
    log_error "systemd가 활성화되지 않았습니다!"
    log_error "WSL을 재시작하세요: wsl --shutdown (Windows)"
    exit 1
fi

# 1. Ollama 설치
log_info "Ollama 설치 상태 확인 중..."

if command -v ollama &> /dev/null; then
    log_success "Ollama가 이미 설치되어 있습니다"
else
    log_info "Ollama 설치 중... (1-2분 소요)"
    curl -fsSL https://ollama.com/install.sh | sh
    
    log_success "Ollama 설치 완료"
fi

# Ollama systemd 서비스 활성화
log_info "Ollama 서비스 설정 중..."

if systemctl is-enabled ollama &> /dev/null; then
    log_success "Ollama 서비스가 이미 활성화되어 있습니다"
else
    sudo systemctl enable ollama
fi

if systemctl is-active ollama &> /dev/null; then
    log_success "Ollama 서비스가 실행 중입니다"
else
    sudo systemctl start ollama
    sleep 3
    log_success "Ollama 서비스 시작 완료"
fi

# Llama 3.1 8B 모델 다운로드
log_info "Llama 3.1 8B 모델 확인 중..."

if ollama list | grep -q "llama3.1:8b"; then
    log_success "Llama 3.1 8B 모델이 이미 설치되어 있습니다"
else
    log_info "Llama 3.1 8B 모델 다운로드 중... (~5GB, 5-10분 소요)"
    log_warning "이 작업은 시간이 오래 걸릴 수 있습니다. 기다려 주세요..."
    
    ollama pull llama3.1:8b
    
    log_success "Llama 3.1 8B 모델 다운로드 완료"
fi

# Ollama 테스트
log_info "Ollama 테스트 중..."
OLLAMA_TEST=$(curl -s http://localhost:11434/api/tags)
if echo "$OLLAMA_TEST" | grep -q "llama3.1"; then
    log_success "Ollama 정상 작동 확인"
else
    log_error "Ollama 테스트 실패"
    exit 1
fi

# 2. Stable Diffusion WebUI 설치
log_info "Stable Diffusion WebUI 확인 중..."

SD_DIR="$PROJECT_ROOT/stable-diffusion-webui"

if [ -d "$SD_DIR" ]; then
    log_success "Stable Diffusion WebUI가 이미 클론되어 있습니다"
else
    log_info "Stable Diffusion WebUI 클론 중..."
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git "$SD_DIR"
    
    log_success "Stable Diffusion WebUI 클론 완료"
fi

# SD WebUI 모델 디렉토리 생성
mkdir -p "$SD_DIR/models/Stable-diffusion"
mkdir -p "$SD_DIR/outputs"

# SDXL 모델 확인
log_warning "⚠️  SDXL 모델은 수동으로 다운로드해야 합니다 (~7GB)"
echo ""
echo "다음 명령으로 다운로드하세요:"
echo "  ${YELLOW}cd $SD_DIR/models/Stable-diffusion${NC}"
echo "  ${YELLOW}wget https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors${NC}"
echo ""

if [ -f "$SD_DIR/models/Stable-diffusion/sd_xl_turbo_1.0_fp16.safetensors" ]; then
    log_success "SDXL-Turbo 모델이 이미 다운로드되어 있습니다"
else
    log_warning "SDXL 모델이 아직 다운로드되지 않았습니다"
    
    read -p "지금 다운로드하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "SDXL-Turbo 다운로드 중... (~7GB, 10-20분 소요)"
        cd "$SD_DIR/models/Stable-diffusion"
        wget -q --show-progress https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors
        cd "$PROJECT_ROOT"
        log_success "SDXL-Turbo 다운로드 완료"
    else
        log_warning "나중에 수동으로 다운로드하세요"
    fi
fi

# 3. Python 환경 설정
log_info "Python 가상환경 설정 중..."

AI_SERVICES_DIR="$PROJECT_ROOT/ai-services"
VENV_DIR="$AI_SERVICES_DIR/venv"

if [ -d "$VENV_DIR" ]; then
    log_success "Python 가상환경이 이미 생성되어 있습니다"
else
    log_info "Python 가상환경 생성 중..."
    python3 -m venv "$VENV_DIR"
    log_success "Python 가상환경 생성 완료"
fi

# 가상환경 활성화
source "$VENV_DIR/bin/activate"

# pip 업그레이드
log_info "pip 업그레이드 중..."
pip install --quiet --upgrade pip

# requirements.txt가 없으면 생성
if [ ! -f "$AI_SERVICES_DIR/requirements.txt" ]; then
    log_info "requirements.txt 생성 중..."
    
    cat > "$AI_SERVICES_DIR/requirements.txt" <<EOF
# Web Framework
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6

# AI Services
edge-tts==6.1.9
openai-whisper==20231117
faster-whisper==0.10.0

# Audio/Video Processing
pydub==0.25.1
ffmpeg-python==0.2.0

# HTTP Client
httpx==0.25.2
aiofiles==23.2.1

# Image Processing
Pillow==10.1.0

# Utilities
python-dotenv==1.0.0
numpy==1.24.3
EOF
fi

# 의존성 설치
log_info "Python 의존성 설치 중... (5-10분 소요)"
pip install --quiet -r "$AI_SERVICES_DIR/requirements.txt"

log_success "Python 의존성 설치 완료"

# 4. Whisper 모델 다운로드
log_info "Whisper 모델 다운로드 중..."

python3 -c "import whisper; whisper.load_model('base')" 2>/dev/null || {
    log_info "Whisper base 모델 다운로드 중... (~150MB)"
    python3 -c "import whisper; whisper.load_model('base')"
}

log_success "Whisper 모델 다운로드 완료"

# 가상환경 비활성화
deactivate

# 5. 서비스 파일 생성 (빈 파일)
log_info "서비스 파일 템플릿 생성 중..."

SERVICES_DIR="$AI_SERVICES_DIR/services"

# __init__.py
touch "$SERVICES_DIR/__init__.py"

# tts_service.py (간단한 템플릿)
if [ ! -f "$SERVICES_DIR/tts_service.py" ]; then
    cat > "$SERVICES_DIR/tts_service.py" <<'EOF'
import edge_tts
import asyncio
from pathlib import Path
import uuid

class TTSService:
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    async def generate(self, text: str, voice: str, speed: float = 1.0):
        """Edge TTS로 음성 생성"""
        filename = f"{uuid.uuid4()}.mp3"
        output_path = self.output_dir / filename
        
        rate = f"+{int((speed - 1) * 100)}%" if speed > 1 else f"{int((speed - 1) * 100)}%"
        
        communicate = edge_tts.Communicate(text, voice, rate=rate)
        await communicate.save(str(output_path))
        
        return str(output_path)
EOF
fi

log_success "서비스 템플릿 생성 완료"

# 6. 로그 디렉토리 확인
mkdir -p "$PROJECT_ROOT/logs"

# 7. 완료 메시지
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "2단계: AI 서비스 설치 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_info "설치된 서비스:"
echo "  ✓ Ollama (Llama 3.1 8B)"
echo "  ✓ Stable Diffusion WebUI"
echo "  ✓ Python 가상환경 + FastAPI"
echo "  ✓ Whisper (Base 모델)"
echo ""

log_info "수동 작업 필요:"
if [ ! -f "$SD_DIR/models/Stable-diffusion/sd_xl_turbo_1.0_fp16.safetensors" ]; then
    echo "  ⚠ SDXL 모델 다운로드 (설치 가이드 참조)"
fi
echo "  ⚠ FastAPI 서비스 코드 작성 (ai-services/app.py)"
echo ""

log_info "서비스 테스트:"
echo "  ${GREEN}# Ollama${NC}"
echo "  ${YELLOW}ollama run llama3.1:8b \"안녕하세요\"${NC}"
echo ""
echo "  ${GREEN}# Python 환경${NC}"
echo "  ${YELLOW}source $VENV_DIR/bin/activate${NC}"
echo "  ${YELLOW}python --version${NC}"
echo ""

log_success "다음 단계로 진행하세요:"
echo "  ${GREEN}./scripts/setup_n8n.sh${NC}"
echo ""
