#!/bin/bash
# =============================================================================
# setup_ai_services.sh - 2단계: AI 서비스 설치
# - Ollama + Llama 3.1 8B
# - Stable Diffusion WebUI 클론
# - Python venv + faster-whisper (CPU) + FastAPI
#
# 주의: GTX 1060 (sm_61) = 최신 PyTorch CUDA 미지원
#       → torch 설치 안 함, faster-whisper CPU 전용
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── 경로: 스크립트 위치 기반 자동 감지 ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AI_DIR="$PROJECT_ROOT/ai-services"
SERVICES_DIR="$AI_DIR/services"
VENV="$AI_DIR/venv"
SD_DIR="$PROJECT_ROOT/stable-diffusion-webui"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   2단계: AI 서비스 설치"
echo "   경로: $PROJECT_ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# systemd 확인
if ! systemctl --version &>/dev/null; then
    warn "systemd 미활성화 → Ollama 서비스 등록 불가 (수동 실행은 가능)"
fi

# ── 1. Ollama ─────────────────────────────────────────────────────────────────
info "Ollama 확인 중..."
if command -v ollama &>/dev/null; then
    success "Ollama 이미 설치됨"
else
    info "Ollama 설치 중..."
    curl -fsSL https://ollama.com/install.sh | sh
    success "Ollama 설치 완료"
fi

# Ollama 서비스 시작
if systemctl is-active ollama &>/dev/null; then
    success "Ollama 서비스 실행 중"
else
    if systemctl list-unit-files ollama.service &>/dev/null; then
        sudo systemctl enable --now ollama
        sleep 3
    else
        # systemd 없을 경우 백그라운드 실행
        if ! pgrep -x ollama &>/dev/null; then
            nohup ollama serve > "$PROJECT_ROOT/logs/ollama.log" 2>&1 &
            sleep 3
        fi
    fi
fi

# Llama 3.1 8B 다운로드
info "Llama 3.1 8B 확인 중..."
if ollama list 2>/dev/null | grep -q "llama3.1:8b"; then
    success "Llama 3.1 8B 이미 설치됨"
else
    info "Llama 3.1 8B 다운로드 중... (~5GB, 5-10분 소요)"
    ollama pull llama3.1:8b
    success "Llama 3.1 8B 다운로드 완료"
fi

# ── 2. Stable Diffusion WebUI ─────────────────────────────────────────────────
info "Stable Diffusion WebUI 확인 중..."
if [ -d "$SD_DIR/.git" ]; then
    success "SD WebUI 이미 클론됨"
else
    info "SD WebUI 클론 중..."
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git "$SD_DIR"
    success "SD WebUI 클론 완료"
fi

mkdir -p "$SD_DIR/models/Stable-diffusion"

# SDXL 모델 확인
if ls "$SD_DIR/models/Stable-diffusion/"*.safetensors &>/dev/null; then
    success "SDXL 모델 이미 존재"
else
    warn "SDXL 모델 없음 (~7GB 수동 다운로드 필요)"
    echo ""
    echo "  다운로드 명령:"
    echo "  cd $SD_DIR/models/Stable-diffusion"
    echo "  wget https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors"
    echo ""
    read -rp "지금 다운로드하시겠습니까? (y/n) " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        cd "$SD_DIR/models/Stable-diffusion" || exit 1
        wget -q --show-progress \
            https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors
        success "SDXL-Turbo 다운로드 완료"
        cd "$PROJECT_ROOT" || exit 1
    fi
fi

# ── 3. Python 가상환경 ────────────────────────────────────────────────────────
info "Python 가상환경 설정 중..."
info "Python 버전: $(python3 --version)"

# 손상된 venv 감지 및 재생성
if [ -d "$VENV" ]; then
    if "$VENV/bin/python3" -c "import pip" &>/dev/null 2>&1; then
        success "Python venv 이미 정상 존재"
    else
        warn "venv 손상 감지 → 재생성"
        rm -rf "$VENV"
        python3 -m venv "$VENV"
        success "Python venv 재생성 완료"
    fi
else
    info "Python venv 생성 중..."
    python3 -m venv "$VENV"
    success "Python venv 생성 완료"
fi

# ── 4. Python 패키지 설치 ─────────────────────────────────────────────────────
source "$VENV/bin/activate"

info "pip 업그레이드 중..."
pip install --upgrade pip setuptools wheel

# requirements.txt 항상 새로 생성 (덮어쓰기)
info "requirements.txt 생성 중..."
cat > "$AI_DIR/requirements.txt" <<'REQEOF'
# =============================================
# Python 3.x 호환 / GTX 1060 CPU 전용
# torch 미포함 (GTX 1060 sm_61 = CUDA 미지원)
# =============================================
setuptools>=69.0.0
wheel>=0.42.0
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
python-multipart>=0.0.9
edge-tts>=6.1.10
faster-whisper>=1.0.0
pydub>=0.25.1
httpx>=0.27.0
aiofiles>=23.2.1
Pillow>=10.2.0
python-dotenv>=1.0.0
numpy>=1.26.0
REQEOF

info "패키지 설치 중 (1/4) - 빌드 도구..."
pip install "setuptools>=69.0.0" "wheel>=0.42.0"

info "패키지 설치 중 (2/4) - FastAPI..."
pip install "fastapi>=0.110.0" "uvicorn[standard]>=0.27.0" \
    "python-multipart>=0.0.9" "httpx>=0.27.0" "aiofiles>=23.2.1"

info "패키지 설치 중 (3/4) - AI 서비스 (torch 없이)..."
# torch 혹시 설치돼 있으면 제거 (GTX 1060 CUDA 충돌 방지)
pip uninstall torch torchvision torchaudio openai-whisper -y 2>/dev/null || true
pip install "faster-whisper>=1.0.0" "edge-tts>=6.1.10"

info "패키지 설치 중 (4/4) - 유틸리티..."
pip install "pydub>=0.25.1" "Pillow>=10.2.0" \
    "python-dotenv>=1.0.0" "numpy>=1.26.0"

success "Python 패키지 설치 완료"

# ── 5. 설치 확인 ──────────────────────────────────────────────────────────────
info "설치 확인 중..."
python3 -c "import fastapi, uvicorn, edge_tts, faster_whisper; print('  ✓ 모든 패키지 정상')" \
    || { error "패키지 import 실패"; }

# ── 6. Whisper 모델 사전 다운로드 (CPU/int8) ─────────────────────────────────
info "Whisper base 모델 다운로드 중... (CPU 전용, ~150MB)"
python3 - <<'PYEOF'
from faster_whisper import WhisperModel
try:
    model = WhisperModel("base", device="cpu", compute_type="int8")
    print("  ✓ Whisper CPU/int8 모드 정상")
    del model
except Exception as e:
    print(f"  경고: {e}\n  (서비스 실행 시 자동 다운로드됩니다)")
PYEOF

deactivate

# ── 7. 서비스 파일 생성 ───────────────────────────────────────────────────────
info "서비스 파일 생성 중..."

# 디렉토리 보장
mkdir -p "$SERVICES_DIR"
touch "$SERVICES_DIR/__init__.py"

# tts_service.py
cat > "$SERVICES_DIR/tts_service.py" <<'EOF'
import edge_tts, asyncio, uuid
from pathlib import Path

class TTSService:
    def __init__(self, output_dir: str):
        self.out = Path(output_dir)
        self.out.mkdir(parents=True, exist_ok=True)

    async def generate(self, text: str, voice: str = "ko-KR-InJoonNeural", speed: float = 1.0) -> str:
        path = self.out / f"{uuid.uuid4()}.mp3"
        rate = f"+{int((speed-1)*100)}%" if speed >= 1 else f"{int((speed-1)*100)}%"
        await edge_tts.Communicate(text, voice, rate=rate).save(str(path))
        return str(path)
EOF

# whisper_service.py (CPU 전용)
cat > "$SERVICES_DIR/whisper_service.py" <<'EOF'
import logging
from faster_whisper import WhisperModel

logger = logging.getLogger(__name__)

class WhisperService:
    def __init__(self, model_size: str = "base"):
        # GTX 1060 (sm_61) = PyTorch CUDA 미지원 → 항상 CPU
        logger.info(f"Whisper 로딩: {model_size} (CPU/int8)")
        self.model = WhisperModel(model_size, device="cpu", compute_type="int8")

    def transcribe(self, audio_path: str) -> dict:
        segments, info = self.model.transcribe(
            audio_path, word_timestamps=True, language="ko"
        )
        words, text = [], ""
        for seg in segments:
            text += seg.text + " "
            for w in (seg.words or []):
                words.append({"word": w.word, "start": round(w.start, 2), "end": round(w.end, 2)})
        return {"text": text.strip(), "duration": round(info.duration, 2), "words": words}
EOF

# app.py (기본 FastAPI)
cat > "$AI_DIR/app.py" <<'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from pathlib import Path
import asyncio, os

from services.tts_service import TTSService
from services.whisper_service import WhisperService

app = FastAPI(title="YouTube Automation API")

BASE_DIR = Path(__file__).parent.parent
MEDIA_DIR = BASE_DIR / "media"

tts = TTSService(str(MEDIA_DIR / "audio"))
whisper = WhisperService()

class TTSRequest(BaseModel):
    script: str
    voice: str = "ko-KR-InJoonNeural"
    speed: float = 1.0

class WhisperRequest(BaseModel):
    audio_path: str

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.post("/api/generate-audio")
async def generate_audio(req: TTSRequest):
    path = await tts.generate(req.script, req.voice, req.speed)
    return {"status": "success", "audio_path": path}

@app.post("/api/analyze-audio")
def analyze_audio(req: WhisperRequest):
    result = whisper.transcribe(req.audio_path)
    return {"status": "success", **result}
EOF

success "서비스 파일 생성 완료"

# ── 8. 로그 디렉토리 ──────────────────────────────────────────────────────────
mkdir -p "$PROJECT_ROOT/logs"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "2단계 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ✓ Ollama + Llama 3.1 8B"
echo "  ✓ Stable Diffusion WebUI"
echo "  ✓ Python venv ($(python3 --version))"
echo "  ✓ faster-whisper (CPU/int8)"
echo "  ✓ FastAPI + Edge TTS"
echo ""
echo "다음 단계:"
echo "  ./scripts/setup_n8n.sh"
echo ""
