# 환경별 설정 가이드

## 개발 (Development) 환경

### 목적
- 로컬 개발 및 테스트
- 기능 검증
- 버그 수정

### 특징
- **Replica**: 1개
- **리소스**: 최소 (CPU: 250m, Memory: 256Mi)
- **로그**: DEBUG 레벨
- **자동 동기화**: 활성화
- **Webhooks**: 비활성화

### 배포 명령어
```bash
kubectl apply -f argocd/overlays/dev/
```

### 네임스페이스
- `starrocks-dev`

### 접근
```bash
# Pod 확인
kubectl get pods -n starrocks-dev

# 로그 확인
kubectl logs -n starrocks-dev -l app=starrocks -f

# Port Forwarding
kubectl port-forward -n starrocks-dev svc/starrocks-operator-dev 9443:9443
```

---

## 스테이징 (Staging) 환경

### 목적
- 프로덕션 배포 전 검증
- 성능 테스트
- 통합 테스트

### 특징
- **Replica**: 2개 (고가용성)
- **리소스**: 중간 (CPU: 500m, Memory: 512Mi)
- **로그**: INFO 레벨
- **Pod Anti-Affinity**: Preferred (다른 노드에 배포)
- **Webhooks**: 활성화
- **메트릭**: 60초 간격

### 배포 명령어
```bash
kubectl apply -f argocd/overlays/staging/
```

### 네임스페이스
- `starrocks-staging`

### 모니터링
```bash
# Pod 분포 확인
kubectl get pods -n starrocks-staging -o wide

# 리소스 사용률 확인
kubectl top pods -n starrocks-staging

# 메트릭 확인
kubectl port-forward -n starrocks-staging svc/starrocks-operator-staging 8080:8080
```

---

## 프로덕션 (Production) 환경

### 목적
- 실제 운영 환경
- 고가용성 보장
- 안정성 및 성능 최우선

### 특징
- **Replica**: 3개 (최고 가용성)
- **리소스**: 높음 (CPU: 1000m, Memory: 1Gi)
- **로그**: WARN 레벨 (최소한의 로깅)
- **Pod Disruption Budget**: minAvailable=2
- **Pod Anti-Affinity**: Required (반드시 다른 노드)
- **Tolerations**: critical 워크로드용
- **자동 동기화**: 비활성화 (수동 배포)
- **메트릭**: 300초 간격

### 배포 명령어
```bash
# 수동 배포 (권장)
kubectl apply -f argocd/overlays/prod/

# 또는 ArgoCD CLI로 동기화
argocd app sync kube-starrocks-operator-prod
```

### 네임스페이스
- `starrocks-prod`

### 프로덕션 체크리스트

배포 전 다음을 확인하세요:

- [ ] 모든 환경에서 충분히 테스트됨
- [ ] 리소스 할당량 충분함
- [ ] 백업 정책 설정됨
- [ ] 모니터링/알림 설정됨
- [ ] 롤백 계획 수립됨
- [ ] 변경사항 로깅 설정됨

### 모니터링 및 알림

```bash
# Pod 상태 확인
kubectl get pods -n starrocks-prod -o wide

# 이벤트 확인
kubectl get events -n starrocks-prod --sort-by='.lastTimestamp'

# 리소스 모니터링
watch kubectl top pods -n starrocks-prod
```

### 고가용성 검증

```bash
# Pod Anti-Affinity 확인
kubectl get pods -n starrocks-prod -o wide | grep starrocks-operator

# 예상 결과: 3개의 Pod이 다른 노드에 분산되어 있어야 함
```

---

## 환경별 값 비교

| 항목 | Dev | Staging | Prod |
|------|-----|---------|------|
| Namespace | starrocks-dev | starrocks-staging | starrocks-prod |
| Replica | 1 | 2 | 3 |
| CPU Req | 250m | 500m | 1000m |
| CPU Limit | 500m | 1000m | 2000m |
| Memory Req | 256Mi | 512Mi | 1Gi |
| Memory Limit | 512Mi | 1Gi | 2Gi |
| Log Level | DEBUG | INFO | WARN |
| Webhooks | 비활성 | 활성 | 활성 |
| Auto Sync | ✅ | ✅ | ❌ |
| PDB | ❌ | ❌ | ✅ |
| Pod Anti-Affinity | - | Preferred | Required |

---

## 환경 전환 가이드

### Dev → Staging

1. 개발 환경에서 기능 검증
2. `git` commit & push
3. Staging 배포:
   ```bash
   argocd app sync kube-starrocks-operator-staging
   ```
4. 통합/성능 테스트 실행
5. 검증 완료 후 Production 배포 승인

### Staging → Production

⚠️ **수동 검토 필수**

1. Staging 테스트 완료 확인
2. Change Log 작성
3. 배포 승인 획득
4. Production 배포:
   ```bash
   argocd app sync kube-starrocks-operator-prod
   ```
5. 배포 후 모니터링

---

## 리소스 요청/제한 가이드

### CPU 설정 기준
- **Dev**: 최소 (테스트 목적)
- **Staging**: 중간 (실제 트래픽 시뮬레이션)
- **Prod**: 최대 (여유도 고려)

### 메모리 설정 기준
- Operator는 일반적으로 메모리를 많이 사용하지 않음
- 클러스터 규모에 따라 증가 가능
- Pod 내 객체 캐시 크기에 따라 조정

### 권장 수정 시 고려사항
```bash
# 현재 리소스 사용률 확인
kubectl top pods -n starrocks-prod

# 메트릭 기반 자동 스케일링 고려
kubectl autoscale deployment starrocks-operator \
  --cpu-percent=70 --min=1 --max=5 -n starrocks-prod
```
