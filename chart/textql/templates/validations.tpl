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
{{- if and .Values.computeEngine.enabled (not .Values.compute.deploymentId) }}
  {{- fail "compute.deploymentId is required when computeEngine.enabled: compute-engine cannot initialize its LLM providers without one. TextQL issues it with your license; for evaluation any UUID works (with a generated ed25519 key in secrets.deploymentPrivateKey, see the user guide)" }}
{{- end }}
{{- if and .Values.computeEngine.enabled (eq $mode "values") (not .Values.secrets.deploymentPrivateKey) }}
  {{- fail "secrets.deploymentPrivateKey is required when computeEngine.enabled (base64 ed25519; TextQL issues it with your license, or generate a throwaway one for evaluation, see the user guide)" }}
{{- end }}
{{- if and .Values.computeEngine.enabled (eq $mode "values") (not .Values.secrets.sandboxProxyCaKey) }}
  {{- fail "secrets.sandboxProxyCaKey (base64 PEM) is required when computeEngine.enabled: compute-engine cannot launch sandbox workers without the proxy CA key (see SETUP.md; the Marketplace deployer generates it)" }}
{{- end }}
{{- if and .Values.sandbox.filestore.enabled (not .Values.compute.gke.filestoreNetwork) }}
  {{- fail "compute.gke.filestoreNetwork is required when sandbox.filestore.enabled: set it to the VPC network your GKE cluster's subnet belongs to" }}
{{- end }}
{{- if and .Values.global.externalSecrets.gcp.serviceAccountRef (not (and .Values.global.externalSecrets.gcp.clusterLocation .Values.global.externalSecrets.gcp.clusterName)) }}
  {{- fail "global.externalSecrets.gcp.clusterLocation and clusterName are required when serviceAccountRef is set" }}
{{- end }}
