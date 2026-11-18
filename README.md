# Comparing Kubernetes NetworkPolicy behavior across local CNI setups

This undergraduate research compares selected NetworkPolicy scenarios across four local networking setups. The results are limited observations, not conformance certification or a product ranking.

## Start here

- [Comparison, methods and limitations](comparison.md)
- [Experiment data and recorded definitions (ZIP)](networkpolicy-comparison-data.zip)

The ZIP contains baseline and repeat result TSVs, historical policy/workload definitions and selected follow-up data. Its README explains the layout. Historical scripts target named clusters and can modify or remove test resources: read them before running and use only disposable test environments. The October 15 source snapshot is evidence of that continuation, not necessarily of prior runs. The archive includes an explicitly named invalid-path run; it is not part of the reported comparisons. It is a research record, not a verified one-command reproduction package.

## Example

In one ingress test, an ipBlock excluding Pod A's IP resulted in A blocked and B/C allowed with kindnet and Calico, but A/B/C blocked with default Cilium. Selectors choosing B/C produced A blocked and B/C allowed with all three. Flannel alone passed all tested sources as a non-enforcing control. These policies select different sets beyond the three test Pods. Kubernetes recommends cluster-external IPs for ipBlock, and Cilium documents its default behavior; this observation is not presented as a bug. Four repetitions per policy were run with baseline controls.

## Environment and scope

Separate single-node kind clusters on one host; Kubernetes v1.35.0, kind v0.31.0, containerd v2.2.0; kindnetd v20251212-v0.29.0-alpha-105-g20ccfc88, Calico v3.32.0, Cilium v1.20.2, flannel v0.28.5 alone. Results do not establish behavior on other versions, configurations, nodes or policies. See the comparison for baseline limitations, an unresolved CIDR discrepancy, and the difference between a timeout and an exact enforcement time.

## Feedback welcome

Are the interpretations and limitations accurate? Would the table help practitioners? Which cases, controls or reproduction details would be most useful to add?

Sources: [Kubernetes v1.35 NetworkPolicy](https://v1-35.docs.kubernetes.io/docs/concepts/services-networking/network-policies/), [Cilium NetworkPolicy documentation](https://docs.cilium.io/en/stable/network/kubernetes/policy/). A separate source-label investigation is discussed at [Cilium Discussions #50094](https://github.com/cilium/cilium/discussions/50094).
