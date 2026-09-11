{{- define "tql.secretsMode" -}}
{{- .Values.global.secretsMode | default "values" -}}
{{- end -}}

{{- define "tql.externalSecretsPrefix" -}}
{{- .Values.global.externalSecrets.remoteKeyPrefix | default "textql" -}}
{{- end -}}

{{- define "tql.externalSecretHeader" -}}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .root.Release.Name }}-{{ .name }}
  labels:
    {{- include "tql.labels" .root | nindent 4 }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: {{ .root.Release.Name }}-secret-store
    kind: SecretStore
  target:
    name: {{ .root.Release.Name }}-{{ .name }}
    creationPolicy: Owner
  data:
{{- end -}}
