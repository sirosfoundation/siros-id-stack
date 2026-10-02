# siros-id-stack

## Introduction
This Helm Chart aims to help users configure and deploy components in the "SIROS ID stack".
In addition, it may also serve as practical reference for working component configuration.

**Warning:** This chart is under heavy development and has some rough edges. Review open issues before usage.

## Features
Sets up the SIROS ID Stack:
- [go-wallet-backend](https://github.com/sirosfoundation/go-wallet-backend)
- [wallet-frontend](https://github.com/sirosfoundation/wallet-frontend)
- Trust infrastructure with [go-trust (pdp)](https://github.com/sirosfoundation/go-trust)
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
* ci/values-emrtd.yaml - overlay that enables the eMRTD document signer registry on the PDP (placeholder image)
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

## eMRTD document signer trust (PDP)
The PDP ([go-trust](https://github.com/sirosfoundation/go-trust)) can answer one extra question for a policy
enforcement point (PEP) that has already verified an electronic passport or ID card chip: *does the Document
Signer Certificate (DSC) chain, for the claimed issuing state, to a reviewed CSCA anchor?* This is the `emrtd`
registry, available from go-trust 0.24.0. The feature is **disabled by default**; with `pdp.emrtd.enabled: false`
the rendered PDP is unchanged.

When enabled, the chart renders `registries.emrtd` and the policy `policies.policies.emrtd-document-signer`
(`require_key_binding: true`, `allowed_key_types: [x5c]`) into the PDP configuration, and adds an init container that
copies the reviewed anchors from a data-only image into an `emptyDir` mounted read-only at `/emrtd`
(`anchors_dir: /emrtd/anchors`, `crls_dir: /emrtd/crls`). Existing actions (`pid-provider`, `verifier`, ...) keep being
decided by their own registries; no `default_policy` is set.

### Values
| value | default | meaning |
|---|---|---|
| `pdp.emrtd.enabled` | `false` | Render the registry, policy, init container and volume |
| `pdp.emrtd.registryName` | `emrtd-csca` | Registry name, referenced by the policy |
| `pdp.emrtd.description` | `eMRTD CSCA anchors` | Free text |
| `pdp.emrtd.pathLenMode` | `""` | `ignore` or `enforce` (RFC 5280 `pathLenConstraint`); empty keeps go-trust's default (ignore) |
| `pdp.emrtd.pathLenOverride` | `null` | Integer >= 0, used instead of each certificate's own limit; implies `enforce`, not valid with `ignore` |
| `pdp.emrtd.watch` | `true` | Reload on file changes. Here the data only changes when the pod is replaced |
| `pdp.emrtd.anchors.image` | `""` | **Required when enabled.** `repository:tag` or `repository@sha256:...` |
| `pdp.emrtd.anchors.pullPolicy` | `""` | Defaults to `global.imagePullPolicy` |
| `pdp.emrtd.anchors.pullSecrets` | `[]` | Secret names (not created by the chart) for pulling the anchors image, merged with `global.imagePullSecrets` |
| `pdp.emrtd.anchors.resources` | small requests/limits | Init container resources; keep them within the pod-level `resources.pdp` |
| `pdp.emrtd.crls.enabled` | `true` | Set `crls_dir`. Without it no revocation check is made |

Misconfiguration fails at `helm template` time: a missing anchors image, `images.pdp` older than 0.24.0 (when the tag
parses as semver), an invalid `pathLenMode`, a `pathLenOverride` combined with `ignore`, or `pdp.extraRegistries`
defining its own `emrtd`. Types and unknown keys under `pdp.emrtd` are checked by `values.schema.json`.
Extra policies can still be added through `pdp.configOverrides` (maps are merged, see
[docs/CONFIG_OVERRIDES.md](docs/CONFIG_OVERRIDES.md)). A test overlay is in `ci/values-emrtd.yaml`.

### Publishing and pinning the anchors image
The anchors are released by the `emrtd-trust-anchors` repository as the **private** container image
`ghcr.io/sirosfoundation/emrtd-trust-anchors`, tagged `vYYYY.MM.DD.N`. Each release records its immutable digest in
the release notes. Pin the digest, and raise the pin in a reviewed change for every release (including revocations):
```yaml
pdp:
  emrtd:
    enabled: true
    anchors:
      image: ghcr.io/sirosfoundation/emrtd-trust-anchors@sha256:<digest from the release notes>
      pullSecrets: [ghcr-emrtd-read]
```
Changing the image changes the pod spec, so the PDP is rolled and the init container installs the new content.
Configuration changes are handled by Reloader as for the rest of the PDP. After each rollout check the PDP log line
`emrtd anchors loaded` for the number of countries and anchors actually loaded.

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
and list its name in `pdp.emrtd.anchors.pullSecrets` (or in `global.imagePullSecrets`).

### Pointing the PEP (facetec-api) at the PDP
The PEP calls the AuthZEN endpoint `POST /evaluation` of the PDP with action name `emrtd-document-signer`, subject
`{"type": "key", "id": "<ISSUING STATE ALPHA-3>"}` and resource `{"type": "x5c", "id": "<same>", "key": ["<DSC base64 DER>", ...]}`.
For facetec-api: set `TRUST_PDP_URL` to the PDP base URL, use the action name `emrtd-document-signer`, and set
`trust.required` so that anything other than `decision: true` (including errors and timeouts) is not trusted. Inside
this cluster the PDP is `http://pdp.<tenant-namespace>.svc.<clusterDomain>`.

### Open points
* **The PDP is not exposed and has no authentication.** No ingress or HTTPRoute exists for it, and this chart adds
  none. The PDP NetworkPolicy admits only wallet-backend, verifier and issuer-apigw. A facetec-api that runs inside
  the cluster needs an additional ingress rule for its pods; one that runs outside needs a path to the PDP that the
  operator secures (private network, network policy, or a gateway with its own authentication in front, since facetec-api's
  PDP client sends no credentials). Neither is chart behaviour.
* The PDP answers with certificate fingerprints and subjects in `context.reason.admin`; this is meant for service
  callers and must not be passed on to end users.
* `signing_time` is taken on the caller's word: the PEP must derive it from a verified SOD.
* go-trust 0.23.0 enables rate limiting (100 requests/s per peer address, burst 10) and keys it on the peer address;
  a gateway in front of the PDP shares one bucket unless `security.trusted_proxies` is set (via `pdp.configOverrides`).
* The anchors are copied once per pod start; a revocation reaches the PDP only when the pin is changed and the pod is rolled.
* The data is for internal trust evaluation only (see the licence notice in the image).

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
