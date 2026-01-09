{{- define "global.service" }}
{{- $CHART_NAME := ""}}
{{- $CHART_NAME = printf .Values.service.app_name }}
apiVersion: v1
kind: Service
metadata:
  labels:
    app: {{ $CHART_NAME }}
  name: {{ $CHART_NAME }}
spec:
  ports:
  - name: http
    port: {{ .Values.service.port }}
    protocol: {{ .Values.service.protocol }}
    targetPort: {{ .Values.service.targetport }}
 {{- if .Values.extraService }}
 {{- range .Values.extraService }}
  - name: {{ .name }}
    port: {{ .port }}
    protocol: {{ .protocol }}
    targetPort: {{ .targetport }}
 {{- end }}   
 {{- end }}
  selector:
    app: {{ .Chart.Name }}
  sessionAffinity: None
  type: ClusterIP
{{- end }}
