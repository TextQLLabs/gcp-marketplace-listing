{{- define "tql.labels" -}}
app.kubernetes.io/name: {{ .Release.Name | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{/* Release-scoped selector labels. */}}
{{- define "tql.selectorLabels" -}}
app: {{ .app }}
app.kubernetes.io/name: {{ .ctx.Release.Name | quote }}
{{- end -}}

{{/* Marketplace apps must run on x86; Istio injection is unsupported. */}}
{{- define "tql.podRuntime" -}}
nodeSelector:
  kubernetes.io/arch: amd64
{{- end -}}

{{- define "tql.podAnnotations" -}}
sidecar.istio.io/inject: "false"
{{- end -}}

{{/* SINGLE_OIDC_TENANT=true without a full OIDC config is a fatal boot
     error in compute-engine, so only turn it on once OIDC is set up. */}}
{{- define "tql.singleOidcTenant" -}}
{{- if and .Values.global.auth.oidc.issuerUrl .Values.global.auth.oidc.clientId -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/* global.hostname (a scalar, so the Marketplace UI can set it) wins
     over the hostnames list. */}}
{{- define "tql.hostnames" -}}
{{- if .Values.global.hostname -}}
{{ list .Values.global.hostname | toYaml }}
{{- else -}}
{{ .Values.global.hostnames | toYaml }}
{{- end -}}
{{- end -}}

{{/* Database wiring: in-cluster postgres or external. */}}

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

{{/* In-cluster postgres runs without TLS; external databases require it. */}}
{{- define "tql.db.url" -}}
{{- $sslmode := ternary "disable" "require" .Values.postgres.enabled -}}
postgresql://{{ include "tql.db.username" . }}:{{ include "tql.db.password" . | urlquery }}@{{ include "tql.db.host" . }}:{{ include "tql.db.port" . }}/{{ include "tql.db.name" . }}?sslmode={{ $sslmode }}
{{- end -}}

{{/* Runtime-contract names. Old compute images hardcode these; images that
     honor the KUBERNETES_*_NAME/SECRET/PVC env overrides can carry the
     release prefix (prefixedNames.enabled). */}}
{{- define "tql.computeDeploymentName" -}}
{{- if .Values.prefixedNames.enabled }}{{ .Release.Name }}-compute-engine{{ else }}compute-engine{{ end -}}
{{- end -}}

{{- define "tql.sandboxFilesPvcName" -}}
{{- if .Values.prefixedNames.enabled }}{{ .Release.Name }}-sandbox-files-pvc{{ else }}sandbox-files-pvc{{ end -}}
{{- end -}}

{{- define "tql.sandboxProxyCaSecretName" -}}
{{- if .Values.prefixedNames.enabled }}{{ .Release.Name }}-sandbox-proxy-ca-cert{{ else }}sandbox-proxy-ca-cert{{ end -}}
{{- end -}}

{{- define "tql.pullSecretName" -}}
{{- if .Values.prefixedNames.enabled }}{{ .Release.Name }}-regcred{{ else }}regcred{{ end -}}
{{- end -}}

{{- define "tql.workerTokenSecretName" -}}
{{- if .Values.prefixedNames.enabled }}{{ .Release.Name }}-sandbox-proxy-worker-tokens{{ else }}sandbox-proxy-worker-tokens{{ end -}}
{{- end -}}

{{/* Init container that blocks until PostgreSQL accepts connections, so
     dependent containers start clean instead of crash-looping through the
     database's own startup. */}}
{{- define "tql.waitForDb" -}}
- name: wait-for-db
  image: "{{ include "tql.image" (dict "ctx" . "key" "postgres" "name" "postgres") }}"
  command:
    - sh
    - -c
    - until pg_isready -h {{ include "tql.db.host" . | quote }} -p {{ include "tql.db.port" . | quote }} -t 3; do echo "waiting for database"; sleep 2; done
  resources:
    requests:
      memory: "32Mi"
      cpu: "20m"
    limits:
      memory: "64Mi"
{{- end -}}
