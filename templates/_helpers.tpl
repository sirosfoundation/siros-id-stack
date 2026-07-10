{{- define "siros-id.namespace" -}}
{{- if .Values.tenant.namespace }}
{{- .Values.tenant.namespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Define the hostnames for the tenant
*/}}
{{ $_ := required "Domain root must be set" .Values.domain.root }}
{{- define "siros-id.hostname.issuerRegistry" -}}
{{- .Values.hostnames.issuerRegistry | default (printf "%s.issuer-registry.%s" .Values.tenant.id .Values.domain.root) -}}
{{- end -}}
{{- define "siros-id.hostname.issuer" -}}
{{- .Values.hostnames.issuer | default (printf "%s.issuer.%s" .Values.tenant.id .Values.domain.root) -}}
{{- end -}}
{{- define "siros-id.hostname.verifier" -}}
{{- .Values.hostnames.verifier | default (printf "%s.verifier.%s" .Values.tenant.id .Values.domain.root) -}}
{{- end -}}
{{- define "siros-id.hostname.walletBackend" -}}
{{- .Values.hostnames.walletBackend | default (printf "backend.%s" .Values.domain.root) -}}
{{- end -}}
{{- define "siros-id.hostname.walletFrontend" -}}
{{- .Values.hostnames.walletFrontend | default (.Values.domain.root) -}}
{{- end -}}
{{- define "siros-id.hostname.walletFrontendBasePath" -}}
{{- .Values.walletFrontend.basePath | default (printf "/id/%s" .Values.tenant.id) -}}
{{- end -}}

{{- define "siros-id.origins.walletFrontend" -}}
https://{{- .Values.hostnames.walletFrontend | default (.Values.domain.root) -}}
{{- end -}}

{{- define "siros-id.fullname" -}}
{{- printf "%s-%s" .Chart.Name .Values.tenant.id | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/* Labels template
Call with (list . (dict "name" "example"))
*/}}
{{- define "siros-id.labels" -}}
{{- $root := index . 0 -}}
{{- $params := index . 1 -}}
{{- $commonLabels := mustDeepCopy $root.Values.global.commonLabels -}}
{{- $labels := mustDeepCopy $params | mergeOverwrite $commonLabels -}}
labels:
  app.kubernetes.io/managed-by: {{ $root.Release.Service | quote }}
  app.kubernetes.io/instance: {{ $root.Release.Name | quote }}
  app.kubernetes.io/part-of: "siros-id"
  {{- with $labels -}}
  {{- toYamlPretty . | nindent 2 }}
  {{- end -}}
{{- end -}}

{{/* Annotations template
Call with (list . (dict "name" "example"))
*/}}
{{- define "siros-id.annotations" -}}
{{- $root := index . 0 -}}
{{- $params := index . 1 -}}
{{- $commonAnnotations := mustDeepCopy $root.Values.global.commonAnnotations -}}
{{- $annotations := mustDeepCopy $params | mergeOverwrite $commonAnnotations -}}
{{- with $annotations -}}
annotations: {{- toYamlPretty . | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "siros-id.displayName" -}}
{{- .Values.tenant.displayName | default (.Values.tenant.id) | quote -}}
{{- end -}}

{{- define "siros-id.originFromUrl" -}}
{{- $url := . -}}
{{- $urlParsed := urlParse $url -}}
{{- urlJoin (dict "scheme" $urlParsed.scheme "host" $urlParsed.host) -}}
{{- end -}}

{{- define "siros-id.dataOrFile" -}}
{{- $root := index . 0 -}}
{{- $params := index . 1 -}}
{{- if $params.data -}}
{{ $params.data }}
{{- else if $params.file -}}
{{ $root.Files.Get $params.file }}
{{- else -}}
{{ fail "Object must contain non-empty .data or .file property" }}
{{- end -}}
{{- end -}}

{{- define "siros-id.vc.credentialMetadata" -}}
{{- $_ := required "You must define credential types in the value features.credentialTypes" .Values.features.credentialTypes -}}
{{- range $id, $data := .Values.features.credentialTypes }}
{{ $id | quote }}:
  vctm_file_path: /vctms/{{ $id }}.json
  format: {{ $data.format }}
{{- end }}
{{- end -}}

{{/* The list of supported credential scopes
*/}}
{{- define "siros-id.vc.credentialScopes" -}}
{{- range $id, $_ := .Values.features.credentialTypes }}
- {{ $id | quote }}
{{- end }}
{{- end -}}

{{/*
Credential types with issuance.source "assertion", as a JSON object.
Use with: {{- $types := include "siros-id.vc.credentialTypesBySource" (list . "assertion") | fromJson -}}
Credential types without an explicit source default to "datastore" and are excluded.
*/}}
{{- define "siros-id.vc.credentialTypesBySource" -}}
{{- $root := index . 0 -}}
{{- $sourceType := index . 1 -}}
{{- $result := dict -}}
{{- range $id, $data := $root.Values.features.credentialTypes -}}
{{- $_ := required "Credential type must have an issuance.source" $data.issuance.source }}
{{- if eq $data.issuance.source $sourceType -}}
{{- $_ := set $result $id $data -}}
{{- end }}
{{- end }}
{{- $result | toYaml -}}
{{- end -}}

{{- define "siros-id.branding.logoDataUrl" -}}
{{-
  .Values.features.branding.logoDataUrl
  | default (printf "data:image/png;base64,%s" (.Files.Get "config/default_logo.png" | b64enc))
-}}
{{- end -}}

{{- define "siros-id.branding.faviconDataUrl" -}}
{{-
  .Values.features.branding.faviconDataUrl
  | default (printf "data:image/png;base64,%s" (.Files.Get "config/default_favicon.png" | b64enc))
-}}
{{- end -}}

{{- define "siros-id.reservedNetworks.v4" -}}
- 0.0.0.0/8
- 10.0.0.0/8
- 100.64.0.0/10
- 127.0.0.0/8
- 169.254.0.0/16
- 172.16.0.0/12
- 192.0.0.0/24
- 192.0.2.0/24
- 192.88.99.0/24
- 192.168.0.0/16
- 198.18.0.0/15
- 198.51.100.0/24
- 203.0.113.0/24
- 224.0.0.0/4
- 233.252.0.0/24
- 240.0.0.0/4
- 255.255.255.255/32
{{- end -}}

{{- define "siros-id.reservedNetworks.v6" -}}
- "::1/128"
# - "::ffff:0:0/96"
- 64:ff9b::/96
- 64:ff9b:1::/48
- 100::/64
- 2001::/32
- 2001:20::/28
- 2001:db8::/32
- 2002::/16
- 3fff::/20
- 5f00::/16
- fc00::/7
- fe80::/10
- ff00::/8
{{- end -}}

{{/* Generate a certificate for a given name.
Call with (list . (dict "name" "example")).
Params:
- name: The name of the certificate (required)
- usages: The usages of the certificate (required)
- ou: The OU of the certificate (required if literalSubject is not set)
- (opt)dnsNames: The DNS names of the certificate (default: [name])
- (opt)literalSubject: The literal subject (default: CN=<name>,OU=<ou>,O=siros-id)
- (opt)secretName: The secret name (default: <name>-cert)
- (opt)issuerRef: The issuer name (default: global.certManager.clientCertificate.issuerRef)
- (opt)rotationPolicy: The private key rotation policy (default: Always)
- (opt)duration: The duration of the certificate (default: 2160h)
- (opt)privateKeyAlgorithm: The private key algorithm (default: ECDSA)
- (opt)privateKeySize: The private key size (default: 256)
*/}}
{{- define "siros-id.certificate" -}}
{{- $root := index . 0 -}}
{{- $params := index . 1 -}}
{{- $_ := required "Certificate name must be set" $params.name -}}
{{- $_ := required "Certificate usages must be set" $params.usages -}}
{{ if (and (not $params.literalSubject) (not $params.ou)) -}}
{{- fail "Certificate OU or literalSubject must be set" -}}
{{- end -}}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ $params.name | quote }}
  namespace: {{ include "siros-id.namespace" $root | quote }}
  {{- include "siros-id.labels" (list $root (dict)) | nindent 2 }}
  {{- include "siros-id.annotations" (list $root (dict)) | nindent 2 }}
spec:
  literalSubject: {{ $params.literalSubject | default (printf "CN=%s,OU=%s,O=siros-id" $params.name $params.ou) | quote }}
  secretName: {{ $params.secretName | default (printf "%s-cert" $params.name) | quote }}
  privateKey:
    algorithm: {{ $params.privateKeyAlgorithm | default "ECDSA" | quote }}
    size: {{ $params.privateKeySize | default 256 }}
    rotationPolicy: {{ $params.rotationPolicy | default "Always" }}
  duration: {{ $params.duration | default "2160h" }}
  additionalOutputFormats:
    - type: CombinedPEM
  usages: 
    {{- range $params.usages }}
    - {{ . | quote }}
    {{- end }}
  dnsNames:
    {{- range ($params.dnsNames | default (list $params.name)) }}
    - {{ . | quote }}
    {{- end }}
  issuerRef:
    name: {{ $params.issuerRef | default ($root.Values.global.certManager.clientCertificate.issuerRef) | quote }}
    kind: Issuer
    group: cert-manager.io
{{- end -}}

{{/* Generate a podDisruptionBudget template.
Call with (list . (dict "name" "example")).
Params:
- name: The name of the podDisruptionBudget 
- minAvailable: The minimum available pods
*/}}
{{- define "siros-id.podDisruptionBudget" -}}
{{- $root := index . 0 -}}
{{- $params := index . 1 -}}
{{- $_ := required "PodDisruptionBudget name must be set" $params.name -}}
{{- $_ := required "PodDisruptionBudget minAvailable must be set" $params.minAvailable -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ $params.name | quote }}
  namespace: {{ include "siros-id.namespace" $root | quote }}
  {{- include "siros-id.labels" (list $root (dict)) | nindent 2 }}
  {{- include "siros-id.annotations" (list $root (dict)) | nindent 2 }}
spec:
  minAvailable: {{ $params.minAvailable }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ $params.name | quote }}
{{- end -}}

{{/* Generate a podSecurityContext template. 
Params:
- (opt)runAsUser: The user to run as (default: 65532)
- (opt)runAsGroup: The group to run as (default: same as runAsUser)
- (opt)fsGroup: The fs group to use (default: same as runAsGroup)
- (opt)seccompProfile: The seccomp profile to use (default: RuntimeDefault)
*/}}
{{- define "siros-id.podSecurityContext" -}}
{{- $runAsUser := .runAsUser | default 65532 -}}
{{- $runAsGroup := .runAsGroup | default $runAsUser -}}
{{- $fsGroup := .fsGroup | default $runAsGroup -}}
securityContext:
  runAsNonRoot: true
  runAsUser: {{ $runAsUser }}
  runAsGroup: {{ $runAsGroup }}
  fsGroup: {{ $fsGroup }}
  seccompProfile:
    type: {{ .seccompProfile | default "RuntimeDefault" | quote }}
{{- end -}}

{{/* Container securityContext template. 
allowPrivilegeEscalation and capabilities can't be set in the podSecurityContext.
*/}}
{{- define "siros-id.containerSecurityContext" -}}
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
{{- end -}}

{{/* Pod-level imagePullSecrets from global values. Omitted when empty. */}}
{{- define "siros-id.imagePullSecrets" -}}
{{- with .Values.global.imagePullSecrets -}}
imagePullSecrets: {{- toYamlPretty . | nindent 2 }}
{{- end -}}
{{- end -}}

{{/* Container-level imagePullPolicy from global values. Omitted when empty. */}}
{{- define "siros-id.imagePullPolicy" -}}
{{- with .Values.global.imagePullPolicy -}}
imagePullPolicy: {{ . | quote }}
{{- end -}}
{{- end -}}

{{/* Pod-level topologySpreadConstraints from global values with per-workload labelSelector.
Call with (list . (dict "name" "wallet-backend")).
Params:
- name: value for labelSelector.matchLabels.app.kubernetes.io/name (required)
*/}}
{{- define "siros-id.topologySpreadConstraints" -}}
{{- $root := index . 0 -}}
{{- $name := index . 1 -}}
{{- $_ := required "topologySpreadConstraints name must be set" $name -}}
{{- with $root.Values.global.topologySpreadConstraints -}}
topologySpreadConstraints:
  {{- toYamlPretty . | nindent 2 }}
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: {{ $name }}
    matchLabelKeys:
      - pod-template-hash
{{- end -}}
{{- end -}}

{{/* Standard HTTP liveness/startup/readiness probes.
Params:
- path: The HTTP path to probe (required)
- (opt)port: The port name to probe (default: http-main)
- (opt)readyPath: The HTTP path to probe for readiness (default: same as path)
- (opt)readyPort: The port name to probe for readiness (default: same as port)
*/}}
{{- define "siros-id.httpProbes" -}}
{{- $port := .port | default "http-main" -}}
{{- $readyPath := .readyPath | default .path -}}
{{- $readyPort := .readyPort | default $port -}}
livenessProbe:
  periodSeconds: 3
  timeoutSeconds: 2
  failureThreshold: 3
  httpGet:
    path: {{ .path | quote }}
    port: {{ $port }}
startupProbe:
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 10
  httpGet:
    path: {{ .path | quote }}
    port: {{ $port }}
readinessProbe:
  periodSeconds: 2
  timeoutSeconds: 2
  failureThreshold: 2
  httpGet:
    path: {{ $readyPath | quote }}
    port: {{ $readyPort }}
{{- end -}}

{{/* Generate a Service for an app.
Call with (list . (dict "name" "example" "ports" (list (dict "name" "http-main" "port" 80 "targetPort" 8080)))).
Params:
- name: The name of the Service and the app selector (required)
- ports: A list of dicts with name, port and targetPort (required)
*/}}
{{- define "siros-id.service" -}}
{{- $root := index . 0 -}}
{{- $params := index . 1 -}}
{{- $_ := required "Service name must be set" $params.name -}}
{{- $_ := required "Service ports must be set" $params.ports -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ $params.name | quote }}
  namespace: {{ include "siros-id.namespace" $root | quote }}
  {{- include "siros-id.labels" (list $root (dict)) | nindent 2 }}
  {{- include "siros-id.annotations" (list $root (dict)) | nindent 2 }}
spec:
  selector:
    app.kubernetes.io/name: {{ $params.name | quote }}
  {{- with $root.Values.global.service.trafficDistribution }}
  trafficDistribution: {{ . }}
  {{- end }}
  ports:
    {{- range $params.ports }}
    - name: {{ .name | quote }}
      port: {{ .port }}
      targetPort: {{ .targetPort }}
    {{- end }}
{{- end -}}

{{/* Generate an HTTPRoute routing a public hostname to a backend Service.
Call with (list . (dict "name" "example" "hostname" "example.com")).
Params:
- name: The name of the route and the backend Service (required)
- hostname: The public hostname (required)
- (opt)port: The backend Service port (default: 80)
*/}}
{{- define "siros-id.hostnameHttpRoute" -}}
{{- $root := index . 0 -}}
{{- $params := index . 1 -}}
{{- $_ := required "HTTPRoute name must be set" $params.name -}}
{{- $_ := required "HTTPRoute hostname must be set" $params.hostname -}}
{{- $_ := required "HTTPRoute parentRef name must be set" $root.Values.gateway.name -}}
{{- $_ := required "HTTPRoute parentRef namespace must be set" $root.Values.gateway.namespace -}}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $params.name | quote }}
  namespace: {{ include "siros-id.namespace" $root | quote }}
  {{- include "siros-id.labels" (list $root (dict)) | nindent 2 }}
  {{- include "siros-id.annotations" (list $root (dict)) | nindent 2 }}
spec:
  parentRefs:
    - name: {{ $root.Values.gateway.name }}
      namespace: {{ $root.Values.gateway.namespace }}
  hostnames:
    - {{ $params.hostname }}
  rules:
    - backendRefs:
        - name: {{ $params.name | quote }}
          port: {{ $params.port | default 80 }}
{{- end -}}

{{/* Mongo client config fragment for the service config files.
Call with (list . "database_name").
Expects the client certificate to be mounted at /client-cert.
*/}}
{{- define "siros-id.vc.config.mongo" -}}
{{- $root := index . 0 -}}
{{- $database := index . 1 -}}
mongo:
  uri: mongodb+srv://mongodb-svc.{{ include "siros-id.namespace" $root }}.svc.{{ $root.Values.global.clusterDomain }}/{{ $database }}?replicaSet=mongodb&ssl=true&authMechanism=MONGODB-X509
  tls: true
  ca_file_path: /client-cert/ca.crt
  cert_file_path: /client-cert/tls.crt
  key_file_path: /client-cert/tls.key
{{- end -}}

{{/* Tracing config fragment for the service config files.
Call with the root context.
*/}}
{{- define "siros-id.vc.config.tracing" -}}
tracing:
  enable: {{ .Values.features.otlpCollector }}
  addr: otlp-collector:4318
{{- end -}}

{{/* mTLS gRPC client config fragment for the service config files.
Call with the name of the target service, e.g. (include ... "issuer-registry").
Expects the client certificate to be mounted at /client-cert.
*/}}
{{- define "siros-id.vc.config.grpcClient" -}}
addr: {{ . }}:8090
tls: true
server_name: {{ . }}
ca_file_path: /client-cert/ca.crt
cert_file_path: /client-cert/tls.crt
key_file_path: /client-cert/tls.key
{{- end -}}

{{/* issuer/verifier cert chain-gen init container template
*/}}
{{- define "siros-id.certChainGenInitContainer" -}}
- name: cert-chain-gen
  image: {{ .Values.images.alpine | quote }}
  {{- include "siros-id.imagePullPolicy" . | nindent 2 }}
  {{- include "siros-id.containerSecurityContext" (dict) | nindent 2 }}
  volumeMounts:
    - name: sign-cert
      mountPath: /sign-cert
      readOnly: true
    - name: sign-cert-chain
      mountPath: /sign-cert-chain
  command:
    - /bin/sh
    - -c
    - cat /sign-cert/tls.crt /sign-cert/ca.crt > /sign-cert-chain/tls.crt
{{- end -}}

{{/* issuer/verifier secrets renderer init container template
Params:
- secretName: The name of the secret to use (required)
- envs: The environment variables to set (required)
*/}}
{{- define "siros-id.secretsRendererInitContainer" -}}
{{- $root := index . 0 -}}
{{- $params := index . 1 -}}
{{- $_ := required "Secret name must be set" $params.secretName -}}
{{- $_ := required "Environment variables must be set" $params.envs -}}
- name: secrets-renderer
  image: {{ $root.Values.images.opsStackUtilities | quote }}
  {{- include "siros-id.imagePullPolicy" $root | nindent 2 }}
  {{- include "siros-id.containerSecurityContext" (dict) | nindent 2 }}
  volumeMounts:
    - name: main-config
      mountPath: /main-config
      readOnly: true
    - name: secrets-rendered
      mountPath: /secrets-rendered
  env:
    {{- range $envName, $key := $params.envs }}
    - name: {{ $envName }}
      valueFrom:
        secretKeyRef:
          name: {{ $params.secretName }}
          key: {{ $key }}
    {{- end }}
  command:
    - /bin/sh
    - -c
    - envsubst < /main-config/secrets.yaml.template > /secrets-rendered/secrets.yaml
{{- end -}}


{{/* API auth config template for issuer/verifier components
We use "fail" here instead of "required" because required can't handle bools.
*/}}
{{- define "siros-id.vc.config.apiAuth" -}}
{{- if not (or .Values.issuer.apiAuth.jwks.enabled .Values.issuer.apiAuth.oidc.enabled) -}}
{{- fail "issuer.apiAuth.jwks.enabled or issuer.apiAuth.oidc.enabled is required" -}}
{{- end -}}
api_auth:
  rules:
    - "(vc (service *)(method *)(path /api/v1/*)(subject admin@{{ .Values.tenant.id }})(authentic_source *)(scope *))"
{{- if .Values.issuer.apiAuth.jwks.enabled }}
  jwks:
    enable: true
    issuer: {{ .Values.issuer.apiAuth.jwks.issuer | quote }}
    audience: https://{{ include "siros-id.hostname.issuer" . }}
    jwks_file_path: /main-config/api_auth_jwks.json
{{ else if .Values.issuer.apiAuth.oidc.enabled }}
  oidc:
    enable: true
    issuer_url: {{ .Values.issuer.apiAuth.oidc.issuerUrl | quote }}
    client_id: {{ .Values.issuer.apiAuth.oidc.clientId | quote }}
    redirect_uri: {{ .Values.issuer.apiAuth.oidc.redirectUri | quote }}
    scopes: {{- toYamlPretty .Values.issuer.apiAuth.oidc.scopes | nindent 4 }}
{{- end -}}
{{- end -}}
