{{/*
Chart-specific aliases that delegate to the common library.
This allows templates to use "go-app.xxx" while the logic lives in common.
*/}}

{{- define "go-app.name" -}}
{{- include "common.name" . }}
{{- end }}

{{- define "go-app.fullname" -}}
{{- include "common.fullname" . }}
{{- end }}

{{- define "go-app.chart" -}}
{{- include "common.chart" . }}
{{- end }}

{{- define "go-app.labels" -}}
{{- include "common.labels" . }}
{{- end }}

{{- define "go-app.selectorLabels" -}}
{{- include "common.selectorLabels" . }}
{{- end }}

{{- define "go-app.serviceAccountName" -}}
{{- include "common.serviceAccountName" . }}
{{- end }}
