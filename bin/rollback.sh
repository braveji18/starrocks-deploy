#!/bin/bash

# 특정 환경을 이전 버전으로 롤백하는 스크립트

set -e

ENVIRONMENT="${1:-}"
REVISION="${2:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_usage() {
    echo "사용법: $0 [environment] [revision]"
    echo ""
    echo "예제:"
    echo "  $0 dev 0          # dev 환경을 버전 0으로 롤백"
    echo "  $0 staging        # staging 환경의 버전 히스토리 조회"
    echo ""
    echo "버전 확인:"
    echo "  argocd app history kube-starrocks-operator-[env]"
}

if [ -z "$ENVIRONMENT" ]; then
    print_usage
    exit 1
fi

# 환경 유효성 검사
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: 유효하지 않은 환경입니다: $ENVIRONMENT${NC}"
    print_usage
    exit 1
fi

app_name="kube-starrocks-operator-${ENVIRONMENT}"

echo -e "${YELLOW}=== StarRocks 롤백 ===${NC}\n"
echo -e "환경: ${BLUE}$ENVIRONMENT${NC}"
echo -e "Application: ${BLUE}$app_name${NC}\n"

# Application 존재 확인
if ! kubectl get application "$app_name" -n argocd &>/dev/null; then
    echo -e "${RED}Error: Application을 찾을 수 없습니다: $app_name${NC}"
    exit 1
fi

# 버전 히스토리 표시
echo -e "${YELLOW}배포 히스토리:${NC}\n"
if command -v argocd &> /dev/null; then
    argocd app history "$app_name"
else
    echo -e "${YELLOW}ArgoCD CLI를 사용하여 히스토리 확인:${NC}"
    echo "  argocd app history $app_name"
fi

# 롤백 버전이 지정되지 않은 경우, 버전 입력 요청
if [ -z "$REVISION" ]; then
    echo ""
    read -p "롤백할 버전 번호를 입력하세요: " REVISION
fi

if [ -z "$REVISION" ] || ! [[ "$REVISION" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: 유효한 버전 번호를 입력하세요${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}$app_name을 버전 $REVISION로 롤백하시겠습니까?${NC}"
read -p "계속하시려면 'yes'를 입력하세요: " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}롤백이 취소되었습니다.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}롤백 중...${NC}"

if command -v argocd &> /dev/null; then
    # ArgoCD CLI 사용
    if argocd app rollback "$app_name" "$REVISION"; then
        echo -e "${GREEN}✓ 롤백이 완료되었습니다${NC}"
    else
        echo -e "${RED}Error: 롤백 실패${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: ArgoCD CLI를 찾을 수 없습니다${NC}"
    echo "다음 명령어를 실행하세요:"
    echo "  argocd app rollback $app_name $REVISION"
    exit 1
fi

# 배포 상태 확인
echo -e "\n${YELLOW}배포 상태 확인 중...${NC}"
sleep 2

kubectl get application "$app_name" -n argocd

echo -e "\n${GREEN}=== 롤백 완료! ===${NC}"
