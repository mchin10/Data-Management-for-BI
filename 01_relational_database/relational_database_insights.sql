/* quick look at the tables */
SELECT *
FROM website_sessions
WHERE website_session_id = 1059;
SELECT *
FROM website_pageviews
WHERE website_session_id = 1059;
SELECT *
FROM orders
WHERE website_session_id = 1059;
SELECT *
FROM order_items
WHERE order_id = 32;
SELECT *
FROM products;
SELECT *
FROM order_item_refunds
LIMIT 10;

# tasks to be completed.  Please note that the database have some materialized views already created.  You cannot use them!  Any query created with any information other than the tables shown in the ERD will not receive any point.
# Assign 1.2.1(5 points)
/*
Traffic Source Conversion Rates
From: Robert (Marketing Director)
Subject: Google Conversion Rate
It appears that google nonbrand is the primary source of our website traffic,  but we need to assess whether these sessions are resulting 
in actual sales. To do this, please calculate the Conversion Rate (CVR) from sessions to orders. Our target minimum CVR is 4% to ensure 
our advertising expenses are justified. If our CVR falls below this threshold, we will consider reducing our advertising bids. Conversely, 
if the CVR exceeds 4%, we can consider increasing our bids to generate more traffic and potential sales.
Business Question: 
	What is the conversion rate (CVR) from sessions to orders comming from Google non-brand sources?
	Are we below or above our target minimum CVR and what action needs to be taken?
Expected Output: 
	A single value containing the CVR for Google non-brand website traffic.
*/
WITH google_sessions AS (
    SELECT website_session_id, user_id
    FROM website_sessions
    WHERE utm_source = 'google' 
    AND utm_campaign = 'nonbrand'
),
customer_orders AS (
    SELECT
        o.user_id,
        COUNT(o.order_id) AS total_orders
    FROM orders o
    JOIN google_sessions g ON o.website_session_id = g.website_session_id
    GROUP BY o.user_id
)
SELECT
    (SUM(co.total_orders) / (SELECT COUNT(website_session_id) FROM google_sessions)) * 100 AS conversion_rate
FROM customer_orders co;
/*
Insight: 
	The CVR for Google non-brand traffic is about 6.66%, which exceeds our target minimum CVR of 4%.
Recommendation: 
	We can consider increasing our advertising bids to generate more traffic and potential sales.
Prediction: 
	Increasing our advertising bids could help to generate more traffic and potential sales.
*/

# Assign 1.2.2 (5 points)
/*
Top Landing Pages
From: Cheryl (Website Manager)
Subject: Top Entry Pages
Can you pull a list of the most frequently visited entry pages on our website? 
I'd like to verify where our users are first landing when they visit the site.
Business Question: 
	What are the most frequently visited landing pages on our website?
Expected Output: 
	A table showing the number of visits for each landing page.
Concepts:
GROUP BY
Aggregate functions
CTE
Window function
*/
WITH first_pageviews AS (
    SELECT
        wp.website_session_id,
        wp.pageview_url,
        ROW_NUMBER() OVER (PARTITION BY wp.website_session_id ORDER BY wp.created_at) AS row_num
    FROM website_pageviews wp
)
SELECT
    fp.pageview_url,
    COUNT(fp.pageview_url) AS visit_count
FROM first_pageviews fp
WHERE fp.row_num = 1
GROUP BY fp.pageview_url
ORDER BY visit_count DESC;
/*
Insight:
	The most frequently visited landing page is the /home page, closely followed by /lp-2.
    /lp-4 is rarely the landing page compared to other pages.
Recommendation:
	Investigate further conversions or bounces between landing pages. 
    Consider improving traffic to less visited pages such as /lp-4.
    Increase pathways to conversions on frequently visited pages like /home and /lp-1.
Prediction:
	Conversions and bounces may give more insight on which pages to optimize.
	Underperforming pages such as /lp-4 may need increased advertising spend or improved traffic.
	Boosting pathways to conversions on /home and /lp-1 could increase sales and engagement.
*/

# Assign 1.2.3 (5 points)
/*
Bounce Rates
From: Cheryl (Website Manager)
Subject: Bounce Rate Analysis

All our incoming traffic goes to the homepage. Let's assess the performance of this landing page. 
Could you please provide the following metrics related to the homepage:
Total Sessions
Bounced Sessions(a bounce happens when the user does not visit anything beyond the landing page)
Bounce Rate (Percentage of Sessions that Bounced)
STEP 1: find the first website_pageview_id for relevant sessions
STEP 2: identify the landing page URL of each session
STEP 3: count the # of pageviews for each session to identify bounces
If there's only one pageview, it means the user left the website after viewing just the landing page aka a bounce.
STEP 4: summarize total sessions and bounced sessions by landing page
Business Question:
	What are the total sessions, bounced sessions, and bounce rate for the homepage as a landing page?
Expected Output:
	A table listing the total sessions, bounced sessions, and bounce rate for sessions starting with the homepage.
Concepts:
GROUP BY with HAVING
Multiple CTEs
*/
WITH first_pageview AS (
    -- STEP 1: find the first website_pageview_id for relevant sessions
    SELECT 
        website_session_id, 
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
), 
landing_pages AS (
    -- STEP 2: identify the landing page URL of each session
    SELECT 
        fp.website_session_id, 
        p.pageview_url AS landing_page
    FROM first_pageview fp
    JOIN website_pageviews p 
        ON fp.first_pageview_id = p.website_pageview_id
),
session_pageview_counts AS (
    -- STEP 3: count the # of pageviews for each session to identify bounces
    SELECT 
        website_session_id, 
        COUNT(*) AS pageview_count
    FROM website_pageviews
    GROUP BY website_session_id
),
bounced_sessions AS (
    -- Identify bounced sessions
    SELECT 
        sp.website_session_id
    FROM session_pageview_counts sp
    WHERE sp.pageview_count = 1
)
-- STEP 4: summarize total sessions and bounced sessions by landing page
SELECT 
    lp.landing_page, 
    COUNT(DISTINCT lp.website_session_id) AS total_sessions,
    COUNT(DISTINCT b.website_session_id) AS bounced_sessions,
    ROUND(100.0 * COUNT(DISTINCT b.website_session_id) / COUNT(DISTINCT lp.website_session_id), 2) AS bounce_rate
FROM landing_pages lp
LEFT JOIN bounced_sessions b 
    ON lp.website_session_id = b.website_session_id
GROUP BY lp.landing_page
HAVING lp.landing_page = '/home';
/*
Insight:
	137,576 sessions began on the homepage.
    57,346 (41.68% of total sessions) sessions bounced, meaning they left the website after landing on the homepage.
    A significant portion of the sessions left the website after landing at the homepage.
Recommendation:
	Optimize homepage content to increase pathways to conversions to reduce bounce rate and increase sales.
Prediction:
	Improving the accessibility to conversions from the home pgage could reduce bounce rate and increase sales and other conversions.
*/

