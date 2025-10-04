-- Create a dedicated catalog + schema for this demo
-- NOTE: Before running this script, replace <SERVICE_PRINCIPAL_ID> with your actual service principal ID.
-- You can obtain the service principal ID from your cloud provider (e.g., Azure Active Directory > App registrations > [Your Service Principal] > Application (client) ID).
-- Example: GRANT USE CATALOG ON CATALOG demos TO '12345678-90ab-cdef-1234-567890abcdef';
CREATE CATALOG IF NOT EXISTS demos                        COMMENT 'Databricks demos';
CREATE SCHEMA  IF NOT EXISTS demos.data_api_serving       COMMENT 'Tables with data to be served via API';

-- Basic privileges for your build principal / SP
GRANT USE CATALOG ON CATALOG demos                        TO '<SERVICE_PRINCIPAL_ID>';
GRANT USE SCHEMA  ON SCHEMA  demos.data_api_serving       TO '<SERVICE_PRINCIPAL_ID>';
GRANT SELECT, MODIFY ON SCHEMA demos.data_api_serving     TO '<SERVICE_PRINCIPAL_ID>';

-- (Recommended) Enable Predictive Optimization at the catalog level.
-- This removes most manual OPTIMIZE/VACUUM scheduling on managed tables.