{{- define "tql.labels" -}}
app.kubernetes.io/name: {{ .Release.Name | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{/* Selector labels: release-scoped so several instances can share a
     namespace, per Marketplace packaging requirements. */}}
{{- define "tql.selectorLabels" -}}
app: {{ .app }}
app.kubernetes.io/name: {{ .ctx.Release.Name | quote }}
{{- end -}}

{{/* Marketplace apps must run on x86 nodes; Istio sidecar injection is
     unsupported and explicitly disabled. */}}
{{- define "tql.podRuntime" -}}
nodeSelector:
  kubernetes.io/arch: amd64
{{- end -}}

{{- define "tql.podAnnotations" -}}
sidecar.istio.io/inject: "false"
{{- end -}}

{{/* Hostnames list; global.hostname (scalar, settable from the Marketplace
     UI) wins over global.hostnames when set. */}}
{{- define "tql.hostnames" -}}
{{- if .Values.global.hostname -}}
{{ list .Values.global.hostname | toYaml }}
{{- else -}}
{{ .Values.global.hostnames | toYaml }}
{{- end -}}
{{- end -}}

{{/* --- Database wiring: in-cluster postgres or external --- */}}

{{- define "tql.db.host" -}}
{{- if .Values.postgres.enabled -}}
{{ .Release.Name }}-postgres
{{- else -}}
{{- required "global.db.host is required when postgres.enabled=false" .Values.global.db.host -}}
{{- end -}}
{{- end -}}

{{- define "tql.db.port" -}}
{{- if .Values.postgres.enabled -}}
5432
{{- else -}}
{{- .Values.global.db.port | toString -}}
{{- end -}}
{{- end -}}

{{- define "tql.db.name" -}}
{{- if .Values.postgres.enabled -}}
{{- .Values.postgres.auth.database -}}
{{- else -}}
{{- .Values.global.db.name -}}
{{- end -}}
{{- end -}}

{{- define "tql.db.username" -}}
{{- if .Values.postgres.enabled -}}
{{- .Values.postgres.auth.username -}}
{{- else -}}
{{- .Values.global.db.username -}}
{{- end -}}
{{- end -}}

{{- define "tql.db.password" -}}
{{- if .Values.postgres.enabled -}}
{{- required "postgres.auth.password is required in secretsMode=values (the Marketplace deployer generates it; CLI installs must set it)" .Values.postgres.auth.password -}}
{{- else -}}
{{- required "global.db.password is required in secretsMode=values when postgres.enabled=false" .Values.global.db.password -}}
{{- end -}}
{{- end -}}

{{/* In-cluster postgres has no TLS; external databases must use it. */}}
{{- define "tql.db.url" -}}
{{- $sslmode := ternary "disable" "require" .Values.postgres.enabled -}}
postgresql://{{ include "tql.db.username" . }}:{{ include "tql.db.password" . | urlquery }}@{{ include "tql.db.host" . }}:{{ include "tql.db.port" . }}/{{ include "tql.db.name" . }}?sslmode={{ $sslmode }}
{{- end -}}
