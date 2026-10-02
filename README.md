# siros-id-stack

## Introduction
This Helm Chart aims to help users configure and deploy components in the "SIROS ID stack".
In addition, it may also serve as practical reference for working component configuration.

**Warning:** This chart is under heavy development and has some rough edges. Review open issues before usage.

## Features
Sets up the SIROS ID Stack:
- [go-wallet-backend](https://github.com/sirosfoundation/go-wallet-backend)
- [wallet-frontend](https://github.com/sirosfoundation/wallet-frontend)
- Trust infrastructure with [go-trust (pdp)](https://github.com/sirosfoundation/go-trust), optionally a dedicated eMRTD PDP
- Issuers and verifiers with [vc](https://github.com/sirosfoundation/vc)
- Highly recommended but optional use of [Reloader](https://github.com/stakater/Reloader) for automatic configuration rollouts
- Kubernetes Features
  - Gateway API
  - certificates via [cert-manager](https://github.com/cert-manager/cert-manager) operator
  - mongodb setup via [mongodb-kubernetes-operator](https://github.com/mongodb/mongodb-kubernetes-operator)
  - Network Policies
  - Pod Disruption Budgets
  - CronJobs

## Requirements
- Helm 4
- Kubernetes 1.34 (due to pod-level resource requests/limits)
- Gateway API, ingress is **NOT** supported at this time
- [cert-manager](https://github.com/cert-manager/cert-manager) (tested with 1.20.0)
- [mongodb-kubernetes-operator](https://github.com/mongodb/mongodb-kubernetes-operator), community edition is supported (tested with 1.8.0)

## Required values
The following must be set in your values overlays (the chart defaults alone are not deployable):
- `tenant.id` — logical tenant identifier
- `domain.root` — base domain for hostnames
- `features.credentialTypes` — at least one credential type definition
- `issuer.apiAuth.jwks.enabled` or `issuer.apiAuth.oidc.enabled` — issuer API authentication
- `gateway.name` - name of the shared gateway to attach HTTPRoutes to

## Commonly modified values
- `networkPolicies.kubeApiServerPort` - port of the kube-apiserver if not 6443
- `networkPolicies.ciliumNetworkPolicies` - if you are using Cilium. Required because of network policy access to the kube-apiserver.
- `global.clusterDomain` - k8s cluster domain if not `cluster.local`

## Examples
* values-demo.yaml - demo values for the stack, including credentials. Expects that the issuer authProvider has an account providing the following claims:
  * "birth_date": "1988-09-09"
  * "family_name": "Oldman"
  * "given_name": "Gary"
* example-tenant.yaml - example with required values defined
* ci/values-emrtd.yaml - overlay that enables the dedicated eMRTD PDP (placeholder digest and selectors)
* config/demo - demo credentials, documents and identities
* quickstart - example values and scripts

### Demo credentials

`values-demo.yaml` declares two groups of credential types:

| scope | vct | issuance |
|---|---|---|
| `demo_1` | `urn:demo:1` | OIDC claims, built on the fly |
| `demo_pid_rb_1_5` | registry URL | OIDC login, from the datastore |
| `ehic` | `urn:eudi:ehic:1` | PID presentation |
| `diploma` | `urn:eudi:diploma:1` | PID presentation |
| `ebw_oid` | `uri:eu.ebw.oid.1` | PID presentation |
| `eucc` | `urn:eudi:eucc:1` | PID presentation |
| `eu_poa` | `uri:eu.eudi.eu-poa.1` | PID presentation |
| `iban_ov` | `eu.we-build.iban-ov.1` | PID presentation |

The last four are the [WE BUILD](https://we-build.eu) EU Business Wallet
attestations - owner identification (ds001), the company-register extract
(ds004), a power of attorney (ds007) and IBAN ownership verification. Their
type metadata is served from
[registry.siros.org](https://registry.siros.org/webuild-consortium).

Every type marked *PID presentation* is issued through an OpenID4VP
presentation of `demo_pid_rb_1_5` (`issuance.authProvider: openid4vp`,
`source: datastore`): the holder gets a PID first, and the identity in that
PID - given name, family name, date of birth - selects which documents come
out of the datastore. Business attestations work this way because they say
something about a legal person *through* the natural person representing it,
which is how they would be issued in a live setting.

The sample documents in `config/demo` give both demo identities a company of
their own, so either one can exercise the full set:

| demo user | company | EBW-OID | EUCC | EU PoA | IBAN-OV |
|---|---|---|---|---|---|
| 100 - Helen Mirren | Aurora Analytics AB (SE) | yes | yes | attorney for Rheinmark Logistik | SEB account |
| 102 - Gary Oldman | Rheinmark Logistik GmbH (DE) | yes | yes | attorney for Aurora Analytics | Deutsche Bank account |

Each person holds a power of attorney for the *other* person's company, so
the two-party case is testable from either identity. The verifier gets
matching presentation-request templates and two presets ("Demo: Company
identity", "Demo: Representation + company account").

Note that documents are imported only when the datastore is initialised. An
environment that already holds data will not pick up a new credential type on
upgrade - clear the datastore, or add the documents through the issuer API
(see `quickstart/add-documents.sh`).

## Dedicated eMRTD PDP
The `pdpEmrtd` block deploys a **second, dedicated** go-trust instance (Service `pdp-emrtd`) that answers one question
for a policy enforcement point (PEP) that has already verified an electronic passport or ID card chip: *does the
Document Signer Certificate (DSC) chain, for the claimed issuing state, to a reviewed CSCA anchor?* (the go-trust
`emrtd` registry, go-trust >= 0.24.0). It is **disabled by default**; with `pdpEmrtd.enabled: false` nothing is rendered
and the shared `pdp` is untouched.

Why a separate PDP and not another registry in the shared `pdp`:
* facetec-api, the PEP, accepts only an `https://` PDP URL (plain `http://` only on loopback) and sends no credentials.
  The shared PDP serves wallet-backend, issuers and verifiers and must not be made reachable for it.
* The shared PDP must not roll every time the (weekly) anchors image changes; the eMRTD PDP rolls on exactly that.
* It has its own rate-limit bucket.
* Only the dedicated PDP needs the pull secret for the private anchors image.

The chart renders for the eMRTD PDP: its own ConfigMap `pdp-emrtd-main` containing **only** `registries.emrtd` and
`policies.policies.emrtd-document-signer` (`require_key_binding`, `allowed_key_types: [x5c]`, optional `emrtd.path_len_*`,
`fail_closed_on_unknown_action: true`; no whitelist, mDOC IACA or always-trusted registry), a Deployment `pdp-emrtd`
(init container from the anchors image copying `/anchors` and `/crls` into an `emptyDir` via `TARGET=/emrtd`, mounted
read-only at `/emrtd`; non-root, read-only root filesystem for the init container, all capabilities dropped; Reloader
annotation; PodDisruptionBudget), a ClusterIP Service `pdp-emrtd` (port 80) and a NetworkPolicy. **No Ingress or
HTTPRoute is created.** The NetworkPolicy denies everything by default: ingress only from `pdpEmrtd.networkPolicy.allowFrom`
on the http port, no egress at all (the anchors are local files).

### Values
| value | default | meaning |
|---|---|---|
| `pdpEmrtd.enabled` | `false` | Render the dedicated PDP |
| `pdpEmrtd.replicas` | `1` | Replicas |
| `pdpEmrtd.image` | `""` | go-trust image, must be >= 0.24.0; defaults to `images.pdp` |
| `pdpEmrtd.externalUrl` | `http://pdp-emrtd` | go-trust `server.external_url` (discovery document only) |
| `pdpEmrtd.logging.level` / `.format` | `info` / `json` | go-trust logging |
| `pdpEmrtd.trustedProxies` | `[]` | CIDRs whose `X-Forwarded-For` is believed (`security.trusted_proxies`); set when a gateway/mesh is in front |
| `pdpEmrtd.registryName`, `.description` | `emrtd-csca` | Registry name (referenced by the policy) and description |
| `pdpEmrtd.pathLenMode` | `""` | `ignore` or `enforce` (RFC 5280 `pathLenConstraint`); empty keeps go-trust's default (ignore) |
| `pdpEmrtd.pathLenOverride` | `null` | Integer >= 0 used instead of each certificate's limit; implies `enforce`, invalid with `ignore` |
| `pdpEmrtd.watch` | `true` | Reload on file changes; here the data only changes when the pod is replaced |
| `pdpEmrtd.anchors.image` | `""` | **Required when enabled.** `repository@sha256:<digest>` (strongly recommended) or `repository:tag` |
| `pdpEmrtd.anchors.pullPolicy` | `""` | Defaults to `global.imagePullPolicy` |
| `pdpEmrtd.anchors.pullSecrets` | `[]` | Secret names (not created by the chart), merged with `global.imagePullSecrets` |
| `pdpEmrtd.anchors.resources` | small | Init container resources; keep within `pdpEmrtd.resources` (pod-level) |
| `pdpEmrtd.crls.enabled` | `true` | Set `crls_dir`; without it no revocation check is made |
| `pdpEmrtd.networkPolicy.allowFrom` | `[]` | **Required when enabled.** NetworkPolicyPeer list (pod/namespace selectors, ipBlock) that may call the PDP. facetec-api is not part of this chart: the operator names it |
| `pdpEmrtd.resources`, `.podDisruptionBudget.minAvailable` | small, `0` | Pod-level resources, PDB |
| `pdpEmrtd.configOverrides.main."config.yaml"` | `{}` | Advanced, see [docs/CONFIG_OVERRIDES.md](docs/CONFIG_OVERRIDES.md) |

Misconfiguration fails at `helm template` time: missing `anchors.image` or `networkPolicy.allowFrom`, an image older than
0.24.0 (when the tag parses as semver), an invalid `pathLenMode`, `pathLenOverride` with `ignore` or negative. Types and
unknown keys under `pdpEmrtd` are checked by `values.schema.json`. A tag instead of a digest in `anchors.image` renders
fine but prints a warning in the install notes (`templates/NOTES.txt`). A test overlay is in `ci/values-emrtd.yaml`.

### Publishing and pinning the anchors image
The anchors are released by the `emrtd-trust-anchors` repository as the **private** container image
`ghcr.io/sirosfoundation/emrtd-trust-anchors`, tagged `vYYYY.MM.DD.N`; each release records its immutable digest in its
release notes. **Pin the digest** (a tag can be moved, and the anchors decide which passports are accepted) and raise the pin in
a reviewed change for every release, revocations included:
```yaml
pdpEmrtd:
  enabled: true
  anchors:
    image: ghcr.io/sirosfoundation/emrtd-trust-anchors@sha256:<digest from the release notes>
    pullSecrets: [ghcr-emrtd-read]
  networkPolicy:
    allowFrom:
      - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: <facetec namespace>}}
        podSelector: {matchLabels: {app.kubernetes.io/name: facetec-api}}
```
Changing the image changes the pod spec, so the eMRTD PDP (only) rolls and the init container installs the new content.
After each rollout check the log line `emrtd anchors loaded` for the number of countries and anchors actually loaded.

### Pull secret for the private package
Pulling needs a credential with `read:packages` (GHCR does not accept fine-grained tokens; use a classic token of a
dedicated machine user). Create the secret in the tenant namespace, with a token from your secret store:
```bash
kubectl create secret docker-registry ghcr-emrtd-read \
  --namespace <tenant-namespace> \
  --docker-server=ghcr.io \
  --docker-username=<machine-user> \
  --docker-password="$GHCR_READ_TOKEN"
```
and list its name in `pdpEmrtd.anchors.pullSecrets`.

### Pointing facetec-api at it
The PEP calls `POST /evaluation` with action `emrtd-document-signer`, subject `{"type": "key", "id": "<issuing state alpha-3>"}`
and resource `{"type": "x5c", "id": "<same>", "key": ["<DSC base64 DER>", ...]}`. For facetec-api set `TRUST_PDP_URL` to an
`https://` bare origin (it never follows redirects), keep the action name `emrtd-document-signer`, and set `trust.required` so
that anything other than `decision: true` (errors and timeouts included) is not trusted.

The Service speaks plain http and has no authentication, and facetec-api refuses a non-loopback `http://` URL. Choose one:
1. **TLS front.** Terminate TLS in a gateway or mesh in front of the Service `pdp-emrtd` (the chart creates none, on
   purpose) and authenticate callers there if facetec-api runs outside the cluster (private networking, mTLS or an authenticating
   gateway are the operator's responsibility). Name the front's pods/addresses in `networkPolicy.allowFrom`, and set
   `trustedProxies` so the rate limit is per client.
2. **Loopback sidecar.** Run go-trust as a second container in facetec-api's own pod, with `TRUST_PDP_URL=http://127.0.0.1:8080`.
   This chart is not involved; the following is the shape, with the same image, config and init container pattern:
```yaml
# in facetec-api's Deployment (not part of this chart)
spec:
  template:
    spec:
      imagePullSecrets: [{name: ghcr-emrtd-read}]
      volumes:
        - {name: pdp-config, configMap: {name: facetec-emrtd-pdp}}   # config.yaml as rendered in ConfigMap pdp-emrtd-main
        - {name: emrtd, emptyDir: {}}
      initContainers:
        - name: emrtd-anchors
          image: ghcr.io/sirosfoundation/emrtd-trust-anchors@sha256:<digest>
          env: [{name: TARGET, value: /emrtd}]
          volumeMounts: [{name: emrtd, mountPath: /emrtd}]
          securityContext: {runAsNonRoot: true, allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: [ALL]}}
      containers:
        - name: facetec-api
          env: [{name: TRUST_PDP_URL, value: "http://127.0.0.1:8080"}]
        - name: pdp
          image: ghcr.io/sirosfoundation/go-trust:0.24.0
          args: [--config, /main-config/config.yaml]   # server.host 127.0.0.1, port 8080
          volumeMounts:
            - {name: pdp-config, mountPath: /main-config, readOnly: true}
            - {name: emrtd, mountPath: /emrtd, readOnly: true}
```
   The ConfigMap can be taken from `helm template -s templates/03-pdp-emrtd.yaml` with `server.host` set to `127.0.0.1`
   through `pdpEmrtd.configOverrides`. On **Fly.io** a Machine runs one process: running facetec-api and go-trust together needs a
   process supervisor in one image (the anchors then have to be baked into that image, there is no init container), or two apps
   with Fly private networking between them. This is an unverified suggestion, nothing here was tried on Fly.

### Open points
* **Reachability and authentication are the operator's.** The eMRTD PDP has no per-caller authentication and facetec-api's
  PDP client sends no credentials. The chart only provides the deny-by-default NetworkPolicy, so someone has to decide where
  facetec-api runs (in-cluster, outside, or sidecar) and add the matching `allowFrom` entry or gateway. The chart exposes nothing.
* **Rate limit:** go-trust 0.23.0+ limits to 100 requests/s per peer address with burst 10, plenty for passport onboarding (one request per
  scan). Behind a gateway all callers share one bucket unless `pdpEmrtd.trustedProxies` is set.
* **Revocation lag:** CRLs ship inside the anchors image, so a revocation reaches the PDP only when the image is updated and the pod rolls.
  The anchors image must be refreshed more often than the CRLs it contains are reissued (anchors are released weekly, so every CRL we
  depend on needs an update interval longer than a week). Tracked in `sirosfoundation/emrtd-trust-anchors#46`; until then deploy the
  newest anchors release promptly.
* **Unknown config keys:** go-trust 0.24.0 only logs `Unknown config key ignored`; the strict startup error announced for 0.24.0 is
  not implemented. A misspelled key silently configures nothing, so test any rendered config (especially `configOverrides`) with the real
  binary and treat that log line as a failure.
* The PDP answers with certificate fingerprints and subjects in `context.reason.admin`: for service callers only, never for end users.
  `signing_time` is taken on the caller's word, so the PEP must derive it from a verified SOD.
* The anchors data is for internal trust evaluation only (see the licence notice in the image).

## Deployment Examples
Example of templating with local chart:
```bash
helm template --values values-demo.yaml --values example-tenant.yaml --output-dir output --validate .
```

Example of templating with versioned remote chart:
```bash
helm template --values values-demo.yaml --values example-tenant.yaml --output-dir output --validate oci://ghcr.io/sirosfoundation/siros-id-stack --version 1.0.0
```

Using the examples above, the routes created for the gateway API will be the following:
* https://example.localhost/id/example-tenant
* https://example-tenant.backend.example.localhost
* https://example-tenant.issuer.example.localhost
* https://example-tenant.verifier.example.localhost

### Debug
Use the `admin-tools` pod to debug the stack. It has 0 replicas by default, so you need to manually set it to 1.
Run `mongosh --tls --tlsCAFile /mongo-cert/ca.crt --tlsCertificateKeyFile /mongo-cert/tls-combined.pem 'mongodb+srv://mongodb-svc.siros-tenant-<YOUR-TENANT-ID>.svc.cluster.local/vc?replicaSet=mongodb&ssl=true&authMechanism=MONGODB-X509'` to connect to the database.

Use `db.adminCommand( { replSetGetStatus: 1 } )` to get the status of the replica set.
Use `db.runCommand( { listCollections: 1 } )` to list the collections in the database.
```bash
# List all databases
db.adminCommand( { listDatabases: 1 } )
# Get status of the replica set
db.adminCommand( { replSetGetStatus: 1 } )

# List the collections in the database
db.runCommand( { listCollections: 1 } )

# Drop a database
use issuer-apigw_cache
db.dropDatabase()
```
