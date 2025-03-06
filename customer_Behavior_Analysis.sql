#created database
use customer_behavior;

#Extracting Product & Review Data

SELECT p.productID, p.productName, p.category, r.reviewID, r.sentiment, r.rating FROM products p
JOIN customer_reviews r ON p.productID = r.productID
WHERE r.sentiment IS NOT NULL ORDER BY r.rating DESC;

#Joining Engagement Data to Analyze Customer Activity

SELECT p.productName, r.sentiment, cj.action, cj.visitDate 
FROM products p LEFT JOIN customer_reviews r ON p.productID = r.productID
LEFT JOIN customer_journey cj ON p.productID = cj.productID
WHERE cj.action IN ('purchase', 'click') ORDER BY cj.visitDate DESC;

#Ranking Products by Review Count

SELECT p.productName,COUNT(r.reviewID) AS review_count,       
RANK() OVER (ORDER BY COUNT(r.reviewID) DESC) AS rank_position
FROM products p LEFT JOIN customer_reviews r ON p.productID = r.productID GROUP BY p.productName;

#High-Rating Products

WITH HighRated AS (SELECT r.productID, p.productName, AVG(r.rating) AS avg_rating
FROM customer_reviews r JOIN products p ON r.productID = p.productID  
GROUP BY r.productID, p.productName HAVING AVG(r.rating) > 3.5) SELECT * FROM HighRated;

#Most Purchased Product

SELECT productName, total_purchases FROM (
SELECT p.productName, COUNT(cj.action) AS total_purchases FROM products p
JOIN customer_journey cj ON p.productID = cj.productID WHERE cj.action = 'purchase'
GROUP BY p.productName ORDER BY total_purchases DESC ) AS MostPurchased;

#Customers stop engaging in their journey

WITH JourneyStages AS (SELECT stage, COUNT(DISTINCT customerID) AS customer_count FROM customer_journey GROUP BY stage),
Retention AS (SELECT stage, customer_count, LAG(customer_count) 
OVER (ORDER BY FIELD(stage, 'home', 'product page', 'cart', 'purchase')) AS prev_stage_count,
(customer_count * 100.0) / LAG(customer_count) OVER (ORDER BY FIELD(stage, 'home', 'product page', 'cart', 'purchase')) 
AS retention_rate FROM JourneyStages)SELECT * FROM Retention;

#actions correlate successful purchase

SELECT cj.action, COUNT(DISTINCT cj.customerID) AS action_count, 
(COUNT(DISTINCT cj.customerID) * 100.0) / (SELECT COUNT(DISTINCT customerID) 
FROM customer_journey WHERE action = 'purchase') AS conversion_rate FROM customer_journey cj
WHERE cj.customerID IN (SELECT DISTINCT customerID FROM customer_journey WHERE action = 'purchase')
GROUP BY cj.action ORDER BY conversion_rate DESC;

#how long users stay each stage before moving forward

SELECT c.customerID, cu.customerName, c.stage, c.visitDate AS entry_date, SEC_TO_TIME(c.duration) AS time_spent_hms
FROM customer_journey c JOIN customers cu ON c.customerID = cu.customerID  ORDER BY c.customerID, c.visitDate;

#best and worst ratings based on customer reviews

WITH ProductRatings AS (SELECT productID, AVG(rating) AS avg_rating, COUNT(reviewID) AS review_count FROM customer_reviews
GROUP BY productID) SELECT p.productName, pr.avg_rating, pr.review_count FROM ProductRatings pr 
JOIN products p ON pr.productID = p.productID ORDER BY pr.avg_rating DESC;

#customer sentiments affect product sales and engagement

SELECT p.productName, 
COALESCE(SUM(CASE WHEN sa.sentiment_score > 0 THEN 1 ELSE 0 END), 0) AS positive_reviews,
COALESCE(SUM(CASE WHEN sa.sentiment_score < 0 THEN 1 ELSE 0 END), 0) AS negative_reviews,
COALESCE(SUM(CASE WHEN sa.sentiment_score = 0 THEN 1 ELSE 0 END), 0) AS neutral_reviews,
COALESCE(COUNT(ed.EngagementID), 0) AS total_engagements, 
COALESCE(SUM(CASE WHEN cj.action = 'purchase' THEN 1 ELSE 0 END), 0) AS total_purchases  FROM products p
LEFT JOIN sentiment_analysis_results sa ON p.productID = sa.productID  
LEFT JOIN customer_journey cj ON p.productID = cj.productID  
LEFT JOIN engagement_data ed ON p.productID = ed.productID  
GROUP BY p.productName ORDER BY total_purchases DESC;

# customer retention rate

WITH first_time_customers AS (SELECT customerID, DATE_FORMAT(MIN(visitdate), '%Y-%m') AS cohort_month
FROM customer_journey GROUP BY customerID),returning_customers AS (SELECT DISTINCT cj.customerID, ftc.cohort_month,
DATE_FORMAT(cj.visitdate, '%Y-%m') AS returning_month FROM customer_journey cj JOIN first_time_customers ftc 
ON cj.customerID = ftc.customerID WHERE DATE_FORMAT(cj.visitdate, '%Y-%m') > ftc.cohort_month)
SELECT ftc.cohort_month, COUNT(DISTINCT ftc.customerID) AS total_new_customers,
COUNT(DISTINCT rc.customerID) AS retained_customers,
IFNULL(COUNT(DISTINCT rc.customerID) * 100.0 / COUNT(DISTINCT ftc.customerID), 0) AS retention_rate
FROM first_time_customers ftc LEFT JOIN returning_customers rc 
ON ftc.cohort_month = rc.cohort_month GROUP BY ftc.cohort_month ORDER BY ftc.cohort_month;

#Compare Repeat vs. First-Time Buyers

WITH first_last_engagement AS (SELECT cj.customerID, MIN(cj.visitdate) AS first_engagement, MAX(cj.visitdate) AS last_engagement
FROM Customer_Journey cj GROUP BY cj.customerID)
SELECT c.customerID, c.customerName, 'First-Time Customer' AS customer_type
FROM Customers c JOIN first_last_engagement fle ON c.customerID = fle.customerID
WHERE fle.first_engagement = fle.last_engagement
UNION ALL SELECT c.customerID, c.customerName, 'Returning Customer' AS customer_type
FROM Customers c JOIN first_last_engagement fle ON c.customerID = fle.customerID
WHERE fle.first_engagement <> fle.last_engagement
UNION ALL SELECT 'Total First-Time Customers' AS customerID, COUNT(*) AS total_customers,
NULL AS customer_type FROM first_last_engagement WHERE first_engagement = last_engagement
UNION ALL SELECT 'Total Returning Customers' AS customerID, COUNT(*) AS total_customers, NULL AS customer_type
FROM first_last_engagement WHERE first_engagement <> last_engagement;

#Best-Performing Products Per Region

SELECT g.country, p.productName,COUNT(ed.engagementID) AS total_engagements
FROM Engagement_Data ed JOIN Products p ON ed.productID = p.productID JOIN Customer_Journey cj ON ed.productID = cj.productID
JOIN Customers c ON cj.customerID = c.customerID JOIN Geography g ON c.GeographyID = g.GeographyID
GROUP BY g.country, p.productName ORDER BY g.country, total_engagements DESC;

