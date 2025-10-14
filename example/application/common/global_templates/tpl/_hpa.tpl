{{- define "global.hpa" }}
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Chart.Name }}
  annotations: {}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
 {{- if .Values.StatefulSet }}
    kind: StatefulSet
 {{- else }}
    kind: Deployment
 {{- end }}
    name: {{ .Chart.Name }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.http_request_count }}
    - type: Pods
      pods:
        metricName: http_request_count
        targetAverageValue: {{ .Values.autoscaling.http_request_count }}
    {{- end }}
{{- end }}
{{- end }}
