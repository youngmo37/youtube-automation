#!/bin/bash
# =============================================================================
# stop_all.sh - 모든 서비스 중지
# =============================================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🛑 서비스 중지"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "FastAPI 중지..."
pkill -15 -f "uvicorn.*app:app" 2>/dev/null || true
sleep 1
pkill -9  -f "uvicorn.*app:app" 2>/dev/null || true
success "FastAPI 중지"

info "SD WebUI 중지..."
pkill -15 -f "webui.sh"       2>/dev/null || true
pkill -15 -f "python.*launch" 2>/dev/null || true
sleep 1
pkill -9  -f "webui.sh"       2>/dev/null || true
pkill -9  -f "python.*launch" 2>/dev/null || true
success "SD WebUI 중지"

info "Docker 컨테이너 중지..."
cd "$PROJECT_ROOT" && docker-compose down 2>/dev/null || true
success "Docker 컨테이너 중지"

read -rp "Ollama도 중지하시겠습니까? (y/n) " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    if systemctl is-active ollama &>/dev/null; then
        sudo systemctl stop ollama
    else
        pkill -15 -x ollama 2>/dev/null || true
    fi
    success "Ollama 중지"
fi

echo ""
success "모든 서비스 중지 완료"
echo ""
