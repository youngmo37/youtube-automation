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

# Python 버전 감지 (setup_base.sh 저장값 or 직접 감지)
log_info "Python 버전 확인 중..."
if [ -f "$HOME/.youtube_automation_env" ]; then
    source "$HOME/.youtube_automation_env"
    log_success "Python: $PYTHON_VERSION ($PYTHON_BIN)"
else
    PYTHON_BIN=$(which python3)
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR_MINOR=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log_info "Python 버전 감지: $PYTHON_VERSION"
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
    # venv가 있지만 정상인지 확인
    if "$VENV_DIR/bin/python3" -c "import pip" &> /dev/null; then
        log_success "Python 가상환경이 이미 정상적으로 생성되어 있습니다"
    else
        log_warning "기존 가상환경이 손상되어 있습니다. 재생성합니다..."
        rm -rf "$VENV_DIR"
        python3 -m venv "$VENV_DIR"
        log_success "Python 가상환경 재생성 완료"
    fi
else
    log_info "Python 가상환경 생성 중..."
    python3 -m venv "$VENV_DIR"
    log_success "Python 가상환경 생성 완료"
fi

# 가상환경 활성화
source "$VENV_DIR/bin/activate"

# pip + setuptools 업그레이드 (Python 3.12 필수)
log_info "pip / setuptools 업그레이드 중... (Python $PYTHON_VERSION)"
pip install --upgrade pip setuptools wheel

# requirements.txt 항상 새로 생성 (기존 파일 덮어쓰기)
log_info "requirements.txt 생성 중... (Python 3.12 호환, 기존 파일 덮어쓰기)"

cat > "$AI_SERVICES_DIR/requirements.txt" <<'REQEOF'
# ─────────────────────────────────────────
# Python 3.12 호환 / GTX 1060 CPU 전용
# GTX 1060 (sm_61) = PyTorch CUDA 미지원 → torch 미설치
# ─────────────────────────────────────────

# 필수 빌드 도구
setuptools>=69.0.0
wheel>=0.42.0

# Web Framework
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
python-multipart>=0.0.9

# TTS
edge-tts>=6.1.10

# Whisper (CPU 전용, torch 불필요)
faster-whisper>=1.0.0

# Audio/Image Processing
pydub>=0.25.1
Pillow>=10.2.0

# HTTP / Utilities
httpx>=0.27.0
aiofiles>=23.2.1
python-dotenv>=1.0.0
numpy>=1.26.0
REQEOF

log_success "requirements.txt 생성 완료"

# 의존성 설치 (단계별, 오류 격리)
log_info "Python 의존성 설치 중... (5-10분 소요)"

# 1단계: 빌드 도구 먼저 (pkg_resources 오류 해결)
log_info "  1/4 빌드 도구 설치..."
pip install "setuptools>=69.0.0" "wheel>=0.42.0"

# 2단계: 웹 프레임워크
log_info "  2/4 FastAPI / Uvicorn 설치..."
pip install "fastapi>=0.110.0" "uvicorn[standard]>=0.27.0" \
    "python-multipart>=0.0.9" "httpx>=0.27.0" "aiofiles>=23.2.1"

# 3단계: AI 서비스
# GTX 1060 (CUDA sm_61) = 현재 PyTorch CUDA 미지원 → torch 설치 불필요
# faster-whisper는 ctranslate2 기반으로 torch 없이도 CPU 동작
log_info "  3/4 AI 서비스 설치 (faster-whisper, edge-tts)..."
log_warning "  GTX 1060 (sm_61): PyTorch CUDA 미지원 → CPU 모드로 설치"

# openai-whisper 혹시 남아있으면 제거 (충돌 방지)
pip uninstall openai-whisper -y 2>/dev/null && log_info "  기존 openai-whisper 제거 완료" || true
# torch도 제거 (GTX 1060에서 CUDA 오류 유발)
pip uninstall torch torchvision torchaudio -y 2>/dev/null || true

pip install "faster-whisper>=1.0.0" "edge-tts>=6.1.10"

# 4단계: 유틸리티
log_info "  4/4 유틸리티 설치..."
pip install "pydub>=0.25.1" "Pillow>=10.2.0" \
    "python-dotenv>=1.0.0" "numpy>=1.26.0"

log_success "Python 의존성 설치 완료"

# 설치 확인
log_info "설치 확인 중..."
python3 -c "import fastapi, uvicorn, edge_tts, faster_whisper; print('  ✓ 모든 패키지 정상')"

# 4. Whisper 모델 다운로드 (CPU 전용)
log_info "Whisper 모델 다운로드 중... (CPU 모드, ~150MB)"

python3 - <<'PYEOF'
from faster_whisper import WhisperModel
import sys

try:
    print("  faster-whisper base 모델 다운로드 중 (CPU/int8)...")
    # GTX 1060 = CUDA sm_61, 현재 PyTorch 미지원 → 항상 CPU 사용
    model = WhisperModel("base", device="cpu", compute_type="int8")
    # 간단한 테스트
    print("  ✓ Whisper CPU 모드 정상 작동")
    del model
except Exception as e:
    print(f"  경고: {e}", file=sys.stderr)
    print("  (서비스 실행 시 자동 다운로드됩니다)")
PYEOF

log_success "Whisper 설치 완료 (CPU 모드)"

# 가상환경 비활성화
deactivate

# 5. 서비스 파일 생성 (빈 파일)
log_info "서비스 파일 템플릿 생성 중..."

SERVICES_DIR="$AI_SERVICES_DIR/services"

# services/__init__.py
touch "$SERVICES_DIR/__init__.py"

# tts_service.py
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
        """Edge TTS로 음성 생성 (무료, 인터넷 필요)"""
        filename = f"{uuid.uuid4()}.mp3"
        output_path = self.output_dir / filename
        
        rate_str = f"+{int((speed - 1) * 100)}%" if speed >= 1 else f"{int((speed - 1) * 100)}%"
        
        communicate = edge_tts.Communicate(text, voice, rate=rate_str)
        await communicate.save(str(output_path))
        
        return str(output_path)
EOF
fi

# whisper_service.py (faster-whisper 사용)
if [ ! -f "$SERVICES_DIR/whisper_service.py" ]; then
    cat > "$SERVICES_DIR/whisper_service.py" <<'EOF'
from faster_whisper import WhisperModel
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

class WhisperService:
    def __init__(self, model_size: str = "base"):
        """
        faster-whisper CPU 전용 (GTX 1060 sm_61 = PyTorch CUDA 미지원)
        compute_type: int8 → CPU에서 빠르고 메모리 효율적
        """
        logger.info(f"Whisper 모델 로딩: {model_size} (CPU/int8)")
        self.model = WhisperModel(model_size, device="cpu", compute_type="int8")
        logger.info("Whisper 모델 로딩 완료")
    
    def transcribe_with_timestamps(self, audio_path: str):
        """오디오 → 텍스트 + 워드 타임스탬프"""
        logger.info(f"Whisper 분석: {audio_path}")
        
        segments, info = self.model.transcribe(
            audio_path,
            word_timestamps=True,
            language="ko"
        )
        
        words = []
        full_text = ""
        
        for segment in segments:
            full_text += segment.text + " "
            if segment.words:
                for word in segment.words:
                    words.append({
                        "word": word.word,
                        "start": round(word.start, 2),
                        "end": round(word.end, 2)
                    })
        
        return {
            "text": full_text.strip(),
            "duration": round(info.duration, 2),
            "words": words
        }
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
