{{- define "global.virtualservice" }}
{{- if .Values.virtualservice.enabled }}
{{- $CHART_NAME := .Values.service.app_name -}}
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: {{ $CHART_NAME }}
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
  {{- if eq $CHART_NAME "backend-websocket" }}
  - match:
    - uri:
        prefix: /ws
      authority:
        exact: ws.example.com
    route:
    - destination:
        host: {{ printf "%s.%s.svc.cluster.local" $CHART_NAME .Release.Namespace | quote }}
        port:
          number: 8080
  {{- end}}
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: {{ printf "%s.%s.svc.cluster.local" $CHART_NAME .Release.Namespace | quote }}
        port:
          number: {{ .Values.virtualservice.port }}
    {{- if eq $CHART_NAME "backend-gateway-api" }}
    corsPolicy:
      allowOrigins:
      - exact: "*"
      allowMethods:
      - OPTIONS
      - GET
      - POST
      - DELETE
      - PUT
      allowHeaders:
      - Content-Type
      - Authorization
      - Cache-Control
      allowCredentials: true
      maxAge: "24h"
    {{- end}}
{{- end }}
{{- end }}
