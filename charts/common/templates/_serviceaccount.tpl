{{/*
Render a ServiceAccount resource.
Expects .Values.serviceAccount with: create, name, annotations, automountServiceAccountToken.
*/}}
{{- define "common.serviceaccount" -}}
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "common.serviceAccountName" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken | default false }}
{{- end }}
{{- end }}
