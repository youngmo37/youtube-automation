#!/bin/bash
# =============================================================================
# health_check.sh - 시스템 상태 확인
# =============================================================================

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

chk() {
    local label=$1 url=$2
    printf "  %-16s" "$label:"
    curl -s --max-time 5 "$url" &>/dev/null \
        && echo -e "${GREEN}✅ OK${NC}" \
        || echo -e "${RED}❌ FAIL${NC}"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "   ${CYAN}서비스 상태${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
chk "Ollama"    "http://localhost:11434/api/tags"
chk "SD WebUI"  "http://localhost:7860/sdapi/v1/sd-models"
chk "FastAPI"   "http://localhost:8000/health"
chk "n8n"       "http://localhost:5678/healthz"

printf "  %-16s" "PostgreSQL:"
docker inspect --format='{{.State.Health.Status}}' n8n-postgres 2>/dev/null \
    | grep -q healthy \
    && echo -e "${GREEN}✅ healthy${NC}" \
    || echo -e "${RED}❌ unhealthy${NC}"

echo ""
echo -e "   ${CYAN}GPU 상태${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu \
        --format=csv,noheader,nounits | while IFS=',' read -r name util mused mtotal temp; do
        echo "  GPU:   $(echo "$name"|xargs)"
        echo "  사용률: $(echo "$util"|xargs)%"
        echo "  VRAM:  $(echo "$mused"|xargs)MB / $(echo "$mtotal"|xargs)MB"
        echo "  온도:  $(echo "$temp"|xargs)°C"
    done
else
    echo "  nvidia-smi 없음"
fi

echo ""
echo -e "   ${CYAN}시스템 리소스${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
USED=$(free -g | awk '/^Mem/{print $3}')
TOTAL=$(free -g | awk '/^Mem/{print $2}')
echo "  메모리: ${USED}GB / ${TOTAL}GB"
echo "  디스크: $(df -h "$HOME" | awk 'NR==2{print $3"/"$2" ("$5" 사용)"}')"

echo ""
echo -e "   ${CYAN}미디어 파일${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for dir in audio images videos final; do
    count=$(find "$PROJECT_ROOT/media/$dir" -type f 2>/dev/null | wc -l)
    size=$(du -sh "$PROJECT_ROOT/media/$dir" 2>/dev/null | awk '{print $1}')
    printf "  %-8s %3d 파일 (%s)\n" "$dir:" "$count" "${size:-0}"
done

echo ""
echo "  확인 시각: $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
