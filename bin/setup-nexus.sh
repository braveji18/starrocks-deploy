#!/bin/bash

# StarRocks Helm Chart를 Nexus에 업로드하는 스크립트

set -e

# 설정
NEXUS_URL="${NEXUS_URL:-https://your-nexus.com}"
NEXUS_REPO="${NEXUS_REPO:-helm-hosted}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-password}"
CHART_SOURCE_DIR="${CHART_SOURCE_DIR:-../starrocks-kubernetes-operator/helm-charts}"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== StarRocks Helm Chart Nexus 업로드 ===${NC}\n"

# 필수 도구 확인
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1을 찾을 수 없습니다. 설치해주세요.${NC}"
        exit 1
    fi
}

check_command "helm"
check_command "curl"

# Chart 소스 디렉토리 확인
if [ ! -d "$CHART_SOURCE_DIR" ]; then
    echo -e "${RED}Error: Chart 디렉토리 '$CHART_SOURCE_DIR'를 찾을 수 없습니다.${NC}"
    exit 1
fi

# Chart 패키징
echo -e "${YELLOW}1. Helm Chart 패키징 중...${NC}"
cd "$CHART_SOURCE_DIR"

# kube-starrocks 차트 패키징
if [ -d "kube-starrocks" ]; then
    helm package kube-starrocks
    CHART_FILE=$(ls kube-starrocks-*.tgz | sort -V | tail -n1)
    echo -e "${GREEN}✓ Chart 패키징 완료: $CHART_FILE${NC}\n"
else
    echo -e "${RED}Error: kube-starrocks 차트 디렉토리를 찾을 수 없습니다.${NC}"
    exit 1
fi

# Nexus 연결 테스트
echo -e "${YELLOW}2. Nexus 연결 테스트 중...${NC}"
if curl -s -u "$NEXUS_USER:$NEXUS_PASSWORD" \
    "$NEXUS_URL/repository/$NEXUS_REPO/index.yaml" > /dev/null; then
    echo -e "${GREEN}✓ Nexus 연결 성공${NC}\n"
else
    echo -e "${RED}Error: Nexus에 연결할 수 없습니다.${NC}"
    echo "URL: $NEXUS_URL"
    echo "저장소: $NEXUS_REPO"
    exit 1
fi

# Chart 업로드
echo -e "${YELLOW}3. Chart를 Nexus에 업로드 중...${NC}"
curl -v --user "$NEXUS_USER:$NEXUS_PASSWORD" \
    --upload-file "$CHART_FILE" \
    "$NEXUS_URL/repository/$NEXUS_REPO/$CHART_FILE"

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Chart 업로드 완료${NC}\n"
else
    echo -e "\n${RED}Error: Chart 업로드 실패${NC}"
    exit 1
fi

# Helm Repository 업데이트
echo -e "${YELLOW}4. 로컬 Helm Repository 업데이트 중...${NC}"

# 기존 저장소 제거
helm repo remove starrocks 2>/dev/null || true

# 새 저장소 추가
helm repo add starrocks "$NEXUS_URL/repository/$NEXUS_REPO/" \
    --username "$NEXUS_USER" \
    --password "$NEXUS_PASSWORD"

helm repo update

# Chart 확인
echo -e "${YELLOW}5. Chart 확인 중...${NC}"
helm search repo starrocks

echo -e "\n${GREEN}=== 설정 완료! ===${NC}"
echo ""
echo "다음 단계:"
echo "1. 배포 스크립트 실행: ./scripts/deploy.sh [environment]"
echo "2. 또는 ArgoCD 설정: kubectl apply -f argocd/overlays/[environment]/"
