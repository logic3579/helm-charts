{{/*
Chart-specific aliases that delegate to the common library.
*/}}

{{- define "python-app.name" -}}
{{- include "common.name" . }}
{{- end }}

{{- define "python-app.fullname" -}}
{{- include "common.fullname" . }}
{{- end }}

{{- define "python-app.chart" -}}
{{- include "common.chart" . }}
{{- end }}

{{- define "python-app.labels" -}}
{{- include "common.labels" . }}
{{- end }}

{{- define "python-app.selectorLabels" -}}
{{- include "common.selectorLabels" . }}
{{- end }}

{{- define "python-app.serviceAccountName" -}}
{{- include "common.serviceAccountName" . }}
{{- end }}
