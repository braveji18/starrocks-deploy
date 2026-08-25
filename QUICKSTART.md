# 빠른 시작 가이드 (5분)

이 가이드를 따라 StarRocks Kubernetes 배포를 빠르게 시작할 수 있습니다.

## 📋 사전 요구사항

- ✅ Kubernetes 클러스터 (1.19+)
- ✅ kubectl, helm, kustomize 설치됨
- ✅ ArgoCD 설치됨 (1.12+)
- ✅ Nexus 저장소 설정됨

## 🚀 1단계: 외부 Operator 소스 가져오기 (1분)

```bash
# StarRocks Operator 클론
git clone https://github.com/StarRocks/starrocks-kubernetes-operator.git
cd starrocks-kubernetes-operator

# Helm Chart 패키징
helm package helm-charts/kube-starrocks

# Chart 파일 확인
ls kube-starrocks-*.tgz
```

## 🏠 2단계: Nexus에 Chart 업로드 (1분)

### 방법 A: 자동 스크립트
```bash
cd starrocks-deploy

# Nexus 정보 설정
export NEXUS_URL="https://your-nexus.com"
export NEXUS_USER="admin"
export NEXUS_PASSWORD="password"
export CHART_SOURCE_DIR="../starrocks-kubernetes-operator"

# 자동 업로드
./bin/setup-nexus.sh
```

### 방법 B: 수동 업로드
```bash
curl -v --user admin:password --upload-file kube-starrocks-1.9.0.tgz \
  https://your-nexus.com/repository/helm-hosted/kube-starrocks-1.9.0.tgz
```

## 🔧 3단계: 설정 파일 수정 (2분)

### 1. ArgoCD ApplicationSet 설정 수정
```bash
# argocd/applications.yaml 수정
vi argocd/applications.yaml

# 변경 대상 (2곳):
# 1. Helm Repository (Nexus)
#    repoURL: https://your-nexus.com/repository/helm-hosted/
# 
# 2. Git Repository
#    repoURL: https://your-git-repo.com/starrocks-deploy.git
```

### 2. Git에 푸시
```bash
git add .
git commit -m "Configure StarRocks Kubernetes deployment"
git push origin main
```

## 📡 4단계: ArgoCD ApplicationSet 배포 (1분)

```bash
# ApplicationSet 배포 (3개 환경의 Application 자동 생성)
kubectl apply -f argocd/applications.yaml

# 배포 확인
kubectl get applicationset -n argocd
kubectl get applications -n argocd

# 출력 예시:
# NAME                                 SYNC STATUS   HEALTH STATUS
# kube-starrocks-operator-dev          Synced        Healthy
# kube-starrocks-operator-staging      Synced        Healthy
# kube-starrocks-operator-prod         OutOfSync     Healthy
```

## 🚀 5단계: Kustomize로 각 환경 배포 (1분)

### 개발 환경
```bash
./bin/deploy.sh dev
```

### 스테이징 환경
```bash
./bin/deploy.sh staging
```

### 프로덕션 환경
```bash
./bin/deploy.sh prod
```

## ✅ 6단계: 배포 확인

```bash
# 배포 상태 확인
./bin/check-status.sh

# 또는 개별 환경 확인
kubectl get pods -n starrocks-dev
kubectl get pods -n starrocks-staging
kubectl get pods -n starrocks-prod

# Application 상태 확인
kubectl get applications -n argocd | grep kube-starrocks
```

## 📊 아키텍처

### ArgoCD Layer
```
argocd/
└── applications.yaml           # ApplicationSet
    ├── dev Application         # namespace, helm values
    ├── staging Application     # namespace, helm values
    └── prod Application        # namespace, helm values
```

### Kustomize Layer
```
kustomize/overlays/
├── dev/                        # ConfigMap, settings
├── staging/                    # ConfigMap, settings
└── prod/                       # ConfigMap, settings
```

### 책임 분리
- **argocd/**: Application, Namespace, Helm 값 정의
- **kustomize/**: 환경별 ConfigMap, 추가 설정

## 📊 배포 후 다음 단계

### 1. StarRocks 클러스터 배포 (선택사항)
```bash
kubectl apply -f docs/sample-cluster.yaml -n starrocks-dev
```

### 2. 클러스터 상태 확인
```bash
kubectl get starrockscluster -n starrocks-dev
```

### 3. 로그 확인
```bash
kubectl logs -n starrocks-dev -l app=starrocks -f
```

## 🆘 문제가 있다면

### Helm Chart 찾을 수 없음
```bash
# Repository 업데이트
helm repo update

# Chart 확인
helm search repo starrocks
```

### Pod이 Pending 상태
```bash
# Pod 상태 확인
kubectl describe pod <pod-name> -n starrocks-dev

# 리소스 부족 시 값 감소
# kustomize/overlays/dev/helm-release.yaml 수정
```

### Git 저장소 접근 실패
```bash
# ArgoCD Repository 재설정
argocd repo add https://your-git-repo.com/starrocks-deploy.git \
  --username your-user \
  --password your-token
```

## 📚 자세한 가이드

- **상세 설정**: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
- **환경별 구성**: [docs/ENVIRONMENT_CONFIG.md](docs/ENVIRONMENT_CONFIG.md)
- **ApplicationSet 가이드**: [docs/APPLICATIONSET_GUIDE.md](docs/APPLICATIONSET_GUIDE.md)
- **문제 해결**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **배포 체크리스트**: [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)

## 🎯 주요 명령어

```bash
# 배포 상태 확인
./bin/check-status.sh

# 롤백
./bin/rollback.sh [env] [revision]

# Pod 로그 조회
kubectl logs -n starrocks-[env] -l app=starrocks -f

# Pod 삭제 (재시작)
kubectl delete pod -n starrocks-[env] -l app=starrocks
```

## 💡 팁

1. **환경별로 단계적 배포**: dev → staging → prod
2. **각 단계에서 충분히 검증** 후 다음 단계로 진행
3. **모니터링 설정** 먼저 완료 후 배포
4. **백업 정책 수립** 후 프로덕션 배포

---

**배포 시간:** 약 5-10분

**다음 작업:** StarRocks 클러스터 생성 및 데이터 로딩

구체적인 질문은 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)를 참고하세요!
