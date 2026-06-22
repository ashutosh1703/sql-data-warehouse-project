/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT 
	ROW_NUMBER() OVER (ORDER BY cst_id) as customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS cutomer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	el.cntry AS country,
	ci.cst_martital_status AS marital_status,
	CASE WHEN ci.cst_gndr != 'N/A' THEN ci.cst_gndr --CRM is the Master for gender info
		ELSE COALESCE(ec.gen,'N/A')
	END AS gender,
	ec.bdate AS birth_date,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ec
on ci.cst_key = ec.cid
LEFT JOIN silver.erp_loc_a101 el
on ci.cst_key = el.cid

GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT 
	ROW_NUMBER() OVER(ORDER BY cp.prd_start_dt,cp.prd_key) AS product_key,
	cp.prd_id AS product_id,
	cp.prd_key AS product_number,
	cp.prd_nm AS product_name,
	cp.cat_id AS category_id,
	epx.cat AS category,
	epx.subcat AS sub_category,
	epx.maintenance AS maintenance,
	cp.prd_cost AS product_cost,
	cp.prd_line AS product_line,
	cp.prd_start_dt AS product_start_date
FROM 
silver.crm_prd_info cp
left join  
silver.erp_px_cat_g1v2 epx
on cp.cat_id = epx.id
where cp.prd_end_dt is NULL -- Filter out all historical data
GO

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT 
  sd.sls_ord_num AS order_number,
  pr.product_key,
  cu.customer_key,
  sd.sls_order_dt AS order_date,
  sd.sls_ship_dt AS shipping_date,
  sd.sls_due_dt AS due_date,
  sd.sls_sales AS sales_amount,
  sd.sls_quantity AS quantity,
  sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN  gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id

LEFT JOIN gold.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id;
GO
