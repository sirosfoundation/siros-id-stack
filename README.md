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
* https://backend.example.localhost (using the header X-Tenant-Id: example-tenant)
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
