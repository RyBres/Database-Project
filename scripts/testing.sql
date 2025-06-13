USE customers;

-- === TESTING TRIGGERS FOR BASKET QUANTITY AND TOTAL UPDATE ===

SELECT * FROM FILLED WHERE Customer_ID = 1;

-- Insert a new product into Taylor Swift's basket
INSERT INTO FILLED VALUES ('2025-04-01 10:00:00', 1, 104, 3, NULL);
SELECT * FROM FILLED WHERE Customer_ID = 1;

-- Insert another product into her basket
INSERT INTO FILLED VALUES ('2025-04-01 10:00:00', 1, 109, 1, 450.00);
SELECT * FROM FILLED WHERE Customer_ID = 1;

-- Delete a product from the basket
DELETE FROM FILLED 
WHERE Date_created = '2025-04-01 10:00:00' AND Customer_ID = 1 AND Product_ID = 104;
SELECT * FROM FILLED WHERE Customer_ID = 1;



-- === TESTING TRIGGER FOR BASKET CLOSURE ON TRANSACTION ===

-- Insert transaction to close the basket
INSERT INTO TRANSACT VALUES (
    99, '2025-04-01 13:00:00', 2750.00, 3, '8342739472834723', TRUE,
    '2025-04-03 12:00:00', '2025-04-02 10:00:00', '2025-04-01 10:00:00', 1
);

-- Check if basket was closed (Date_closed set)
SELECT Date_closed 
FROM BASKET 
WHERE Date_created = '2025-04-01 10:00:00' AND Customer_ID = 1;



