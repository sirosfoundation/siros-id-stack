# WE BUILD credentials in the demo tenant

The demo tenant issues ten credential types. Six come from the
[WE BUILD attestation rulebooks catalogue][catalog]: EBWOID, EUCC, EU PoA,
IBAN-OV, VAT ID, eInvoice and eReceipt. This file covers what is specific to
those, and what currently does not work.

Work item: [sirosfoundation/ops-tasks#47][47].

[catalog]: https://github.com/webuild-consortium/webuild-attestation-rulebooks-catalog
[47]: https://github.com/sirosfoundation/ops-tasks/issues/47

## Where the type metadata comes from

`vctm_vat_id.json`, `vctm_einvoice.json` and `vctm_ereceipt.json` are
generated output, not hand-written, and they are generated **in
[demo-credentials][dc]**, which is the source of truth for these credentials.
Its `tools/make_webuild_vctms.py` derives them from the catalogue's JSON
Schemas using the same claim derivation `registry-cli` uses for the published
metadata on registry.siros.org. Refresh the copies here from there after the
catalogue changes; do not edit them in place.

A deployment repository should not be where credentials other things consume
are authored - sirosid-dev needs the same three, and did its own transcription
before this moved.

Generating rather than copying is deliberate. `vctm_ebw_oid.json` and
`vctm_eucc.json` were pasted out of registry output and arrived with no `sd`,
no rendering and a name taken off the schema title; they are being repaired by
hand in [#26][26] and [#28][28] and should move to demo-credentials too once
those land.

Three things the schemas cannot supply, and the generator does:

- **`sd`.** Each rulebook states disclosure in a prose table, not in the
  schema. It transcribes that table and cites the section. This
  matters more than it sounds: `registry-cli` infers disclosure from property
  descriptions, these schemas carry none, so every claim would otherwise
  default to `allowed` — the opposite of the rule for, say, every VAT ID
  claim that the tax administration requires in plain text.
- **`display`**, since a schema title is not a card name.
- **`rendering`**, which a schema has no place for.

`svg_id` is derived, not supplied, by the rule in [registry-cli#62][62], so a
template written against the registry's metadata also works against this
chart's.

[26]: https://github.com/sirosfoundation/siros-id-stack/pull/26
[28]: https://github.com/sirosfoundation/siros-id-stack/pull/28
[62]: https://github.com/sirosfoundation/registry-cli/pull/62

## Attributes with no claim

Some attributes a rulebook defines have no claim in the generated metadata, so
a verifier cannot request them and a card cannot render them. All three causes
are in the generator, and they compose — `merchant.address.city` on eReceipt
needs all three fixed.

| Cause | Effect here | Issue |
|---|---|---|
| `$ref` properties produce no children | eReceipt's `merchant.name`, the field that makes a receipt recognisable | [registry-cli#63][63] |
| Array items are not descended into | VAT ID's `validity_period.start_date` / `end_date`; eReceipt's `products[]` and `vats[]` line items | [registry-cli#64][64] |
| Objects below depth 2 produce no children | VAT ID's registered address and legal-person fields, all of which rb-vat-id §5.1 gives their own disclosure rule | [registry-cli#65][65] |

[63]: https://github.com/sirosfoundation/registry-cli/issues/63
[64]: https://github.com/sirosfoundation/registry-cli/issues/64
[65]: https://github.com/sirosfoundation/registry-cli/issues/65

## Where the rulebooks and the schemas disagree

Filed upstream; the documents here follow the schema, since that is what the
issuer validates against.

- **VAT ID** — the rulebook's `vct` is `uri:eu.eudi.vat.1` and the schema's is
  `uri:eu.eudi.vat.2`; six attribute paths in the §5.1 disclosure table name
  claims the schema does not have; and `economic_operator` is marked not
  selectively disclosable while its own sub-attributes are marked disclosable,
  which cannot both hold. [catalogue#333][c333]
- **eReceipt** — `verifications[]` uses `transactionId` in the rulebook and
  `transaction_id` in the schema, and the schema constrains `type` to a code
  list the rulebook does not mention. With `additionalProperties: false` a
  payload written from the rulebook does not validate. [catalogue#332][c332]

[c332]: https://github.com/webuild-consortium/webuild-attestation-rulebooks-catalog/issues/332
[c333]: https://github.com/webuild-consortium/webuild-attestation-rulebooks-catalog/issues/333

## What the demo does not show

Every type here is issued the same way: a document is pre-seeded in the
datastore, keyed to a demo subject through the identity mapping, and released
after the holder presents a PID over OpenID4VP.

For VAT ID, EUCC and EBWOID that is roughly the real flow — an authentic
source holds a record about a registered entity and attests to it.

For eInvoice and eReceipt it is not. rb-e-receipt §1 has an eReceipt "issued
by a merchant (or its Payment Service Provider) to the customer's EUDI Wallet
after a payment"; an eInvoice likewise originates from a seller's system at
the moment of invoicing. Neither is a register lookup, and no amount of chart
configuration makes the datastore model into one. What the demo does
demonstrate for these two is the half that follows: the wallet holding the
credential, rendering it, and presenting selected claims to a verifier.
[siros-id-stack#29][29] tracks the issuance side.

[29]: https://github.com/sirosfoundation/siros-id-stack/issues/29

## Demo subjects

Subjects `100` and `102` are the same companies across every business
credential, so a holder's EBWOID, EUCC and VAT ID describe one organisation:

| Subject | Company | Country | Identifier |
|---|---|---|---|
| 100 | Aurora Analytics AB | SE | `SEBOLAG.5591234567` |
| 102 | Rheinmark Logistik GmbH | DE | `DEHRB.B123456` |

For eInvoice and eReceipt the subject is the buyer or customer — the party who
would keep the document.

All six documents validate against the catalogue's schemas.
[dc]: https://github.com/sirosfoundation/demo-credentials
