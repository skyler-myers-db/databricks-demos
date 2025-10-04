Input schema (logical):
```json
{
  "select_csv": "comma-separated allowlisted columns",
  "filters_json": {
    "email": "string (exact match, case-insensitive)",
    "name": "string (exact match)",
    "name_contains": "string (case-insensitive substring)",
    "customer_id": "integer",
    "ip_addr": "string (exact match)",
    "phone": "string (exact match)",
    "modified_from": "ISO-8601 date or timestamp",
    "modified_to":   "ISO-8601 date or timestamp (exclusive)"
  },
  "sort_json": "reserved (stringified JSON array; ignored today)",
  "limit": "int 1..MAX_PAGE_SIZE (default 50, max from env)",
  "cursor": "opaque URL-safe base64 string returned by server"
}
```
---
## Allowed columns (projection):
customer_id, name, email, ip_addr, phone, modified_ts

## Keyset ordering:
ORDER BY modified_ts DESC, customer_id DESC

Cursor: Encodes {"after": [ "<ISO8601-modified_ts>", <customer_id> ] }

---

Output schema:
```json
{
  "count": "int number of items in this page",
  "items": [ { /* objects containing requested columns only (JSON-safe types) */ } ],
  "next_cursor": "string | null",
  "has_more": "boolean"
}
```
JSON Schema for filters_json (draft 2020‑12):
```json
{
  "$id": "https://example.com/schemas/customers.filters.json",
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "email": { "type": "string" },
    "name": { "type": "string" },
    "name_contains": { "type": "string" },
    "customer_id": { "type": "integer" },
    "ip_addr": { "type": "string" },
    "phone": { "type": "string" },
    "modified_from": {
      "type": "string",
      "description": "ISO-8601 date or timestamp"
    },
    "modified_to": {
      "type": "string",
      "description": "ISO-8601 date or timestamp (exclusive upper bound)"
    }
  }
}
```
---
OpenAPI style:
```yaml
openapi: 3.1.0
info:
  title: Customers Data API (via Databricks Model Serving)
  version: 1.0.0
paths:
  /serving-endpoints/customers-api/invocations:
    post:
      summary: Query customers with keyset pagination
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [dataframe_split]
              properties:
                dataframe_split:
                  type: object
                  required: [columns, data]
                  properties:
                    columns:
                      type: array
                      items:
                        enum: [select_csv, filters_json, sort_json, limit, cursor]
                    data:
                      type: array
                      items:
                        type: array
                        minItems: 5
                        maxItems: 5
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema:
                type: object
                properties:
                  predictions:
                    type: array
                    items:
                      type: object
                      properties:
                        count: { type: integer }
                        items: { type: array, items: { type: object } }
                        next_cursor: { type: [ "string", "null" ] }
                        has_more: { type: boolean }
```
Contract guarantees:
	•	next_cursor is opaque and may change shape; treat it as a token.
	•	Server may trim columns not in allowlist.
	•	limit is capped by MAX_PAGE_SIZE to protect the warehouse.
