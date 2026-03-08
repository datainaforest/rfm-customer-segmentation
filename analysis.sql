/* =====================================================
   CUSTOMER SEGMENTATION ANALYSIS (RFM)
   Author: Łukasz Trzeciak
   Dataset: Online Retail
   ===================================================== */


/* =====================================================
   1. DATA CLEANING CHECK
   ===================================================== */

/* Valid transactions only */
SELECT COUNT(*) AS cleaned_records
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL;

/* Date range */
SELECT
    MIN(InvoiceDate) AS first_purchase_date,
    MAX(InvoiceDate) AS last_purchase_date
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL;


/* =====================================================
   2. KPI METRICS
   ===================================================== */

/* Total revenue */
SELECT
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL;

/* Total customers */
SELECT
    COUNT(DISTINCT CustomerID) AS total_customers
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL;

/* Average revenue per customer */
SELECT
    ROUND(SUM(Quantity * UnitPrice) / COUNT(DISTINCT CustomerID), 2) AS avg_revenue_per_customer
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL;

/* Average orders per customer */
SELECT
    ROUND(COUNT(DISTINCT InvoiceNo) / COUNT(DISTINCT CustomerID), 2) AS avg_orders_per_customer
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL;


/* =====================================================
   3. MONTHLY REVENUE TREND
   ===================================================== */

SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS order_month,
    ROUND(SUM(Quantity * UnitPrice), 2) AS monthly_revenue
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL
GROUP BY order_month
ORDER BY order_month;


/* =====================================================
   4. REVENUE BY COUNTRY
   ===================================================== */

SELECT
    Country,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL
GROUP BY Country
ORDER BY total_revenue DESC;


/* =====================================================
   5. TOP CUSTOMERS BY REVENUE
   ===================================================== */

SELECT
    CustomerID,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue,
    COUNT(DISTINCT InvoiceNo) AS total_orders
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL
GROUP BY CustomerID
ORDER BY total_revenue DESC
LIMIT 10;


/* =====================================================
   6. RFM BASE TABLE
   ===================================================== */

SELECT
    CustomerID,
    MAX(InvoiceDate) AS last_purchase_date,
    DATEDIFF(
        (SELECT MAX(InvoiceDate)
         FROM online_retail
         WHERE InvoiceNo NOT LIKE 'C%'
           AND Quantity > 0
           AND UnitPrice > 0
           AND CustomerID IS NOT NULL),
        MAX(InvoiceDate)
    ) AS recency,
    COUNT(DISTINCT InvoiceNo) AS frequency,
    ROUND(SUM(Quantity * UnitPrice), 2) AS monetary
FROM online_retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL
GROUP BY CustomerID
ORDER BY monetary DESC;


/* =====================================================
   7. RFM SCORING
   ===================================================== */

WITH rfm AS (
    SELECT
        CustomerID,
        DATEDIFF(
            (SELECT MAX(InvoiceDate)
             FROM online_retail
             WHERE InvoiceNo NOT LIKE 'C%'
               AND Quantity > 0
               AND UnitPrice > 0
               AND CustomerID IS NOT NULL),
            MAX(InvoiceDate)
        ) AS recency,
        COUNT(DISTINCT InvoiceNo) AS frequency,
        SUM(Quantity * UnitPrice) AS monetary
    FROM online_retail
    WHERE InvoiceNo NOT LIKE 'C%'
      AND Quantity > 0
      AND UnitPrice > 0
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
)
SELECT
    CustomerID,
    recency,
    frequency,
    ROUND(monetary, 2) AS monetary,
    NTILE(4) OVER (ORDER BY recency DESC) AS r_score,
    NTILE(4) OVER (ORDER BY frequency) AS f_score,
    NTILE(4) OVER (ORDER BY monetary) AS m_score
FROM rfm;


/* =====================================================
   8. CUSTOMER SEGMENTATION
   ===================================================== */

WITH rfm AS (
    SELECT
        CustomerID,
        DATEDIFF(
            (SELECT MAX(InvoiceDate)
             FROM online_retail
             WHERE InvoiceNo NOT LIKE 'C%'
               AND Quantity > 0
               AND UnitPrice > 0
               AND CustomerID IS NOT NULL),
            MAX(InvoiceDate)
        ) AS recency,
        COUNT(DISTINCT InvoiceNo) AS frequency,
        SUM(Quantity * UnitPrice) AS monetary
    FROM online_retail
    WHERE InvoiceNo NOT LIKE 'C%'
      AND Quantity > 0
      AND UnitPrice > 0
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
),
rfm_scores AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency) AS f_score,
        NTILE(4) OVER (ORDER BY monetary) AS m_score
    FROM rfm
)
SELECT
    CustomerID,
    recency,
    frequency,
    ROUND(monetary, 2) AS monetary,
    CASE
        WHEN r_score = 4 AND f_score >= 3 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 3 AND f_score = 2 THEN 'Potential Loyalists'
        WHEN r_score = 2 THEN 'At Risk'
        ELSE 'Lost Customers'
    END AS customer_segment
FROM rfm_scores;


/* =====================================================
   9. CUSTOMER SEGMENT DISTRIBUTION
   ===================================================== */

WITH rfm AS (
    SELECT
        CustomerID,
        DATEDIFF(
            (SELECT MAX(InvoiceDate)
             FROM online_retail
             WHERE InvoiceNo NOT LIKE 'C%'
               AND Quantity > 0
               AND UnitPrice > 0
               AND CustomerID IS NOT NULL),
            MAX(InvoiceDate)
        ) AS recency,
        COUNT(DISTINCT InvoiceNo) AS frequency,
        SUM(Quantity * UnitPrice) AS monetary
    FROM online_retail
    WHERE InvoiceNo NOT LIKE 'C%'
      AND Quantity > 0
      AND UnitPrice > 0
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
),
rfm_scores AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency) AS f_score,
        NTILE(4) OVER (ORDER BY monetary) AS m_score
    FROM rfm
),
segments AS (
    SELECT
        *,
        CASE
            WHEN r_score = 4 AND f_score >= 3 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 3 AND f_score = 2 THEN 'Potential Loyalists'
            WHEN r_score = 2 THEN 'At Risk'
            ELSE 'Lost Customers'
        END AS segment
    FROM rfm_scores
)

SELECT
    segment,
    COUNT(*) AS total_customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM segments
GROUP BY segment
ORDER BY total_customers DESC;


/* =====================================================
   10. REVENUE BY CUSTOMER SEGMENT
   ===================================================== */

WITH rfm AS (
    SELECT
        CustomerID,
        DATEDIFF(
            (SELECT MAX(InvoiceDate)
             FROM online_retail
             WHERE InvoiceNo NOT LIKE 'C%'
               AND Quantity > 0
               AND UnitPrice > 0
               AND CustomerID IS NOT NULL),
            MAX(InvoiceDate)
        ) AS recency,
        COUNT(DISTINCT InvoiceNo) AS frequency,
        SUM(Quantity * UnitPrice) AS monetary
    FROM online_retail
    WHERE InvoiceNo NOT LIKE 'C%'
      AND Quantity > 0
      AND UnitPrice > 0
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
),
rfm_scores AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency) AS f_score,
        NTILE(4) OVER (ORDER BY monetary) AS m_score
    FROM rfm
),
segments AS (
    SELECT
        *,
        CASE
            WHEN r_score = 4 AND f_score >= 3 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 3 AND f_score = 2 THEN 'Potential Loyalists'
            WHEN r_score = 2 THEN 'At Risk'
            ELSE 'Lost Customers'
        END AS segment
    FROM rfm_scores
)

SELECT
    segment,
    ROUND(SUM(monetary), 2) AS total_revenue
FROM segments
GROUP BY segment
ORDER BY total_revenue DESC;
