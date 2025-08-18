#!/bin/bash

# 모든 kubectl 명령어에 사용할 네임스페이스 설정
export KUBE_NAMESPACE="corbin-oran"

echo "네임스페이스 준비 중: $KUBE_NAMESPACE"

# 원본 파일 백업
find RAN_Intelligent_Controllers/ -name "*.sh" -type f -exec cp {} {}.backup \; 2>/dev/null || echo "일부 백업 파일을 생성할 수 없습니다"

# 스크립트들이 당신의 네임스페이스를 사용하도록 수정
find RAN_Intelligent_Controllers/ -name "*.sh" -type f -exec sed -i "s/-n ricplt/-n $KUBE_NAMESPACE/g" {} \;
find RAN_Intelligent_Controllers/ -name "*.sh" -type f -exec sed -i "s/--namespace ricplt/--namespace $KUBE_NAMESPACE/g" {} \;
find RAN_Intelligent_Controllers/ -name "*.sh" -type f -exec sed -i "s/--namespace=ricplt/--namespace=$KUBE_NAMESPACE/g" {} \;

echo "스크립트가 다음 네임스페이스를 사용하도록 수정됨: $KUBE_NAMESPACE"
echo "원본 파일들은 .backup 확장자로 백업됨"
