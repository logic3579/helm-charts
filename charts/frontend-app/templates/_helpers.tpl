{{/*
Chart-specific aliases that delegate to the common library.
*/}}

{{- define "frontend-app.name" -}}
{{- include "common.name" . }}
{{- end }}

{{- define "frontend-app.fullname" -}}
{{- include "common.fullname" . }}
{{- end }}

{{- define "frontend-app.chart" -}}
{{- include "common.chart" . }}
{{- end }}

{{- define "frontend-app.labels" -}}
{{- include "common.labels" . }}
{{- end }}

{{- define "frontend-app.selectorLabels" -}}
{{- include "common.selectorLabels" . }}
{{- end }}

{{- define "frontend-app.serviceAccountName" -}}
{{- include "common.serviceAccountName" . }}
{{- end }}
