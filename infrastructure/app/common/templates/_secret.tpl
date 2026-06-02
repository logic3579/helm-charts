{{/*
Render a Secret resource.
Expects .Values.secret with: enabled, data.

NOTE: Secret values are sourced from .Values.secret.data (plaintext in values, base64-encoded here).
For production, prefer External Secrets Operator (ESO) or Sealed Secrets to avoid storing
plaintext credentials in values files or CI variables. Use this built-in Secret only for
non-sensitive config or local development.
*/}}
{{- define "common.secret" -}}
{{- if .Values.secret.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
type: Opaque
data:
  {{- range $key, $value := .Values.secret.data }}
  {{ $key }}: {{ $value | b64enc | quote }}
  {{- end }}
{{- end }}
{{- end }}
