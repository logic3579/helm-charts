{{- define "global.deployment" }}
apiVersion: apps/v1
{{- if .Values.StatefulSet }}
kind: StatefulSet
{{ else }}
kind: Deployment
{{- end }}
metadata:
  name: {{ .Chart.Name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
 {{- if .Values.StatefulSet }}
  serviceName: {{ .Chart.Name }}
 {{- end }}
  template:
    metadata:
      annotations:
        rollout: {{ randAlphaNum 5 | quote }}
      labels:
        app: {{ .Chart.Name }}
    spec:
      affinity: {}
      securityContext:
        fsGroup: 1000
      imagePullSecrets:
        - name: harbor-secret
      containers:
      - envFrom:
        - configMapRef:
            name: global-resources
        - configMapRef:
            name: {{ .Chart.Name }}-config
        env:
        - name: DEBUG
          value: "{{ .Values.debug }}"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        - name: APP_TYPE
          value: {{ .Values.APP_TYPE }}
        - name: APP_NAME
          value: {{ .Values.APP_NAME }}
        image: {{ .Values.image.repo }}:{{ .Values.image.tag }}
        imagePullPolicy: {{ .Values.image.pullPolicy }}
      {{- if .Values.privileged }}
        securityContext:
          privileged: true
      {{- end }}
        name: {{ .Chart.Name }}
        command: ["/entrypoint.sh"]
        args: ["bash","-c","/run.sh"]
        ports:
        - containerPort: {{ .Values.service.targetport }}
          name: http-port
          protocol: TCP
       {{- if .Values.extraService }}
       {{- range .Values.extraService }}
        - containerPort: {{ .targetport }}
          name: {{ .name }}
          protocol: {{ .protocol }}
       {{- end }}
       {{- end }}
       {{- if .Values.livenessProbe }}
        livenessProbe:
{{ toYaml .Values.livenessProbe | indent 12 }}
       {{- end }}

        {{- if .Values.readinessProbe }}
        readinessProbe:
{{ toYaml .Values.readinessProbe | indent 12 }}
        {{- end }}

  {{- if .Values.resources }}
        resources:
{{ toYaml .Values.resources | indent 12 }}
  {{- end }}
        volumeMounts:
        - mountPath: /entrypoint.sh
          subPath: entrypoint.sh
          name: global-entrypoint
        - mountPath: /run.sh
          subPath: run.sh
          name: global-run
      volumes:
      - emptyDir: {}
        name: shared-data
      - emptyDir: {}
        name: shared-secrets
      - configMap:
          defaultMode: 0777
          name: global-entrypoint
        name: global-entrypoint
      - configMap:
          defaultMode: 0777
          name: global-run
        name: global-run
  {{- if .Values.nodeSelector }}
      nodeSelector:
{{ toYaml .Values.nodeSelector | indent 8 }}
  {{- end }}
{{- end }}
