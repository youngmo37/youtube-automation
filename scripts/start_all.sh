#!/bin/bash

################################################################################
# YouTube Automation - 모든 서비스 시작
#
# 실행: ./scripts/start_all.sh
################################################################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

PROJECT_ROOT="$HOME/youtube-automation-wsl"
LOG_DIR="$PROJECT_ROOT/logs"

mkdir -p "$LOG_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🚀 YouTube Automation - 서비스 시작"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Docker 서비스 시작
log_info "Docker 서비스 확인 중..."

if ! systemctl is-active docker &> /dev/null; then
    log_info "Docker 시작 중..."
    sudo systemctl start docker
    sleep 2
fi

log_success "Docker 실행 중"

# 2. Docker Compose (n8n + PostgreSQL)
log_info "n8n 컨테이너 시작 중..."

cd "$PROJECT_ROOT"
docker-compose up -d

sleep 5
log_success "n8n 컨테이너 시작 완료"

# 3. Ollama
log_info "Ollama 서비스 확인 중..."

if ! systemctl is-active ollama &> /dev/null; then
    log_info "Ollama 시작 중..."
    sudo systemctl start ollama
    sleep 3
fi

# Ollama 헬스 체크
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    log_success "Ollama 실행 중"
else
    log_error "Ollama 시작 실패"
fi

# 4. Stable Diffusion WebUI
log_info "Stable Diffusion WebUI 확인 중..."

SD_DIR="$PROJECT_ROOT/stable-diffusion-webui"

if pgrep -f "webui.sh" > /dev/null; then
    log_success "SD WebUI가 이미 실행 중입니다"
else
    if [ ! -f "$SD_DIR/webui.sh" ]; then
        log_error "SD WebUI가 설치되지 않았습니다"
    else
        log_info "SD WebUI 시작 중... (1-2분 소요)"
        
        cd "$SD_DIR"
        nohup ./webui.sh --listen --api --xformers --nowebui > "$LOG_DIR/sdwebui.log" 2>&1 &
        
        # API 준비 대기
        log_info "SD WebUI API 준비 대기 중..."
        
        for i in {1..60}; do
            if curl -s http://localhost:7860/sdapi/v1/sd-models > /dev/null 2>&1; then
                log_success "SD WebUI 준비 완료"
                break
            fi
            
            if [ $i -eq 60 ]; then
                log_warning "SD WebUI 준비 시간 초과 (계속 로딩 중일 수 있음)"
                log_info "로그 확인: tail -f $LOG_DIR/sdwebui.log"
            fi
            
            sleep 2
        done
        
        cd "$PROJECT_ROOT"
    fi
fi

# 5. FastAPI
log_info "FastAPI 서버 확인 중..."

if pgrep -f "uvicorn.*app:app" > /dev/null; then
    log_success "FastAPI가 이미 실행 중입니다"
else
    if [ ! -f "$PROJECT_ROOT/ai-services/app.py" ]; then
        log_warning "FastAPI 코드가 없습니다 (ai-services/app.py)"
        log_info "README.md의 FastAPI 코드를 참조하세요"
    else
        log_info "FastAPI 시작 중..."
        
        cd "$PROJECT_ROOT/ai-services"
        source venv/bin/activate
        
        nohup uvicorn app:app --host 0.0.0.0 --port 8000 --workers 2 > "$LOG_DIR/fastapi.log" 2>&1 &
        
        sleep 3
        
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            log_success "FastAPI 시작 완료"
        else
            log_warning "FastAPI 시작 확인 불가 (로그 확인 필요)"
        fi
        
        deactivate
        cd "$PROJECT_ROOT"
    fi
fi

# 6. 최종 상태 확인
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   📊 서비스 상태"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_service() {
    local name=$1
    local url=$2
    
    if curl -s --max-time 5 "$url" > /dev/null 2>&1; then
        echo -e "   ${name}: ${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "   ${name}: ${RED}❌ FAIL${NC}"
        return 1
    fi
}

check_service "Ollama    " "http://localhost:11434/api/tags"
check_service "SD WebUI  " "http://localhost:7860/sdapi/v1/sd-models"
check_service "FastAPI   " "http://localhost:8000/health"
check_service "PostgreSQL" "http://localhost:5432" || echo -e "   PostgreSQL: ${GREEN}✅ OK${NC} (내부 네트워크)"
check_service "n8n       " "http://localhost:5678/healthz"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🌐 접속 주소"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   n8n:           ${GREEN}http://localhost:5678${NC}"
echo "   FastAPI Docs:  ${GREEN}http://localhost:8000/docs${NC}"
echo "   SD WebUI:      ${GREEN}http://localhost:7860${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   📝 로그 위치"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   n8n:       ${YELLOW}docker logs -f n8n${NC}"
echo "   SD WebUI:  ${YELLOW}tail -f $LOG_DIR/sdwebui.log${NC}"
echo "   FastAPI:   ${YELLOW}tail -f $LOG_DIR/fastapi.log${NC}"
echo ""

log_success "✅ 모든 서비스 시작 완료!"
echo ""
