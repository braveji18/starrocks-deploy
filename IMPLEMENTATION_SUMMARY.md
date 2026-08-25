# StarRocks Kubernetes 배포 환경 구현 완료

## ✅ 완성된 구조

### 1. Kustomize 구성
```
kustomize/
└── overlays/                      # 환경별 설정(ConfigMap, values 등)
    ├── dev/                       # 개발 환경
    │   ├── kustomization.yaml    # ConfigMap 생성, 공통 레이블
    │   └── values.yaml           # 추가 설정 참고용
    ├── staging/                   # 스테이징 환경
    │   ├── kustomization.yaml
    │   └── values.yaml
    └── prod/                      # 프로덕션 환경
        ├── kustomization.yaml
        └── values.yaml
```

**특징:**
- **책임 분리**: Application/Namespace는 argocd에서만 관리
- **Kustomize 역할**: 환경별 설정값(ConfigMap) 관리
- **단순함**: 최소한의 파일만 포함
- **유연함**: ConfigMap으로 동적 설정 주입

### 2. ArgoCD ApplicationSet 구성
```
argocd/
└── applications.yaml             # ApplicationSet (List Generator)
```

**특징:**
- **ApplicationSet**을 사용한 동적 Application 생성
- **List Generator**로 dev, staging, prod 환경 정의
- 각 환경별로 고유한 설정 (namespace, syncPolicy 등)
- 템플릿 기반으로 3개의 Application 자동 생성
- **모든 환경**: 수동 동기화 (명시적 배포 승인 필요)
- 안전성과 제어 우선
- Kustomize 없이 직접 배포 가능

### 3. 배포 스크립트
```
bin/
├── setup-nexus.sh                # Helm Chart를 Nexus에 업로드
├── deploy.sh                     # 환경별 배포 실행
├── check-status.sh               # 배포 상태 확인
└── rollback.sh                   # 롤백 처리
```

### 4. 문서
```
docs/
├── SETUP_GUIDE.md               # 상세 설정 가이드
├── ENVIRONMENT_CONFIG.md        # 환경별 설정 상세 설명
├── TROUBLESHOOTING.md           # 문제 해결 가이드
└── sample-cluster.yaml          # StarRocks 클러스터 샘플
```

### 5. 최상위 문서
- `QUICKSTART.md` - 5분 안에 시작하기
- `DEPLOYMENT_CHECKLIST.md` - 배포 전/후 체크리스트
- `CLAUDE.md` - AI 어시스턴트용 가이드

---

## 🔧 환경별 설정

### 개발 (Development)
| 항목 | 설정 |
|------|------|
| Replica | 1 |
| CPU Req/Limit | 250m / 500m |
| Memory Req/Limit | 256Mi / 512Mi |
| Log Level | DEBUG |
| Auto Sync | ✅ |
| Pod Anti-Affinity | - |
| Namespace | starrocks-dev |

### 스테이징 (Staging)
| 항목 | 설정 |
|------|------|
| Replica | 2 |
| CPU Req/Limit | 500m / 1000m |
| Memory Req/Limit | 512Mi / 1Gi |
| Log Level | INFO |
| Auto Sync | ✅ |
| Pod Anti-Affinity | Preferred |
| Namespace | starrocks-staging |

### 프로덕션 (Production)
| 항목 | 설정 |
|------|------|
| Replica | 3 |
| CPU Req/Limit | 1000m / 2000m |
| Memory Req/Limit | 1Gi / 2Gi |
| Log Level | WARN |
| Auto Sync | ❌ (수동) |
| Pod Anti-Affinity | Required |
| Pod Disruption Budget | minAvailable=2 |
| Namespace | starrocks-prod |

---

## 📋 필요한 수정사항

배포 전에 다음을 **반드시** 수정하세요:

### 1. Helm Repository URL
파일: `argocd/applications.yaml`
```yaml
source:
  repoURL: https://your-nexus.com/repository/helm-hosted/  # ← 수정
```

### 2. Git Repository URL
파일: `argocd/applications.yaml`
```yaml
source:
  repoURL: https://your-git-repo.com/starrocks-deploy.git  # ← 수정
```

### 3. Operator 버전 (선택사항)
파일: `argocd/applications.yaml`
```yaml
targetRevision: "1.9.0"  # ← 필요시 수정
```

---

## 🚀 배포 흐름

### 1단계: 초기 설정
```bash
# 필수: URL 수정
# argocd/applications.yaml에서 Git Repository URL 변경
vi argocd/applications.yaml

# Git에 모든 변경사항 커밋
git add .
git commit -m "Configure StarRocks Kubernetes deployment"
git push origin main

# ArgoCD ApplicationSet 배포
kubectl apply -f argocd/applications.yaml

# 배포 확인
kubectl get applicationset -n argocd
kubectl get applications -n argocd
```

### 2단계: 개발 환경 검증
```bash
# 배포
./bin/deploy.sh dev

# 상태 확인
./bin/check-status.sh

# 문제 해결 (필요시)
kubectl logs -n starrocks-dev -l app=starrocks -f
```

### 3단계: 스테이징 검증
```bash
# 배포
./bin/deploy.sh staging

# 통합/성능 테스트 수행
```

### 4단계: 프로덕션 배포
```bash
# 배포 (수동 확인 포함)
./bin/deploy.sh prod

# 지속적 모니터링
./bin/check-status.sh
```

---

## 🔄 업그레이드 절차

### Operator 버전 업그레이드
```bash
# 1. Nexus에 새 버전 업로드
curl -u admin:password --upload-file kube-starrocks-1.10.0.tgz \
  https://your-nexus.com/repository/helm-hosted/

# 2. 버전 업데이트
# kustomize/base/helm-release.yaml에서 targetRevision 변경

# 3. 개발 환경에서 테스트
./bin/deploy.sh dev

# 4. 스테이징에서 검증
./bin/deploy.sh staging

# 5. 프로덕션 배포
./bin/deploy.sh prod
```

### 롤백 절차
```bash
# 배포 실패 시 이전 버전으로 복귀
./bin/rollback.sh [env] [revision]

# 버전 확인:
argocd app history kube-starrocks-operator-[env]
```

---

## 📊 모니터링 포인트

배포 후 모니터링할 항목:

1. **Pod 상태**
   ```bash
   kubectl get pods -n starrocks-[env] -w
   ```

2. **리소스 사용률**
   ```bash
   kubectl top pods -n starrocks-[env]
   ```

3. **로그 모니터링**
   ```bash
   kubectl logs -n starrocks-[env] -l app=starrocks -f
   ```

4. **이벤트 확인**
   ```bash
   kubectl get events -n starrocks-[env] --sort-by='.lastTimestamp'
   ```

5. **ArgoCD 상태**
   ```bash
   argocd app list
   argocd app get kube-starrocks-operator-[env]
   ```

---

## 🔒 보안 고려사항

### 프로덕션 배포 시 필수 사항

- [ ] RBAC 설정 검토
- [ ] NetworkPolicy 활성화
- [ ] Pod Security Policy 준수
- [ ] 이미지 레지스트리 정책 확인
- [ ] Secret 관리 정책 수립
- [ ] 감사 로깅 활성화
- [ ] 백업 정책 구현

### 네임스페이스 격리
- 각 환경이 별도 네임스페이스 사용
- 리소스 할당량 (ResourceQuota) 설정 권장
- 네트워크 정책으로 트래픽 제어

---

## 📚 다음 단계

1. **StarRocks 클러스터 배포** (선택사항)
   ```bash
   kubectl apply -f docs/sample-cluster.yaml -n starrocks-[env]
   ```

2. **모니터링 설정**
   - Prometheus 연동
   - Grafana 대시보드 생성
   - 알람 규칙 설정

3. **백업/복구 설정**
   - 정기 백업 스케줄
   - 백업 검증 프로세스
   - 복구 테스트

4. **운영 자동화**
   - 배포 파이프라인 구성
   - 자동 롤아웃 정책 수립
   - 장애 대응 프로세스

---

## 📞 참고 자료

| 주제 | 문서 |
|------|------|
| 빠른 시작 | [QUICKSTART.md](QUICKSTART.md) |
| 상세 설정 | [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) |
| 환경별 설정 | [docs/ENVIRONMENT_CONFIG.md](docs/ENVIRONMENT_CONFIG.md) |
| 문제 해결 | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| 배포 체크리스트 | [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) |
| StarRocks 공식 | https://github.com/StarRocks/starrocks-kubernetes-operator |

---

## 🎯 구현 완료 체크리스트

- [x] Kustomize 기본 구조 생성
- [x] 환경별 overlays 구성 (dev, staging, prod)
- [x] ArgoCD Application 매니페스트 생성
- [x] 배포 스크립트 작성
- [x] 상세 문서 작성
- [x] 샘플 설정 제공
- [x] 체크리스트 및 가이드 생성

**다음:** 위의 필수 수정사항을 완료한 후 배포를 시작하세요!

---

**구현 완료 날짜:** 2026-08-25

**권장 다음 단계:** QUICKSTART.md 참고하여 5분 안에 배포 시작
