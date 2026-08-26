## Non-RT RIC, N-Release

The Non-RT RIC, conceptualized by the O-RAN Alliance's Working Group 2 (WG2) [\[1\]][oran-wg2] and implemented by the O-RAN Software Community [\[2\]][oransc-nonrtric], facilitates strategic long-term planning and policy management in Radio Access Networks (RAN).

This automation tool is based on the N-Release of the Non-RT RIC. More information about these releases can be found at [\[3\]][oransc-releases].

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
istio-system       istio-ingressgateway-df9c58689-2vnnw                1/1     Running
istio-system       istiod-5dc57787d8-xf52d                             1/1     Running
kube-flannel       kube-flannel-ds-s98ck                               1/1     Running
kube-system        coredns-674b8bbfcf-lptsl                            1/1     Running
kube-system        coredns-674b8bbfcf-n4g8r                            1/1     Running
kube-system        etcd-vmware-022                                     1/1     Running
kube-system        kube-apiserver-vmware-022                           1/1     Running
kube-system        kube-controller-manager-vmware-022                  1/1     Running
kube-system        kube-proxy-xrbtc                                    1/1     Running
kube-system        kube-scheduler-vmware-022                           1/1     Running
mariadb-operator   mariadb-operator-56cfcf64b6-rb58j                   1/1     Running
mariadb-operator   mariadb-operator-cert-controller-5c7fdfc6fb-7kpnm   1/1     Running
mariadb-operator   mariadb-operator-webhook-8574cb7f96-crc2d           1/1     Running
nonrtric           a1-sim-osc-0-7756867694-7bqrr                       2/2     Running
nonrtric           a1-sim-osc-1-775ff747-6zk4m                         2/2     Running
nonrtric           a1-sim-std-0-75cd5d48c5-v6wfj                       2/2     Running
nonrtric           a1-sim-std-1-6457947b84-kzd79                       2/2     Running
nonrtric           a1-sim-std2-0-7fd4898bf4-p9wxm                      2/2     Running
nonrtric           a1-sim-std2-1-67f59bfb67-89m5z                      2/2     Running
nonrtric           capifcore-ccbfbff56-wfv59                           2/2     Running
nonrtric           controlpanel-56cf48cb74-jlh72                       2/2     Running
nonrtric           dmaapadapterservice-0                               2/2     Running
nonrtric           dmeparticipant-587677f696-z57hq                     2/2     Running
nonrtric           informationservice-0                                2/2     Running
nonrtric           nonrtricgateway-86d47b667c-sdcnw                    2/2     Running
nonrtric           oran-nonrtric-kong-647bb8bd4c-mxvzs                 3/3     Running
nonrtric           oran-nonrtric-postgresql-0                          2/2     Running
nonrtric           policymanagementservice-0                           2/2     Running
nonrtric           rappmanager-0                                       2/2     Running
nonrtric           servicemanager-6d68c57877-g548l                     2/2     Running
nonrtric           topology-7d86cfb845-zjf5v                           2/2     Running
onap               mariadb-galera-0                                    1/1     Running
onap               onap-cps-core-5fc5cfbb9b-27rrf                      1/1     Running
onap               onap-cps-temporal-7779b4fb98-nfkj5                  1/1     Running
onap               onap-cps-temporal-db-0                              1/1     Running
onap               onap-dcae-ves-collector-5d7b77bf95-mrpnc            1/1     Running
onap               onap-ncmp-dmi-plugin-78495dfc46-bsd7p               1/1     Running
onap               onap-policy-apex-pdp-74d54f7dc7-nrcf5               1/1     Running
onap               onap-policy-api-78fd547944-6blx6                    1/1     Running
onap               onap-policy-clamp-ac-a1pms-ppnt-7d9d7d99bd-6p5d8    1/1     Running
onap               onap-policy-clamp-ac-http-ppnt-5bcdd5fb5c-zx46j     1/1     Running
onap               onap-policy-clamp-ac-k8s-ppnt-8475f875cd-h7g94      1/1     Running
onap               onap-policy-clamp-ac-kserve-ppnt-bcd797748-dj6nn    1/1     Running
onap               onap-policy-clamp-ac-pf-ppnt-9f7bc55b8-l96qh        1/1     Running
onap               onap-policy-clamp-runtime-acm-65d4c8dc69-jft55      1/1     Running
onap               onap-policy-pap-559556bdd8-bjnnc                    1/1     Running
onap               onap-policy-postgres-primary-5fcc987884-sb8dp       1/1     Running
onap               onap-policy-postgres-replica-55566db74b-zqpnv       1/1     Running
onap               onap-postgres-primary-757f57c74-pj4m4               1/1     Running
onap               onap-postgres-replica-66b479ddc6-ch78g              1/1     Running
onap               onap-sdnc-0                                         1/1     Running
onap               onap-sdnc-ansible-server-5cf4f5c899-m47bx           1/1     Running
onap               onap-sdnc-web-7777b9f486-gcdb5                      1/1     Running
onap               onap-strimzi-entity-operator-7bf97748b6-dmcnm       2/2     Running
onap               onap-strimzi-onap-strimzi-broker-0                  1/1     Running
onap               onap-strimzi-onap-strimzi-controller-1              1/1     Running
openebs            openebs-localpv-provisioner-569b6d7f77-5gsfp        1/1     Running
smo                bundle-server-54cbbbc9d7-8t6vh                      1/1     Running
smo                dfc-0                                               2/2     Running
smo                focom-to-teiv-adapter-6ffc7446c8-q9h9k              1/1     Running
smo                influxdb2-0                                         1/1     Running
smo                kafka-client                                        1/1     Running
smo                kafka-producer-pm-json2influx-0                     1/1     Running
smo                kafka-producer-pm-json2kafka-0                      1/1     Running
smo                kafka-producer-pm-xml2json-0                        1/1     Running
smo                keycloak-649dd6dd8b-9gt4j                           1/1     Running
smo                keycloak-proxy-6b76854c98-h754j                     1/1     Running
smo                minio-0                                             1/1     Running
smo                minio-client                                        1/1     Running
smo                ncmp-to-teiv-adapter-8568c94dc6-cfmq8               1/1     Running
smo                opa-76849b588f-gcpp2                                1/1     Running
smo                oran-smo-postgresql-0                               1/1     Running
smo                pm-producer-json2kafka-0                            2/2     Running
smo                pmlog-0                                             2/2     Running
smo                redpanda-console-5f867cf878-4md6p                   1/1     Running
smo                topology-exposure-5c6d86795-zhjkn                   1/1     Running
smo                topology-ingestion-69bbddd8c7-tfl48                 1/1     Running
strimzi-system     strimzi-cluster-operator-76dbc4446b-lr8fn           1/1     Running
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
