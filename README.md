# StarRocks Kubernetes 배포 환경

StarRocks Kubernetes Operator를 ArgoCD + ApplicationSet으로 관리하는 GitOps 배포 환경입니다.

## 📁 디렉토리 구조

```
starrocks-deploy/
├── argocd/
│   └── applications.yaml          # ApplicationSet (3개 환경 자동 생성)
│
├── kustomize/
│   └── overlays/
│       ├── dev/                   # 개발 환경 설정 (ConfigMap)
│       ├── staging/               # 스테이징 환경 설정 (ConfigMap)
│       └── prod/                  # 프로덕션 환경 설정 (ConfigMap)
│
├── bin/                           # 유틸리티 스크립트
│   ├── deploy.sh                 # 환경별 배포
│   ├── check-status.sh           # 상태 확인
│   ├── rollback.sh               # 롤백
│   └── setup-nexus.sh            # Nexus 업로드
│
├── docs/                          # 문서
│   ├── SETUP_GUIDE.md            # 상세 설정 가이드
│   ├── ENVIRONMENT_CONFIG.md     # 환경별 설정
│   ├── APPLICATIONSET_GUIDE.md   # ApplicationSet 가이드
│   ├── TROUBLESHOOTING.md        # 문제 해결
│   └── sample-cluster.yaml       # StarRocks 클러스터 샘플
│
├── QUICKSTART.md                  # 5분 빠른 시작
├── DEPLOYMENT_CHECKLIST.md        # 배포 체크리스트
├── IMPLEMENTATION_SUMMARY.md      # 구현 상태
└── CLAUDE.md                      # AI 어시스턴트 가이드
```

## 🏗️ 아키텍처

### 계층 구조

```
┌────────────────────────────────────────────┐
│    ArgoCD Layer (applications.yaml)        │
├────────────────────────────────────────────┤
│ • ApplicationSet (List Generator)          │
│   └─ 3개 Application 자동 생성             │
│      ├─ kube-starrocks-operator-dev      │
│      ├─ kube-starrocks-operator-staging  │
│      └─ kube-starrocks-operator-prod     │
│ • 각 Application:                         │
│   ├─ Namespace 생성                       │
│   ├─ Helm Chart 참조 (Nexus)             │
│   ├─ Helm Values 정의                     │
│   └─ Sync Policy 설정                     │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│   Kustomize Layer (overlays/)             │
├────────────────────────────────────────────┤
│ • 환경별 ConfigMap 생성                    │
│ • 공통 레이블 설정                         │
│ • 설정값 참고용 values.yaml               │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│    Git Repository (Source of Truth)       │
└────────────────────────────────────────────┘
```

### 책임 분리

| 계층 | 담당 | 내용 |
|------|------|------|
| **ArgoCD** | 리소스 정의 | Application, Namespace, Helm 차트 및 값 |
| **Kustomize** | 환경 설정 | ConfigMap, 레이블, 환경별 설정값 |

## 🚀 빠른 시작 (5분)

### 1단계: 설정 파일 수정
```bash
# argocd/applications.yaml에서 URL 수정
vi argocd/applications.yaml

# 변경 대상:
# repoURL: https://your-nexus.com/repository/helm-hosted/       (Nexus)
# repoURL: https://your-git-repo.com/starrocks-deploy.git      (Git)
```

### 2단계: Git에 푸시
```bash
git add .
git commit -m "Configure StarRocks Kubernetes deployment"
git push origin main
```

### 3단계: ApplicationSet 배포
```bash
# 모든 환경의 Application 생성 (dev, staging, prod)
kubectl apply -f argocd/applications.yaml

# 확인
kubectl get applicationset -n argocd
kubectl get applications -n argocd
```

### 4단계: 상태 확인
```bash
# 배포 상태 확인
./bin/check-status.sh

# 또는 개별 확인
kubectl get pods -n starrocks-dev
kubectl get pods -n starrocks-staging
kubectl get pods -n starrocks-prod
```

더 자세한 내용은 [QUICKSTART.md](QUICKSTART.md)를 참고하세요.

## 📊 환경별 특징

| 환경 | Replica | CPU | Memory | 동기화 정책 | Namespace |
|------|---------|-----|--------|----------|-----------|
| **Dev** | 1 | 250m/500m | 256Mi/512Mi | 수동 | `starrocks-dev` |
| **Staging** | 2 | 500m/1000m | 512Mi/1Gi | 수동 | `starrocks-staging` |
| **Prod** | 3 | 1000m/2000m | 1Gi/2Gi | 수동 | `starrocks-prod` |

## 🔧 주요 파일 설명

### argocd/applications.yaml
- **ApplicationSet** 정의
- **List Generator**로 3개 환경 설정
- Helm Chart 참조 (Nexus)
- Helm Values 정의
- Namespace 자동 생성

### kustomize/overlays/[env]/kustomization.yaml
- 환경별 ConfigMap 생성
- 공통 레이블 추가
- 설정값 정의

### kustomize/overlays/[env]/values.yaml
- 추가 설정 참고용
- 선택사항

## 🔄 배포 흐름

```
1. argocd/applications.yaml 수정
   ↓
2. Git에 푸시
   ↓
3. kubectl apply -f argocd/applications.yaml
   ↓
4. ApplicationSet이 3개 Application 생성
   ↓
5. ArgoCD가 각 환경에 배포
   ├─ dev: 자동 동기화 + 자동 복구
   ├─ staging: 자동 동기화 + 자동 복구
   └─ prod: 수동 동기화 (안전성)
```

## 📚 문서

### 시작하기
- [QUICKSTART.md](QUICKSTART.md) - 5분 빠른 시작
- [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) - 상세 설정 가이드

### 상세 정보
- [docs/ENVIRONMENT_CONFIG.md](docs/ENVIRONMENT_CONFIG.md) - 환경별 설정
- [docs/APPLICATIONSET_GUIDE.md](docs/APPLICATIONSET_GUIDE.md) - ApplicationSet 사용법
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - 문제 해결

### 운영
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - 배포 체크리스트
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - 구현 상태
- [CLAUDE.md](CLAUDE.md) - AI 어시스턴트 가이드

## 🎯 주요 명령어

### 배포
```bash
# ApplicationSet 배포
kubectl apply -f argocd/applications.yaml

# 또는 스크립트 사용
./bin/deploy.sh dev       # 개발 환경
./bin/deploy.sh staging   # 스테이징 환경
./bin/deploy.sh prod      # 프로덕션 환경
```

### 모니터링
```bash
# 배포 상태 확인
./bin/check-status.sh

# Application 상태
kubectl get applications -n argocd

# Pod 확인
kubectl get pods -n starrocks-[env]

# 로그
kubectl logs -n starrocks-[env] -l app=starrocks -f
```

### 운영
```bash
# 롤백
./bin/rollback.sh [env] [revision]

# 상태 동기화
argocd app sync kube-starrocks-operator-[env]
```

## 🔗 외부 참고자료

- **StarRocks Operator**: https://github.com/StarRocks/starrocks-kubernetes-operator
- **ArgoCD**: https://argo-cd.readthedocs.io/
- **Kustomize**: https://kustomize.io/
- **Helm**: https://helm.sh/docs/

## ✨ 주요 특징

✅ **GitOps** - Git이 유일한 소스 (Source of Truth)
✅ **자동화** - ApplicationSet으로 환경 자동 생성
✅ **확장성** - 환경 추가 시 generator에만 추가
✅ **안전성** - 프로덕션은 수동 동기화
✅ **명확함** - 깔끔한 계층 분리
✅ **간단함** - 한 줄의 배포 명령어

## 📝 라이센스

이 프로젝트는 StarRocks 커뮤니티를 위한 배포 환경입니다.

---

**시작하기**: [QUICKSTART.md](QUICKSTART.md)를 참고하세요!
