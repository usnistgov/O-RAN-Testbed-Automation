## Non-RT RIC, M-Release

The Non-RT RIC, conceptualized by the O-RAN Alliance's Working Group 2 (WG2) [\[1\]][oran-wg2] and implemented by the O-RAN Software Community [\[2\]][oransc-nonrtric], facilitates strategic long-term planning and policy management in Radio Access Networks (RAN).

This automation tool is based on the M-Release of the Non-RT RIC. More information about these releases can be found at [\[3\]][oransc-releases].

## Usage

- **Installation Process**: Use `./full_install.sh` to get the Non-RT RIC running on the host machine. The installation process consists of the following steps.
  - Installs Docker, Kubernetes, and Helm if not previously installed.
  - Uses Helm to install the Non-RT RIC components.
  - Waits for the pods to be ready.
  - Builds and runs the control panel.
  - Opens the browser to the control panel's web interface.

- **Control Panel Access**: Access the control panel at `http://localhost:4200` in a web browser. Start with `./run_control_panel.sh`, stop with `./stop_control_panel.sh`, and check status with `./control_panel_is_running.sh`. Optionally, the mock control panel can be ran by instead running `./run_control_panel.sh mock`.
- **Start the Non-RT RIC**: The Kubernetes pods start automatically on system boot, however, to ensure that all the components are running and properly configured, use `./run.sh`.
- **Status**: Check on the pod statuses of the Non-RT RIC components with `kubectl get pods -A`, or by running the interactive pod manager (K9s) with `k9s -A` or `./start_k9s.sh`.
- **Logs**: From within K9s, use the `Arrow Keys` to highlight a pod, `Enter` to view the logs for the pod, `w` to wrap text, `Esc` to go back, `Ctrl+k` to restart a pod that isn't responding, and `s` to open a command line shell in the pod. The control panel output is displayed in the terminal and in `logs/controlpanel_stdout.txt`.
- **Uninstall**: Remove the Non-RT RIC with `./full_uninstall.sh`.


<details>
  <summary><b>View the list of Kubernetes pods running after the Non-RT RIC is installed.</b></summary>
  <hr>
  
```console
$ kubectl get pods -A
NAMESPACE          NAME                                                READY   STATUS
istio-system       istio-ingressgateway-7547ddb497-hlqzt               1/1     Running
istio-system       istiod-694d545dfd-znq6k                             1/1     Running
kube-flannel       kube-flannel-ds-tpgdf                               1/1     Running
kube-system        coredns-674b8bbfcf-66rsw                            1/1     Running
kube-system        coredns-674b8bbfcf-b98k9                            1/1     Running
kube-system        etcd-vmware-022                                     1/1     Running
kube-system        kube-apiserver-vmware-022                           1/1     Running
kube-system        kube-controller-manager-vmware-022                  1/1     Running
kube-system        kube-proxy-5r2q4                                    1/1     Running
kube-system        kube-scheduler-vmware-022                           1/1     Running
mariadb-operator   mariadb-operator-6474c5796b-t7nrq                   1/1     Running
mariadb-operator   mariadb-operator-cert-controller-5c877544dd-hgjrl   1/1     Running
mariadb-operator   mariadb-operator-webhook-85f4744d6d-vk276           1/1     Running
nonrtric           a1-sim-osc-0-7756867694-kbxq2                       2/2     Running
nonrtric           a1-sim-osc-1-775ff747-qp5wn                         2/2     Running
nonrtric           a1-sim-std-0-75cd5d48c5-wwt6w                       2/2     Running
nonrtric           a1-sim-std-1-6457947b84-djlws                       2/2     Running
nonrtric           a1-sim-std2-0-7fd4898bf4-9vbgd                      2/2     Running
nonrtric           a1-sim-std2-1-67f59bfb67-x9llc                      2/2     Running
nonrtric           capifcore-ccbfbff56-htrzg                           2/2     Running
nonrtric           controlpanel-56cf48cb74-lkpwk                       2/2     Running
nonrtric           dmaapadapterservice-0                               2/2     Running
nonrtric           dmeparticipant-587677f696-qmlkl                     2/2     Running
nonrtric           informationservice-0                                2/2     Running
nonrtric           nonrtricgateway-86d47b667c-znqtd                    2/2     Running
nonrtric           oran-nonrtric-kong-647bb8bd4c-l2gn9                 3/3     Running
nonrtric           oran-nonrtric-postgresql-0                          2/2     Running
nonrtric           policymanagementservice-0                           2/2     Running
nonrtric           rappmanager-0                                       2/2     Running
nonrtric           servicemanager-6d68c57877-2hh2b                     2/2     Running
nonrtric           topology-7d86cfb845-8lr4f                           2/2     Running
onap               mariadb-galera-0                                    1/1     Running
onap               onap-cps-core-67f977b774-wtplk                      1/1     Running
onap               onap-cps-temporal-64d88ffcc4-mwb6m                  1/1     Running
onap               onap-cps-temporal-db-0                              1/1     Running
onap               onap-dcae-ves-collector-5d7b77bf95-srqfh            1/1     Running
onap               onap-ncmp-dmi-plugin-664784d768-wmsql               1/1     Running
onap               onap-policy-apex-pdp-75498445cb-f6xhj               1/1     Running
onap               onap-policy-api-6d9d46f84b-7t9nb                    1/1     Running
onap               onap-policy-clamp-ac-a1pms-ppnt-664757fb94-lktbl    1/1     Running
onap               onap-policy-clamp-ac-http-ppnt-f65c6fc7c-rbw9v      1/1     Running
onap               onap-policy-clamp-ac-k8s-ppnt-78fb99b7db-bkn44      1/1     Running
onap               onap-policy-clamp-ac-kserve-ppnt-96bd46764-9kvf2    1/1     Running
onap               onap-policy-clamp-ac-pf-ppnt-d69dcc66d-ksqjv        1/1     Running
onap               onap-policy-clamp-runtime-acm-6b79d6cd59-cjm2d      1/1     Running
onap               onap-policy-pap-67fcd9874d-hgztd                    1/1     Running
onap               onap-policy-postgres-primary-5fcc987884-s2bct       1/1     Running
onap               onap-policy-postgres-replica-55566db74b-xg2cw       1/1     Running
onap               onap-postgres-primary-757f57c74-ncfkv               1/1     Running
onap               onap-postgres-replica-66b479ddc6-mnr2f              1/1     Running
onap               onap-sdnc-0                                         1/1     Running
onap               onap-sdnc-ansible-server-6f6cbf88fd-4nql5           1/1     Running
onap               onap-sdnc-web-5f896b94f-h8cxq                       1/1     Running
onap               onap-strimzi-entity-operator-5d8bbb9c9f-r5pr7       2/2     Running
onap               onap-strimzi-onap-strimzi-broker-0                  1/1     Running
onap               onap-strimzi-onap-strimzi-controller-1              1/1     Running
openebs            openebs-localpv-provisioner-569b6d7f77-dp5sr        1/1     Running
smo                bundle-server-54cbbbc9d7-9rm9j                      1/1     Running
smo                dfc-0                                               2/2     Running
smo                focom-to-teiv-adapter-6ffc7446c8-9qz5t              1/1     Running
smo                influxdb2-0                                         1/1     Running
smo                kafka-client                                        1/1     Running
smo                kafka-producer-pm-json2influx-0                     1/1     Running
smo                kafka-producer-pm-json2kafka-0                      1/1     Running
smo                kafka-producer-pm-xml2json-0                        1/1     Running
smo                keycloak-649dd6dd8b-sjsmv                           1/1     Running
smo                keycloak-proxy-6b76854c98-lhvls                     1/1     Running
smo                minio-0                                             1/1     Running
smo                minio-client                                        1/1     Running
smo                ncmp-to-teiv-adapter-8568c94dc6-2994j               1/1     Running
smo                opa-76849b588f-8tppf                                1/1     Running
smo                oran-smo-postgresql-0                               1/1     Running
smo                pm-producer-json2kafka-0                            2/2     Running
smo                pmlog-0                                             2/2     Running
smo                redpanda-console-5f867cf878-7tbsq                   1/1     Running
smo                topology-exposure-5c6d86795-hzmjp                   1/1     Running
smo                topology-ingestion-69bbddd8c7-kp7wq                 1/1     Running
strimzi-system     strimzi-cluster-operator-76dbc4446b-bkhdb           1/1     Running
```
  </pre>
</details>

## Migration to Cilium

For instructions on migrating the cluster to Cilium, since the scripts behave the same, please see the Near-RT RIC [README.md](../Near-Real-Time-RIC/README.md#migration-to-cilium) document.

---

## References

1. Working Group 2: Non-Real-time RAN Intelligent Controller and A1 Interface Workgroup. O-RAN Alliance. [https://public.o-ran.org/display/WG2/Introduction][oran-wg2]
2. Non Realtime RAN Intelligent Controller. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/projects.html#non-realtime-ran-intelligent-controller-nonrtric][oransc-nonrtric]
3. Release Notes. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/release-notes.html][oransc-releases]

<!-- References -->

[oran-wg2]: https://public.o-ran.org/display/WG2/Introduction
[oransc-nonrtric]: https://docs.o-ran-sc.org/en/latest/projects.html#non-realtime-ran-intelligent-controller-nonrtric
[oransc-releases]: https://docs.o-ran-sc.org/en/latest/release-notes.html
