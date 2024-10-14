#!/bin/bash

kubectl get svc --all-namespaces -o=custom-columns='NAME:.metadata.name,CLUSTER_IP:.spec.clusterIP,PORTS:.spec.ports[*].port'