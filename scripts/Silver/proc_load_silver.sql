/*
===============================================================================
Stored Procedure: Load Bronze Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL process to populate the 'silver' schema 
tables from the 'bronze' schema.
Actions performed:- 
  -Truncate Silver tables
  -Inserts transformed and cleaned data  from Bronze into Silver tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silevr.load_silver;
===============================================================================
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME,@end_time DATETIME,@batch_start_time DATETIME,@batch_end_time DATETIME;
	BEGIN TRY
		SET  @batch_start_time = GETDATE();
		PRINT'===================================';
		PRINT'Loading Silver Layer';
		PRINT'===================================';
		
		PRINT'-----------------------------------';
		PRINT'Loading CRM Layer';
		PRINT'-----------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table : silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;

		PRINT '>> Inserting data : silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info(
		cst_id,
		cst_key,
		cst_martital_status,
		cst_firstname,
		cst_lastname,
		cst_gndr,
		cst_create_date)
		select 
		cst_id,
		cst_key,
		TRIM(cst_firstname) AS cst_firstname,
		TRIM(cst_lastname) AS cst_lastname,
		CASE WHEN cst_martital_status = UPPER(TRIM('M')) THEN 'Married'
		WHEN cst_martital_status = UPPER(TRIM('S')) THEN 'Single'
		ELSE 'N/A'
		END cst_martital_status,
		CASE WHEN cst_gndr = UPPER(TRIM('M')) THEN 'Male'
		WHEN cst_gndr = UPPER(TRIM('F')) THEN 'Female'
		ELSE 'N/A'
		END cst_gndr,
		cst_create_date 
		from (
			SELECT *,ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS row_num 
			FROM bronze.crm_cust_info 
			WHERE cst_id IS NOT NULL
		)t 
		WHERE row_num=1 ;
		SET @end_time = GETDATE();
		PRINT'>> Load Duration: '+ cast(DATEDIFF(second, @start_time, @end_time) as NVARCHAR) + 'seconds';
		PRINT'>> ----------------------';
		PRINT' ';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table : silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting data : silver.crm_prd_info';

		INSERT INTO silver.crm_prd_info(
			prd_id,
			prd_key,  
			cat_id, 
			prd_nm,  
			prd_cost, 
			prd_line ,
			prd_start_dt ,
			prd_end_dt
		)
		SELECT 
		prd_id,
		SUBSTRING(prd_key,7,LEN(prd_key)) as prd_key,
		REPLACE(SUBSTRING(prd_key,1,5),'-','_') as cat_id,
		prd_nm,
		ISNULL(prd_cost,0) AS prd_cost,
		CASE UPPER(TRIM(prd_line)) 
			WHEN 'M' THEN 'Mountain'
			WHEN 'R' THEN 'Road'
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
			ELSE 'N/A'
		END AS prd_line,
		CAST(prd_start_dt AS DATE) AS prd_start_dt ,
		CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info ;
		SET @end_time = GETDATE();
		PRINT'>> Load Duration: '+ cast(DATEDIFF(second, @start_time, @end_time) as NVARCHAR) + 'seconds';
		PRINT'>> ----------------------';
		PRINT' ';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table : silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting data : silver.crm_sales_details';

		INSERT INTO SILVER.crm_sales_details(
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price
		)
		select 
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) !=8 THEN NULL
			ELSE CAST(CAST(sls_order_dt AS VARCHAR)AS DATE)
		END AS sls_order_dt,
		CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) !=8 THEN NULL
			ELSE CAST(CAST(sls_ship_dt AS VARCHAR)AS DATE)
		END AS sls_ship_dt,
		CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) !=8 THEN NULL
			ELSE CAST(CAST(sls_due_dt AS VARCHAR)AS DATE)
		END AS sls_due_dt,
		CASE WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
			 THEN sls_quantity *ABS(sls_price)
			 ELSE sls_sales
		END AS sls_sales,
		sls_quantity,
		CASE WHEN sls_price is NULL OR sls_price<=0
			THEN sls_sales / NULLIF(sls_quantity, 0)
			ELSE sls_price
		END AS sls_price
		from bronze.crm_sales_details;
		SET @end_time = GETDATE();
		PRINT'>> Load Duration: '+ cast(DATEDIFF(second, @start_time, @end_time) as NVARCHAR) + 'seconds';
		PRINT'>> ----------------------';
		PRINT' ';

		PRINT'-----------------------------------';
		PRINT'Loading ERP Layer';
		PRINT'-----------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table : silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting data : silver.erp_cust_az12';

		INSERT INTO silver.erp_cust_az12(cid,bdate,gen)
		select 
		CASE WHEN cid like 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
		ELSE cid
		END AS cid,
		CASE WHEN bdate > GETDATE() THEN NULL
			ELSE bdate
		END AS bdate,
		CASE WHEN UPPER(TRIM(gen)) IN ( 'M','MALE') THEN 'Male'
		WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
		ELSE 'N/A'
		END AS gen
		from bronze.erp_cust_az12;
		SET @end_time = GETDATE();
		PRINT'>> Load Duration: '+ cast(DATEDIFF(second, @start_time, @end_time) as NVARCHAR) + 'seconds';
		PRINT'>> ----------------------';
		PRINT' ';


		SET @start_time = GETDATE();
		PRINT '>> Truncating Table : silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting data : silver.erp_loc_a101';

		INSERT INTO silver.erp_loc_a101(
		cid,
		cntry)
		select 
		REPLACE(cid,'-',''),
		CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
		WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
		ELSE TRIM(cntry)
		END AS cntry
		from bronze.erp_loc_a101;
		SET @end_time = GETDATE();
		PRINT'>> Load Duration: '+ cast(DATEDIFF(second, @start_time, @end_time) as NVARCHAR) + 'seconds';
		PRINT'>> ----------------------';
		PRINT' ';


		SET @start_time = GETDATE();
		PRINT '>> Truncating Table : silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting data : silver.erp_px_cat_g1v2';

		INSERT INTO silver.erp_px_cat_g1v2(
		id,
		cat,
		subcat,
		maintenance)
		select 
		id,
		cat,
		subcat,
		maintenance
		from bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE();
		PRINT'>> Load Duration: '+ cast(DATEDIFF(second, @start_time, @end_time) as NVARCHAR) + 'seconds';
		PRINT'>> ----------------------';
		PRINT' ';
		SET @batch_end_time = GETDATE();
		PRINT'========================='
		PRINT'Loading Silver Layer is Completed';
		PRINT'   -Total Load Duration : '+CAST(DATEDIFF(SECOND,@batch_start_time,@batch_end_time) as NVARCHAR) + 'seconds';
		PRINT'========================='
	END TRY
	BEGIN CATCH
		PRINT'=================================================='
		PRINT'ERROR OCCURED DURING LOADING SILVER LAYER'
		PRINT'ERROR MESSAGE' + ERROR_MESSAGE();
		PRINT'ERROR MESSAGE' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT'ERROR MESSAGE' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT'=================================================='
	END CATCH
END
