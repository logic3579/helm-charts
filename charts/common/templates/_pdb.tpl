{{/*
Render a PodDisruptionBudget.
Expects .Values.podDisruptionBudget with: enabled, minAvailable or maxUnavailable.
*/}}
{{- define "common.pdb" -}}
{{- if .Values.podDisruptionBudget.enabled }}
{{- if and .Values.podDisruptionBudget.minAvailable .Values.podDisruptionBudget.maxUnavailable }}
{{- fail "podDisruptionBudget: minAvailable and maxUnavailable are mutually exclusive, set only one" }}
{{- end }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  {{- with .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ . }}
  {{- end }}
  {{- with .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ . }}
  {{- end }}
{{- end }}
{{- end }}
