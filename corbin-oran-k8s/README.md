# Corbin O-RAN Kubernetes Deployment

이 디렉토리는 corbin-oran 네임스페이스에 배포되는 모든 O-RAN 컴포넌트들의 Kubernetes 매니페스트를 포함합니다.

## 디렉토리 구조

- `open5gs/`: Open5GS 5G Core Network 매니페스트
- `srsran/`: srsRAN gNB 및 UE 매니페스트  
- `osc-ric/`: OSC Near-RT RIC 컴포넌트 매니페스트
- `e2sim/`: E2 Simulator 매니페스트
- `monitoring/`: 모니터링 도구 (Grafana, InfluxDB 등)
- `networking/`: 네트워크 정책 및 서비스 매니페스트

## 배포 순서

1. Namespace 생성
2. Open5GS (5G Core)
3. OSC RIC 컴포넌트들
4. srsRAN gNB
5. E2 Simulator
6. 모니터링 도구

