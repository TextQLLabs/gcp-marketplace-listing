{{- define "tql.scheduling.serviceTierLabel" -}}
textql.com/scheduling-tier: service
{{- end -}}

{{- define "tql.scheduling" -}}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: "kubernetes.io/hostname"
          labelSelector:
            matchExpressions:
              - key: worker-type
                operator: In
                values:
                  - sandbox
                  - dashboard
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: {{ .app }}
{{- end -}}
