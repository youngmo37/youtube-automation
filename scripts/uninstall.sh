#!/bin/bash
# =============================================================================
# uninstall.sh - 설치된 모든 서비스 완전 삭제
#
# 삭제 항목:
#   - Docker 컨테이너 / 볼륨 (n8n, PostgreSQL)
#   - Ollama + 모델
#   - Stable Diffusion WebUI + 모델
#   - Python venv
#   - 생성된 미디어 파일 (선택)
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "   ${RED}⚠️  완전 삭제 스크립트${NC}"
echo "   경로: $PROJECT_ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
warn "다음 항목이 삭제됩니다:"
echo "  - Docker 컨테이너 + 볼륨 (n8n, PostgreSQL 데이터 포함)"
echo "  - Ollama 서비스 + 모델 (~5GB)"
echo "  - Stable Diffusion WebUI + SDXL 모델 (~7GB)"
echo "  - Python 가상환경"
echo ""
read -rp "계속하시겠습니까? (yes 입력) " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "취소됨"
    exit 0
fi
echo ""

# ── 1. 실행 중인 서비스 중지 ──────────────────────────────────────────────────
info "실행 중인 서비스 중지..."
pkill -9 -f "uvicorn.*app:app" 2>/dev/null || true
pkill -9 -f "webui.sh"         2>/dev/null || true
pkill -9 -f "python.*launch"   2>/dev/null || true
success "프로세스 종료"

# ── 2. Docker 컨테이너 + 볼륨 삭제 ───────────────────────────────────────────
info "Docker 컨테이너 및 볼륨 삭제..."
cd "$PROJECT_ROOT" 2>/dev/null || true
docker-compose down -v --remove-orphans 2>/dev/null || true
docker rm -f n8n n8n-postgres 2>/dev/null || true
docker volume rm "$(basename "$PROJECT_ROOT")_postgres_data" 2>/dev/null || true
success "Docker 정리 완료"

# ── 3. Ollama 삭제 ────────────────────────────────────────────────────────────
info "Ollama 삭제 중..."
if systemctl is-active ollama &>/dev/null; then
    sudo systemctl stop ollama
    sudo systemctl disable ollama 2>/dev/null || true
fi
sudo rm -f /usr/local/bin/ollama
sudo rm -rf /usr/local/lib/ollama
sudo rm -f /etc/systemd/system/ollama.service
sudo systemctl daemon-reload 2>/dev/null || true
success "Ollama 바이너리 삭제"

read -rp "Ollama 모델도 삭제하시겠습니까? (~5GB) (y/n) " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.ollama"
    success "Ollama 모델 삭제 (~5GB 확보)"
else
    warn "Ollama 모델 유지: $HOME/.ollama"
fi

# ── 4. Stable Diffusion WebUI 삭제 ────────────────────────────────────────────
SD_DIR="$PROJECT_ROOT/stable-diffusion-webui"
if [ -d "$SD_DIR" ]; then
    read -rp "Stable Diffusion WebUI를 삭제하시겠습니까? (~7GB+ 모델 포함) (y/n) " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        info "SD WebUI 삭제 중..."
        rm -rf "$SD_DIR"
        success "SD WebUI 삭제 완료"
    else
        warn "SD WebUI 유지: $SD_DIR"
    fi
fi

# ── 5. Python 가상환경 삭제 ───────────────────────────────────────────────────
VENV="$PROJECT_ROOT/ai-services/venv"
if [ -d "$VENV" ]; then
    info "Python venv 삭제..."
    rm -rf "$VENV"
    success "Python venv 삭제"
fi

# ── 6. 생성 파일 삭제 (선택) ──────────────────────────────────────────────────
MEDIA_DIR="$PROJECT_ROOT/media"
if [ -d "$MEDIA_DIR" ]; then
    MEDIA_SIZE=$(du -sh "$MEDIA_DIR" 2>/dev/null | awk '{print $1}')
    read -rp "생성된 미디어 파일도 삭제하시겠습니까? ($MEDIA_SIZE) (y/n) " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        rm -rf "$MEDIA_DIR"
        success "미디어 파일 삭제"
    fi
fi

# ── 7. 로그 삭제 (선택) ───────────────────────────────────────────────────────
LOG_DIR="$PROJECT_ROOT/logs"
if [ -d "$LOG_DIR" ]; then
    read -rp "로그 파일도 삭제하시겠습니까? (y/n) " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        rm -rf "$LOG_DIR"
        success "로그 삭제"
    fi
fi

# ── 8. 환경 파일 삭제 ─────────────────────────────────────────────────────────
rm -f "$HOME/.youtube_automation_env"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "삭제 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
warn "스크립트 파일 자체는 유지됩니다."
echo "처음부터 다시 설치하려면:"
echo "  ./scripts/setup_base.sh"
echo ""
