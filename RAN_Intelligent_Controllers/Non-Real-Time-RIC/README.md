## Non-RT RIC, L-Release

The Non-RT RIC, conceptualized by the O-RAN Alliance's Working Group 2 (WG2) [\[1\]][oran-wg2] and implemented by the O-RAN Software Community [\[2\]][oransc-nonrtric], facilitates strategic long-term planning and policy management in Radio Access Networks (RAN).

This automation tool is based on the L-Release of the Non-RT RIC. More information about these releases can be found at [\[3\]][oransc-releases].

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
NAMESPACE      NAME                                            READY   STATUS
istio-system   istio-ingressgateway-75bddb84ff-fczl2           1/1     Running
istio-system   istiod-f59bfc4b4-25dfc                          1/1     Running
kube-flannel   kube-flannel-ds-fx6cm                           1/1     Running
kube-system    coredns-668d6bf9bc-kzs28                        1/1     Running
kube-system    coredns-668d6bf9bc-mpb9x                        1/1     Running
kube-system    etcd-vmware-022                                 1/1     Running
kube-system    kube-apiserver-vmware-022                       1/1     Running
kube-system    kube-controller-manager-vmware-022              1/1     Running
kube-system    kube-proxy-l6ncs                                1/1     Running
kube-system    kube-scheduler-vmware-022                       1/1     Running
nonrtric       a1-sim-osc-0                                    1/1     Running
nonrtric       a1-sim-osc-1                                    1/1     Running
nonrtric       a1-sim-std-0                                    1/1     Running
nonrtric       a1-sim-std-1                                    1/1     Running
nonrtric       a1-sim-std2-0                                   1/1     Running
nonrtric       a1-sim-std2-1                                   1/1     Running
nonrtric       a1controller-59675f9b55-fnjqp                   1/1     Running
nonrtric       capifcore-58b5887dc9-56n74                      1/1     Running
nonrtric       controlpanel-9d574cb44-dkrq6                    1/1     Running
nonrtric       db-85c8fdc968-bftwp                             1/1     Running
nonrtric       dmaapadapterservice-0                           1/1     Running
nonrtric       dmaapmediatorservice-0                          1/1     Running
nonrtric       helmmanager-0                                   1/1     Running
nonrtric       informationservice-0                            1/1     Running
nonrtric       nonrtricgateway-55476db4c5-g5ppr                1/1     Running
nonrtric       oran-nonrtric-kong-86c9cb9f99-wvbhv             2/2     Running
nonrtric       oran-nonrtric-postgresql-0                      1/1     Running
nonrtric       orufhrecovery-55697f9666-h6lwn                  1/1     Running
nonrtric       policymanagementservice-0                       1/1     Running
nonrtric       ransliceassurance-7bfc6676fd-fk9qj              1/1     Running
nonrtric       rappcatalogueenhancedservice-7795848b6c-v45fb   1/1     Running
nonrtric       rappcatalogueservice-5cdb59b486-2hzb5           1/1     Running
nonrtric       rappmanager-0                                   1/1     Running
nonrtric       servicemanager-795d499bd-msl8n                  1/1     Running
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
