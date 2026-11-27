#!/usr/bin/env python3
"""Generate starting-point svg_templates for the business credentials.

These are a starting point for a designer, not finished assets.

How a template binds to data: the wallet builds an svg_id -> claim path map
from the type metadata's claims and substitutes every {{svg_id}} in the SVG
with that claim's value (wallet-common/src/rendering.ts). So a placeholder
only renders if some claim in the vctm carries a matching `svg_id`. The ids
used here are already set on vctm_ebw_oid.json and vctm_eucc.json.

Two rules worth knowing before editing:

  * svg_id must match ^[A-Za-z_][A-Za-z0-9_]*$, so a nested claim such as
    administrative_unit.vat_id needs a flat id (`vat_id`) whose claim entry
    carries the nested path.
  * Placeholders must be text. draft-ietf-oauth-sd-jwt-vc section 4.5.1.2.2
    permits no non-text placeholder, which is what ruled out {{portrait}} on
    the scanned passport in sirosfoundation/ops-tasks#18. There is therefore
    no per-issuer logo slot here.

A claim the verifier did not ask for renders as "-", so a template should
stay readable when a field is withheld.

House conventions, from vctm/siros_id_v1.svg in demo-credentials: 365x243,
Arial, rx 14.5, 1px #BDBDBD border, 9px labels, 11px values, 14px headline.
"""

import os

W, H = 365, 243
INK, MUTED, VALUE, SUBTLE, RULE, STROKE = (
    "#0C0E11", "#718096", "#1A202C", "#4A5568", "#E2E8F0", "#BDBDBD")


def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def label(x, y, text):
    return (f'<text x="{x}" y="{y}" font-family="Arial" font-size="9" '
            f'fill="{MUTED}" letter-spacing="0.8">{esc(text)}</text>')


def value(x, y, text, size=11, fill=VALUE, weight=None):
    w = f' font-weight="{weight}"' if weight else ""
    return (f'<text x="{x}" y="{y}" font-family="Arial" font-size="{size}" '
            f'fill="{fill}"{w}>{esc(text)}</text>')


def card(slug, accent, tint, type_label, headline, identifier, fields, footer):
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}" fill="none">',
        '<!-- Starting point for design. Double-brace placeholders bind to '
        'claims by svg_id; see make_templates.py. The wallet substitutes '
        'across the whole file, comments included, so do not write one here. -->',
        "<defs>",
        f'  <linearGradient id="bg_{slug}" x1="0" y1="0" x2="0" y2="{H}" '
        f'gradientUnits="userSpaceOnUse">',
        '    <stop offset="0" stop-color="#FFFFFF"/>'
        '<stop offset="1" stop-color="#F7F9FC"/>',
        "  </linearGradient>",
        f'  <clipPath id="card_{slug}"><rect x="0.5" y="0.5" width="{W - 1}" '
        f'height="{H - 1}" rx="14.5"/></clipPath>',
        "</defs>",
        f'<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="14.5" '
        f'fill="url(#bg_{slug})" stroke="{STROKE}"/>',
        f'<g clip-path="url(#card_{slug})">'
        f'<rect x="0" y="0" width="6" height="{H}" fill="{accent}"/></g>',
        f'<text x="26" y="32" font-family="Arial" font-size="9" fill="{accent}" '
        f'letter-spacing="0.8">{esc(type_label.upper())}</text>',
        value(26, 66, headline, size=14, fill=INK, weight="bold"),
        value(26, 85, identifier, size=11, fill=SUBTLE),
        f'<line x1="26" y1="112" x2="339" y2="112" stroke="{RULE}"/>',
    ]

    for index, (lab, placeholder) in enumerate(fields[:4]):
        x = (26, 190)[index % 2]
        y = 136 + (index // 2) * 34
        out.append(label(x, y, lab.upper()))
        out.append(value(x, y + 14, placeholder))

    out.append(f'<rect x="12" y="194" width="342" height="38" rx="8" fill="{tint}"/>')
    out.append(label(26, 211, footer[0].upper()))
    out.append(value(26, 225, footer[1]))
    out.append("</svg>")

    return "\n".join(out) + "\n"


CARDS = {
    "ebw_oid": dict(
        accent="#1A365D", tint="#EEF2F8",
        type_label="Business Wallet Owner ID",
        headline="{{name}}",
        identifier="{{id}}",
        fields=[
            ("Issuing authority", "{{issuing_authority}}"),
            ("Country", "{{issuing_country}}"),
            ("Expires", "{{date_of_expiry}}"),
            ("Attestation category", "{{attestation_legal_category}}"),
        ],
        footer=("Issued by", "{{issuing_authority}}"),
    ),
    "eucc": dict(
        accent="#14532D", tint="#EDF4EF",
        type_label="EU Company Certificate",
        headline="{{legal_person_name}}",
        identifier="{{legal_person_id}}",
        fields=[
            ("Legal form", "{{legal_form_type}}"),
            ("Status", "{{legal_person_status}}"),
            ("Registered", "{{registration_date}}"),
            ("Member State", "{{registration_member_state}}"),
        ],
        footer=("Business register", "{{authentic_source_name}}"),
    ),
}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    for slug, spec in CARDS.items():
        path = os.path.join(here, f"{slug}.svg")
        with open(path, "w") as handle:
            handle.write(card(slug, **spec))
        print(f"wrote {os.path.basename(path)}")


if __name__ == "__main__":
    main()
