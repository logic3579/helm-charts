{{- define "global.configmap" }}
{{- $globdata := .Files.Glob "config/*" }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Chart.Name }}-config
data:
{{- range $path, $file := $globdata }}
  {{ base $path }}: |
{{ printf "%s" $file | indent 4 }}
{{- end }}
{{- end }}
