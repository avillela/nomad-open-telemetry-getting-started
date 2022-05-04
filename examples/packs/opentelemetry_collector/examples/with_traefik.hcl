# This example configures a basic OTel Collector with Traefik.
# It receives traces over OTLP, and ships them to Lighstep, Honeycomb, and Datadog
# API keys/tokens are retrieved from Vault.

job_type = "service"

job_name = "otel-collector"

task_config = {
  image   = "otel/opentelemetry-collector-contrib"
  version = "0.40.0"
  env = {
    HNY_DATASET_NAME = "my-hny-dataset"
    DD_SERVICE_NAME = "my-dd-service"
    DD_TAG = "env:local_dev_env"
  }
}

# Override vault config in vars file
vault_config = {
  enabled = true
  policies  = ["otel"]
}

# Traefik config
traefik_config = {
  enabled = true
  http_host = "otel-collector-http.localhost"
}

config_yaml = <<EOH
---
receivers:
  otlp:
    protocols:
      grpc:
      http:
        endpoint: "0.0.0.0:4318"

processors:
  batch:
    timeout: 10s
  memory_limiter:
    limit_mib: 1536
    spike_limit_mib: 512
    check_interval: 5s

exporters:
  logging:
    logLevel: debug

  otlp/hc:
    endpoint: "api.honeycomb.io:443"
    headers: 
      "x-honeycomb-team": "{{ with secret "kv/data/otel/o11y/honeycomb" }}{{ .Data.data.api_key }}{{ end }}"
      "x-honeycomb-dataset": "$HNY_DATASET_NAME"
  otlp/ls:
    endpoint: ingest.lightstep.com:443
    headers: 
      "lightstep-access-token": "{{ with secret "kv/data/otel/o11y/lightstep" }}{{ .Data.data.api_key }}{{ end }}"

  datadog:
    service: $DD_SERVICE_NAME
    tags:
      - $DD_TAG
    api:
      key: "{{ with secret "kv/data/otel/o11y/datadog" }}{{ .Data.data.api_key }}{{ end }}"
      site: datadoghq.com

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [logging, otlp/ls, otlp/hc, datadog]
EOH
