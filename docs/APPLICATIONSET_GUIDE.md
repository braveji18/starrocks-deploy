# ArgoCD ApplicationSet 가이드

## 개요

이 프로젝트는 **ApplicationSet**을 사용하여 여러 환경(dev, staging, prod)의 배포를 관리합니다.

ApplicationSet은 ArgoCD 1.12+ 에서 도입되었으며, 하나의 리소스 정의로 여러 Application을 동적으로 생성할 수 있습니다.

## ApplicationSet의 장점

### 1. **중앙화된 관리**
- 모든 환경의 Application을 하나의 ApplicationSet으로 관리
- 변경 시 한 곳만 수정

### 2. **템플릿 기반 생성**
```yaml
template:
  metadata:
    name: kube-starrocks-operator-{{ name }}
  spec:
    destination:
      namespace: {{ namespace }}
```

### 3. **Generator를 통한 동적 생성**
- **List Generator**: 고정된 환경 리스트
- **Git Generator**: Git 저장소의 파일에서 추출
- **Cluster Generator**: 클러스터 정보 기반
- **Matrix Generator**: 여러 generator 조합

## 현재 구조

### ApplicationSet 정의
파일: `argocd/applications.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: starrocks-operator
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - name: dev
            namespace: starrocks-dev
            autoSync: "true"
          - name: staging
            namespace: starrocks-staging
            autoSync: "true"
          - name: prod
            namespace: starrocks-prod
            autoSync: "false"
  
  template:
    metadata:
      name: kube-starrocks-operator-{{ name }}
    spec:
      destination:
        namespace: {{ namespace }}
      syncPolicy:
        automated:
          selfHeal: {{ selfHealEnabled }}
```

### 생성되는 Application

ApplicationSet으로부터 다음 3개의 Application이 자동으로 생성됩니다:

| Application | Namespace | 자동 동기화 | 용도 |
|------------|-----------|----------|------|
| `kube-starrocks-operator-dev` | `starrocks-dev` | ✅ 활성화 | 개발 환경 |
| `kube-starrocks-operator-staging` | `starrocks-staging` | ✅ 활성화 | 스테이징 환경 |
| `kube-starrocks-operator-prod` | `starrocks-prod` | ❌ 비활성화 | 프로덕션 환경 |

## 배포

### 1. ApplicationSet 배포

```bash
# Kustomize를 사용한 배포
kubectl apply -k argocd/

# 또는 직접 배포
kubectl apply -f argocd/applications.yaml
```

### 2. 생성된 Application 확인

```bash
# 모든 Application 확인
kubectl get applications -n argocd

# 출력 예시:
# NAME                                    SYNC STATUS   HEALTH STATUS
# kube-starrocks-operator-dev             Synced        Healthy
# kube-starrocks-operator-staging         Synced        Healthy
# kube-starrocks-operator-prod            OutOfSync     Healthy
```

### 3. ApplicationSet 상태 확인

```bash
# ApplicationSet 조회
kubectl get applicationsets -n argocd

# ApplicationSet 상세 정보
kubectl describe applicationset starrocks-operator -n argocd

# ApplicationSet 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller -f
```

## 환경별 설정 커스터마이제이션

### List Generator 요소 추가/수정

`argocd/applications.yaml`의 `generators.list.elements`에서 환경을 추가/수정합니다:

```yaml
generators:
  - list:
      elements:
        # 새로운 환경 추가
        - name: uat
          namespace: starrocks-uat
          autoSync: "true"
          pruneEnabled: "true"
```

변경 후:
```bash
kubectl apply -k argocd/
```

새로운 Application이 자동으로 생성됩니다.

## 변수 참조

ApplicationSet 템플릿에서 사용 가능한 변수:

```yaml
# List Generator의 요소에서 정의된 변수
{{ name }}                  # 환경 이름 (dev, staging, prod)
{{ namespace }}             # 네임스페이스
{{ autoSync }}              # 자동 동기화 여부
{{ pruneEnabled }}          # Prune 활성화 여부
{{ selfHealEnabled }}       # Self-heal 활성화 여부
```

## 트러블슈팅

### ApplicationSet이 Application을 생성하지 않음

1. **ApplicationSet Controller 확인**
   ```bash
   kubectl get pods -n argocd | grep applicationset
   ```
   응답: `argocd-applicationset-controller-*`

2. **Controller 로그 확인**
   ```bash
   kubectl logs -n argocd \
     -l app.kubernetes.io/name=argocd-applicationset-controller -f
   ```

3. **ApplicationSet 상태 확인**
   ```bash
   kubectl get applicationset starrocks-operator -n argocd -o yaml
   ```

### Application 템플릿 오류

변수명 오류 또는 템플릿 문법 오류:

```bash
# YAML 검증
kubectl apply -k argocd/ --dry-run=client

# 렌더링 결과 확인
kustomize build argocd/ | grep -A 20 "kind: ApplicationSet"
```

## 고급 사용법

### Matrix Generator를 사용한 복합 설정

여러 Generator를 조합하여 더 복잡한 시나리오 처리:

```yaml
generators:
  - matrix:
      generators:
        - list:
            elements:
              - name: dev
              - name: prod
        - list:
            elements:
              - region: us-east-1
              - region: us-west-2
```

위 설정은 4개의 Application을 생성합니다:
- `kube-starrocks-operator-dev-us-east-1`
- `kube-starrocks-operator-dev-us-west-2`
- `kube-starrocks-operator-prod-us-east-1`
- `kube-starrocks-operator-prod-us-west-2`

### Git Generator를 사용한 동적 생성

Git 저장소의 디렉토리 구조에 따라 자동으로 Application 생성:

```yaml
generators:
  - git:
      repoURL: https://your-git-repo.com/starrocks-deploy.git
      revision: main
      directories:
        - path: kustomize/overlays/*
```

이 경우, 각 overlay 디렉토리마다 자동으로 Application이 생성됩니다.

## 모범 사례

### 1. 환경별 네임스페이스 격리
```yaml
elements:
  - name: dev
    namespace: starrocks-dev
  - name: prod
    namespace: starrocks-prod
```

### 2. 자동 동기화 정책 환경별 차별화
```yaml
- name: prod
  autoSync: "false"           # Prod는 수동 동기화
  selfHealEnabled: "false"    # Prod는 자동 복구 비활성화
```

### 3. 변수명 명확히
```yaml
elements:
  - name: dev
    displayName: "Development"
    syncWave: "-5"            # 먼저 배포
  - name: prod
    displayName: "Production"
    syncWave: "5"             # 나중에 배포
```

### 4. 공통 설정과 환경별 설정 분리
```yaml
template:
  spec:
    # 공통 설정
    project: default
    source:
      plugin:
        name: kustomize
    
    # 환경별 설정 (변수 사용)
    destination:
      namespace: {{ namespace }}
    syncPolicy:
      automated:
        selfHeal: {{ selfHealEnabled }}
```

## 관련 문서

- [QUICKSTART.md](../QUICKSTART.md) - 빠른 시작
- [SETUP_GUIDE.md](./SETUP_GUIDE.md) - 상세 설정
- [DEPLOYMENT_CHECKLIST.md](../DEPLOYMENT_CHECKLIST.md) - 배포 체크리스트

## 외부 참고자료

- [ArgoCD ApplicationSet 공식 문서](https://argocd-applicationset.readthedocs.io/)
- [ApplicationSet Generators](https://argocd-applicationset.readthedocs.io/en/stable/Generators/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
