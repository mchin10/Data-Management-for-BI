-- Create products table and import from Tableau Prep
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(50),
    product_description TEXT
);

SELECT *
FROM products;

-- Create users table and import from Tableau Prep
CREATE TABLE users (
	user_id INT PRIMARY KEY,
	first_name TEXT,
	last_name TEXT,
	email TEXT,
	billing_street_address TEXT,
	billing_city TEXT,
	billing_state TEXT,
	billing_postal_code TEXT,
	billing_country TEXT,
	shipping_street_address TEXT,
	shipping_city TEXT,
	shipping_state TEXT,
	shipping_postal_code TEXT,
	shipping_country TEXT
);

SELECT *
FROM users;

-- Create orders table and import from Tableau Prep
CREATE TABLE orders (
	order_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    website_session_id INT,
    user_id INT,
    primary_product_id INT,
    items_purchased SMALLINT,
    price_usd DECIMAL(6,2),
    cogs_usd DECIMAL(6,2)
);

SELECT *
FROM orders;

-- Create orders_items table
CREATE TABLE order_items (
	order_item_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    order_id INT,
    product_id INT,
    is_primary_item SMALLINT,
    price_usd DECIMAL(6,2),
    cogs_usd DECIMAL(6,2)
);

SELECT *
FROM order_items;

-- Change data types in dim_date
ALTER TABLE dim_date
MODIFY COLUMN `date` DATE PRIMARY KEY,
MODIFY COLUMN day_name VARCHAR(10),
MODIFY COLUMN `day` INT,
MODIFY COLUMN `week` INT,
MODIFY COLUMN `month` INT,
MODIFY COLUMN `quarter` INT,
MODIFY COLUMN `year` YEAR;

SELECT * 
FROM dim_date;

SELECT * 
FROM dim_product;

SELECT * 
FROM dim_user;

-- Add Primary Keys and Foreign Keys to fact_order_item
ALTER TABLE fact_order_item
ADD CONSTRAINT pk_order_item PRIMARY KEY (order_id, order_item_id),
ADD CONSTRAINT fk_product_id FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
ADD CONSTRAINT fk_order_date FOREIGN KEY (order_date) REFERENCES dim_date(`date`),
ADD CONSTRAINT fk_user_id FOREIGN KEY (user_id) REFERENCES dim_user(user_id);

-- Add Primary and Foreign Keys to fact_order_item_refund
ALTER TABLE fact_order_item_refund
ADD CONSTRAINT pk_order_item_refund PRIMARY KEY (order_item_id, order_item_refund_id),
ADD CONSTRAINT fk_product_id_refund FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
ADD CONSTRAINT fk_refund_date FOREIGN KEY (refund_date) REFERENCES dim_date(`date`),
ADD CONSTRAINT fk_user_id_refund FOREIGN KEY (user_id) REFERENCES dim_user(user_id);

-- CREATE dim_campaign table
CREATE TABLE dim_campaign AS (
	SELECT DISTINCT utm_campaign, utm_source, utm_content
	FROM sessions
);

ALTER TABLE dim_campaign
ADD COLUMN campaign_id INT AUTO_INCREMENT PRIMARY KEY;

SELECT * 
FROM dim_campaign;

-- Add Primary Key to dim_landing_page
ALTER TABLE dim_landing_page
MODIFY COLUMN landing_page_url VARCHAR(50) PRIMARY KEY;

-- CREATE fact_website_sessions
CREATE TABLE fact_website_sessions (
	website_session_id INT PRIMARY KEY,
    session_date DATE,
    landing_page_url VARCHAR(50),
    campaign_id INT,
    user_id INT,
    device_type VARCHAR(15),
    pageviews_count INT,
    orders_count INT,
    bounce_count INT,
    CONSTRAINT fk_session_date FOREIGN KEY (session_date) REFERENCES dim_date(`date`),
    CONSTRAINT fk_landing_page FOREIGN KEY (landing_page_url) REFERENCES dim_landing_page(landing_page_url),
    CONSTRAINT fk_campaign_id FOREIGN KEY (campaign_id) REFERENCES dim_campaign(campaign_id),
    CONSTRAINT fk_user_id_sessions FOREIGN KEY (user_id) REFERENCES dim_user(user_id)
);

SELECT *
FROM fact_website_sessions;


-- Using the Data Warehouse
-- Total revenue per month for each year
SELECT YEAR(order_date) AS `year`, MONTH(order_date) AS `month`, SUM(revenue_usd) AS total_revenue
FROM fact_order_item
GROUP BY `year`, `month`;

-- Year over year increase in revenue
SELECT 
    YEAR(order_date) AS `year`,
    LAG(SUM(revenue_usd)) OVER (ORDER BY YEAR(order_date)) AS previous_year_revenue,
    SUM(revenue_usd) AS current_year_revenue,
    (SUM(revenue_usd) - LAG(SUM(revenue_usd)) OVER (ORDER BY YEAR(order_date))) / 
    LAG(SUM(revenue_usd)) OVER (ORDER BY YEAR(order_date)) * 100 AS yoy_revenue_increase_percentage
FROM fact_order_item
GROUP BY `year`
ORDER BY `year`;

-- Total sales and profit by states and countries
SELECT u.billing_state, u.billing_country, SUM(oi.revenue_usd) AS total_revenue, SUM(oi.profit_usd) AS total_profit
FROM fact_order_item oi
JOIN dim_user u
	ON u.user_id = oi.user_id
GROUP BY u.billing_state, u.billing_country;

-- Top 2 products that are returned most frequently and the associated lost revenue
SELECT p.product_name, COUNT(oir.order_item_id) AS count_returned, SUM(oir.refund_usd) AS lost_revenue
FROM fact_order_item_refund oir
JOIN dim_product p
	ON p.product_id = oir.product_id
GROUP BY p.product_name
ORDER BY count_returned DESC
LIMIT 2;

-- Behavior of total monthly sales for the entire time period of the data
SELECT d.`month`, SUM(oi.revenue_usd) AS total_monthly_sales
FROM fact_order_item oi
JOIN dim_date d
	ON oi.order_date = d.`date`
GROUP BY `month`
ORDER BY `month`;

-- Top 5 users and the amount of business that they provide to the company each year
SELECT u.first_name, u.last_name, u.email, SUM(oi.revenue_usd) AS total_revenue, COUNT(oi.order_id) AS number_of_orders
FROM fact_order_item oi
JOIN dim_user u
	ON oi.user_id = u.user_id
GROUP BY u.first_name, u.last_name, u.email
ORDER BY total_revenue DESC
LIMIT 5;

-- The number of returned items for each day of the week for June 2023.
SELECT d.day_name, COUNT(oir.order_item_refund_id) AS number_of_returns
FROM fact_order_item_refund oir
JOIN dim_date d
    ON oir.refund_date = d.date
WHERE MONTH(oir.refund_date) = 6 
  AND YEAR(oir.refund_date) = 2023
GROUP BY d.day_name
ORDER BY number_of_returns DESC;

-- Average revenue and cost of goods sold by product line for each of the months and quarters
SELECT d.`quarter`, d.`month`, p.product_name, ROUND(AVG(oi.revenue_usd), 2) AS avg_revenue, ROUND(AVG(oi.cogs_usd), 2) AS avg_cogs
FROM fact_order_item oi
JOIN dim_date d
	ON oi.order_date = d.`date`
JOIN dim_product p
	ON oi.product_id = p.product_id
GROUP BY d.`quarter`, d.`month`, p.product_name
ORDER BY d.`quarter`, d.`month`, p.product_name;

-- Daily purchase count for a given city in December of 2023.
SELECT DISTINCT billing_city, COUNT(billing_city) AS count_city
FROM dim_user
GROUP BY billing_city
ORDER BY count_city DESC;

SELECT d.`date`, COUNT(oi.order_id) AS daily_purchase_count
FROM fact_order_item oi
JOIN dim_date d
	ON oi.order_date = d.`date`
JOIN dim_user u
	ON oi.user_id = u.user_id
WHERE u.billing_city = "North Michael" AND MONTH(d.`date`) = 12 AND YEAR(d.`date`) = 2023
GROUP BY d.`date`;

-- The number of orders by landing page and utm campaigns as well as utm source.
SELECT l.landing_page_url, c.utm_campaign, c.utm_source, SUM(s.orders_count) AS number_of_orders
FROM fact_website_sessions s
JOIN dim_landing_page l
	ON s.landing_page_url = l.landing_page_url
JOIN dim_campaign c
	ON s.campaign_id = c.campaign_id
GROUP BY l.landing_page_url, c.utm_campaign, c.utm_source;

-- Sales volume coming from various types of devices.
SELECT s.device_type, SUM(s.orders_count)
FROM fact_website_sessions s
GROUP BY s.device_type;

-- Total profit per quarter per year
SELECT YEAR(order_date) AS `year`, QUARTER(order_date) AS `quarter`, SUM(profit_usd) AS total_profit
FROM fact_order_item
GROUP BY `year`, `quarter`;

-- Total profit loss per quarter per year
SELECT YEAR(refund_date) AS `year`, QUARTER(refund_date) AS `quarter`, SUM(profit_loss_usd) AS total_profit_loss
FROM fact_order_item_refund
GROUP BY `year`, `quarter`;

-- Top 2 products purchased most frequently and the associated revenue
SELECT p.product_name, COUNT(oi.order_item_id) AS count_purchased, SUM(oi.revenue_usd) AS total_revenue
FROM fact_order_item oi
JOIN dim_product p
	ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY count_purchased DESC
LIMIT 2;

-- Number of returned items for each month in 2023
SELECT d.`month`, COUNT(oir.order_item_refund_id) AS number_of_returns
FROM fact_order_item_refund oir
JOIN dim_date d
    ON oir.refund_date = d.date
WHERE YEAR(oir.refund_date) = 2023
GROUP BY d.`month`
ORDER BY number_of_returns DESC;

-- Average profit by product per quarter
SELECT d.`quarter`, p.product_name, AVG(profit_usd) AS average_profit
FROM fact_order_item oi
JOIN dim_date d
	ON oi.order_date = d.`date`
JOIN dim_product p
	ON oi.product_id = p.product_id
GROUP BY d.`quarter`, d.`month`, p.product_name
ORDER BY d.`quarter`, d.`month`, p.product_name;

-- Average sales by city, zip, and state
SELECT u.billing_state, u.billing_postal_code, u.billing_city, AVG(oi.revenue_usd) AS average_sales
FROM fact_order_item oi
JOIN dim_user u
	ON oi.user_id = u.user_id
GROUP BY u.billing_state, u.billing_postal_code, u.billing_city;
