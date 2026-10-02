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
