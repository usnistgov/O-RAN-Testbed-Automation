## Near Real-Time RAN Intelligent Controller (Near-RT RIC)

**Purpose**: Enable dynamic management and optimization of Radio Access Networks (RAN).

**Design**: Conceptualized by the O-RAN Alliance's Working Group 3 (WG3) [[1]][oran-wg3].

**Implementation**: Implemented by the O-RAN Software Community Near-RT RIC Group [[2]][oransc-nearrtric] and the Linux Foundation.

**Functionality**: Hosts xApps that provide real-time analytics and decision-making capabilities for RAN operations, functioning in a closed-loop with actions executed within a time frame of 10 ms to 1 second.

## Non-Real-Time RAN Intelligent Controller (Non-RT RIC)

**Purpose**: Facilitate strategic RAN planning and policy management.

**Design**: Conceptualized by the O-RAN Alliance's Working Group 2 (WG2) [[3]][oran-wg2].

**Implementation**: Implemented by the O-RAN Software Community Non-RT RIC Group [[4]][oransc-nonrtric] and the Linux Foundation.

**Functionality**: Hosts rApps that support RAN policy enforcement and long-term network management and optimization, functioning in a closed-loop with actions executed within a time frame of 1 second to 10 seconds.

## References
1. Working Group 3: Near-Real-time RAN Intelligent Controller and E2 Interface Workgroup. O-RAN Alliance. [https://public.o-ran.org/display/WG3/Introduction][oran-wg3]
2. Near Realtime RAN Intelligent Controller. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/projects.html#near-realtime-ran-intelligent-controller-ric][oransc-nearrtric]
3. Working Group 2: Non-Real-time RAN Intelligent Controller and A1. O-RAN Alliance. [https://public.o-ran.org/display/WG2/Introduction][oran-wg2]
4. Non-RealTime RAN Intelligent Controller. O-RAN Software Community. [https://docs.o-ran-sc.org/en/latest/projects.html#non-realtime-ran-intelligent-controller-nonrtric][oransc-nonrtric]

<!-- References -->

[oran-wg3]: https://public.o-ran.org/display/WG3/Introduction
[oransc-nearrtric]: https://docs.o-ran-sc.org/en/latest/projects.html#near-realtime-ran-intelligent-controller-ric
[oran-wg2]: https://public.o-ran.org/display/WG2/Introduction
[oransc-nonrtric]: https://docs.o-ran-sc.org/en/latest/projects.html#non-realtime-ran-intelligent-controller-nonrtric
