#!/bin/bash

# 환경별 배포 스크립트

set -e

ENVIRONMENT="${1:-dev}"
NAMESPACE="starrocks-${ENVIRONMENT}"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_usage() {
    echo "사용법: $0 [dev|staging|prod]"
    echo ""
    echo "예제:"
    echo "  $0 dev       # 개발 환경 배포"
    echo "  $0 staging   # 스테이징 환경 배포"
    echo "  $0 prod      # 프로덕션 환경 배포"
}

# 환경 유효성 검사
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: 유효하지 않은 환경입니다: $ENVIRONMENT${NC}"
    print_usage
    exit 1
fi

echo -e "${YELLOW}=== StarRocks Kubernetes 배포 ===${NC}"
echo -e "환경: ${BLUE}$ENVIRONMENT${NC}"
echo -e "네임스페이스: ${BLUE}$NAMESPACE${NC}\n"

# 선행 조건 확인
check_prerequisites() {
    echo -e "${YELLOW}선행 조건 확인 중...${NC}"

    local missing=false

    for cmd in kubectl kustomize helm; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}✗ $cmd를 찾을 수 없습니다.${NC}"
            missing=true
        else
            echo -e "${GREEN}✓ $cmd 설치됨${NC}"
        fi
    done

    if [ "$missing" = true ]; then
        exit 1
    fi

    echo ""
}

# 쿠버네티스 연결 확인
check_cluster() {
    echo -e "${YELLOW}쿠버네티스 클러스터 연결 확인 중...${NC}"

    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: 쿠버네티스 클러스터에 연결할 수 없습니다.${NC}"
        exit 1
    fi

    local cluster_name=$(kubectl config current-context)
    echo -e "${GREEN}✓ 클러스터 연결됨: $cluster_name${NC}\n"
}

# 환경 설정 확인
check_environment_config() {
    echo -e "${YELLOW}환경 설정 확인 중...${NC}"

    local kustomize_path="kustomize/overlays/$ENVIRONMENT"

    if [ ! -d "$kustomize_path" ]; then
        echo -e "${RED}Error: 환경 설정 디렉토리를 찾을 수 없습니다: $kustomize_path${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ 환경 설정 찾음: $kustomize_path${NC}\n"
}

# Kustomize 빌드 및 검증
validate_manifests() {
    echo -e "${YELLOW}Kubernetes 매니페스트 검증 중...${NC}"

    local kustomize_path="kustomize/overlays/$ENVIRONMENT"

    if ! kustomize build "$kustomize_path" | kubectl apply --dry-run=client -f - &>/dev/null; then
        echo -e "${RED}Error: 매니페스트 검증 실패${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ 매니페스트 검증 성공${NC}\n"
}

# 배포 전 확인
pre_deployment_checks() {
    echo -e "${YELLOW}배포 전 확인 중...${NC}"

    # 네임스페이스 확인
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo -e "${BLUE}ℹ 네임스페이스가 이미 존재합니다: $NAMESPACE${NC}"
    else
        echo -e "네임스페이스를 생성합니다: $NAMESPACE"
    fi

    # 기존 리소스 확인
    local existing=$(kubectl get application -n argocd -l environment=$ENVIRONMENT 2>/dev/null | wc -l)
    if [ $existing -gt 1 ]; then
        echo -e "${YELLOW}⚠ 기존 Application이 존재합니다:${NC}"
        kubectl get application -n argocd -l environment=$ENVIRONMENT
    fi

    echo ""
}

# 배포 실행
deploy() {
    echo -e "${YELLOW}배포를 진행하시겠습니까?${NC}"
    echo -e "환경: ${BLUE}$ENVIRONMENT${NC}"
    echo -e "네임스페이스: ${BLUE}$NAMESPACE${NC}"
    echo ""
    read -p "계속하시려면 'yes'를 입력하세요: " confirm

    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}배포가 취소되었습니다.${NC}"
        exit 0
    fi

    echo -e "\n${YELLOW}매니페스트 적용 중...${NC}"

    local kustomize_path="kustomize/overlays/$ENVIRONMENT"

    # Kustomize로 빌드 후 적용
    if kustomize build "$kustomize_path" | kubectl apply -f -; then
        echo -e "${GREEN}✓ 매니페스트 적용 완료${NC}"
    else
        echo -e "${RED}Error: 매니페스트 적용 실패${NC}"
        exit 1
    fi
}

# 배포 상태 확인
verify_deployment() {
    echo -e "\n${YELLOW}배포 상태 확인 중...${NC}"

    # Application 상태 확인
    echo -e "\n${BLUE}ArgoCD Application 상태:${NC}"
    kubectl get application -n argocd -l environment=$ENVIRONMENT

    # Pod 상태 확인
    echo -e "\n${BLUE}Pod 상태:${NC}"
    kubectl get pods -n "$NAMESPACE" -l app=starrocks

    # 대기 (Pod 시작 대기)
    echo -e "\n${YELLOW}Pod 시작 대기 중... (최대 120초)${NC}"
    if kubectl wait --for=condition=ready pod -n "$NAMESPACE" -l app=starrocks --timeout=120s 2>/dev/null; then
        echo -e "${GREEN}✓ Pod이 준비되었습니다${NC}"
    else
        echo -e "${YELLOW}⚠ Pod이 완전히 준비되지 않았습니다. 상태를 확인하세요.${NC}"
        kubectl describe pods -n "$NAMESPACE" -l app=starrocks
    fi
}

# 배포 후 정보
post_deployment_info() {
    echo -e "\n${GREEN}=== 배포 완료! ===${NC}\n"

    echo -e "${BLUE}다음 단계:${NC}"
    echo "1. 배포 상태 확인:"
    echo "   kubectl get applications -n argocd -l environment=$ENVIRONMENT"
    echo ""
    echo "2. Pod 로그 확인:"
    echo "   kubectl logs -n $NAMESPACE -l app=starrocks -f"
    echo ""
    echo "3. StarRocks 클러스터 배포 (선택사항):"
    echo "   kubectl apply -f docs/sample-cluster.yaml -n $NAMESPACE"
    echo ""
    echo -e "${BLUE}문서:${NC}"
    echo "- 설정 가이드: docs/SETUP_GUIDE.md"
    echo "- 환경 설정: docs/ENVIRONMENT_CONFIG.md"
    echo "- 문제 해결: docs/TROUBLESHOOTING.md"
}

# 메인 실행
main() {
    check_prerequisites
    check_cluster
    check_environment_config
    validate_manifests
    pre_deployment_checks
    deploy
    verify_deployment
    post_deployment_info
}

main
