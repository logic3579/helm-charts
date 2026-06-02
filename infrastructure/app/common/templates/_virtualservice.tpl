{{/*
Render an Istio VirtualService resource.
Expects .Values.virtualservice with: enabled, gateways, hosts, port.
Optional: corsPolicy with allowOrigins, allowMethods, allowHeaders.

corsPolicy.allowOrigins supports two forms:
  - String (shorthand for exact match): "https://www.example.com"
  - Map (explicit match type):
      exact: "https://www.example.com"
      prefix: "https://"
      regex: "https://.*\\.example\\.com"
*/}}
{{- define "common.virtualservice" -}}
{{- if .Values.virtualservice.enabled }}
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  gateways:
    {{- range .Values.virtualservice.gateways }}
    - {{ . | quote }}
    {{- end }}
  hosts:
    {{- range .Values.virtualservice.hosts }}
    - {{ . | quote }}
    {{- end }}
  http:
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: {{ printf "%s.%s.svc.cluster.local" (include "common.fullname" .) .Release.Namespace }}
            port:
              number: {{ .Values.virtualservice.port | default .Values.service.port }}
      {{- with .Values.virtualservice.corsPolicy }}
      corsPolicy:
        allowOrigins:
          {{- range .allowOrigins }}
          {{- if kindIs "string" . }}
          - exact: {{ . | quote }}
          {{- else }}
          - {{ toYaml . | trim }}
          {{- end }}
          {{- end }}
        allowMethods:
          {{- toYaml .allowMethods | nindent 10 }}
        allowHeaders:
          {{- toYaml .allowHeaders | nindent 10 }}
        allowCredentials: {{ .allowCredentials | default false }}
        maxAge: {{ .maxAge | default "24h" | quote }}
      {{- end }}
      {{- with .Values.virtualservice.timeout }}
      timeout: {{ . }}
      {{- end }}
      {{- with .Values.virtualservice.retries }}
      retries:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end }}
