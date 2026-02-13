#!/bin/bash
# =============================================================================
# setup_base.sh - 1단계: 기본 환경 설정
# - Docker Engine 설치
# - Docker Compose 설치
# - systemd 활성화
# - 기본 디렉토리 생성
# =============================================================================

# ── 색상 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }

# ── 경로: 스크립트 위치 기반 자동 감지 ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   1단계: 기본 환경 설정"
echo "   경로: $PROJECT_ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 1. 시스템 확인 ────────────────────────────────────────────────────────────
UBUNTU_VER=$(lsb_release -rs 2>/dev/null || echo "unknown")
info "Ubuntu: $UBUNTU_VER"

# GPU 확인 (경고만, 종료 안 함)
if command -v nvidia-smi &>/dev/null; then
    success "GPU 확인:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    warn "nvidia-smi 없음 - Stable Diffusion은 GPU 필요 (나머지는 계속 가능)"
fi

# 디스크 확인
AVAIL=$(df -BG "$HOME" | awk 'NR==2{print $4}' | tr -d 'G')
if [ "$AVAIL" -lt 30 ]; then
    error "디스크 공간 부족: ${AVAIL}GB 여유 (최소 30GB 필요)"
    exit 1
fi
success "디스크: ${AVAIL}GB 여유"

# ── 2. 시스템 업데이트 ────────────────────────────────────────────────────────
info "시스템 업데이트 중..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    ca-certificates curl gnupg lsb-release \
    git wget ffmpeg \
    python3 python3-venv python3-pip \
    build-essential
success "기본 패키지 설치 완료"

# ── 3. Python 버전 확인 ───────────────────────────────────────────────────────
PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
info "Python 버전: $PY_VER"

if [ "$PY_MINOR" -lt 9 ]; then
    error "Python 3.9 이상 필요 (현재 $PY_VER)"
    exit 1
fi

# python3-venv 확인
if ! python3 -m venv --help &>/dev/null; then
    info "python3-venv 추가 설치..."
    sudo apt-get install -y -qq "python${PY_VER}-venv" 2>/dev/null || \
    sudo apt-get install -y -qq python3-venv
fi
success "Python $PY_VER 환경 준비 완료"

# ── 4. Docker 설치 ────────────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    success "Docker 이미 설치됨: $(docker --version)"
else
    info "Docker 설치 중..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    success "Docker 설치 완료"
fi

# docker-compose (standalone) 확인
if ! command -v docker-compose &>/dev/null; then
    info "docker-compose 설치 중..."
    VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
          | grep '"tag_name"' | cut -d'"' -f4)
    sudo curl -fsSL \
        "https://github.com/docker/compose/releases/download/${VER}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi
success "docker-compose: $(docker-compose --version)"

# ── 5. systemd 설정 ───────────────────────────────────────────────────────────
info "systemd 설정 중..."
if grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
    success "systemd 이미 활성화됨"
else
    sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true

[network]
generateResolvConf=true
EOF
    warn "WSL 재시작 필요: Windows PowerShell → wsl --shutdown → wsl"
fi

# ── 6. 디렉토리 구조 생성 ─────────────────────────────────────────────────────
info "디렉토리 구조 생성 중..."
mkdir -p "$PROJECT_ROOT"/{scripts,logs,media/{audio,images,videos,final},n8n-data}
mkdir -p "$PROJECT_ROOT"/ai-services/{services,venv}
success "디렉토리 생성 완료"

# ── 7. 환경 정보 저장 (다음 스크립트에서 참조) ───────────────────────────────
cat > "$HOME/.youtube_automation_env" <<EOF
PROJECT_ROOT="$PROJECT_ROOT"
PY_VER="$PY_VER"
EOF
success "환경 정보 저장: $HOME/.youtube_automation_env"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "1단계 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
warn "systemd 적용을 위해 WSL 재시작 권장:"
echo "  Windows PowerShell: wsl --shutdown  →  wsl"
echo ""
echo "재시작 후:"
echo "  cd $PROJECT_ROOT"
echo "  ./scripts/setup_ai_services.sh"
echo ""
