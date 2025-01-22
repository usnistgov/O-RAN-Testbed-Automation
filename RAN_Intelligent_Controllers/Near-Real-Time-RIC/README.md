## Near-RT RIC, J-Release

The Near-RT RIC, conceptualized by the O-RAN Alliance's Working Group 3 (WG3) [[1]][oran-wg3] and implemented by the O-RAN Software Community [[2]][oransc-nearrtric], enables dynamic management and optimization of Radio Access Networks (RAN).

This automation tool is based on the J-Release of the Near-RT RIC. More information about these releases can be found at [[3]][oransc-releases].

## Usage

- **Installation Process**: Use `./full_install.sh` to get the Near-RT RIC running on the host machine. The installation process consists of the following steps.
  - Installs Docker, Kubernetes, and Helm if not previously installed.
  - Uses Helm to install the RIC components.
  - Builds, installs, and configures the E2 Simulator (e2sim).
  - Connects the e2term pod to e2sim within the Near-RT RIC.
  - Installs and Configures the xApp manager (appmgr) to deploy a Hello World (hw-go) xApp.

- **Start the Near-RT RIC**: While the Kubernetes pods start automatically on system boot, the entire process of ensuring that the components are running, connected, and that the xApp is deployed can be re-executed with `./run.sh`.
- **Status**: Check on a pod's status with `kubectl get pods -A`, or by running the interactive pod manager (K9s) with `k9s -A` or `./start_k9s.sh`.
- **Logs**: From within K9s, use the `Arrow Keys` to highlight a pod, `Enter` to view the logs for the pod, `w` to wrap text, `Esc` to go back, `Ctrl+k` to restart a pod that isn't responding, and `s` to open a command line shell in the pod.

## References

1. Working Group 3: Near-Real-time RAN Intelligent Controller and E2 Interface Workgroup. O-RAN Alliance. [https://public.o-ran.org/display/WG3/Introduction][oran-wg3]
2. Near Realtime RAN Intelligent Controller. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/projects.html#near-realtime-ran-intelligent-controller-ric][oransc-nearrtric]
3. Release Notes. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/release-notes.html][oransc-releases]

<!-- References -->

[oran-wg3]: https://public.o-ran.org/display/WG3/Introduction
[oransc-nearrtric]: https://docs.o-ran-sc.org/en/latest/projects.html#near-realtime-ran-intelligent-controller-ric
[oransc-releases]: https://docs.o-ran-sc.org/en/latest/release-notes.html
