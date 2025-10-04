# register_and_deploy_customers.py
import os, json, mlflow, pandas as pd
from mlflow.models import infer_signature

# 1) Tracking/registry targets
mlflow.set_tracking_uri("databricks")  # works in notebook or with HOST/TOKEN set
mlflow.set_registry_uri("databricks-uc")

# 2) Input/output examples to drive signature + Serving UI
input_example = pd.DataFrame(
    [
        {
            "select_csv": "customer_id,name,email",
            "filters_json": json.dumps(
                {
                    "name_contains": "ali",
                    "modified_from": "2025-10-01",
                    "modified_to": "2025-12-01",
                }
            ),
            "sort_json": "[]",  # reserved for future; keyset enforced in model
            "limit": 5,
            "cursor": None,
        }
    ]
)

output_example = pd.DataFrame(
    [
        {
            "count": 5,
            "items": [
                {
                    "customer_id": 1001000,
                    "name": "ex exercitation dolor",
                    "email": "sit@pariatur.co.uk",
                },
                {
                    "customer_id": 1000999,
                    "name": "laborum cupidatat",
                    "email": "nostrud@ipsum.co.uk",
                },
            ],
            "next_cursor": "eyJhZnRlciI6WyIyMDI1LTEwLTAzVDIxOjM3OjAzLjc2M1oiLDEwMDA5OTldfQ",  # example
            "has_more": True,
        }
    ]
)

signature = infer_signature(input_example, output_example)

# 3) Model metadata
code_file = "./api_model_customers.py"  # the file above (contains set_model(...))
registered_model_name = "demos.data_api_serving.customers_api"

# 4) Log & register
with mlflow.start_run(run_name="customers_api_from_code"):
    mlflow.pyfunc.log_model(
        name="customers_api_model",
        python_model=code_file,  # Models-from-Code entry script
        registered_model_name=registered_model_name,
        signature=signature,
        input_example=input_example,
        infer_code_paths=True,
        pip_requirements=[
            "pandas>=2.1",
            "mlflow>=2.8.0",
            "pydantic>=2",
            "databricks-sql-connector[pyarrow]>=3.0.0",
            "databricks-sdk>=0.33.0",
        ],
    )

print(f"Registered: {registered_model_name}")
