#!/bin/bash

################################################################################
# YouTube Automation - 1단계: 기본 환경 설정
# 
# 이 스크립트는 다음을 설치합니다:
# - Docker Engine (WSL Native)
# - Docker Compose
# - systemd 활성화
# - 기본 디렉토리 구조 생성
#
# 실행: ./scripts/setup_base.sh
################################################################################

set -e  # 오류 발생 시 즉시 종료

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 프로젝트 루트 디렉토리
PROJECT_ROOT="$HOME/youtube-automation"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   YouTube Automation - 1단계: 기본 환경 설정"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. 시스템 요구사항 확인
# Ubuntu 버전 확인
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")
log_info "Ubuntu 버전: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
log_info "시스템 요구사항 확인 중..."

# GPU 확인 (경고만, 종료 안 함)
if ! command -v nvidia-smi &> /dev/null; then
    log_warning "⚠️  nvidia-smi를 찾을 수 없습니다"
    log_warning "    AI 이미지/영상 생성에는 NVIDIA GPU가 필요합니다"
    log_warning "    드라이버 설치: https://developer.nvidia.com/cuda/wsl"
    log_warning "    TTS, 대본 작성 등 GPU 불필요 기능은 계속 사용 가능합니다"
    GPU_AVAILABLE=false
else
    log_success "GPU 확인 완료"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    GPU_AVAILABLE=true
fi

# 메모리 확인
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 15 ]; then
    log_warning "권장 메모리: 16GB 이상 (현재: ${TOTAL_MEM}GB)"
fi

# 디스크 공간 확인
AVAILABLE_SPACE=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 50 ]; then
    log_error "디스크 공간 부족: 최소 50GB 필요 (현재: ${AVAILABLE_SPACE}GB)"
    exit 1
fi

log_success "디스크 공간 확인 완료 (${AVAILABLE_SPACE}GB 여유)"

# 2. 시스템 업데이트
log_info "시스템 패키지 업데이트 중..."
sudo apt update -qq
sudo apt upgrade -y -qq

log_info "필수 패키지 설치 중..."
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    wget \
    ffmpeg \
    python3.10 \
    python3.10-venv \
    python3-pip \
    build-essential

log_success "시스템 패키지 설치 완료"

# Python 버전 자동 감지
log_info "Python 버전 감지 중..."

PYTHON_BIN=$(which python3)
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR_MINOR=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

log_success "Python 버전: $PYTHON_VERSION (python3 → $PYTHON_BIN)"

# 최소 버전 확인 (3.9 이상 필요)
PYTHON_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
if [ "$PYTHON_MINOR" -lt 9 ]; then
    log_error "Python 3.9 이상이 필요합니다 (현재: $PYTHON_VERSION)"
    exit 1
fi

# venv 모듈 확인 및 버전별 설치
if ! python3 -m venv --help > /dev/null 2>&1; then
    log_info "python3-venv 추가 설치 중..."
    sudo apt install -y "python${PYTHON_MAJOR_MINOR}-venv" 2>/dev/null || \
    sudo apt install -y python3-venv
fi

log_success "Python 환경 준비 완료"

# 환경 변수로 저장 (다른 스크립트에서 참조)
echo "PYTHON_BIN=$PYTHON_BIN" > "$HOME/.youtube_automation_env"
echo "PYTHON_VERSION=$PYTHON_VERSION" >> "$HOME/.youtube_automation_env"
echo "PYTHON_MAJOR_MINOR=$PYTHON_MAJOR_MINOR" >> "$HOME/.youtube_automation_env"

# 3. Docker 설치
log_info "Docker 설치 상태 확인 중..."

if command -v docker &> /dev/null; then
    log_success "Docker가 이미 설치되어 있습니다 ($(docker --version))"
else
    log_info "Docker 설치 중... (1-2분 소요)"
    
    # Docker GPG 키 추가
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Docker 저장소 추가
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Docker 설치
    sudo apt update -qq
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 현재 사용자를 docker 그룹에 추가
    sudo usermod -aG docker $USER
    
    log_success "Docker 설치 완료 ($(docker --version))"
fi

# 4. Docker Compose 설치
log_info "Docker Compose 설치 상태 확인 중..."

if command -v docker-compose &> /dev/null; then
    log_success "Docker Compose가 이미 설치되어 있습니다 ($(docker-compose --version))"
else
    log_info "Docker Compose 설치 중..."
    
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker Compose 설치 완료 ($(docker-compose --version))"
fi

# 5. systemd 설정
log_info "systemd 설정 중..."

# /etc/wsl.conf 파일 확인
if [ -f /etc/wsl.conf ]; then
    log_warning "/etc/wsl.conf가 이미 존재합니다"
    
    # systemd 활성화 확인
    if ! grep -q "systemd=true" /etc/wsl.conf; then
        log_info "systemd 설정 추가 중..."
        echo "" | sudo tee -a /etc/wsl.conf
        echo "[boot]" | sudo tee -a /etc/wsl.conf
        echo "systemd=true" | sudo tee -a /etc/wsl.conf
    fi
else
    log_info "/etc/wsl.conf 생성 중..."
    sudo tee /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true

[network]
generateResolvConf=true

[interop]
enabled=true
appendWindowsPath=true
EOF
fi

log_success "systemd 설정 완료"

# 6. 프로젝트 디렉토리 구조 생성
log_info "디렉토리 구조 생성 중..."

mkdir -p "$PROJECT_ROOT"/{logs,media/{audio,images,videos,final},n8n-data,ai-services/services}

log_success "디렉토리 구조 생성 완료"

# 디렉토리 구조 출력
tree -L 2 "$PROJECT_ROOT" 2>/dev/null || ls -R "$PROJECT_ROOT"

# 7. .gitignore 생성
log_info ".gitignore 생성 중..."

cat > "$PROJECT_ROOT/.gitignore" <<'EOF'
# 환경 변수
.env

# Python
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python

# 생성 파일
media/
logs/
*.log

# Docker
n8n-data/

# AI 모델
models/
stable-diffusion-webui/models/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
EOF

log_success ".gitignore 생성 완료"

# 8. 완료 메시지
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "1단계: 기본 환경 설정 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_warning "⚠️  중요: WSL을 재시작해야 systemd가 활성화됩니다"
echo ""
echo "Windows PowerShell에서 다음 명령 실행:"
echo "  ${YELLOW}wsl --shutdown${NC}"
echo "  ${YELLOW}wsl${NC}"
echo ""
echo "재시작 후 다음 명령으로 계속:"
echo "  ${GREEN}cd ~/youtube-automation${NC}"
echo "  ${GREEN}./scripts/setup_ai_services.sh${NC}"
echo ""

# systemd 확인 (재시작 전이므로 실패할 수 있음)
if systemctl --version &> /dev/null; then
    log_success "systemd가 이미 활성화되어 있습니다. 재시작 불필요!"
    echo ""
    echo "다음 단계로 진행하세요:"
    echo "  ${GREEN}./scripts/setup_ai_services.sh${NC}"
else
    log_warning "systemd가 아직 활성화되지 않았습니다. WSL 재시작 필요!"
fi

echo ""
