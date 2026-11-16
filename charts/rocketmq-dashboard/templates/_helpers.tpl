{{/* Reserve room for the MySQL component and its headless Service suffix. */}}
{{- define "rocketmq-dashboard.mysql.fullname" -}}
{{- printf "%s-mysql" (include "common.fullname" . | trunc 48 | trimSuffix "-") -}}
{{- end -}}

{{/* MySQL must not match the frontend Service or Deployment selectors. */}}
{{- define "rocketmq-dashboard.mysql.selectorLabels" -}}
{{- include "common.selectorLabels" (dict "Values" (dict "nameOverride" (include "rocketmq-dashboard.mysql.fullname" .)) "Chart" .Chart "Release" .Release) -}}
{{- end -}}

{{- define "rocketmq-dashboard.mysql.labels" -}}
{{ include "common.labels" (dict "Values" (dict "nameOverride" (include "rocketmq-dashboard.mysql.fullname" .)) "Chart" .Chart "Release" .Release) }}
app.kubernetes.io/component: mysql
{{- end -}}

{{- define "rocketmq-dashboard.mysql.secretName" -}}
{{- .Values.mysql.auth.existingSecret | default (include "rocketmq-dashboard.mysql.fullname" .) -}}
{{- end -}}
