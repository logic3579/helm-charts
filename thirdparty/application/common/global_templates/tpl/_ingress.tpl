{{- define "global.ingress" }}
{{- if .Values.ingress.enabled }}
{{- $CHART_NAME := ""}}
{{- $CHART_NAME = printf .Values.service.app_name }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
    nginx.ingress.kubernetes.io/cors-allow-methods: 'GET,OPTIONS,DELETE,PUT'
    nginx.ingress.kubernetes.io/cors-allow-origin: '*'
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/compute-full-forwarded-for: "true"
    nginx.ingress.kubernetes.io/proxy-real-ip-cidr: "0.0.0.0/0"
    nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Content-Type,Authorization,lang,satoken,platform_key"
{{- if .Values.ingress.annotations }}
{{ toYaml .Values.ingress.annotations | indent 4 }}
{{- end }}
  name: {{ $CHART_NAME }}
spec:
  ingressClassName: "nginx"
  rules:
  - host: {{ .Values.ingress.domain }}
    http:
      paths:
      - backend:
          service:
            name: {{ $CHART_NAME }}
            port:
              number: {{ $.Values.service.port }}
        path: /
        pathType: Prefix
{{- end }}
---
{{- if .Values.ingress.wsEnabled }}
{{- $CHART_NAME := ""}}
{{- $CHART_NAME = printf .Values.service.app_name }}
{{- $WS_CHART_NAME := ""}}
{{- $WS_CHART_NAME = printf "%s-ws" $CHART_NAME }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
    nginx.ingress.kubernetes.io/cors-allow-methods: 'GET,OPTIONS,DELETE,PUT'
    nginx.ingress.kubernetes.io/cors-allow-origin: '*'
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/compute-full-forwarded-for: "true"
    nginx.ingress.kubernetes.io/proxy-real-ip-cidr: "0.0.0.0/0"
    nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Content-Type,Authorization,lang,satoken,platform_key"
{{- if .Values.ingress.annotations }}
{{ toYaml .Values.ingress.annotations | indent 4 }}
{{- end }}
  name: {{ $WS_CHART_NAME }}
spec:
  ingressClassName: "nginx"
  rules:
  - host: {{ .Values.ingress.wsDomain }}
    http:
      paths:
      - backend:
          service:
            name: {{ $CHART_NAME }}
            port:
              number: {{ (index $.Values.extraService 0).port }}
        path: /
        pathType: Prefix
{{- end }}

{{- end }}
