#!/bin/bash

# 모든 환경의 배포 상태를 확인하는 스크립트

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=== StarRocks Kubernetes 배포 상태 ===${NC}\n"

ENVIRONMENTS=("dev" "staging" "prod")

for env in "${ENVIRONMENTS[@]}"; do
    namespace="starrocks-${env}"
    app_name="kube-starrocks-operator-${env}"

    echo -e "${BLUE}[$env 환경]${NC}"
    echo "─────────────────────────────────────────"

    # Application 상태
    echo -e "Application 상태:"
    if kubectl get application "$app_name" -n argocd 2>/dev/null; then
        argocd app get "$app_name" 2>/dev/null || echo "  (ArgoCD 미연결)"
    else
        echo -e "${YELLOW}  Application이 없습니다${NC}"
    fi
    echo ""

    # Namespace 상태
    echo -e "네임스페이스:"
    if kubectl get namespace "$namespace" 2>/dev/null; then
        kubectl get namespace "$namespace"
    else
        echo -e "${YELLOW}  네임스페이스가 없습니다${NC}"
    fi
    echo ""

    # Pod 상태
    echo -e "Pod 상태:"
    if kubectl get pods -n "$namespace" -l app=starrocks 2>/dev/null | grep -q starrocks; then
        kubectl get pods -n "$namespace" -l app=starrocks --no-headers | \
            awk '{printf "  %-50s %s\n", $1, $3}'
        echo ""

        # Pod 리소스 사용률
        echo -e "리소스 사용률:"
        kubectl top pods -n "$namespace" -l app=starrocks 2>/dev/null || \
            echo "  (메트릭 서버 미설치)"
    else
        echo -e "${YELLOW}  Pod이 없습니다${NC}"
    fi
    echo ""

    # 최근 이벤트
    echo -e "최근 이벤트:"
    kubectl get events -n "$namespace" --sort-by='.lastTimestamp' 2>/dev/null | \
        tail -5 | awk '{printf "  %s - %s\n", $6, $4}' || \
        echo "  이벤트가 없습니다"
    echo ""
    echo ""
done

echo -e "${GREEN}=== 조회 완료 ===${NC}"
echo ""
echo "상세 정보 보기:"
for env in "${ENVIRONMENTS[@]}"; do
    echo "  kubectl describe pods -n starrocks-${env}"
done
