{{- $mode := include "tql.secretsMode" . }}
{{- if not (or (eq $mode "values") (eq $mode "externalSecrets")) }}
  {{- fail (printf "Invalid global.secretsMode: %s (must be values or externalSecrets)" $mode) }}
{{- end }}
{{- if and (eq $mode "externalSecrets") (not .Values.global.externalSecrets.gcp.projectId) }}
  {{- fail "global.externalSecrets.gcp.projectId is required in secretsMode=externalSecrets" }}
{{- end }}
{{- if not (include "tql.hostnames" . | fromYamlArray) }}
  {{- fail "global.hostname or global.hostnames must contain at least one hostname" }}
{{- end }}
{{- if not .Values.web.publicApi }}
  {{- fail "web.publicApi is required" }}
{{- end }}
{{- if and .Values.sandbox.filestore.enabled (not .Values.compute.gke.filestoreNetwork) }}
  {{- fail "compute.gke.filestoreNetwork is required when sandbox.filestore.enabled: set it to the VPC network your GKE cluster's subnet belongs to" }}
{{- end }}
{{- if and .Values.global.externalSecrets.gcp.serviceAccountRef (not (and .Values.global.externalSecrets.gcp.clusterLocation .Values.global.externalSecrets.gcp.clusterName)) }}
  {{- fail "global.externalSecrets.gcp.clusterLocation and clusterName are required when serviceAccountRef is set" }}
{{- end }}
