#!/usr/bin/env bash
set -euo pipefail
export MSYS_NO_PATHCONV=1
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/results/run-2026-10-28"
[ ! -e "$OUT" ] || { echo "Refusing to overwrite $OUT" >&2; exit 1; }
mkdir -p "$OUT"
cp "$HERE"/*.yaml "$HERE/run.sh" "$OUT/"
ctx=""; dir=""; owned=0
cleanup() {
  if [ "$owned" = 1 ]; then
    kubectl --context "$ctx" -n np9-main delete networkpolicy experiment --ignore-not-found >> "$dir/kubectl.log" 2>&1 || echo "Cleanup failed for $ctx; inspect manually" >&2
  fi
}
trap cleanup EXIT
for cni in flannel kindnet calico cilium; do
  ctx="kind-netpol-$cni"; dir="$OUT/$cni"; mkdir "$dir"
  kubectl --context "$ctx" get nodes -o json > "$dir/nodes.json"
  kubectl --context "$ctx" get pods -A -o json > "$dir/pods-before.json"
  kubectl --context "$ctx" version -o json > "$dir/version.json"
  namespaces=$(kubectl --context "$ctx" get namespaces -o name)
  for ns in np9-main np9-other; do
    if printf '%s\n' "$namespaces" | grep -Fx "namespace/$ns" >/dev/null; then
      echo "Refusing existing namespace $ctx $ns" >&2; exit 1
    fi
  done
  owned=1
  kubectl --context "$ctx" apply -f - < "$HERE/workload.yaml" > "$dir/kubectl.log" 2>&1
  kubectl --context "$ctx" -n np9-main wait --for=condition=Ready pod --all --timeout=120s >> "$dir/kubectl.log" 2>&1
  kubectl --context "$ctx" -n np9-other wait --for=condition=Ready pod --all --timeout=120s >> "$dir/kubectl.log" 2>&1
  kubectl --context "$ctx" get pods -A -o json > "$dir/pods-ready.json"
  aip=$(kubectl --context "$ctx" -n np9-main get pod client-a -o jsonpath='{.status.podIP}')
  sip=$(kubectl --context "$ctx" -n np9-main get pod server -o jsonpath='{.status.podIP}')
  svc=$(kubectl --context "$ctx" -n np9-main get svc server -o jsonpath='{.spec.clusterIP}')
  [ -n "$aip" ] && [ -n "$sip" ] && [ -n "$svc" ]
  printf 'client-a=%s\nserver=%s\nservice=%s\n' "$aip" "$sip" "$svc" > "$dir/addresses.txt"
  printf 'run\tcase\tsrc\tdst\tresult\n' > "$dir/results.tsv"
  for run in 1 2 3 4; do
    for case_name in baseline ipblock selector; do
      kubectl --context "$ctx" -n np9-main delete networkpolicy experiment --ignore-not-found >> "$dir/kubectl.log" 2>&1
      if [ "$case_name" = ipblock ]; then
        sed "s/CLIENT_A_IP/$aip/" "$HERE/ipblock.yaml" | kubectl --context "$ctx" apply -f - >> "$dir/kubectl.log" 2>&1
      elif [ "$case_name" = selector ]; then
        kubectl --context "$ctx" apply -f - < "$HERE/selector.yaml" >> "$dir/kubectl.log" 2>&1
      fi
      kubectl --context "$ctx" -n np9-main get networkpolicy -o yaml > "$dir/policy-$run-$case_name.yaml"
      sleep 5
      for src in a b c; do
        ns=np9-main; [ "$src" != c ] || ns=np9-other
        for dst in P80 P81 S80; do
          case "$dst" in P80) target="$sip:80";; P81) target="$sip:81";; S80) target="$svc:80";; esac
          rc=0; probe=$(kubectl --context "$ctx" -n "$ns" exec "client-$src" -- /agnhost connect "$target" --timeout=3s 2>&1) || rc=$?
          printf 'run=%s case=%s src=%s dst=%s target=%s rc=%s\n%s\n' "$run" "$case_name" "$src" "$dst" "$target" "$rc" "$probe" >> "$dir/probes.log"
          if [ "$rc" -eq 0 ]; then verdict=ALLOW
          elif [[ "$probe" = *TIMEOUT* ]]; then verdict=DENY-TIMEOUT
          elif [[ "$probe" = *REFUSED* ]]; then verdict=DENY-REFUSED
          else verdict=ERROR; fi
          printf '%s\t%s\t%s\t%s\t%s\n' "$run" "$case_name" "$src" "$dst" "$verdict" >> "$dir/results.tsv"
          if [ "$verdict" = ERROR ] || { [ "$case_name" = baseline ] && [ "$verdict" != ALLOW ]; }; then
            echo "INVALID: $cni run=$run case=$case_name src=$src dst=$dst $verdict" >&2
            kubectl --context "$ctx" -n np9-main delete networkpolicy experiment --ignore-not-found >> "$dir/kubectl.log" 2>&1 || true
            exit 1
          fi
        done
      done
      echo "$cni run=$run $case_name complete"
    done
  done
  kubectl --context "$ctx" -n np9-main delete networkpolicy experiment --ignore-not-found >> "$dir/kubectl.log" 2>&1
  kubectl --context "$ctx" -n np9-main get networkpolicy -o yaml > "$dir/policies-after.yaml"
  owned=0
  date -Iseconds > "$dir/complete"
done


