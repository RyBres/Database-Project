-- Statistical functional requirements

-- (1) Products sold the most (by total quantity)
SELECT 
    filled.Product_ID,
    prod.Name,
    SUM(filled.Quantity_product) AS Total_Qty
FROM FILLED filled
JOIN TRANSACT tx 
    ON filled.Date_created = tx.Date_created AND filled.Customer_ID = tx.Customer_ID
JOIN PRODUCT_ALL prod 
    ON filled.Product_ID = prod.Product_ID
WHERE tx.Transact_date BETWEEN '2025-04-01' AND '2025-04-30'
GROUP BY filled.Product_ID, prod.Name
ORDER BY Total_Qty DESC;

-- (2) Products sold to the most unique customers
SELECT 
    filled.Product_ID,
    prod.Name,
    COUNT(DISTINCT filled.Customer_ID) AS Buyer_Count
FROM FILLED filled
JOIN TRANSACT tx 
    ON filled.Date_created = tx.Date_created AND filled.Customer_ID = tx.Customer_ID
JOIN PRODUCT_ALL prod 
    ON filled.Product_ID = prod.Product_ID
WHERE tx.Transact_date BETWEEN '2025-04-01' AND '2025-04-30'
GROUP BY filled.Product_ID, prod.Name
ORDER BY Buyer_Count DESC;

-- (3) Top customers by money spent
SELECT 
    c.Customer_ID,
    c.First_name,
    c.Surname,
    SUM(tx.Total_amount) AS Total_Spent
FROM CUSTOMER c
JOIN TRANSACT tx ON tx.Customer_ID = c.Customer_ID
WHERE tx.Transact_date BETWEEN '2025-04-01' AND '2025-04-30'
GROUP BY c.Customer_ID
ORDER BY Total_Spent DESC
LIMIT 10;

-- (4) Zip codes with most shipments
SELECT 
    addr.Zip_code,
    COUNT(*) AS Num_Shipments
FROM TRANSACT tx
JOIN SHIP_CUST sc ON sc.Customer_ID = tx.Customer_ID
JOIN SHIP_ADDR addr ON addr.Addr_name = sc.Addr_name
WHERE tx.Transact_date BETWEEN '2025-04-01' AND '2025-04-30'
GROUP BY addr.Zip_code
ORDER BY Num_Shipments DESC
LIMIT 5;

-- (5) Avg selling price per product type (rounded to 2 decimals)
SELECT 
    prod.Product_type,
    ROUND(AVG(filled.Final_price / filled.Quantity_product), 2) AS Avg_Price
FROM FILLED filled
JOIN TRANSACT tx 
    ON filled.Date_created = tx.Date_created AND filled.Customer_ID = tx.Customer_ID
JOIN PRODUCT_ALL prod 
    ON filled.Product_ID = prod.Product_ID
WHERE tx.Transact_date BETWEEN '2025-04-01' AND '2025-04-30'
GROUP BY prod.Product_type
ORDER BY Avg_Price DESC;


