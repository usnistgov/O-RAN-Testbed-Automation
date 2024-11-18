## Non-RT RIC, J-Release

The Non-RT RIC, conceptualized by the O-RAN Alliance's Working Group 2 (WG2) [[1]][oran-wg2] and implemented by the O-RAN Software Community [[2]][oransc-nonrtric], facilitates strategic long-term planning and policy management in Radio Access Networks (RAN).

This automation tool is based on the J-Release of the Non-RT RIC. More information about these releases can be found at [[3]][oransc-releases].

## Usage

- **Installation Process**: Use `./full_install.sh` to get the Non-RT RIC running on the host machine. The installation process consists of the following steps.
  - Installs Docker, Kubernetes, and Helm if not previously installed.
  - Uses Helm to install the Non-RT RIC components.
  - Waits for the pods to be ready.
  - Builds and runs the control panel.
  - Opens the browser to the control panel's web interface.
- **Control Panel Access**: Access the control panel at `http://localhost:4200` in a web browser. Start with `./run_control_panel.sh`, stop with `./stop_control_panel.sh`, and check status with `./control_panel_is_running.sh`. To serve as a proof-of-concept, the control panel starts in mock mode, but can be switched to real mode by setting MOCK_MODE=false in the run_control_panel.sh script.
- **Status**: Check on the pod statuses of the Non-RT RIC components with `kubectl get pods -A`, or by running the interactive pod manager (K9s) with `k9s -A` or `./start_k9s.sh`.
- **Logs**: From within K9s, use the `Arrow Keys` to highlight a pod, `Enter` to view the logs for the pod, `w` to wrap text, `Esc` to go back, `Ctrl+k` to restart a pod that isn't responding, and `s` to open a command line shell in the pod. The control panel output is displayed in the terminal and in `logs/controlpanel_stdout.txt`.

## References

1. Working Group 2: Non-Real-time RAN Intelligent Controller and A1 Interface Workgroup. O-RAN Alliance. [https://public.o-ran.org/display/WG2/Introduction][oran-wg2]
2. Non Realtime RAN Intelligent Controller. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/projects.html#non-realtime-ran-intelligent-controller-nonrtric][oransc-nonrtric]
3. Release Notes. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/release-notes.html][oransc-releases]

<!-- References -->

[oran-wg2]: https://public.o-ran.org/display/WG2/Introduction
[oransc-nonrtric]: https://docs.o-ran-sc.org/en/latest/projects.html#non-realtime-ran-intelligent-controller-nonrtric
[oransc-releases]: https://docs.o-ran-sc.org/en/latest/release-notes.html
