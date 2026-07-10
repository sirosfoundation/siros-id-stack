#!/usr/bin/env bash
set -u

# get your bearer token
BEARER_TOKEN=""
ISSUER_URL="https://<YOUR-TENANT>.issuer.example.localhost"

IDENTITY='''
{
    "authentic_source_person_id": "authentic_source_person_id_2001",
    "authentic_source": "MockTaxAuthority",
    "attributes": {
    "birth_date": "1948-04-03",
    "family_name": "Meier",
    "given_name": "Laban"
    }
}
'''

DOCUMENT='''
{
    "meta": {
        "authentic_source": "MockTaxAuthority",
        "scope": "demo_pid_rb_1_5",
        "document_id": "document_id_demo_pid_rb_1_5_2001",
        "created_at": "0001-01-01T00:00:00Z"
    },
    "identity_mapping_ids": [
        "194804032094"
    ],
    "document_data": {
        "address": {
            "country": "SE",
            "formatted": "Tulegatan 11, Stockholm",
            "house_number": "11",
            "locality": "Stockholm",
            "postal_code": "11353",
            "region": "Stockholm",
            "street_address": "Tulegatan"
        },
        "birth_family_name": "Meier",
        "birth_given_name": "Laban",
        "birthdate": "1948-04-03",
        "date_of_expiry": "2027-05-19T15:07:11+02:00",
        "date_of_issuance": "2026-04-19T15:07:11+02:00",
        "document_number": "doc-demo_pid_rb_1_5-2001",
        "email": "meier@example.com",
        "family_name": "Meier",
        "given_name": "Laban",
        "issuing_authority": "SUNET",
        "issuing_country": "SE",
        "issuing_jurisdiction": "SUNET",
        "nationalities": [
            "SE"
        ],
        "personal_administrative_number": "pan-2001",
        "phone_number": "+46700000000",
        "picture": "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAFElEQVQYV2P8z8DwHwYGBgZGMAEADigBCCGZkB0AAAAASUVORK5CYII=",
        "place_of_birth": {
            "country": "SE",
            "locality": "Tulegatan 11",
            "region": "Stockholm"
        },
        "sex": "0"
    }
}
'''

curl -H "Authorization: Bearer $BEARER_TOKEN" --json "$IDENTITY" "$ISSUER_URL/api/v1/identity/mapping"
curl -H "Authorization: Bearer $BEARER_TOKEN" --json "$DOCUMENT" "$ISSUER_URL/api/v1/datastore"
