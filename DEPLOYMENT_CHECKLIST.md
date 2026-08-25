# StarRocks Kubernetes 배포 체크리스트

## 사전 준비

### 인프라 준비
- [ ] Kubernetes 클러스터 설정됨 (1.19 이상)
- [ ] kubectl 설치 및 클러스터에 연결됨
- [ ] ArgoCD 클러스터에 설치됨
- [ ] Nexus 저장소 설정됨

### 도구 설치
- [ ] helm CLI 설치됨 (3.0 이상)
- [ ] kustomize CLI 설치됨 (4.0 이상)
- [ ] argocd CLI 설치됨 (선택사항)
- [ ] kubectl 플러그인 설치됨 (선택사항)

### 저장소 준비
- [ ] 사내 Git 저장소 생성됨
- [ ] GitHub에서 Operator 소스 복제 (참고용)
- [ ] Helm Chart를 Nexus에 업로드할 준비됨

---

## 환경별 배포 단계

### 1. 개발(Dev) 환경 배포

#### 설정 검증
- [ ] `kustomize/overlays/dev/kustomization.yaml` 확인
- [ ] `kustomize/overlays/dev/values.yaml` 검토
- [ ] Namespace 설정 확인 (`starrocks-dev`)

#### Nexus 설정
- [ ] Helm Chart를 Nexus에 업로드됨
- [ ] `kustomize/base/helm-release.yaml`의 repoURL 업데이트됨
  ```yaml
  repoURL: https://your-nexus.com/repository/helm-hosted/
  ```

#### 배포 실행
- [ ] `./bin/setup-nexus.sh` 실행 (필요시)
- [ ] `./bin/deploy.sh dev` 실행
- [ ] 배포 성공 확인
- [ ] Pod이 Running 상태인지 확인

#### 검증
- [ ] `kubectl get pods -n starrocks-dev` 확인
- [ ] `kubectl logs -n starrocks-dev -l app=starrocks` 확인
- [ ] ArgoCD Application 상태 확인

### 2. 스테이징(Staging) 환경 배포

#### 설정 검증
- [ ] Dev 환경에서 기능 검증 완료
- [ ] `kustomize/overlays/staging/` 설정 검토
- [ ] 리소스 요청/제한 적절한지 확인

#### Git 저장소 설정
- [ ] 모든 변경사항이 Git에 커밋됨
- [ ] `argocd/applications.yaml`의 staging 설정 확인

#### ArgoCD 설정
- [ ] Git 저장소를 ArgoCD에 추가
- [ ] 저장소 접근 권한 확인
- [ ] SSH 키 또는 토큰 설정됨
- [ ] ApplicationSet Controller 활성화 확인 (ArgoCD 1.12+)

#### 배포 실행
- [ ] Application 배포: `kubectl apply -f argocd/applications.yaml`
- [ ] Staging Application 동기화: `argocd app sync kube-starrocks-operator-staging`
- [ ] Pod이 다른 노드에 분산되는지 확인 (Anti-Affinity)

#### 성능/통합 테스트
- [ ] 리소스 모니터링 (`kubectl top pods`)
- [ ] 부하 테스트 실행
- [ ] 통합 테스트 성공 확인

### 3. 프로덕션(Prod) 환경 배포

#### 사전 검증
- [ ] Staging 환경에서 모든 테스트 완료
- [ ] Change Log 작성 및 검토
- [ ] 롤백 계획 수립
- [ ] 배포 일정 공지

#### 설정 검증
- [ ] 프로덕션 설정 검토 (Pod Disruption Budget, Anti-Affinity 등)
- [ ] 리소스 요청/제한 적절한지 확인
- [ ] Tolerations 설정 확인

#### 보안/규정 준수
- [ ] RBAC 설정 검토
- [ ] NetworkPolicy 활성화 확인
- [ ] 로그 레벨이 WARN으로 설정되었는지 확인
- [ ] 감사 로깅 설정 확인

#### 모니터링 설정
- [ ] Prometheus/모니터링 시스템 연동
- [ ] 알람 규칙 설정
- [ ] 대시보드 생성
- [ ] 온콜(On-call) 담당자 지정

#### 백업/재해복구
- [ ] 백업 정책 설정
- [ ] 백업 저장소 확인
- [ ] 재해복구 계획 검증
- [ ] 복구 절차 테스트

#### 최종 배포
- [ ] Staging 환경에서 최종 검증
- [ ] 승인 획득
- [ ] 배포 전 클러스터 상태 백업
- [ ] `./bin/deploy.sh prod` 실행 (수동 확인 포함)
- [ ] 배포 진행 상황 모니터링

#### 배포 후 검증
- [ ] 모든 Pod이 실행 중인지 확인
- [ ] 다른 노드에 분산되었는지 확인 (Required Anti-Affinity)
- [ ] Pod Disruption Budget 확인
- [ ] 애플리케이션 헬스 체크
- [ ] 로그 모니터링
- [ ] 메트릭 확인

---

## StarRocks 클러스터 배포 (선택사항)

### 기본 클러스터 배포
- [ ] `docs/sample-cluster.yaml` 검토
- [ ] 환경별로 샘플 수정
- [ ] 클러스터 배포:
  ```bash
  kubectl apply -f docs/sample-cluster.yaml
  ```
- [ ] 클러스터 상태 확인:
  ```bash
  kubectl get starrockscluster -n starrocks-[env]
  ```

### 클러스터 초기화
- [ ] FE 관리자 계정 생성
- [ ] 기본 데이터베이스 생성
- [ ] 백업 정책 설정

---

## 배포 후 작업

### 문서화
- [ ] 배포 과정 문서화
- [ ] 구성 변경사항 기록
- [ ] 문제 해결 로그 저장

### 모니터링 설정
- [ ] 메트릭 대시보드 생성
- [ ] 알람 규칙 구성
- [ ] 로그 집계 설정

### 팀 교육
- [ ] 운영팀 교육
- [ ] 문제 해결 절차 공유
- [ ] 긴급 연락 체계 확립

### 정기 점검
- [ ] 주간 상태 확인
- [ ] 월간 성능 검토
- [ ] 분기별 재해복구 테스트

---

## 롤백 계획

### 배포 실패 시
- [ ] 로그 수집 및 분석
- [ ] 원인 파악
- [ ] `./bin/rollback.sh` 실행
- [ ] 이전 버전으로 복구
- [ ] 검증 완료

### 업그레이드 후 이상 발생 시
1. 로그 확인: `kubectl logs -n starrocks-[env] ...`
2. 이벤트 확인: `kubectl get events -n starrocks-[env]`
3. 롤백 실행: `./bin/rollback.sh [env] [revision]`
4. ArgoCD 동기화: `argocd app sync kube-starrocks-operator-[env]`

---

## 자주 사용하는 명령어

```bash
# 배포 상태 확인
./bin/check-status.sh

# 개발 환경 배포
./bin/deploy.sh dev

# 스테이징 환경 배포
./bin/deploy.sh staging

# 프로덕션 환경 배포
./bin/deploy.sh prod

# 배포 롤백
./bin/rollback.sh [env] [revision]

# Pod 로그 확인
kubectl logs -n starrocks-[env] -l app=starrocks -f

# 클러스터 상태 확인
kubectl get starrockscluster -n starrocks-[env]
```

---

## 긴급 연락처 및 참고

- StarRocks 커뮤니티: https://github.com/StarRocks/starrocks
- 내부 문서: [문서 위치]
- 담당자: [담당자 연락처]

---

## 최종 확인

배포 완료 후:

- [ ] 모든 체크리스트 항목 확인됨
- [ ] 문서화 완료됨
- [ ] 팀에 배포 알림됨
- [ ] 모니터링 설정 완료됨
- [ ] 긴급 연락체계 확립됨

**배포 완료 날짜:** _________________

**담당자:** _________________

**검수자:** _________________
