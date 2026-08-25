# 문제 해결 가이드

## 🔍 배포 상태 확인

### Application 동기화 실패

```bash
# Application 상태 확인
kubectl describe application kube-starrocks-operator-dev -n argocd

# 상세 오류 확인
argocd app get kube-starrocks-operator-dev --refresh

# ArgoCD 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f
```

**일반적인 원인:**
- Git 저장소 접근 권한 없음
- Helm repository 접근 불가
- Kustomize 구문 오류
- 네임스페이스 생성 실패

### Pod 생성 실패

```bash
# Pod 상태 확인
kubectl describe pod -n starrocks-dev -l app=starrocks

# 이벤트 확인
kubectl get events -n starrocks-dev --sort-by='.lastTimestamp'

# Pod 로그 확인
kubectl logs -n starrocks-dev -l app=starrocks --previous
```

**일반적인 원인:**
- 리소스 부족 (CPU/Memory)
- 이미지 풀 실패
- 노드 셀렉터 불일치

---

## 🔧 일반적인 문제 및 해결책

### 1. Helm Chart를 찾을 수 없음

**오류:**
```
Error: chart requires kubeVersion: >=1.19.0-0 which is incompatible with Kubernetes v1.18.0
```

**해결책:**
```bash
# Kubernetes 버전 확인
kubectl version --short

# Helm repository 업데이트
helm repo update

# Chart 가용성 확인
helm search repo starrocks
```

### 2. Kustomize 플러그인 로드 실패

**오류:**
```
kustomize plugin not found
```

**해결책:**

ArgoCD ConfigMap에서 설정 확인:
```bash
kubectl get cm argocd-cm -n argocd -o yaml | grep kustomize

# 플러그인 활성화
kubectl patch cm argocd-cm -n argocd -p '{"data":{"kustomize.buildOptions":"--enable-alpha-plugins"}}'

# ArgoCD 재시작
kubectl rollout restart deployment argocd-application-controller -n argocd
```

### 3. Git 저장소 인증 실패

**오류:**
```
fatal: could not authenticate to repository
```

**해결책:**

SSH Key 또는 Token 설정:
```bash
# SSH 키로 저장소 추가
argocd repo add git@your-git-repo.com:starrocks-deploy.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# 또는 Personal Access Token으로 추가
argocd repo add https://your-git-repo.com/starrocks-deploy.git \
  --username your-username \
  --password your-token
```

### 4. Nexus Helm Repository 접근 불가

**오류:**
```
Error: repo index not found
```

**해결책:**

```bash
# Nexus 연결 테스트
curl -u admin:password https://your-nexus.com/repository/helm-hosted/index.yaml

# Helm repository 재추가
helm repo remove starrocks
helm repo add starrocks https://your-nexus.com/repository/helm-hosted/ \
  --username admin \
  --password password

# 캐시 정리
helm repo update
rm -rf ~/.helm/cache
```

### 5. Pod 리소스 부족

**증상:**
```
Pending 상태로 계속 머무름
```

**확인:**
```bash
# 노드 리소스 확인
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# 할당 불가능한 Pod 확인
kubectl describe pod <pod-name> -n starrocks-dev
```

**해결책:**
```bash
# 환경별 리소스 값 감소
# kustomize/overlays/[env]/values.yaml 수정
resources:
  requests:
    cpu: 100m      # 감소
    memory: 128Mi   # 감소

# 변경사항 적용
kubectl apply -f kustomize/overlays/dev/
```

---

## 🔐 보안 관련 문제

### Pod Security Policy 위반

**오류:**
```
Pod does not have minimum level RESTRICTED
```

**해결책:**

Pod Security Policy 확인:
```bash
kubectl get psp

# 필요한 경우 정책 수정
kubectl patch psp restricted --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/runAsUser/rule",
    "value": "MustRunAsNonRoot"
  }
]'
```

### RBAC 권한 부족

**오류:**
```
forbidden: User "system:serviceaccount:starrocks-dev:default" cannot get starrocksclusters
```

**해결책:**

```bash
# Role Binding 생성
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: starrocks-operator
rules:
  - apiGroups: ["starrocks.com"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: starrocks-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: starrocks-operator
subjects:
  - kind: ServiceAccount
    name: starrocks-operator
    namespace: starrocks-dev
EOF
```

---

## 📊 성능 문제

### Operator 느린 응답

**확인:**
```bash
# 메트릭 확인
kubectl port-forward -n starrocks-dev svc/starrocks-operator-dev 8080:8080

# Prometheus에서 메트릭 쿼리
# http://localhost:8080/metrics
```

**최적화:**
```yaml
# values.yaml에서 캐시 설정 조정
cache:
  enabled: true
  maxSize: 1000
  ttl: 300s
```

### 메모리 누수 의심

**확인:**
```bash
# Pod 메모리 사용률 추이
kubectl top pod -n starrocks-dev --containers

# 시간별 메모리 사용량 확인
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/starrocks-dev/pods
```

**해결책:**
```bash
# Pod 재시작
kubectl rollout restart deployment starrocks-operator -n starrocks-dev

# 재시작 정책 변경 (필요시)
kubectl set env deployment/starrocks-operator \
  -n starrocks-dev \
  GOMAXPROCS=4 \
  GOGC=75
```

---

## 🔄 업그레이드 문제

### 롤백 절차

업그레이드 후 문제 발생 시:

```bash
# 이전 버전으로 롤백
# kustomize/base/helm-release.yaml에서 targetRevision을 이전 버전으로 변경
# 또는
argocd app rollback kube-starrocks-operator-dev <revision>
```

### 무중단 배포 검증

```bash
# 배포 진행 상황 확인
kubectl rollout status deployment/starrocks-operator -n starrocks-prod

# 롤링 업데이트 진행 상황 모니터링
watch kubectl get pods -n starrocks-prod

# 예상 결과: 기존 Pod은 유지되고 새 Pod이 추가됨
```

---

## 📋 디버깅 팁

### 완전한 로그 수집

```bash
# 모든 관련 리소스의 YAML 수집
kubectl get all -n starrocks-dev -o yaml > debug-starrocks-dev.yaml

# ArgoCD 로그 수집
kubectl logs -n argocd \
  -l app.kubernetes.io/name=argocd-application-controller \
  --tail=100 > debug-argocd.log

# 클러스터 이벤트 수집
kubectl get events -n starrocks-dev --sort-by='.lastTimestamp' > events.log
```

### Dry-run으로 배포 테스트

```bash
# 실제 배포 없이 렌더링 결과 확인
kustomize build kustomize/overlays/dev | kubectl apply -f - --dry-run=client

# Helm으로 렌더링
helm template starrocks-operator starrocks/kube-starrocks \
  -n starrocks-dev \
  -f kustomize/overlays/dev/values.yaml
```

### 환경 변수 확인

```bash
# Operator Pod의 환경 변수 확인
kubectl exec -it <operator-pod> -n starrocks-dev -- env | sort
```

---

## 📞 추가 지원

문제가 계속되면:

1. 로그 수집: `kubectl logs -n starrocks-dev ...`
2. 이벤트 확인: `kubectl get events -n starrocks-dev`
3. [StarRocks GitHub Issues](https://github.com/StarRocks/starrocks-kubernetes-operator/issues)
4. StarRocks 커뮤니티 지원
