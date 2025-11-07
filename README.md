# DailyFeed Installer

DailyFeed 애플리케이션을 Kubernetes(kind) 클러스터에 설치하는 스크립트 모음입니다.
<br/>

## 이미지 버전
사용가능한 이미지 버전은 다음과 같습니다.
- main : 가장 최근의 안정적인 버전
- cbt-{yyyyMMdd}-{번호} : 테스트 용도의 버전

<br/>


## 설치 방법

### 기본 설치

```bash
# 인프라 + 애플리케이션 모두 설치
./local-install-infra-and-app.sh <version>

# 예시
./local-install-infra-and-app.sh cbt-20251028-1
```

### 인프라만 설치

```bash
cd dailyfeed-infrastructure
source install-local.sh
```

### 애플리케이션만 설치

```bash
cd dailyfeed-app-helm
source install-local.sh <version>

# 예시
source install-local.sh test-20251025-1
```

## 구성 요소

### Infrastructure (dailyfeed-infrastructure)
- kind 클러스터 생성
- Istio 서비스 메시
- Kafka, Redis, MySQL, MongoDB
- Metrics Server
- Ingress Controller

### Application (dailyfeed-app-helm)
- Backend 서비스들 (member, image, timeline, content, activity, search)
- Frontend
- HPA 설정
- Istio 라우팅 설정

## 트러블슈팅

### Docker Hub Rate Limit 오류

이미지 pull 시 다음과 같은 오류가 발생하는 경우:

```
429 Too Many Requests
toomanyrequests: You have reached your unauthenticated pull rate limit.
```

**원인**: Docker Hub의 이미지 pull 횟수 제한 (익명: 100회/6시간, 무료 계정: 200회/6시간)

**해결 방법**:

1. 이미지를 로컬에서 미리 로드:

```bash
# 이미지를 Docker로 pull한 후 kind 클러스터로 로드
cd dailyfeed-infrastructure
./load-images-to-kind.sh
cd ..
```

2. 그 후 설치 진행:

```bash
./local-install-infra-and-app.sh <version>
```

**참고**:
- Docker Hub Pro/Business 계정 사용자는 이 문제가 발생하지 않을 가능성이 높습니다
- 대부분의 사용자는 `load-images-to-kind.sh` 없이 정상 설치 가능합니다
- Rate Limit은 6시간마다 리셋됩니다

### Pod가 ImagePullBackOff 상태인 경우

```bash
# Pod 상태 확인
kubectl get pods -n infra
kubectl describe pod <pod-name> -n infra

# Rate Limit 오류라면 위의 해결 방법 참고
```

### 클러스터 재생성

```bash
# 기존 클러스터 삭제
kind delete cluster --name istio-cluster

# 새로 생성
cd dailyfeed-infrastructure/kind
./create-cluster.sh
```

## 요구사항

- Docker Desktop
- kubectl
- Helm 3
- kind
- 최소 8GB RAM

## 포트 매핑

- `80`: Nginx Ingress (API 접속)
- `3306`: MySQL
- `6379`: Redis
- `27017`: MongoDB
- `8888-8893`: 각 마이크로서비스 개발/디버그용 NodePort
- `9092`: Kafka
- `30080`: 애플리케이션
- `31000`: Kiali
- `31001`: Jaeger UI
- `31002`: Prometheus
- `31380`: Istio Ingress Gateway

## 디렉토리 구조

```
dailyfeed-installer/
├── README.md                           # 이 파일
├── local-install-infra-and-app.sh      # 전체 설치 스크립트
├── dailyfeed-infrastructure/           # 인프라 설치
│   ├── install-local.sh
│   ├── load-images-to-kind.sh          # Rate Limit 회피용 이미지 로더
│   ├── kind/                           # kind 클러스터 설정
│   ├── istio/                          # Istio 설치
│   └── helm/                           # Kafka, Redis, MySQL 등
└── dailyfeed-app-helm/                 # 애플리케이션 Helm charts
    ├── install-local.sh
    ├── base-chart/
    ├── member/
    ├── image/
    ├── timeline/
    ├── content/
    ├── activity/
    ├── search/
    └── frontend/
```
