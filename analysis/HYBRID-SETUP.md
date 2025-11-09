# 하이브리드 인프라 구성 가이드

## 개요

이 구성은 인프라는 Docker Compose로, 애플리케이션은 Kubernetes(Kind)로 실행하는 하이브리드 방식입니다.

### 장점
- **성능 향상**: 인프라가 Docker Compose로 직접 실행되어 네트워크 오버헤드 감소 (30-50% 응답속도 개선)
- **리소스 절약**: Kubernetes 클러스터가 앱만 실행하므로 메모리 5-8GB 절약
- **빠른 시작**: 인프라 초기화 시간 단축
- **디버깅 용이**: Docker Compose로 인프라 로그 확인 및 관리 간편

### 구성

**인프라 (Docker Compose)**
- MySQL: `localhost:23306`
- MongoDB Replica Set: `localhost:27017` (Primary)
- Redis: `localhost:26379`
- Kafka 3 brokers: `localhost:29092`, `localhost:29093`, `localhost:29094`
- Zookeeper 3 nodes

**애플리케이션 (Kubernetes - Kind)**
- Control Plane: 1 node
- Worker: 1 node (기존 3개에서 축소)
- Namespace: `dailyfeed`
- Istio Service Mesh
- Monitoring: Kiali, Jaeger, Prometheus, Grafana

## 설치 방법

### 1. 전체 설치 (권장)

```bash
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-installer

# 인프라 + 앱 전체 설치
./local-install-infra-and-app.sh <IMAGE_VERSION>

# 예시
./local-install-infra-and-app.sh beta-20251108-001
```

### 2. 단계별 설치

#### Step 1: 인프라만 설치
```bash
cd dailyfeed-infrastructure
./install-local-hybrid.sh
```

이 스크립트는 다음을 수행합니다:
1. Docker Compose로 인프라 시작
2. MongoDB 사용자 초기화
3. Kind 클러스터 생성 (경량 구성)
4. Kubernetes 리소스 설정 (ConfigMap, Secret)
5. Istio 및 모니터링 도구 설치

#### Step 2: 애플리케이션 배포
```bash
cd ../dailyfeed-app-helm
./install-local.sh <IMAGE_VERSION>
```

## 설치 확인

### 인프라 상태 확인
```bash
# Docker Compose 서비스 확인
cd dailyfeed-infrastructure/docker/local-hybrid
docker-compose ps

# 예상 출력: 모든 서비스가 Up 상태
# - mysql-dailyfeed
# - mongo-dailyfeed-1, mongo-dailyfeed-2, mongo-dailyfeed-3
# - kafka-1, kafka-2, kafka-3
# - zookeeper-dailyfeed
# - redis-dailyfeed
```

### Kubernetes 상태 확인
```bash
# Kind 클러스터 확인
kind get clusters
# 출력: istio-cluster

# Pod 상태 확인
kubectl get pods -n dailyfeed

# 서비스 확인
kubectl get svc -n dailyfeed
```

### 애플리케이션 접속 테스트
```bash
# Member Service (NodePort 8888)
curl http://localhost:8888/actuator/health

# Content Service (NodePort 8891)
curl http://localhost:8891/actuator/health

# Timeline Service (NodePort 8890)
curl http://localhost:8890/actuator/health
```

## 인프라 연결 설정

애플리케이션은 `host.docker.internal`을 통해 Docker Compose 인프라에 접근합니다.

### ConfigMap 설정 (`dailyfeed-infrastructure/helm/manifests/local/`)

**MySQL** (`mysql-config-local.yaml`)
```yaml
MYSQL_HOST: "host.docker.internal"
MYSQL_PORT: "23306"
MYSQL_JDBC_URL: "jdbc:mysql://host.docker.internal:23306/dailyfeed?..."
```

**MongoDB** (`mongodb-config-local.yaml`)
```yaml
MONGODB_HOST: "host.docker.internal"
MONGODB_PORT: "27017"
MONGODB_CONNECTION_URI: "mongodb://dailyfeed:hitEnter###@host.docker.internal:27017/dailyfeed?replicaSet=rs0"
```

**Redis** (`redis-config-local.yaml`)
```yaml
REDIS_HOST: "host.docker.internal"
REDIS_PORT: "26379"
```

**Kafka** (`kafka-config-local.yaml`)
```yaml
KAFKA_HOST: "host.docker.internal"
KAFKA_PORT: "29092"
```

## 삭제 방법

### 전체 삭제
```bash
cd /Users/alpha300uk/workspace/alpha300uk/0.toy-project/dailyfeed/project/dailyfeed-installer
./uninstall-local-hybrid.sh
```

### 단계별 삭제

#### 1. 애플리케이션만 삭제
```bash
cd dailyfeed-app-helm
./uninstall-local.sh
```

#### 2. 인프라만 삭제
```bash
cd ../dailyfeed-infrastructure
./uninstall-local-hybrid.sh
```

이 스크립트는:
1. Kind 클러스터 삭제
2. Docker Compose 인프라 중지 및 볼륨 삭제

## 트러블슈팅

### 1. MongoDB 연결 오류
```bash
# MongoDB 사용자 재생성
cd dailyfeed-infrastructure/docker/local-hybrid
./init-mongodb-users.sh
```

### 2. Docker Compose 서비스가 시작되지 않음
```bash
# 로그 확인
cd dailyfeed-infrastructure/docker/local-hybrid
docker-compose logs -f <service-name>

# 예: MongoDB 로그
docker-compose logs -f mongo-dailyfeed-1
```

### 3. Kubernetes Pod에서 인프라 연결 실패
```bash
# Pod에서 네트워크 테스트
kubectl exec -it <pod-name> -n dailyfeed -- curl -v telnet://host.docker.internal:23306

# DNS 확인
kubectl exec -it <pod-name> -n dailyfeed -- nslookup host.docker.internal
```

### 4. host.docker.internal 해석 실패
Kind 클러스터 설정에서 `extraPortMappings`를 통해 호스트와 연결됩니다.
```yaml
# cluster-local-hybrid.yml에 정의됨
extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
```

### 5. 메모리 부족
```bash
# Docker Desktop 메모리 증설 필요 (최소 8GB 권장)
# Settings > Resources > Memory

# 현재 Docker 리소스 확인
docker info | grep Memory
```

## 성능 비교

| 구성 | 메모리 사용량 | 응답 속도 | 초기화 시간 |
|-----|------------|---------|----------|
| 기존 (Full K8s) | ~15GB | 100% | ~3분 |
| 하이브리드 | ~7-8GB | 130-150% | ~1.5분 |
| 개선율 | 50% 절감 | 30-50% 개선 | 50% 단축 |

## 주요 파일 위치

### 인프라 설정
- Docker Compose: `dailyfeed-infrastructure/docker/local-hybrid/docker-compose.yaml`
- Kind 클러스터 구성: `dailyfeed-infrastructure/kind/cluster-local-hybrid.yml`
- 하이브리드 설치: `dailyfeed-infrastructure/install-local-hybrid.sh`
- MongoDB 초기화: `dailyfeed-infrastructure/docker/local-hybrid/init-mongodb-users.sh`

### Kubernetes 리소스
- ConfigMaps: `dailyfeed-infrastructure/helm/manifests/local/*-config-local.yaml`
- Secrets: `dailyfeed-infrastructure/helm/manifests/local/*-secret-local.yaml`

### 전체 설치/삭제
- 설치: `local-install-infra-and-app.sh`
- 삭제: `uninstall-local-hybrid.sh`

## 기존 방식과의 차이점

### 기존 (Full Kubernetes)
```
인프라도 Kubernetes에 배포
├── MySQL (Helm)
├── MongoDB (StatefulSet)
├── Kafka (StatefulSet 3 replicas)
├── Zookeeper (StatefulSet 3 replicas)
├── Redis (Deployment)
└── 앱 (Deployment)

클러스터: Control-plane + 3 workers
```

### 하이브리드 (새로운 방식)
```
인프라는 Docker Compose
├── MySQL (Docker)
├── MongoDB Replica Set (Docker)
├── Kafka Cluster (Docker)
├── Zookeeper (Docker)
└── Redis (Docker)

앱만 Kubernetes
└── 앱 (Deployment)

클러스터: Control-plane + 1 worker
```

## 참고사항

1. **개발 환경 전용**: 이 구성은 로컬 개발 환경에 최적화되어 있습니다.
2. **프로덕션 미사용**: 프로덕션 환경에서는 기존 Full Kubernetes 방식을 사용하세요.
3. **데이터 영속성**: Docker Compose 볼륨은 named volume 사용, `docker-compose down -v` 시 데이터 삭제됨
4. **포트 충돌 주의**: 로컬에 이미 MySQL, MongoDB 등이 실행 중이면 포트 충돌 발생 가능

---

**작성일**: 2025-11-08
**버전**: 1.0
