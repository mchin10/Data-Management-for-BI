/*
1. Run a query to get all of the data from the table e_beauty_for_class from the kcslmubu_practice_database
   and download it as a csv file.  Create a database named assignment_1 in your own lmu.build server.
   Upload the csv file with e_beauty_data to that database and name the table as e_beauty_assignment_1.
*/   
USE kcslmubu_practice_database;
SELECT * 
FROM e_beauty_for_class;

/*
2. The data, while relatively clean, still has a lot of dirtiness that must be cleaned and the data to be
   distributed to multiple tables that would represent e_beauty's data in a relational db in 3NF. The tasks are
   a. Many of the state values in the table are not in the two letter state code.  You have to change them into
      their two letter code using data from the Internet.  Here is a link that will give you the names of all the
      states and their corresponding two letter state codes: 
      https://www.bls.gov/respondents/mwr/electronic-data-interchange/appendix-d-usps-state-abbreviations-and-fips-codes.htm
      Download the data using any method that you have learned in your BSAN 6040 course, clean it so that you have only
      two columns (state name and state code) and create a csv file.  Upload the file to your assignment_1 database and 
      name it state_list. 
*/
USE mchinlmu_assignment_1;
SELECT *
FROM e_beauty_assignment_1;
SELECT *
FROM state_list;

/*
    b. Check the e_beauty_assignment_1 table for duplicate order_id, identify those duplicate orders, do a quick check to 
       ensure if they are indeed duplicate and then isolate them to another table using create table as command.  Name it
       duplicate_orders.
*/
-- Check for duplicate order_id       
SELECT order_id, COUNT(*) AS count
FROM e_beauty_assignment_1
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Spot check for duplicates
SELECT * 
FROM e_beauty_assignment_1 
WHERE order_id IN (
    SELECT order_id 
    FROM e_beauty_assignment_1 
    GROUP BY order_id 
    HAVING COUNT(*) > 1
)
ORDER BY order_id;

-- Create new table for duplicates
CREATE TABLE duplicate_orders AS
SELECT *
FROM e_beauty_assignment_1
WHERE order_id IN (
    SELECT order_id 
    FROM e_beauty_assignment_1 
    GROUP BY order_id 
    HAVING COUNT(*) > 1
	ORDER BY order_id
);

-- Check duplicate_orders table
SELECT *
FROM duplicate_orders
ORDER BY order_id;

/*     
	c. Create another table with the "create table as select" command and get all the orders to that table but without
       duplicates.  Hint: DISTINCT.  Name it e_beauty_order_no_duplicate.
*/
CREATE TABLE e_beauty_order_no_duplicate AS
SELECT DISTINCT *
FROM e_beauty_assignment_1;

SELECT order_id, COUNT(*) AS count
FROM e_beauty_order_no_duplicate
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT *
FROM e_beauty_order_no_duplicate
WHERE order_id = 140903139;

DELETE FROM e_beauty_order_no_duplicate
WHERE order_id = 140903139 AND order_total = 56.72;

/*
    d. Using the state_list table, and any other methods and techniques that you have learned so far, update
       all the values in the state column in the e_beauty_order_no_duplicate to the appropriate two letter state code.
       Note that some of the values are already in the two letter state code format.  You have to figure out how to
       accommodate them and turn the values with the full state names to their corresponding state code. Hint: you
       may have to do some filtering and UNION and then do "create table as" out of a query. Name the new table 
       e_beauty_order_final.
*/
CREATE TABLE e_beauty_order_final AS
SELECT 
    e.order_id, e.email, e.full_name, e.first_name, e.last_name, 
    e.address, e.city, s.StateCode AS state, e.zip, 
    e.DOB, e.order_total, e.review, e.order_date
FROM e_beauty_order_no_duplicate e
JOIN state_list s ON e.state = s.StateName
UNION
SELECT 
    order_id, email, full_name, first_name, last_name, 
    address, city, state, zip, 
    DOB, order_total, review, order_date
FROM e_beauty_order_no_duplicate 
WHERE state IN (SELECT StateCode FROM state_list);

/*	
    e. Add a column to the e_beauty_order_final table with DATE as the datatype and name it dob_corrected.  Ensure that
    it is positioned right after the DOB column.
*/
ALTER TABLE e_beauty_order_final
ADD COLUMN dob_corrected DATE AFTER DOB;

/*
    f. Update the dob_corrected column with the corresponding values from the DOB column.  Note that you have to
    use STR_TO_DATE function to correctly insert the values.  The missing values will all become 0000-00-00 and that is
    OK.
*/
UPDATE e_beauty_order_final
SET dob_corrected = STR_TO_DATE(DOB, "%m/%d/%Y")
    WHERE DOB IS NOT NULL AND DOB <> '';
    
/*
    Now that you have a fully clean order_table, let us start working on transferring the data correctly to other
    tables that would create a relational 3NF model for this dataset. We would need just three tables, customer, city,
    and order.

    g. It appears that many of the customers have multiple emails that they used in their orders at different
    points of time.  We need to reconcile them by identifying the latest email used by each customer.  Write
    a query that would create a list of all the customers of e_beauty with their latest e-mails.  
*/    

WITH latest_orders AS (
    SELECT full_name, MAX(order_date) AS latest_order_date
    FROM e_beauty_order_final
    GROUP BY full_name
)
SELECT e.full_name, l.latest_order_date, e.email AS latest_email
FROM e_beauty_order_final e
JOIN latest_orders l
ON e.full_name = l.full_name AND e.order_date = l.latest_order_date
ORDER BY l.latest_order_date DESC;

/*
    h. Using the query result from g and e_beauty_order_final table and any appropriate method that you deem fit,
    create a list of all the customers of e_beauty with their first name, last name, latest email, address, zip, and
    a column that would contain all the emails that the customers have used for their interaction with e_beauty. 
    A simple example (using a different table) is shown below (without the current email).  Hint:GROUP_CONCAT.
    
    SELECT DISTINCT first_name, last_name, address, city, state, zip,
      GROUP_CONCAT(DISTINCT email ORDER BY email SEPARATOR ", ") AS email_list
	FROM e_beauty_for_class
    GROUP BY first_name, last_name, address, city, state, zip
    ORDER BY
    first_name, last_name;
    
    SELECT DISTINCT first_name, last_name, address, GROUP_CONCAT(DISTINCT city), GROUP_CONCAT(DISTINCT state)
    FROM e_beauty_for_class
    GROUP BY first_name, last_name, address;
*/
WITH latest_orders AS (
    SELECT full_name, MAX(order_date) AS latest_order_date
    FROM e_beauty_order_final
    GROUP BY full_name
),
latest_emails AS (
    SELECT e.full_name, e.email AS latest_email
    FROM e_beauty_order_final e
    JOIN latest_orders l
    ON e.full_name = l.full_name AND e.order_date = l.latest_order_date
)
SELECT DISTINCT e.first_name, e.last_name, e.address, 
    GROUP_CONCAT(DISTINCT e.city ORDER BY e.city SEPARATOR ', ') AS city_list,
    GROUP_CONCAT(DISTINCT e.state ORDER BY e.state SEPARATOR ', ') AS state_list,
    GROUP_CONCAT(DISTINCT e.zip ORDER BY e.zip SEPARATOR ', ') AS zip_list,
    le.latest_email, 
    GROUP_CONCAT(DISTINCT e.email ORDER BY e.email SEPARATOR ', ') AS email_list
FROM e_beauty_order_final e
JOIN latest_emails le ON e.full_name = le.full_name
GROUP BY e.first_name, e.last_name, e.address, le.latest_email
ORDER BY e.first_name, e.last_name;

/*  
    i. Find the records that have illegal characters in the first_name or last_name fields.  Illegal 
       characters for names are #, ?, ., or numbers.  To check for all of them in one statement, you may have to 
       use REGEXP function.  You can ask ChatGPT for a demo and explanation of the function.  However, in the current
       dataset, the illegal characters are #, ?, and .  You can check for each one individually.
*/
SELECT * 
FROM e_beauty_order_final
WHERE first_name REGEXP '[#?.0-9]' 
   OR last_name REGEXP '[#?.0-9]';

/*   
	j. Delete all the records that have illegal characters in the first name or last name.  You may want to 
    create a back up of the table first though before accidentally deleting all the work that you have done so far!
*/
DELETE FROM e_beauty_order_final
WHERE first_name REGEXP '[#?.0-9]' 
   OR last_name REGEXP '[#?.0-9]';
   
/*    
    k. Update the order_total field to string but only with numbers by issuing the following commands:
       UPDATE e_beauty_order_final
          SET order_total = TRIM(order_total)*1;
*/
UPDATE e_beauty_order_final
	SET order_total = TRIM(order_total)*1;

/*    
	l. Change the fields in the table to their correct data types. order_total should be a decimal with 2 digit 
    after the decimal and at least 6 digits before the decimal.
    
    If you do everything correctly, you should get a dataset that should be relatively clean. You can now use this to
    create the tables needed for the normalized version of the dataset.
*/
ALTER TABLE e_beauty_order_final
MODIFY COLUMN order_total DECIMAL (8,2),
MODIFY COLUMN order_date DATE;

/* 
3. Create a 3NF design for the e_beauty data that will have 3 entities:- customer, zip codes (to have the information on
   city and state) and order.  Do you think that would be a correct design?  Justify your answers.  Also identify the 
   primary and foreign keys (where applicable) in each of the tables.
*/
/* 
ANSWER: I think this would be a correct design with the variables given. The customer table would have email as the primary key and full_name,
first_name, last_name, address, zip, DOB, and dob_corrected as columns. The column zip would be a foreign key connecting to the zip_codes table.
The zip_codes table would have zip as a primary key and the columns city and state. The order table would have order_id as the primary key and email,
order_total, review, and order_date as columns with email being the foreign key connecting to the customer table.
*/

/*    
4. Write a query using create table as select method that would create the customer table from the order table.  How would the 
order table change if you have a customer table?  What fields will be eliminated from the order table and what fields would be 
used for maintaining connections between the customer and order table? 
*/
CREATE TABLE customer AS
SELECT email, full_name, first_name, last_name, address, zip, DOB, dob_corrected
FROM e_beauty_order_final;
-- With a customer table, you would remove the redundant customer info from the order_table
-- The fields to be eliminated would be full_name, first_name, last_name, address, zip, DOB, and dob_corrected
-- If a zip_codes table was created, you would also remove city and state from the order table
-- To maintain connections between the customer and order table, you would make email a primary key for the customer table and a foreign key in the order table

/* 
5. One of the power of SQL is to be able to get useful information from databases that can help in decision making and 
gaining business insights.  With that in mind and using the database e_beauty_assignment_seal where I have uploaded
customer, product, order, and zip code tables for e_beauty (note that the data in those tables may be slightly different
than yours; I have made some extra cleaning and also created some fictitious products using ChatGPT) write sql statements 
to answer the following questions:
	a. 1. Customer Insights & Retention
			i.  Who are the most loyal customers (repeat buyers)?
                Use case: Identify top repeat buyers and offer loyalty rewards or special promotions.
*/
USE kcslmubu_e_beauty_assignment_seal;
SELECT c.first_name, c.last_name, c.latest_email, COUNT(o.orderid) AS count_orders
FROM customer_table_e_beauty c
JOIN order_table_e_beauty o
ON c.customer_id = o.customer_id
GROUP BY c.first_name, c.last_name, c.latest_email
ORDER BY count_orders DESC;

/*
ii. What is the average order value (AOV) per customer?
	Use case: Helps in pricing strategies and customer segmentation for premium vs. budget buyers.
*/
SELECT c.first_name, c.last_name, ROUND(AVG(o.total),2) AS AOV
FROM customer_table_e_beauty c
JOIN order_table_e_beauty o
ON c.customer_id = o.customer_id
GROUP BY c.first_name, c.last_name;

/*
	b. Geographic & Market Expansion Analysis: helps to identify underperforming states or territories to 
    target with marketing efforts.
			i. Which states have the highest revenue per customer?
            Use case: Determine where high-value customers are located to focus advertising and premium product promotions.
*/
SELECT z.state_name, COUNT(DISTINCT c.customer_id) AS total_customers, SUM(o.total) AS total_revenue, ROUND(SUM(o.total) / COUNT(DISTINCT c.customer_id), 2) AS revenue_per_customer
FROM order_table_e_beauty o
JOIN customer_table_e_beauty c ON o.customer_id = c.customer_id
JOIN zips_city_state_population z ON c.zip = z.zip
GROUP BY z.state_name
ORDER BY revenue_per_customer DESC;

/*
            ii. Are there states where e_beauty did not make any sales at all (may need a different JOIN than the regular
                inner join).
*/
SELECT z.state_name
FROM zips_city_state_population z
LEFT JOIN customer_table_e_beauty c ON z.zip = c.zip
LEFT JOIN order_table_e_beauty o ON c.customer_id = o.customer_id
GROUP BY z.state_name
HAVING SUM(o.total) IS NULL OR SUM(o.total) = 0
ORDER BY z.state_name;

/* 
	c. Product & Category Analysis
			i. What is the most popular purchase month? 
            Use case: Helps in seasonal sales forecasting and planning inventory around peak sales months.
*/
SELECT MONTH(order_date) AS order_month, COUNT(orderid) order_count
FROM order_table_e_beauty
GROUP BY order_month
ORDER BY order_count DESC;

/*
			ii. Is there a relationship between customer reviews and sales?
            Use case: Helps determine if higher-rated products drive more revenue or if negative reviews impact sales.
*/ 
SELECT p.product_name, ROUND(AVG(o.review), 2) AS avg_review, SUM(o.quantity) AS sales_quantity, SUM(o.total) AS total_revenue
FROM order_table_e_beauty o
JOIN product_table_e_beauty p ON o.product_id = p.product_id
GROUP BY p.product_name
ORDER BY avg_review DESC;

/*
	d. Marketing & Promotional Analysis.
			i. Which customers increased or decreased their spending over time?
            Use case: Identify customers whose spending has decreased and target them with win-back campaigns.
*/
WITH customer_spending AS (
    SELECT customer_id, YEAR(order_date) AS order_year, SUM(total) AS total_spent
    FROM order_table_e_beauty
    GROUP BY customer_id, order_year
),
spending_trend AS (
    SELECT c1.customer_id, c1.order_year AS current_year, 
		c1.total_spent AS current_spend, 
		c2.order_year AS previous_year, 
		c2.total_spent AS previous_spend,
        (c1.total_spent - c2.total_spent) AS spend_change
    FROM customer_spending c1
    LEFT JOIN customer_spending c2 ON c1.customer_id = c2.customer_id AND c1.order_year = c2.order_year + 1
)
SELECT customer_id, current_year, previous_year, current_spend, previous_spend, spend_change
FROM spending_trend
ORDER BY spend_change DESC;

/*
			ii. What percentage of customers made only one purchase?
            Use case: Helps determine customer retention and the need for engagement strategies to encourage repeat purchases.
*/
WITH customer_purchase_count AS (
    SELECT customer_id, COUNT(orderid) AS purchase_count
    FROM order_table_e_beauty
    GROUP BY customer_id
)
SELECT COUNT(*) * 100 / (SELECT COUNT(DISTINCT(customer_id)) FROM order_table_e_beauty) AS percent_one_purchase
FROM customer_purchase_count
WHERE purchase_count = 1;

/*            
            iii. Create a list of top 5 customers and bottom 5 customers in terms of order_total for last 4 years. Your result 
            should be a single list and should have a field indicating the year for each of the records as well as the type indicating
            if it is in the top list or the bottom list.  An example output is shown below.
*/
WITH customer_yearly_spending AS (
    SELECT o.customer_id, YEAR(o.order_date) AS order_year, SUM(o.total) AS total_spent
    FROM order_table_e_beauty o
    WHERE YEAR(o.order_date) >= 2021
    GROUP BY o.customer_id, order_year
)
(SELECT cy.customer_id, cy.order_year,cy.total_spent, 'Top 5' AS list_type
FROM customer_yearly_spending cy
ORDER BY cy.total_spent DESC
LIMIT 5)
UNION ALL
(SELECT cy.customer_id, cy.order_year, cy.total_spent, 'Bottom 5' AS list_type
FROM customer_yearly_spending cy
ORDER BY cy.total_spent ASC
LIMIT 5)
ORDER BY total_spent DESC, order_year DESC;

/* 
6. What other information items should be included in the database that can be useful for e_beauty?  Would they be part of the 
existing tables?  If yes, the show how the design of the current tables would change.  If you think that new tables need to be 
added to the database for keeping extra business related information that can help e_beauty, then suggest the design of 
those tables. 
*/
/* ANSWER: Additional customer demographic data could be included to better segment customers. This could include variables such as
gender, marital_status, income_level, and employment_status. This could be part of the customer_table_e_beauty table. Other information 
items that could be included are an inventory table or shipping/delvery info table. The inventory table would connect to the product table
on product_id and could include features such as stock, supplier_name, and restock_date. The shipping info table would connect to the order
table on order_id and could include features such as shipping_address, shipping_status, and delivery_date.

