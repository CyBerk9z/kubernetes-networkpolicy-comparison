# NetworkPolicy comparison: full baseline matrix and selected follow-ups

This is a research measurement of selected cases, not a conformance certification, product ranking, or a claim that a particular behavior is a bug. Measurements were made in separate single-node kind clusters on one host. kind v0.31.0, Kubernetes v1.35.0, containerd v2.2.0, Docker Desktop/WSL2; flannel v0.28.5 alone (non-enforcing control), kindnetd v20251212-v0.29.0-alpha-105-g20ccfc88, Calico v3.32.0, Cilium v1.20.2. Main matrix uses the respective default configurations. Five seconds elapsed after applying each policy. Baseline and exact results were retained.

## Observed ingress example (EXP-009)

Each entry below is observed source reachability across four repetitions and three destination probes (12 observations per source). `Pass` means 12/12 successful; `timeout` means 12/12 connection timeouts. A no-policy control passed all probes on all setups. The measurements use a 5-second wait and 3-second connection timeout.

| Policy | Setup | Source A | Source B | Source C |
|---|---|---|---|---|
| ipBlock except A's Pod IP | flannel alone | Pass | Pass | Pass |
| ipBlock except A's Pod IP | kindnet | Timeout | Pass | Pass |
| ipBlock except A's Pod IP | Calico | Timeout | Pass | Pass |
| ipBlock except A's Pod IP | Cilium | Timeout | Timeout | Timeout |
| Selectors choosing B and C | flannel alone | Pass | Pass | Pass |
| Selectors choosing B and C | kindnet | Timeout | Pass | Pass |
| Selectors choosing B and C | Calico | Timeout | Pass | Pass |
| Selectors choosing B and C | Cilium | Timeout | Pass | Pass |

The policy selection sets differ for other Pods and external IPs; this example does not show equivalence or a specification violation. [Definitions and historical runner](exp-009/README.md).

## How to read the tables

**The tables below are expectation-match counts, not observed pass counts or conformance scores.** Each numerator counts probes whose recorded result matches an experiment-defined expected result (which may be either pass or deny); the denominator counts probes. An `ANY` expectation is counted as a match regardless of observed outcome. For example, ingress C08 is 9/9 for flannel even though the separately tested out-of-range ports pass there. These counts summarize only the original run and must be read alongside the definitions and observations. For cases with undefined behavior the summary tool counts ANY as matching and the observed results are separately described below. The same 988 CNI-specific probe conditions were recorded four times (3,952 observations); the later 2,964 outcomes matched the first observations. Runs used existing clusters, not rebuilt clusters; later runs followed a Docker restart and CNI execution changed from parallel to sequential.

Ingress probes: sources a, b and c to Pod IP ports 80/81 and Service IP port 80 (9). Egress probes: clients a and b to Pod ports 80/81, Service by IP and DNS, and an external destination (10). Protocol probes: ordinary Pod a and same-node hostNetwork Pod h with TCP, UDP, SCTP and ICMP (8). For exact selectors, endpoints and policies consult the experiment source; case names alone are not sufficient to reproduce. DNS and Service behaviors depend on the environment. Timeouts are classified as blocked observations, not proof of the underlying packet handling.

For ingress, `clear` and `gray` are the experiment authors’ working labels for expectation categories; they are not official Kubernetes classifications. The values in all tables combine probes with different expected outcomes, and a match does not necessarily indicate enforcement.

## Ingress (EXP-004)

| case | expectation category | flannel | kindnet | calico | cilium |
|---|---|---|---|---|---|
| C00-no-policy | clear | 9/9 | 9/9 | 9/9 | 9/9 |
| C01-deny-all | clear | 0/9 | 9/9 | 9/9 | 9/9 |
| C02-pod-selector | clear | 3/9 | 9/9 | 9/9 | 9/9 |
| C03-ns-selector | clear | 3/9 | 9/9 | 9/9 | 9/9 |
| C04-ns-AND-pod | clear | 3/9 | 9/9 | 9/9 | 9/9 |
| C05-ns-OR-pod | clear | 6/9 | 9/9 | 9/9 | 9/9 |
| C06-port-numeric | clear | 6/9 | 9/9 | 9/9 | 9/9 |
| C07-port-named | clear | 6/9 | 9/9 | 9/9 | 9/9 |
| C08-endport | clear | 9/9 | 9/9 | 9/9 | 9/9 |
| C09-ipblock-except-pod | gray | 6/9 | 9/9 | 9/9 | 3/9 |
| C10-union-2policies | clear | 6/9 | 9/9 | 9/9 | 9/9 |

## Egress (EXP-005)

| case | flannel | kindnet | calico | cilium |
|---|---|---|---|---|
| E00-no-policy | 10/10 | 10/10 | 10/10 | 10/10 |
| E01-deny-all | 5/10 | 10/10 | 10/10 | 10/10 |
| E02-to-pod-noDNS | 8/10 | 10/10 | 10/10 | 10/10 |
| E03-to-pod+DNS | 9/10 | 10/10 | 10/10 | 10/10 |
| E04-ipblock-all+DNS | 10/10 | 10/10 | 10/10 | 6/10 |
| E05-ipblock-except-ext+DNS | 9/10 | 10/10 | 10/10 | 10/10 |
| E06-port80-anywhere+DNS | 8/10 | 10/10 | 10/10 | 10/10 |
| E07-namedport-to-pod+DNS | 8/10 | 10/10 | 10/10 | 10/10 |
| E08-ipblock-svcIP+DNS | 7/10 | 10/10 | 10/10 | 10/10 |
| E09-ipblock-podIP+DNS | 9/10 | 10/10 | 10/10 | 6/10 |

## Protocols (EXP-006)

| case | flannel | kindnet | calico | cilium |
|---|---|---|---|---|
| P00-no-policy | 8/8 | 8/8 | 8/8 | 6/8 |
| P01-deny-all | 5/8 | 8/8 | 8/8 | 8/8 |
| P02-tcp-only | 6/8 | 8/8 | 8/8 | 8/8 |
| P03-udp-only | 6/8 | 8/8 | 8/8 | 8/8 |
| P04-sctp-only | 6/8 | 8/8 | 8/8 | 6/8 |
| P05-from-app-client | 8/8 | 8/8 | 8/8 | 7/8 |

## Observations requiring context

- In ingress C09, flannel alone passed all tested traffic, kindnet and Calico blocked source A and passed B/C, while Cilium blocked A/B/C. In EXP-009, selectors choosing B/C produced A blocked and B/C passed on kindnet, Calico and Cilium, with all passing on flannel alone. Four repeats, three sources and three destination probes per policy; all no-policy controls passed. The two policies do not select equivalent sets outside the three test Pods.
- E04 and E09: in the isolated client, Cilium blocked the four tested internal destinations, whereas kindnet and Calico passed them. In E08 the Service IP and DNS probes were blocked by kindnet, Calico and Cilium and passed on flannel alone. This observation does not establish NAT evaluation order.
- For P01–P04 ordinary-Pod ICMP passed with flannel and was blocked with kindnet, Calico and Cilium. P05 ICMP passed on all. The same-node hostNetwork client passed TCP/UDP/ICMP across tested policies; Cilium's SCTP failed even in P00 with no policy. Do not infer SCTP policy enforcement from a failing baseline. ICMP and hostNetwork outcomes should not be generalized beyond these probes.
- EXP-008 tested TCP endPort 80–81 with listeners 79, 80, 81, 82. Policy-free controls passed; kindnet, Calico and Cilium passed 80/81 and blocked 79/82, flannel alone passed all four. Initial run plus three repeat runs.
- Cilium's pods-mode 0.0.0.0/0 CIDR experiment differed between 15 and 28 October. Three independent configuration-switch cycles did not reproduce the earlier observation; the cause is unknown. Do not use the old single run as a general rule.

## Limitations and further observations

Single host, single node, fixed versions, limited cases and repeated measurements within saved clusters; no claim about other versions, nodes, configurations or exact enforcement timing. EXP-027 was interrupted and is excluded from completed counts. A separate source-label-change investigation, including two clusters on the same host, is discussed at https://github.com/cilium/cilium/discussions/50094 .

Kubernetes v1.35 NetworkPolicy: https://v1-35.docs.kubernetes.io/docs/concepts/services-networking/network-policies/ . Cilium describes default ipBlock behavior at https://docs.cilium.io/en/stable/network/kubernetes/policy/ (stable page can change with releases). Existing related testing tool: https://github.com/mattfenwick/cyclonus .

## Feedback requested

1. Are any observations or interpretations misleading or missing essential context?
2. Would this table be useful when working with NetworkPolicy? Which cases or presentation changes matter most?
3. Which reproducibility details or controls would you prioritize before relying on it?

The accompanying data archive contains original result TSVs, saved repeat results, recorded source snapshots, and selected follow-up definitions and observations. The snapshot records the October 15 continuation; it should not be assumed to be the exact source for all earlier runs. Please inspect historical scripts before execution.
