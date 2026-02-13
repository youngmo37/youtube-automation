#!/bin/bash

################################################################################
# YouTube Automation - 3단계: n8n 설정
# 
# 이 스크립트는 다음을 수행합니다:
# - docker-compose.yml 생성
# - .env 파일 설정
# - n8n + PostgreSQL 컨테이너 시작
# - 서비스 헬스 체크
#
# 실행: ./scripts/setup_n8n.sh
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
echo "   YouTube Automation - 3단계: n8n 설정"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_ROOT"

# 1. .env 파일 확인 및 생성
log_info ".env 파일 확인 중..."

if [ -f ".env" ]; then
    log_success ".env 파일이 이미 존재합니다"
else
    if [ -f ".env.example" ]; then
        log_info ".env.example에서 복사 중..."
        cp .env.example .env
    else
        log_info ".env 파일 생성 중..."
        cat > .env <<'EOF'
# n8n 인증
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=admin123

# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=n8n_password
POSTGRES_DB=n8n

# 외부 API Keys (나중에 설정)
PERPLEXITY_API_KEY=
AZURE_OPENAI_KEY=
AZURE_OPENAI_ENDPOINT=
YOUTUBE_CLIENT_ID=
YOUTUBE_CLIENT_SECRET=
EOF
    fi
    
    log_success ".env 파일 생성 완료"
    log_warning "⚠️  보안을 위해 비밀번호를 변경하세요: nano .env"
fi

# 2. docker-compose.yml 확인 및 생성
log_info "docker-compose.yml 확인 중..."

if [ -f "docker-compose.yml" ]; then
    log_success "docker-compose.yml이 이미 존재합니다"
else
    log_info "docker-compose.yml 생성 중..."
    cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  # PostgreSQL 데이터베이스
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ai-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # n8n 워크플로우 엔진
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - N8N_HOST=localhost
      - N8N_SECURE_COOKIE=false
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=Asia/Seoul
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - ./n8n-data:/home/node/.n8n
      - ./media:/media
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - ai-network
    extra_hosts:
      # WSL Docker 호스트 접근 (FastAPI, Ollama 등)
      - "host.docker.internal:172.17.0.1"
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ai-network:
    driver: bridge

volumes:
  postgres_data:
EOF
    
    log_success "docker-compose.yml 생성 완료"
fi

# 3. Docker 서비스 확인
log_info "Docker 서비스 확인 중..."

if ! systemctl is-active docker &> /dev/null; then
    log_info "Docker 서비스 시작 중..."
    sudo systemctl start docker
    sleep 2
fi

if systemctl is-active docker &> /dev/null; then
    log_success "Docker 서비스 실행 중"
else
    log_error "Docker 서비스를 시작할 수 없습니다"
    exit 1
fi

# 4. 기존 컨테이너 확인
log_info "기존 컨테이너 확인 중..."

if docker ps -a | grep -q "n8n"; then
    log_warning "기존 n8n 컨테이너가 존재합니다"
    
    read -p "기존 컨테이너를 삭제하고 새로 시작하시겠습니까? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "기존 컨테이너 중지 및 삭제 중..."
        docker-compose down
        log_success "기존 컨테이너 삭제 완료"
    else
        log_info "기존 컨테이너 유지"
    fi
fi

# 5. Docker Compose 실행
log_info "Docker 컨테이너 시작 중..."

docker-compose up -d

log_success "Docker 컨테이너 시작 완료"

# 6. 컨테이너 상태 확인
log_info "컨테이너 상태 확인 중... (30초 대기)"

sleep 30

POSTGRES_STATUS=$(docker inspect -f '{{.State.Health.Status}}' n8n-postgres 2>/dev/null || echo "unknown")
N8N_STATUS=$(docker inspect -f '{{.State.Status}}' n8n 2>/dev/null || echo "unknown")

echo ""
echo "컨테이너 상태:"
echo "  PostgreSQL: $POSTGRES_STATUS"
echo "  n8n:        $N8N_STATUS"
echo ""

if [ "$POSTGRES_STATUS" = "healthy" ] && [ "$N8N_STATUS" = "running" ]; then
    log_success "모든 컨테이너가 정상 실행 중입니다"
else
    log_warning "일부 컨테이너가 준비되지 않았습니다"
    log_info "로그 확인: docker-compose logs -f"
fi

# 7. n8n 접속 확인
log_info "n8n 웹 인터페이스 확인 중..."

MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
        log_success "n8n 웹 인터페이스 정상 작동"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            log_error "n8n 웹 인터페이스 접속 실패"
            log_info "로그 확인: docker logs n8n"
        else
            echo -n "."
            sleep 3
        fi
    fi
done
echo ""

# 8. 완료 메시지
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "3단계: n8n 설정 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_info "접속 정보:"
echo "  🌐 n8n 웹 인터페이스:"
echo "     ${GREEN}http://localhost:5678${NC}"
echo ""
echo "  👤 초기 계정:"
echo "     Username: ${YELLOW}admin${NC}"
echo "     Password: ${YELLOW}admin123${NC}"
echo "     (보안을 위해 .env에서 변경하세요)"
echo ""

log_info "유용한 명령어:"
echo "  ${YELLOW}# 컨테이너 상태 확인${NC}"
echo "  docker-compose ps"
echo ""
echo "  ${YELLOW}# 로그 확인${NC}"
echo "  docker-compose logs -f n8n"
echo ""
echo "  ${YELLOW}# 컨테이너 재시작${NC}"
echo "  docker-compose restart n8n"
echo ""
echo "  ${YELLOW}# 컨테이너 중지${NC}"
echo "  docker-compose down"
echo ""

log_success "모든 설치가 완료되었습니다! 🎉"
echo ""
log_info "다음 단계:"
echo "  1. ${GREEN}./scripts/start_all.sh${NC} 실행하여 모든 서비스 시작"
echo "  2. ${GREEN}./scripts/health_check.sh${NC}로 상태 확인"
echo "  3. http://localhost:5678 에서 n8n 워크플로우 설정"
echo ""
