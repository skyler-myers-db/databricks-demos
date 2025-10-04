import os, json, requests

HOST = dbutils.secrets.get(
    "demos",
    "host",
)  # e.g., https://dbc-xxxxxxxx-xxx.cloud.databricks.com
TOKEN = dbutils.secrets.get(
    "demos",
    "token",
)  # a PAT just to call Serving; not used by the model code
ENDPOINT = "customers"
URL = f"https://{HOST}/serving-endpoints/{ENDPOINT}/invocations"
headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}


def page(cursor=None):
    payload = {
        "dataframe_split": {
            "columns": ["select_csv", "filters_json", "sort_json", "limit", "cursor"],
            "data": [
                [
                    "customer_id,name,email",
                    json.dumps({"name_contains": "ali", "modified_from": "2025-10-01"}),
                    "[]",
                    5,
                    cursor,
                ]
            ],
        }
    }
    r = requests.post(URL, headers=headers, json=payload, timeout=60)
    r.raise_for_status()
    return r.json()["predictions"][0]


cur, n = None, 1
while True:
    res = page(cursor=cur)
    print(f"\nPage {n} (count={res['count']}, has_more={res['has_more']})")
    print(json.dumps(res["items"], indent=2, default=str))
    if not res["has_more"]:
        break
    cur, n = res["next_cursor"], n + 1
