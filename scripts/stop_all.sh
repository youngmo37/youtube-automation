#!/bin/bash

################################################################################
# YouTube Automation - 모든 서비스 중지
#
# 실행: ./scripts/stop_all.sh
################################################################################

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

PROJECT_ROOT="$HOME/youtube-automation-wsl"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🛑 YouTube Automation - 서비스 중지"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. FastAPI 중지
log_info "FastAPI 중지 중..."

if pgrep -f "uvicorn.*app:app" > /dev/null; then
    pkill -15 -f "uvicorn.*app:app"
    sleep 2
    
    # 강제 종료 (여전히 실행 중이면)
    if pgrep -f "uvicorn.*app:app" > /dev/null; then
        pkill -9 -f "uvicorn.*app:app"
    fi
    
    log_success "FastAPI 중지 완료"
else
    log_info "FastAPI가 실행 중이 아닙니다"
fi

# 2. Stable Diffusion WebUI 중지
log_info "SD WebUI 중지 중..."

if pgrep -f "webui.sh" > /dev/null; then
    pkill -15 -f "webui.sh"
    pkill -15 -f "python.*launch.py"
    sleep 2
    
    # 강제 종료
    pkill -9 -f "webui.sh"
    pkill -9 -f "python.*launch.py"
    
    log_success "SD WebUI 중지 완료"
else
    log_info "SD WebUI가 실행 중이 아닙니다"
fi

# 3. Docker Compose 중지 (n8n + PostgreSQL)
log_info "Docker 컨테이너 중지 중..."

cd "$PROJECT_ROOT"

if docker-compose ps | grep -q "Up"; then
    docker-compose down
    log_success "Docker 컨테이너 중지 완료"
else
    log_info "Docker 컨테이너가 실행 중이 아닙니다"
fi

# 4. Ollama 중지 (선택)
log_info "Ollama 상태 확인 중..."

if systemctl is-active ollama &> /dev/null; then
    read -p "Ollama도 중지하시겠습니까? (다른 작업에서 사용 중일 수 있음) (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemctl stop ollama
        log_success "Ollama 중지 완료"
    else
        log_info "Ollama는 계속 실행 중입니다"
    fi
else
    log_info "Ollama가 실행 중이 아닙니다"
fi

# 5. 완료 메시지
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "모든 서비스 중지 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_info "남은 프로세스 확인:"
ps aux | grep -E "uvicorn|webui|n8n" | grep -v grep || echo "  없음"

echo ""
log_info "서비스 재시작:"
echo "  ${GREEN}./scripts/start_all.sh${NC}"
echo ""
