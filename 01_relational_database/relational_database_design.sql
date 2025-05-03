-- CREATE TABLES

CREATE TABLE company (
    company_id INT AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(255),
    company_address VARCHAR(255),
    company_phone VARCHAR(255),
    company_best_time TIME
);

CREATE TABLE customer (
	cust_code INT AUTO_INCREMENT PRIMARY KEY,
    cust_fn VARCHAR(255),
    cust_ln VARCHAR(255),
    cust_address VARCHAR(255),
    cust_phone VARCHAR(255),
    cust_signature VARCHAR(255),
    company_id INT,
	FOREIGN KEY (company_id) REFERENCES company(company_id)
);

CREATE TABLE product (
	product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_model VARCHAR(255)
);

CREATE TABLE sales_rep (
	sales_rep_id INT AUTO_INCREMENT PRIMARY KEY,
    sales_rep_phone_office VARCHAR(255),
    sales_rep_phone_mobile VARCHAR(255)
);

CREATE TABLE `order` (
	order_id INT AUTO_INCREMENT PRIMARY KEY,
    order_date DATE,
    cust_code INT,
    sales_rep_id INT,
    FOREIGN KEY (cust_code) REFERENCES customer(cust_code),
    FOREIGN KEY (sales_rep_id) REFERENCES sales_rep(sales_rep_id)
);

CREATE TABLE payment (
	invoice_no VARCHAR(255) PRIMARY KEY,
    payment_status VARCHAR(255),
    payment_date DATE,
    payment_acct_no VARCHAR(255),
    payment_method VARCHAR(255),
    order_id INT,
    FOREIGN KEY (order_id) REFERENCES `order`(order_id)
);

CREATE TABLE shipment (
	shipment_id INT AUTO_INCREMENT PRIMARY KEY,
    shipment_carrier VARCHAR(255),
    tracking_no INT,
    ship_date DATE,
    delivery_date DATE,
    ship_status VARCHAR(255),
    date_received DATE,
    person_received VARCHAR(255),
    order_id INT,
    FOREIGN KEY (order_id) REFERENCES `order`(order_id)
);

CREATE TABLE order_details (
	order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10,2),
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES `order`(order_id),
    FOREIGN KEY (product_id) REFERENCES product(product_id)
);

-- Order history (customer details, products, order and delivery dates, pricing)
SELECT c.cust_fn, c.cust_ln, c.cust_address, c.cust_phone,
	p.product_model, o.order_date, s.ship_date,
    SUM(od.unit_price * od.quantity) AS total
FROM customer c
JOIN `order` o ON c.cust_code = o.cust_code
JOIN shipment s ON o.order_id = s.order_id
JOIN order_details od ON o.order_id = od.order_id
JOIN product p ON od.product_id = p.product_id
GROUP BY c.cust_fn, c.cust_ln, c.cust_address, c.cust_phone, p.product_model, o.order_date, s.ship_date;

-- Shipment tracking (product details, carrier, tracking number, shipping status)
SELECT p.product_model, s.shipment_carrier, s.tracking_no, s.ship_status
FROM product p
JOIN order_details od ON p.product_id = od.product_id
JOIN `order` o ON od.order_id = o.order_id
JOIN shipment s ON o.order_id = s.order_id
ORDER BY s.shipment_carrier;

-- Revenue breakdown (by customer and product model)
SELECT c.cust_fn, c.cust_ln, p.product_model, 
	SUM(od.quantity * od.unit_price) AS revenue 
FROM customer c
JOIN `order` o ON c.cust_code = o.cust_code
JOIN order_details od ON o.order_id = od.order_id
JOIN product p ON od.product_id = p.product_id
GROUP BY c.cust_fn, c.cust_ln, p.product_model;

-- Product sales by company
SELECT co.company_name, p.product_model, SUM(od.unit_price * od.quantity) AS revenue
FROM company co
JOIN customer c ON co.company_id = c.company_id
JOIN `order` o ON c.cust_code = o.cust_code
JOIN order_details od ON o.order_id = od.order_id
JOIN product p ON od.product_id = p.product_id
GROUP BY co.company_name, p.product_model;

