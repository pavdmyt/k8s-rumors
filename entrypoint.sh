#!/bin/bash
set -e

[[ ! -v SECRET ]] && echo "SECRET to copy is not defined" && exit 1
[[ ! -v ORIGIN_NAMESPACE ]] && echo "ORIGIN_NAMESPACE is not defined" && exit 1
[[ ! -v DEST_NAMESPACES ]] && echo "DEST_NAMESPACES is not defined" && exit 1

watchNamespaces () {

	while :; do
		
		echo "$(date '+%Y-%m-%d %H:%M:%S') starting namespaces watch loop"

		kubectl get ns --watch --field-selector="status.phase==Active" --no-headers -o "custom-columns=:metadata.name" | \
		while read ns; do
		  if [[ "${ns}" != "${ORIGIN_NAMESPACE}" ]]; then
			for dest in "${DEST_NAMESPACES[@]}"; do
				if [[ "${dest}" == "${ns}" ]]; then
					echo "$(date '+%Y-%m-%d %H:%M:%S') namespace - ${ns}"
					kubectl -n "${ORIGIN_NAMESPACE}" get secret "${SECRET}" -o yaml --export | \
					kubectl -n "${ns}" apply -f -
				fi
			done
		  fi
		done

	done

}

watchSecret () {

	while :; do
		echo "$(date '+%Y-%m-%d %H:%M:%S') starting secret watch loop"
		kubectl -n "${ORIGIN_NAMESPACE}" get secret "${SECRET}" --watch --no-headers -o "custom-columns=:metadata.name" | \
		while read secret; do
			export=$(kubectl -n "${NAMESPACE}" get secret "${secret}" -o yaml --export)
            for ns in $(kubectl get ns --field-selector="status.phase==Active" --no-headers -o "custom-columns=:metadata.name"); do
                if [[ "${ns}" != "${NAMESPACE}" ]]; then
                    for dest in "${DEST_NAMESPACES[@]}"; do
                        if [[ "${ns}" == "${dest}" ]]; then
                          echo "$(date '+%Y-%m-%d %H:%M:%S') namespace - ${ns}"
                          echo "${export}" | kubectl -n "${ns}" apply -f -
                        fi
                    done
                fi
            done
        done
    done

}

action="${1:-ns}"

case "${action}" in
    ns)
        watchNamespaces
        ;;
    *)
        watchSecret
        ;;
esac
