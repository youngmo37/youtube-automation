#!/bin/bash
# =============================================================================
# start_all.sh - 모든 서비스 시작
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🚀 서비스 시작"
echo "   경로: $PROJECT_ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 1. Docker (n8n + PostgreSQL) ──────────────────────────────────────────────
info "Docker 시작..."
if ! systemctl is-active docker &>/dev/null; then
    sudo systemctl start docker && sleep 2
fi
cd "$PROJECT_ROOT" && docker-compose up -d
success "Docker 컨테이너 시작"

# ── 2. Ollama ─────────────────────────────────────────────────────────────────
info "Ollama 시작..."
if systemctl list-unit-files ollama.service &>/dev/null 2>&1; then
    sudo systemctl start ollama
else
    if ! pgrep -x ollama &>/dev/null; then
        nohup ollama serve > "$LOG_DIR/ollama.log" 2>&1 &
    fi
fi
sleep 2
if curl -s http://localhost:11434/api/tags &>/dev/null; then
    success "Ollama 실행 중"
else
    warn "Ollama 응답 없음 - 로그: $LOG_DIR/ollama.log"
fi

# ── 3. Stable Diffusion WebUI ─────────────────────────────────────────────────
SD_DIR="$PROJECT_ROOT/stable-diffusion-webui"
if [ -f "$SD_DIR/webui.sh" ]; then
    if pgrep -f "webui.sh" &>/dev/null; then
        success "SD WebUI 이미 실행 중"
    else
        # Python 3.10 venv 확인 및 생성
        if [ -d "$SD_DIR/venv" ]; then
            VENV_PY=$("$SD_DIR/venv/bin/python" --version 2>&1)
            if echo "$VENV_PY" | grep -q "3.10"; then
                success "SD WebUI venv Python 3.10 확인"
            else
                warn "SD WebUI venv Python 버전 불일치 ($VENV_PY) → 3.10으로 재생성"
                rm -rf "$SD_DIR/venv"
            fi
        fi
        if [ ! -d "$SD_DIR/venv" ]; then
            if command -v python3.10 &>/dev/null; then
                info "SD WebUI venv Python 3.10으로 생성..."
                python3.10 -m venv "$SD_DIR/venv"
                "$SD_DIR/venv/bin/pip" install --upgrade pip setuptools wheel -q
                success "SD WebUI venv 생성 완료"
            else
                warn "python3.10 없음 → 설치: sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt install python3.10 python3.10-venv"
            fi
        fi

        info "SD WebUI 시작 중... (2-5분 소요)"
        cd "$SD_DIR"
        nohup bash webui.sh --listen --api --medvram --xformers --nowebui \
            --skip-python-version-check \
            > "$LOG_DIR/sdwebui.log" 2>&1 &
        cd "$PROJECT_ROOT"

        # 준비 대기 (최대 5분)
        for i in $(seq 1 60); do
            if curl -s http://localhost:7860/sdapi/v1/sd-models &>/dev/null; then
                success "SD WebUI 준비 완료"
                break
            fi
            [ "$i" -eq 60 ] && warn "SD WebUI 준비 중 (백그라운드 로딩 중)"
            sleep 5
        done
    fi
else
    warn "SD WebUI 미설치 - setup_ai_services.sh 실행 필요"
fi

# ── 4. FastAPI ────────────────────────────────────────────────────────────────
VENV="$PROJECT_ROOT/ai-services/venv"
APP="$PROJECT_ROOT/ai-services/app.py"
if [ -f "$APP" ] && [ -d "$VENV" ]; then
    if pgrep -f "uvicorn.*app:app" &>/dev/null; then
        success "FastAPI 이미 실행 중"
    else
        info "FastAPI 시작..."
        cd "$PROJECT_ROOT/ai-services"
        source "$VENV/bin/activate"
        nohup uvicorn app:app --host 0.0.0.0 --port 8000 \
            > "$LOG_DIR/fastapi.log" 2>&1 &
        deactivate
        cd "$PROJECT_ROOT"
        sleep 3
        if curl -s http://localhost:8000/health &>/dev/null; then
            success "FastAPI 실행 중"
        else
            warn "FastAPI 응답 없음 - 로그: $LOG_DIR/fastapi.log"
        fi
    fi
else
    warn "FastAPI 미설치 - setup_ai_services.sh 실행 필요"
fi

# ── 상태 요약 ─────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
chk() {
    local label=$1 url=$2
    printf "  %-16s" "$label:"
    curl -s --max-time 3 "$url" &>/dev/null \
        && echo -e "${GREEN}✅ OK${NC}" \
        || echo -e "${RED}❌ FAIL${NC}"
}
chk "Ollama"    "http://localhost:11434/api/tags"
chk "SD WebUI"  "http://localhost:7860/sdapi/v1/sd-models"
chk "FastAPI"   "http://localhost:8000/health"
chk "n8n"       "http://localhost:5678/healthz"
echo ""
echo "  🌐 n8n:          http://localhost:5678"
echo "  📖 FastAPI Docs: http://localhost:8000/docs"
echo "  🎨 SD WebUI:     http://localhost:7860"
echo ""
echo "  로그: tail -f $LOG_DIR/fastapi.log"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
