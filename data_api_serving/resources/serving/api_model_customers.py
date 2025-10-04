import os, json, base64, logging
from typing import Any, Dict, List, Tuple, Optional
from datetime import datetime, date
from decimal import Decimal

import pandas as pd
import mlflow.pyfunc
from mlflow.models import set_model

LOG = logging.getLogger("api")
LOG.setLevel(logging.INFO)

CATALOG = os.getenv("DATA_CATALOG", "demo")
SCHEMA = os.getenv("DATA_SCHEMA", "data_api_serving")
TABLE = os.getenv("DATA_TABLE", "customer_details")
MAX_LIMIT = int(os.getenv("MAX_PAGE_SIZE", "200"))

# Public projection allowlist
ALLOWED_COLS = {
    "customer_id": "customer_id",
    "name": "name",
    "email": "email",
    "ip_addr": "ip_addr",
    "phone": "phone",
    "modified_ts": "modified_ts",
}
DEFAULT_SELECT = ["customer_id", "name", "email"]

# Types for safe casting in predicates
COL_TYPES = {
    "customer_id": "BIGINT",
    "name": "STRING",
    "email": "STRING",
    "ip_addr": "STRING",
    "phone": "STRING",
    "modified_ts": "TIMESTAMP",
}

# Stable keyset for pagination (DESC/DESC means "newest first")
KEYSET = [("modified_ts", "DESC"), ("customer_id", "DESC")]


def _json_default(o):
    # Datetime-like
    if isinstance(o, (datetime, pd.Timestamp)):
        # Keep full ISO-8601 with offset (Spark/DBSQL parses "+00:00" reliably)
        return o.isoformat()
    if isinstance(o, date):
        return o.isoformat()

    # Numerics that JSON doesn't know (e.g., Decimal)
    if isinstance(o, Decimal):
        return float(o)

    # Bytes
    if isinstance(o, (bytes, bytearray, memoryview)):
        return bytes(o).decode("utf-8", errors="ignore")

    # Fallback: stringify to avoid hard failures
    return str(o)


def _jsonable(v: Any) -> Any:
    """Convert Python objects into JSON-serializable forms."""
    if isinstance(v, (datetime, pd.Timestamp)):
        # Keep timezone if present; otherwise treat as UTC-naive
        s = v.isoformat()
        # Normalize +00:00 -> Z (purely aesthetic; optional)
        return s.replace("+00:00", "Z")
    if isinstance(v, date):
        return v.isoformat()
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, bytes):
        return v.decode("utf-8", errors="ignore")
    if isinstance(v, list):
        return [_jsonable(x) for x in v]
    if isinstance(v, tuple):
        return [_jsonable(x) for x in v]
    if isinstance(v, dict):
        return {k: _jsonable(x) for (k, x) in v.items()}
    return v


def _jsonify_items(items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    def _walk(x):
        if isinstance(x, dict):
            return {k: _walk(v) for k, v in x.items()}
        if isinstance(x, list):
            return [_walk(v) for v in x]
        return _json_default(x)

    return [_walk(it) for it in items]


def _jsonify_items(items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [_jsonable(it) for it in items]


def _b64(d: Dict[str, Any]) -> str:
    return base64.urlsafe_b64encode(
        json.dumps(d, separators=(",", ":"), default=_json_default).encode()
    ).decode()


def _unb64(t: Optional[str]) -> Dict[str, Any]:
    if not t:
        return {}
    try:
        return json.loads(base64.urlsafe_b64decode(t.encode()).decode())
    except Exception:
        return {}


def _norm(model_input: Any) -> Dict[str, Any]:
    if isinstance(model_input, pd.DataFrame):
        return model_input.iloc[0].to_dict()
    return dict(model_input or {})


def _parse_select(select_csv: Optional[str]) -> List[str]:
    if not select_csv:
        return DEFAULT_SELECT
    cols = [c.strip() for c in select_csv.split(",") if c.strip()]
    safe = [ALLOWED_COLS[c] for c in cols if c in ALLOWED_COLS]
    return safe or DEFAULT_SELECT


def _parse_filters(filters_json: Optional[str]) -> Dict[str, Any]:
    """
    filters_json example (all optional):
      {
        "email": "a@example.com",
        "name": "Alice",
        "name_contains": "ali",
        "customer_id": 1000123,
        "ip_addr": "203.0.113.7",
        "phone": "555-0100",
        "modified_from": "2025-10-01",
        "modified_to":   "2025-11-01"
      }
    """
    if not filters_json:
        return {}
    try:
        f_in = json.loads(filters_json)
    except Exception:
        return {}

    f: Dict[str, Any] = {}
    for k in ["email", "name", "ip_addr", "phone"]:
        if k in f_in and f_in[k] not in (None, ""):
            f[k] = str(f_in[k])

    if "customer_id" in f_in and f_in["customer_id"] not in (None, ""):
        f["customer_id"] = int(f_in["customer_id"])

    if "name_contains" in f_in and f_in["name_contains"]:
        f["name_contains"] = str(f_in["name_contains"]).lower()

    if "modified_from" in f_in and f_in["modified_from"]:
        f["modified_from"] = str(f_in["modified_from"])
    if "modified_to" in f_in and f_in["modified_to"]:
        f["modified_to"] = str(f_in["modified_to"])

    return f


def _compose_order() -> List[Tuple[str, str]]:
    # Keep keyset first for stable cursors
    return KEYSET[:]


def _sql_cast_param(col: str, pname: str) -> str:
    t = COL_TYPES.get(col, "STRING").upper()
    if t in ("BIGINT", "INT"):
        return f"CAST(:{pname} AS BIGINT)"
    if t in ("DOUBLE", "FLOAT", "DECIMAL"):
        return f"CAST(:{pname} AS DOUBLE)"
    if t == "TIMESTAMP":
        return f"CAST(:{pname} AS TIMESTAMP)"
    return f":{pname}"  # STRING (safe)


def _build_keyset_where(
    keys: List[Tuple[str, str]], after_vals: List[Any]
) -> Tuple[str, Dict[str, Any]]:
    """
    Lexicographic predicate for keyset pagination. Example for DESC/DESC:
      (modified_ts < :k0) OR (modified_ts = :k0 AND customer_id < :k1)
    With explicit CASTs so strings compare as native types.
    """
    assert len(keys) == len(after_vals)
    clauses = []
    params: Dict[str, Any] = {}
    for i in range(len(keys)):
        parts = []
        for j in range(i):
            colj, _dirj = keys[j]
            parts.append(f"{ALLOWED_COLS[colj]} = {_sql_cast_param(colj, f'k{j}')}")
            params[f"k{j}"] = after_vals[j]
        coli, diri = keys[i]
        op = "<" if diri.upper() == "DESC" else ">"
        parts.append(f"{ALLOWED_COLS[coli]} {op} {_sql_cast_param(coli, f'k{i}')}")
        params[f"k{i}"] = after_vals[i]
        clauses.append("(" + " AND ".join(parts) + ")")
    return " OR ".join(clauses), params


def _build_sql(
    select_cols: List[str],
    filters: Dict[str, Any],
    limit: int,
    cursor: Optional[str],
) -> Tuple[str, Dict[str, Any], List[str], List[str]]:
    where = []
    params: Dict[str, Any] = {}

    # Filters
    if "email" in filters:
        where.append("lower(email) = :email_lc")
        params["email_lc"] = filters["email"].lower()
    if "name" in filters:
        where.append("name = :name")
        params["name"] = filters["name"]
    if "name_contains" in filters:
        where.append("lower(name) LIKE :name_like")
        params["name_like"] = f"%{filters['name_contains']}%"
    if "customer_id" in filters:
        where.append(f"customer_id = {_sql_cast_param('customer_id', 'customer_id')}")
        params["customer_id"] = filters["customer_id"]
    if "ip_addr" in filters:
        where.append("ip_addr = :ip_addr")
        params["ip_addr"] = filters["ip_addr"]
    if "phone" in filters:
        where.append("phone = :phone")
        params["phone"] = filters["phone"]
    if "modified_from" in filters:
        where.append(
            f"modified_ts >= {_sql_cast_param('modified_ts', 'modified_from')}"
        )
        params["modified_from"] = filters["modified_from"]
    if "modified_to" in filters:
        where.append(f"modified_ts < {_sql_cast_param('modified_ts', 'modified_to')}")
        params["modified_to"] = filters["modified_to"]

    # Cursor
    after_vals = _unb64(cursor).get("after") if cursor else None
    if after_vals:
        pred, pred_params = _build_keyset_where(KEYSET, after_vals)
        where.append(f"({pred})")
        params.update(pred_params)

    where_sql = (" WHERE " + " AND ".join(where)) if where else ""

    # ORDER BY
    order_cols = _compose_order()
    order_sql = ", ".join([f"{ALLOWED_COLS[c]} {d}" for (c, d) in order_cols])

    # Projection: always include keyset columns internally
    keyset_cols = [c for (c, _) in KEYSET]
    internal_select = select_cols[:]
    for c in keyset_cols:
        if c not in internal_select:
            internal_select.append(c)

    # Limit + 1 for has_more detection
    page_size = max(1, min(int(limit or 50), MAX_LIMIT))
    params["lim"] = page_size + 1

    stmt = f"""
      SELECT {", ".join(internal_select)}
      FROM {CATALOG}.{SCHEMA}.{TABLE}
      {where_sql}
      ORDER BY {order_sql}
      LIMIT :lim
    """
    return stmt, params, internal_select, select_cols


def _connect_kwargs() -> Dict[str, Any]:
    server_hostname = os.environ["DATABRICKS_SERVER_HOSTNAME"]
    http_path = os.environ["DATABRICKS_HTTP_PATH"]
    auth_type = os.environ.get("DATABRICKS_AUTH_TYPE", "pat").lower()

    kw: Dict[str, Any] = dict(server_hostname=server_hostname, http_path=http_path)
    if auth_type in ("oauth", "oauth-m2m"):
        from databricks.sdk.core import Config, oauth_service_principal

        cfg = Config(
            host=f"https://{server_hostname}",
            auth_type="oauth-m2m",
            client_id=os.environ["DATABRICKS_CLIENT_ID"],
            client_secret=os.environ["DATABRICKS_CLIENT_SECRET"],
        )
        kw["credentials_provider"] = lambda: oauth_service_principal(cfg)
    else:
        kw["access_token"] = os.environ["DATABRICKS_TOKEN"]

    kw["session_configuration"] = {"query_tags": "app:customers-api"}
    return kw


class CustomersAPI(mlflow.pyfunc.PythonModel):
    def predict(self, context, model_input):
        from databricks import sql

        req = _norm(model_input)
        select_cols = _parse_select(req.get("select_csv"))
        filters = _parse_filters(req.get("filters_json"))
        limit = req.get("limit", 50)
        cursor = req.get("cursor")

        stmt, params, internal_select, public_select = _build_sql(
            select_cols, filters, limit, cursor
        )

        with sql.connect(**_connect_kwargs()) as conn, conn.cursor() as cur:
            cur.execute(stmt, params)
            rows = cur.fetchall()
            cols = (
                [d[0] for d in cur.description] if cur.description else internal_select
            )
            items = [
                {cols[i]: rows[r][i] for i in range(len(cols))}
                for r in range(len(rows))
            ]

        page_size = max(1, min(int(limit or 50), MAX_LIMIT))
        has_more = len(items) > page_size

        next_cursor = None
        if has_more:
            last = items[page_size - 1]  # last item we will return (not the +1)
            # serialize keyset values for cursor
            ks_vals = [_jsonable(last[k]) for (k, _) in KEYSET]
            next_cursor = _b64({"after": ks_vals})
            items = items[:page_size]  # trim the +1 lookahead

        # Drop keyset cols if not requested
        for k, _ in KEYSET:
            if k not in public_select:
                for it in items:
                    it.pop(k, None)

        # Make the payload fully JSON-safe
        items = _jsonify_items(items)
        return pd.DataFrame(
            [
                {
                    "count": len(items),
                    "items": items,
                    "next_cursor": next_cursor,
                    "has_more": has_more,
                }
            ]
        )


# Models-from-Code entry point
set_model(CustomersAPI())
