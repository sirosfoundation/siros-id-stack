# Configuration overrides

## Introduction
The "configOverrides" feature provided through values.yaml enables operators to modify the "raw"
configuration of certain components. It's purpose is to enable experiments, development and testing
of new features without requiring integration into the Helm chart.

This documentation aims to describe how it works and its limitations.

## Overriding YAML configuration
For components that utilize YAML files for their configuration (most of them), the user should
define a YAML dictionary with their desired additions/modifications. This dictionary will be merged
with the rendered and deserialized version of the configuration file template (before being
serialized into YAML again) - if a value exist in both, the override will take precedece.

The same limitations exists as when supplying multiple values files in Helm: lists/arrays can not
be merged, their content will be replaced by the one defined in the override.

## VCTM registry configuration layout (wallet-backend)
The wallet-backend pod also runs the VCTM registry role. `walletBackend.registryConfigLayout`
selects how it is configured:

- `legacy` (default): a separate `registry.yaml` is rendered into the `wallet-backend-main`
  ConfigMap and passed to the backend with `-registry-config`. Use this with go-wallet-backend
  images that do not include sirosfoundation/go-wallet-backend#431.
- `integrated`: the registry settings are rendered as a `registry:` section inside
  `backend.yaml`; the `registry.yaml` key and the `-registry-config` argument are gone. Requires
  an image that includes #431.

`walletBackend.registryExtraConfig` (registry-section layout) is deep-merged into the registry
settings in both layouts; `require_auth` is written as `jwt.require_auth` in `legacy`. In
`integrated`, `configOverrides.server.main."registry.yaml"` is rejected (move its content to
`registryExtraConfig`), and server/logging/http_client settings belong to `backend.yaml`.

Switching: deploy an image with #431 first (`images.walletBackend`), then set
`registryConfigLayout: integrated`. Roll back by setting `legacy` again (before or together with
reverting the image).
