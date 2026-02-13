#!/bin/bash
# =============================================================================
# setup_n8n.sh - 3단계: n8n + PostgreSQL Docker 설정
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   3단계: n8n 설정"
echo "   경로: $PROJECT_ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_ROOT" || error "프로젝트 경로 없음: $PROJECT_ROOT"

# ── 1. .env 파일 ──────────────────────────────────────────────────────────────
if [ -f ".env" ]; then
    warn ".env 이미 존재 → 덮어쓰지 않음"
else
    info ".env 파일 생성 중..."
    cat > .env <<'EOF'
# n8n 인증
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=admin1234

# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=n8npassword
POSTGRES_DB=n8n
EOF
    success ".env 생성 완료"
    warn "보안을 위해 비밀번호 변경 권장: nano $PROJECT_ROOT/.env"
fi

# ── 2. docker-compose.yml ─────────────────────────────────────────────────────
info "docker-compose.yml 생성 중..."
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    env_file: .env
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ai-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    env_file: .env
    environment:
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_BASIC_AUTH_USER: ${N8N_BASIC_AUTH_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_BASIC_AUTH_PASSWORD}
      GENERIC_TIMEZONE: Asia/Seoul
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - ./n8n-data:/home/node/.n8n
      - ./media:/media
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - ai-net
    extra_hosts:
      - "host.docker.internal:172.17.0.1"

networks:
  ai-net:
    driver: bridge

volumes:
  postgres_data:
EOF
success "docker-compose.yml 생성 완료"

# ── 3. Docker 실행 ────────────────────────────────────────────────────────────
info "Docker 서비스 시작 중..."

if ! systemctl is-active docker &>/dev/null; then
    sudo systemctl start docker
    sleep 2
fi

docker-compose down 2>/dev/null || true
docker-compose up -d
success "컨테이너 시작 완료"

# ── 4. n8n 준비 대기 ──────────────────────────────────────────────────────────
info "n8n 준비 대기 중 (최대 60초)..."
for i in $(seq 1 20); do
    if curl -s http://localhost:5678/healthz &>/dev/null; then
        success "n8n 접속 확인"
        break
    fi
    printf "."
    sleep 3
done
echo ""

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "3단계 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🌐 n8n: http://localhost:5678"
echo "     ID: admin  PW: admin1234"
echo ""
echo "다음 단계:"
echo "  ./scripts/start_all.sh"
echo ""
