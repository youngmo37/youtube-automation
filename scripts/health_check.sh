#!/bin/bash

################################################################################
# YouTube Automation - 시스템 헬스 체크
#
# 실행: ./scripts/health_check.sh
################################################################################

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="$HOME/youtube-automation-wsl"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   📊 YouTube Automation - 시스템 헬스 체크"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 서비스 체크 함수
check_service() {
    local name=$1
    local url=$2
    local timeout=${3:-5}
    
    printf "   %-15s " "$name:"
    
    if curl -s --max-time "$timeout" "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# HTTP 응답 시간 체크
check_response_time() {
    local name=$1
    local url=$2
    
    printf "   %-15s " "$name:"
    
    local start_time=$(date +%s%3N)
    
    if curl -s --max-time 10 "$url" > /dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        if [ "$response_time" -lt 1000 ]; then
            echo -e "${GREEN}✅ ${response_time}ms${NC}"
        elif [ "$response_time" -lt 3000 ]; then
            echo -e "${YELLOW}⚠ ${response_time}ms (느림)${NC}"
        else
            echo -e "${RED}❌ ${response_time}ms (매우 느림)${NC}"
        fi
    else
        echo -e "${RED}❌ 응답 없음${NC}"
    fi
}

# 1. 서비스 상태
echo "${CYAN}━━━ 서비스 상태 ━━━${NC}"
echo ""

check_service "Ollama" "http://localhost:11434/api/tags"
check_service "SD WebUI" "http://localhost:7860/sdapi/v1/sd-models" 10
check_service "FastAPI" "http://localhost:8000/health"
check_service "n8n" "http://localhost:5678/healthz"

# Docker 컨테이너 체크
printf "   %-15s " "PostgreSQL:"
if docker ps | grep -q "n8n-postgres"; then
    POSTGRES_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' n8n-postgres 2>/dev/null || echo "unknown")
    if [ "$POSTGRES_HEALTH" = "healthy" ]; then
        echo -e "${GREEN}✅ Healthy${NC}"
    else
        echo -e "${YELLOW}⚠ $POSTGRES_HEALTH${NC}"
    fi
else
    echo -e "${RED}❌ 컨테이너 없음${NC}"
fi

echo ""

# 2. 응답 시간
echo "${CYAN}━━━ 응답 시간 ━━━${NC}"
echo ""

check_response_time "Ollama" "http://localhost:11434/api/tags"
check_response_time "FastAPI" "http://localhost:8000/health"
check_response_time "n8n" "http://localhost:5678/healthz"

echo ""

# 3. GPU 상태
echo "${CYAN}━━━ GPU 상태 ━━━${NC}"
echo ""

if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu \
        --format=csv,noheader,nounits | while IFS=',' read -r name gpu_util mem_util mem_used mem_total temp; do
        
        # 공백 제거
        name=$(echo "$name" | xargs)
        gpu_util=$(echo "$gpu_util" | xargs)
        mem_util=$(echo "$mem_util" | xargs)
        mem_used=$(echo "$mem_used" | xargs)
        mem_total=$(echo "$mem_total" | xargs)
        temp=$(echo "$temp" | xargs)
        
        echo "   GPU: $name"
        
        # GPU 사용률
        printf "   GPU 사용률:     "
        if [ "$gpu_util" -lt 30 ]; then
            echo -e "${GREEN}${gpu_util}%${NC}"
        elif [ "$gpu_util" -lt 70 ]; then
            echo -e "${YELLOW}${gpu_util}%${NC}"
        else
            echo -e "${RED}${gpu_util}% (높음)${NC}"
        fi
        
        # VRAM 사용률
        printf "   VRAM:           "
        if [ "$mem_util" -lt 50 ]; then
            echo -e "${GREEN}${mem_used}MB / ${mem_total}MB (${mem_util}%)${NC}"
        elif [ "$mem_util" -lt 80 ]; then
            echo -e "${YELLOW}${mem_used}MB / ${mem_total}MB (${mem_util}%)${NC}"
        else
            echo -e "${RED}${mem_used}MB / ${mem_total}MB (${mem_util}%) - 높음!${NC}"
        fi
        
        # 온도
        printf "   온도:           "
        if [ "$temp" -lt 70 ]; then
            echo -e "${GREEN}${temp}°C${NC}"
        elif [ "$temp" -lt 85 ]; then
            echo -e "${YELLOW}${temp}°C (주의)${NC}"
        else
            echo -e "${RED}${temp}°C (과열 위험!)${NC}"
        fi
    done
else
    echo -e "   ${RED}nvidia-smi를 사용할 수 없습니다${NC}"
fi

echo ""

# 4. 시스템 리소스
echo "${CYAN}━━━ 시스템 리소스 ━━━${NC}"
echo ""

# 메모리
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
USED_MEM=$(free -g | awk '/^Mem:/{print $3}')
MEM_PERCENT=$(awk "BEGIN {printf \"%.0f\", ($USED_MEM/$TOTAL_MEM)*100}")

printf "   메모리:         "
if [ "$MEM_PERCENT" -lt 70 ]; then
    echo -e "${GREEN}${USED_MEM}GB / ${TOTAL_MEM}GB (${MEM_PERCENT}%)${NC}"
elif [ "$MEM_PERCENT" -lt 90 ]; then
    echo -e "${YELLOW}${USED_MEM}GB / ${TOTAL_MEM}GB (${MEM_PERCENT}%)${NC}"
else
    echo -e "${RED}${USED_MEM}GB / ${TOTAL_MEM}GB (${MEM_PERCENT}%) - 부족!${NC}"
fi

# 디스크
DISK_INFO=$(df -h "$HOME" | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
DISK_PERCENT=$(df -h "$HOME" | awk 'NR==2 {print $5}' | tr -d '%')

printf "   디스크:         "
if [ "$DISK_PERCENT" -lt 70 ]; then
    echo -e "${GREEN}${DISK_INFO}${NC}"
elif [ "$DISK_PERCENT" -lt 90 ]; then
    echo -e "${YELLOW}${DISK_INFO}${NC}"
else
    echo -e "${RED}${DISK_INFO} - 공간 부족!${NC}"
fi

# CPU (1분 평균 로드)
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
CPU_CORES=$(nproc)

printf "   CPU 로드:       "
echo -e "${BLUE}${CPU_LOAD} (${CPU_CORES} 코어)${NC}"

echo ""

# 5. 프로세스 확인
echo "${CYAN}━━━ 주요 프로세스 ━━━${NC}"
echo ""

check_process() {
    local name=$1
    local pattern=$2
    
    printf "   %-15s " "$name:"
    
    if pgrep -f "$pattern" > /dev/null; then
        local pid=$(pgrep -f "$pattern" | head -1)
        local mem=$(ps -p "$pid" -o rss= | awk '{printf "%.1f MB", $1/1024}')
        echo -e "${GREEN}✅ 실행 중${NC} (PID: $pid, 메모리: $mem)"
    else
        echo -e "${RED}❌ 중지됨${NC}"
    fi
}

check_process "Ollama" "ollama"
check_process "SD WebUI" "webui.sh"
check_process "FastAPI" "uvicorn.*app:app"

echo ""

# 6. 디스크 사용량 (미디어 파일)
if [ -d "$PROJECT_ROOT/media" ]; then
    echo "${CYAN}━━━ 생성 파일 통계 ━━━${NC}"
    echo ""
    
    AUDIO_COUNT=$(find "$PROJECT_ROOT/media/audio" -type f 2>/dev/null | wc -l)
    AUDIO_SIZE=$(du -sh "$PROJECT_ROOT/media/audio" 2>/dev/null | awk '{print $1}' || echo "0")
    
    IMAGE_COUNT=$(find "$PROJECT_ROOT/media/images" -type f 2>/dev/null | wc -l)
    IMAGE_SIZE=$(du -sh "$PROJECT_ROOT/media/images" 2>/dev/null | awk '{print $1}' || echo "0")
    
    VIDEO_COUNT=$(find "$PROJECT_ROOT/media/videos" -type f 2>/dev/null | wc -l)
    VIDEO_SIZE=$(du -sh "$PROJECT_ROOT/media/videos" 2>/dev/null | awk '{print $1}' || echo "0")
    
    FINAL_COUNT=$(find "$PROJECT_ROOT/media/final" -type f 2>/dev/null | wc -l)
    FINAL_SIZE=$(du -sh "$PROJECT_ROOT/media/final" 2>/dev/null | awk '{print $1}' || echo "0")
    
    printf "   오디오:         %3d 파일 (%s)\n" "$AUDIO_COUNT" "$AUDIO_SIZE"
    printf "   이미지:         %3d 파일 (%s)\n" "$IMAGE_COUNT" "$IMAGE_SIZE"
    printf "   비디오:         %3d 파일 (%s)\n" "$VIDEO_COUNT" "$VIDEO_SIZE"
    printf "   최종 영상:      %3d 파일 (%s)\n" "$FINAL_COUNT" "$FINAL_SIZE"
    
    echo ""
fi

# 7. 로그 파일 크기
if [ -d "$PROJECT_ROOT/logs" ]; then
    echo "${CYAN}━━━ 로그 파일 ━━━${NC}"
    echo ""
    
    find "$PROJECT_ROOT/logs" -type f -name "*.log" | while read -r logfile; do
        local size=$(du -h "$logfile" | awk '{print $1}')
        local name=$(basename "$logfile")
        printf "   %-20s %s\n" "$name" "$size"
    done
    
    echo ""
fi

# 8. 요약
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 전체 상태 판단
OVERALL_STATUS="${GREEN}✅ 정상${NC}"

if ! curl -s http://localhost:8000/health > /dev/null 2>&1 || \
   ! curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
    OVERALL_STATUS="${RED}❌ 일부 서비스 중지${NC}"
fi

if [ "$MEM_PERCENT" -gt 90 ] || [ "$DISK_PERCENT" -gt 90 ]; then
    OVERALL_STATUS="${YELLOW}⚠ 리소스 부족 주의${NC}"
fi

echo -e "   전체 상태: $OVERALL_STATUS"
echo ""

# 추천 액션
if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo -e "   ${YELLOW}권장 조치:${NC}"
    echo "   - ./scripts/start_all.sh 실행"
    echo ""
fi

if [ "$DISK_PERCENT" -gt 80 ]; then
    echo -e "   ${YELLOW}디스크 정리 권장:${NC}"
    echo "   - 오래된 미디어 파일 삭제"
    echo "   - rm -rf $PROJECT_ROOT/media/audio/*"
    echo ""
fi

echo "   마지막 체크: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
