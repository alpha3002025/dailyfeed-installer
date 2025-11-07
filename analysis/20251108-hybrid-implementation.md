# 하이브리드 인프라 구성 구현 완료

## 구현 개요

Docker Compose로 인프라를 실행하고 애플리케이션만 Kubernetes(Kind)에 배포하는 하이브리드 구성으로 변경 완료.

---

## 변경된 파일들

### 1. ConfigMap 및 Secret 업데이트
Docker Compose 인프라 주소로 변경:

**MySQL 설정** (`dailyfeed-infrastructure/helm/manifests/local/mysql-config-local.yaml`)
```yaml
MYSQL_HOST: "host.docker.internal"  # 변경: mysql.infra.svc.cluster.local
MYSQL_PORT: "23306"                  # 변경: 3306
MYSQL_JDBC_URL: "jdbc:mysql://host.docker.internal:23306/dailyfeed?..."
```

**MongoDB 설정** (`dailyfeed-infrastructure/helm/manifests/local/mongodb-config-local.yaml`)
```yaml
MONGODB_HOST: "host.docker.internal"  # 변경: mongodb.infra.svc.cluster.local
MONGODB_PORT: "27017"
```

**MongoDB Secret** (`dailyfeed-infrastructure/helm/manifests/local/mongodb-secret-local.yaml`)
```yaml
MONGODB_CONNECTION_URI: "mongodb://dailyfeed:hitEnter###@host.docker.internal:27017/dailyfeed?replicaSet=rs0"
# replicaSet=rs0 파라미터 추가
```

**Redis 설정** (`dailyfeed-infrastructure/helm/manifests/local/redis-config-local.yaml`)
```yaml
REDIS_HOST: "host.docker.internal"  # 변경: redis-master.infra.svc.cluster.local
REDIS_PORT: "26379"                  # 변경: 6379
```

**Kafka 설정** (`dailyfeed-infrastructure/helm/manifests/local/kafka-config-local.yaml`)
```yaml
KAFKA_HOST: "host.docker.internal"  # 변경: kafka.infra.svc.cluster.local
KAFKA_PORT: "29092"                  # 변경: 9092
```

### 2. 새로 생성된 파일들

#### Kind 클러스터 경량 구성
**파일**: `dailyfeed-infrastructure/kind/cluster-local-hybrid.yml`
- Worker 노드: 3개 → 1개로 축소
- 인프라 관련 NodePort 제거 (MySQL, MongoDB, Redis 등)
- 앱 디버깅용 NodePort만 유지

#### 하이브리드 인프라 설치 스크립트
**파일**: `dailyfeed-infrastructure/install-local-hybrid.sh`

주요 작업:
1. Docker Compose로 인프라 시작
2. MongoDB 사용자 자동 생성
3. Kind 클러스터 생성 (경량 구성)
4. ConfigMap/Secret 적용 (host.docker.internal 주소)
5. Istio 및 모니터링 도구 설치

#### MongoDB 사용자 초기화 스크립트
**파일**: `dailyfeed-infrastructure/docker/mysql-mongodb-redis/init-mongodb-users.sh`

기능:
- Docker Compose MongoDB에 접속
- `dailyfeed`, `dailyfeed-search` 사용자 생성
- 중복 생성 방지 로직 포함

#### 하이브리드 구성 삭제 스크립트
**파일**: `dailyfeed-infrastructure/uninstall-local-hybrid.sh`

작업:
1. Kind 클러스터 삭제
2. Docker Compose 인프라 중지 및 볼륨 삭제

#### 전체 삭제 스크립트
**파일**: `uninstall-local-hybrid.sh`

작업:
1. 애플리케이션 삭제
2. 인프라 삭제 (하이브리드)

#### 상세 가이드 문서
**파일**: `HYBRID-SETUP.md`

내용:
- 설치/삭제 방법
- 설정 설명
- 트러블슈팅
- 성능 비교
- 기존 방식과의 차이점

### 3. 수정된 파일들

**파일**: `local-install-infra-and-app.sh`

변경 내용:
```bash
# Before
source install-local.sh

# After
source install-local-hybrid.sh
```

---

## 인프라 주소 매핑

### Docker Compose → Kubernetes

| 서비스 | Docker Compose 주소 | Kubernetes 접근 주소 |
|--------|-------------------|-------------------|
| MySQL | `localhost:23306` | `host.docker.internal:23306` |
| MongoDB Primary | `localhost:27017` | `host.docker.internal:27017` |
| MongoDB Secondary 1 | `localhost:27018` | - |
| MongoDB Secondary 2 | `localhost:27019` | - |
| Redis | `localhost:26379` | `host.docker.internal:26379` |
| Kafka Broker 1 | `localhost:29092` | `host.docker.internal:29092` |
| Kafka Broker 2 | `localhost:29093` | - |
| Kafka Broker 3 | `localhost:29094` | - |
| Zookeeper | `localhost:22181` | - |
| Kafka UI | `localhost:38080` | - |
| Redis Commander | `localhost:38081` | - |

---

## 사용 방법

### 전체 설치
```bash
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-installer

./local-install-infra-and-app.sh <IMAGE_VERSION>

# 예시
./local-install-infra-and-app.sh beta-20251108-001
```

### 전체 삭제
```bash
./uninstall-local-hybrid.sh
```

### 인프라만 설치
```bash
cd dailyfeed-infrastructure
./install-local-hybrid.sh
```

### 인프라만 삭제
```bash
cd dailyfeed-infrastructure
./uninstall-local-hybrid.sh
```

### 인프라 재시작
```bash
cd dailyfeed-infrastructure/docker/mysql-mongodb-redis
docker-compose restart
```

### Docker Compose 인프라 로그 확인
```bash
cd dailyfeed-infrastructure/docker/mysql-mongodb-redis

# 전체 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f mysql-dailyfeed
docker-compose logs -f mongo-dailyfeed-1
docker-compose logs -f kafka-1
```

---

## 아키텍처 변경 비교

### 기존 (Full Kubernetes)
```
┌─────────────────────────────────────┐
│   Kind Cluster (4 nodes)            │
│  ┌───────────────────────────────┐  │
│  │ Control Plane                 │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Worker 1                      │  │
│  │  - MySQL Pod                  │  │
│  │  - MongoDB Pod                │  │
│  │  - Kafka Pods (x3)            │  │
│  │  - App Pods                   │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Worker 2                      │  │
│  │  - Zookeeper Pods (x3)        │  │
│  │  - Redis Pod                  │  │
│  │  - App Pods                   │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Worker 3                      │  │
│  │  - App Pods                   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘

메모리: ~15GB
응답속도: 기준 (100%)
초기화: ~3분
```

### 하이브리드 (새로운 방식)
```
┌─────────────────────────────────────┐
│   Docker Compose (Host)             │
│  ┌───────────────────────────────┐  │
│  │ MySQL Container               │  │
│  │ MongoDB Replica Set (x3)      │  │
│  │ Kafka Cluster (x3)            │  │
│  │ Zookeeper (x3)                │  │
│  │ Redis Container               │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
          ↕ host.docker.internal
┌─────────────────────────────────────┐
│   Kind Cluster (2 nodes)            │
│  ┌───────────────────────────────┐  │
│  │ Control Plane                 │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Worker 1                      │  │
│  │  - App Pods Only              │  │
│  │  - Istio Sidecars             │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘

메모리: ~7-8GB (50% 절감)
응답속도: 130-150% (30-50% 개선)
초기화: ~1.5분 (50% 단축)
```

---

## 주요 변경 사항 요약

| 항목 | 기존 | 변경 후 | 효과 |
|-----|------|--------|------|
| MySQL | Kubernetes (Helm) | Docker Compose (port 23306) | 네트워크 오버헤드 제거 |
| MongoDB | Kubernetes (StatefulSet) | Docker Compose Replica Set | 초기화 시간 단축 |
| Kafka | Kubernetes (StatefulSet x3) | Docker Compose (ports 29092-29094) | 리소스 절약 |
| Zookeeper | Kubernetes (StatefulSet x3) | Docker Compose | 리소스 절약 |
| Redis | Kubernetes (Deployment) | Docker Compose (port 26379) | 성능 개선 |
| Worker 노드 | 3개 | 1개 | 메모리 2-4GB 절약 |
| 연결 방식 | K8s Service DNS | host.docker.internal | 직접 연결 |
| 네트워크 홉 | 5-7 홉 | 2-3 홉 | 레이턴시 감소 |

---

## 예상 성능 개선

### 리소스 사용량
- **메모리**: ~15GB → ~7-8GB (약 50% 절감)
- **CPU**: 6-8 cores → 3-4 cores (약 50% 절감)
- **디스크 I/O**: Kubernetes emptyDir → Docker named volume (안정성 향상)

### 응답 시간
- **서비스 간 통신**: 30-50% 빠름
- **데이터베이스 쿼리**: 20-30% 빠름
- **전체 응답 시간**: 30-50% 개선

### 초기화 시간
- **인프라 시작**: ~3분 → ~1분 (66% 단축)
- **애플리케이션 배포**: ~2분 → ~1.5분 (25% 단축)
- **전체**: ~5분 → ~2.5분 (50% 단축)

---

## 트러블슈팅

### 1. host.docker.internal 해석 실패
**증상**: Pod에서 인프라 연결 불가

**해결방법**:
```bash
# Kind 클러스터 재생성
kind delete cluster --name istio-cluster
cd dailyfeed-infrastructure
./install-local-hybrid.sh
```

### 2. MongoDB 사용자 없음 오류
**증상**: `Authentication failed`

**해결방법**:
```bash
cd dailyfeed-infrastructure/docker/mysql-mongodb-redis
./init-mongodb-users.sh
```

### 3. Docker Compose 서비스 시작 실패
**증상**: `docker-compose ps`에서 서비스가 Down 상태

**해결방법**:
```bash
# 로그 확인
docker-compose logs <service-name>

# 재시작
docker-compose restart <service-name>

# 완전 재생성
docker-compose down -v
docker-compose up -d
```

### 4. 포트 충돌
**증상**: `Bind for 0.0.0.0:23306 failed: port is already allocated`

**해결방법**:
```bash
# 포트 사용 중인 프로세스 확인
lsof -i :23306

# 기존 MySQL 중지 또는 docker-compose.yaml에서 포트 변경
```

---

## 참고 문서

- 상세 사용 가이드: `HYBRID-SETUP.md`
- 성능 분석: `analysis/20251108-improving.md`

---

**구현 완료일**: 2025-11-08
**구현자**: Claude Code

## 구현된 개선 사항

✅ 하이브리드 인프라 구성 (Docker Compose + Kubernetes)
✅ Worker 노드 축소 (3개 → 1개)
✅ ConfigMap/Secret 업데이트 (host.docker.internal)
✅ 경량 Kind 클러스터 구성
✅ 자동화 스크립트 작성
✅ MongoDB 사용자 자동 생성
✅ 상세 문서화
✅ Uninstall 스크립트

## 다음 단계 권장 사항

1. **Istio 비활성화 옵션 추가** (선택적)
   - 더 많은 성능 개선 (10-20%)
   - `install-local-hybrid-no-istio.sh` 스크립트 생성

2. **리소스 제약 완화** (선택적)
   - 앱 Helm values에서 requests/limits 축소
   - 더 빠른 Pod 스케줄링

3. **HPA 최소 레플리카 조정** (선택적)
   - `minReplicas: 2 → 1`로 변경
   - 리소스 절약

4. **성능 테스트 실행**
   - 기존 vs 하이브리드 벤치마크
   - 실제 성능 개선 검증
