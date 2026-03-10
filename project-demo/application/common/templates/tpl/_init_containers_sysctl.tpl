{{- define "global.init_containers_sysctl" }}
      initContainers:
      - name: sysctl
        image: alpine:3.20
        securityContext:
          privileged: true
        command: ["sh", "-c", "apk add --no-cache procps && sysctl -w net.ipv4.tcp_syn_retries=1"]
{{- end }}
