# EXP-009: ingress ipBlock and selectors

This directory contains the original test definitions and runner. [Results](../comparison.md#observed-ingress-example-exp-009) summarize four repeats per condition. The runner is historical, not independently retested as a one-command setup.

## Test layout

The test uses two new namespaces: `np9-main` contains the server, client-a (`app=client`) and client-b (`app=other`); `np9-other` contains client-c (`app=client`). Probes connect to server Pod ports 80/81 and Service port 80 using agnhost. Each of four repeats tests no policy, `ipBlock` and selectors, in that order; the runner waits 5 seconds after each policy change and uses a 3-second connection timeout. The ipBlock excludes client-a's current Pod IP, inserted by the runner in place of `CLIENT_A_IP`. Each source has 12 probes per condition (four repeats × three destinations).

## Running the historical script

Use **disposable test clusters only**. The script applies namespaces, Pods, a Service and NetworkPolicies, and deletes the `experiment` NetworkPolicy in its test namespace. It refuses to start if either namespace already exists in a target cluster. It also refuses an existing `results/run-2026-10-28` output directory. Review the script and manifests first. Requires Bash, kind, kubectl, access to the agnhost image, and four already configured single-node kind clusters with contexts `kind-netpol-flannel`, `kind-netpol-kindnet`, `kind-netpol-calico`, and `kind-netpol-cilium`. Installing and configuring those clusters is outside this directory. Configurations, image versions and host conditions can change results.

From a clean checkout, enter this directory and run `bash run.sh`. The runner captures results and logs under `results/run-2026-10-28/`. It uses the current IPs and refuses to overwrite existing output. In the original experiment the namespace and workloads were retained after deleting the experiment Policy; remove test resources manually when appropriate.

Do not treat a 3-second timeout as proof of exactly where or why packets were dropped. Consult the [full comparison](../comparison.md) for limits and the downloadable archive for the original TSV data.
