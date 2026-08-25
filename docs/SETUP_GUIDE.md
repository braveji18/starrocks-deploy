# StarRocks Kubernetes 배포 설정 가이드

## 📋 사전 요구사항

- Kubernetes 클러스터 (1.19 이상)
- `kubectl` CLI 도구
- `helm` CLI 도구 (3.0 이상)
- `kustomize` CLI 도구 (4.0 이상)
- ArgoCD 설치됨
- Nexus 저장소 설정됨

## 1️⃣ 단계 1: 외부 Operator 가져오기

### 1.1 StarRocks Kubernetes Operator GitHub에서 다운로드

```bash
git clone https://github.com/StarRocks/starrocks-kubernetes-operator.git
cd starrocks-kubernetes-operator
```

### 1.2 Helm Chart 추출

```bash
# Helm charts 디렉토리 확인
ls helm-charts/

# 필요한 chart를 Nexus로 업로드
helm package helm-charts/kube-starrocks
```

## 2️⃣ 단계 2: Nexus Helm 저장소 설정

### 2.1 Nexus에서 Helm 저장소 생성

Nexus 웹 UI에서:
1. `Settings` → `Repositories` → `Create repository`
2. Repository type: `helm (hosted)`
3. Name: `helm-hosted` 또는 원하는 이름
4. Blob store: `default`
5. Create 클릭

### 2.2 Helm Chart 업로드

```bash
# 방법 1: curl을 이용한 업로드
curl -v --user admin:password --upload-file kube-starrocks-1.9.0.tgz \
  https://your-nexus.com/repository/helm-hosted/kube-starrocks-1.9.0.tgz

# 방법 2: Helm plugin 사용
helm plugin install https://github.com/chartmuseum/helm-push.git
helm cm-push kube-starrocks-1.9.0.tgz https://your-nexus.com/repository/helm-hosted/
```

### 2.3 로컬 Helm Repository 추가

```bash
helm repo add starrocks https://your-nexus.com/repository/helm-hosted/ \
  --username admin --password password
helm repo update
```

## 3️⃣ 단계 3: Git Repository 설정

### 3.1 사내 Git에 푸시

```bash
cd starrocks-deploy
git remote set-url origin https://your-git-repo.com/starrocks-deploy.git
git push -u origin main
```

### 3.2 필요한 정보 업데이트

`kustomize/base/helm-release.yaml` 에서 다음을 수정:
```yaml
source:
  repoURL: https://your-nexus.com/repository/helm-hosted/
```

`argocd/overlays/*/application.yaml` 에서 다음을 수정:
```yaml
source:
  repoURL: https://your-git-repo.com/starrocks-deploy.git
```

## 4️⃣ 단계 4: ArgoCD 설정

### 4.1 ArgoCD 저장소 추가

```bash
# Git 저장소 추가 (ArgoCD UI 또는 CLI)
argocd repo add https://your-git-repo.com/starrocks-deploy.git
```

### 4.2 Secret 생성 (Private Repository인 경우)

```bash
kubectl create secret generic argocd-repo-creds \
  --from-literal=username=your-username \
  --from-literal=password=your-token \
  -n argocd
```

### 4.3 Kustomize Plugin 설정

ArgoCD에서 kustomize를 사용하려면, `argocd-cm` ConfigMap에 추가:

```yaml
data:
  kustomize.buildOptions: "--enable-alpha-plugins"
```

## 5️⃣ 단계 5: 배포

### 5.1 개발 환경 배포

```bash
kubectl apply -f argocd/overlays/dev/
# 또는
argocd app create kube-starrocks-operator-dev \
  --repo https://your-git-repo.com/starrocks-deploy.git \
  --path kustomize/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace starrocks-dev
```

### 5.2 스테이징 환경 배포

```bash
kubectl apply -f argocd/overlays/staging/
```

### 5.3 프로덕션 환경 배포

```bash
kubectl apply -f argocd/overlays/prod/
```

## 6️⃣ 단계 6: 배포 상태 확인

```bash
# ArgoCD Application 확인
kubectl get applications -n argocd
argocd app list

# 특정 Application 상태 확인
argocd app get kube-starrocks-operator-dev

# Pod 확인
kubectl get pods -n starrocks-dev
kubectl get pods -n starrocks-staging
kubectl get pods -n starrocks-prod

# Logs 확인
kubectl logs -n starrocks-dev deployment/starrocks-operator -f
```

## 7️⃣ 단계 7: StarRocks Cluster 배포

Operator가 실행되면, StarRocks 클러스터를 배포할 수 있습니다:

```bash
# 샘플 클러스터 배포
kubectl apply -f - <<EOF
apiVersion: starrocks.com/v1
kind: StarRocksCluster
metadata:
  name: starrocks-sample
  namespace: starrocks-dev
spec:
  imageTag: v2.7.0
  feSpec:
    replicas: 3
    resources:
      requests:
        memory: "4Gi"
        cpu: "4"
  beSpec:
    replicas: 3
    resources:
      requests:
        memory: "8Gi"
        cpu: "8"
EOF

# 클러스터 상태 확인
kubectl get starrockscluster -n starrocks-dev
kubectl describe starrockscluster starrocks-sample -n starrocks-dev
```

## 🔒 보안 설정

### 7.1 네트워크 정책

프로덕션 환경에서는 NetworkPolicy 활성화:

```bash
kubectl label namespace starrocks-prod network-policy=enabled
```

### 7.2 RBAC 설정

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: starrocks-operator
  namespace: starrocks-prod
rules:
  - apiGroups: ["starrocks.com"]
    resources: ["*"]
    verbs: ["*"]
```

## 📊 모니터링 설정

### 8.1 Prometheus 연동

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: starrocks-operator
  namespace: starrocks-prod
spec:
  selector:
    matchLabels:
      app: starrocks
  endpoints:
    - port: metrics
      interval: 30s
```

## 🔄 업그레이드 절차

### 9.1 Operator 업그레이드

1. Nexus에 새 버전 업로드
2. `kustomize/base/helm-release.yaml`에서 버전 변경
3. 환경별로 검증 후 배포

```bash
# 개발 환경에서 테스트
kustomize build kustomize/overlays/dev | kubectl apply -f -

# 스테이징에서 검증
kustomize build kustomize/overlays/staging | kubectl apply -f -

# 프로덕션 배포
kustomize build kustomize/overlays/prod | kubectl apply -f -
```

## 🆘 문제 해결

[TROUBLESHOOTING.md](./TROUBLESHOOTING.md) 참고
