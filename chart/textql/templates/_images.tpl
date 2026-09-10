{{/* Image reference for a component: the per-image override in
     .Values.images wins; otherwise <registry>/<name>:<imageTag>. An empty
     .name means the main app image, which lives at <registry> itself per
     the Marketplace repo layout. */}}
{{- define "tql.image" -}}
{{- $override := index .ctx.Values.images .key | default "" -}}
{{- if $override -}}
{{- $override -}}
{{- else if .name -}}
{{- printf "%s/%s:%s" .ctx.Values.global.registry .name .ctx.Values.global.imageTag -}}
{{- else -}}
{{- printf "%s:%s" .ctx.Values.global.registry .ctx.Values.global.imageTag -}}
{{- end -}}
{{- end -}}
