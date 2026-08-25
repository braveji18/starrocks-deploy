# StarRocks Kubernetes 배포 환경

StarRocks Kubernetes Operator를 Helm + Kustomize + ArgoCD로 관리하는 배포 환경입니다.

## 📁 디렉토리 구조

```
starrocks-deploy/
├── chart/                          # Helm Chart (Nexus 저장소 참조)
├── kustomize/                      # 환경별 설정값 (ConfigMap 등)
│   └── overlays/
│       ├── dev/                    # 개발 환경 설정
│       ├── staging/                # 스테이징 환경 설정
│       └── prod/                   # 프로덕션 환경 설정
├── argocd/                         # ArgoCD 설정
│   └── applications.yaml          # ApplicationSet (List Generator)
├── docs/                           # 문서
└── bin/                           # 유틸리티 스크립트
```

## 🚀 빠른 시작

### 1. Helm Repository 설정 (Nexus)
```bash
# Nexus에서 StarRocks Helm Chart를 호스팅하도록 설정
# helm-hosted 저장소 생성 후 아래와 같이 추가
helm repo add starrocks https://your-nexus.com/repository/helm-hosted/
helm repo update

# 또는 자동 스크립트 사용
./bin/setup-nexus.sh
```

### 2. ArgoCD ApplicationSet 배포
```bash
# ApplicationSet 배포
kubectl apply -f argocd/applications.yaml

# 또는 스크립트 사용
./bin/deploy.sh dev       # 개발 환경
./bin/deploy.sh staging   # 스테이징 환경
./bin/deploy.sh prod      # 프로덕션 환경
```

### 3. 배포 상태 확인
```bash
# 전체 환경의 배포 상태 확인
./bin/check-status.sh

# 또는 개별 조회
kubectl get applications -n argocd
argocd app list
```

## 📋 주요 파일 설명

- **kustomize/base/** - 모든 환경이 공유하는 기본 설정
- **kustomize/overlays/[env]/** - 환경별 커스터마이제이션
- **argocd/base/** - ArgoCD Application 기본 설정
- **argocd/overlays/[env]/** - 환경별 ArgoCD 설정

## 🔧 환경 변수 및 설정

각 환경의 `values-[env].yaml`에서 다음을 설정합니다:
- StarRocks 클러스터 이름
- Replica 개수
- Resource 요청/제한
- Storage 설정
- Networking 설정

## 📚 추가 문서

- [설정 가이드](docs/SETUP_GUIDE.md)
- [환경별 구성](docs/ENVIRONMENT_CONFIG.md)
- [문제 해결](docs/TROUBLESHOOTING.md)

## 🔗 참고 자료

- [StarRocks Kubernetes Operator](https://github.com/StarRocks/starrocks-kubernetes-operator)
- [ArgoCD 문서](https://argo-cd.readthedocs.io/)
- [Kustomize 문서](https://kustomize.io/)
