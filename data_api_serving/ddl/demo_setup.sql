-- Create a dedicated catalog + schema for this demo
CREATE CATALOG IF NOT EXISTS demos                        COMMENT 'Databricks demos';
CREATE SCHEMA  IF NOT EXISTS demos.data_api_serving       COMMENT 'Tables with data to be served via API';

-- Basic privileges for your build principal / SP
GRANT USE CATALOG ON CATALOG demos                        TO `4c3b95fa-045d-49f6-98cd-d06da3d5b023`;
GRANT USE SCHEMA  ON SCHEMA  demos.data_api_serving       TO `4c3b95fa-045d-49f6-98cd-d06da3d5b023`;
GRANT SELECT, MODIFY ON SCHEMA demos.data_api_serving     TO `4c3b95fa-045d-49f6-98cd-d06da3d5b023`;

-- (Recommended) Enable Predictive Optimization at the catalog level.
-- This removes most manual OPTIMIZE/VACUUM scheduling on managed tables.