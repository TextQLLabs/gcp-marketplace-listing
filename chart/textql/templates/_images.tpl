{{/* Image reference for a component. Every reference is substitutable, as
     Cloud Marketplace requires: the full-reference override in .Values.images
     (keyed by .key) wins; otherwise <global.registry>/<.name>:<global.imageTag>.
     All images of a release share one version tag. */}}
{{- define "tql.image" -}}
{{- $override := index .ctx.Values.images .key | default "" -}}
{{- if $override -}}
{{- $override -}}
{{- else -}}
{{- printf "%s/%s:%s" .ctx.Values.global.registry .name .ctx.Values.global.imageTag -}}
{{- end -}}
{{- end -}}
