-- Ryan Bresnahan
-- 04/29/2025

-- ============= SCHEMA =============
-- Create schema and tables.
DROP DATABASE IF EXISTS customers;
CREATE DATABASE customers;
USE customers;


-- ============= TABLES =============
-- Create tables.

CREATE TABLE CUSTOMER_MEMBERSHIP (
    Membership VARCHAR(50) PRIMARY KEY,
    Credit_line DECIMAL(10,2),
    Special_offer TEXT
);

CREATE TABLE CUSTOMER (
    Customer_ID INT AUTO_INCREMENT PRIMARY KEY,
    First_name VARCHAR(50),
    Surname VARCHAR(50),
    Email_address VARCHAR(100),
    Home_address VARCHAR(255),
    Area_code VARCHAR(10),
    Prefix VARCHAR(10),
    Line_number VARCHAR(15),
    Membership VARCHAR(50),
    FOREIGN KEY (Membership) REFERENCES CUSTOMER_MEMBERSHIP(Membership)
);

CREATE TABLE SHIP_ADDR (
    Addr_name VARCHAR(50) PRIMARY KEY,
    Street_name VARCHAR(100),
    Street_number VARCHAR(10),
    City VARCHAR(50),
    State VARCHAR(50),
    Country VARCHAR(50),
    Zip_code VARCHAR(10)
);

CREATE TABLE SHIP_CUST (
-- Changed second shipping address table. It was a product of over-normalization and likely a mix-up -- see Google sheets explanation.
    Addr_name VARCHAR(50),
	Customer_ID INT,
    PRIMARY KEY (Addr_name, Customer_ID),
    FOREIGN KEY (Addr_name) REFERENCES SHIP_ADDR(Addr_name),
    FOREIGN KEY (Customer_ID) REFERENCES CUSTOMER(Customer_ID)
);

CREATE TABLE CRED_CARD (
    Card_number VARCHAR(20) PRIMARY KEY,
    Security_number VARCHAR(10),
    Card_type VARCHAR(30),
    Expiry_date DATE,
    First_name VARCHAR(50),
    Surname VARCHAR(50),
    Billing_address VARCHAR(255),
    Customer_ID INT,
    FOREIGN KEY (Customer_ID) REFERENCES CUSTOMER(Customer_ID)
);

CREATE TABLE BASKET (
    Date_created DATETIME,
    Total_amount DECIMAL(10,2),
    Date_closed DATETIME,
    Quantity_items INT,
    Customer_ID INT,
    PRIMARY KEY (Date_created, Customer_ID),
    FOREIGN KEY (Customer_ID) REFERENCES CUSTOMER(Customer_ID)
);


CREATE TABLE PRODUCT_ALL (
    Product_ID INT PRIMARY KEY,
    Name VARCHAR(100),
    Description TEXT,
    Rec_price DECIMAL(10,2),
    Product_type VARCHAR(50)
);

CREATE TABLE FILLED (
    Date_created DATETIME,
    Customer_ID INT,
    Product_ID INT,
    Quantity_product INT,
    Final_price DECIMAL(10,2),
    PRIMARY KEY (Date_created, Customer_ID, Product_ID),
    FOREIGN KEY (Date_created, Customer_ID) REFERENCES BASKET(Date_created, Customer_ID),
    FOREIGN KEY (Product_ID) REFERENCES PRODUCT_ALL(Product_ID)
);

CREATE TABLE PRODUCT_LAPTOP (
    Product_ID INT PRIMARY KEY,
    CPU_type VARCHAR(50),
    Weight DECIMAL(6,2),
    Battery_time VARCHAR(50),
    FOREIGN KEY (Product_ID) REFERENCES PRODUCT_ALL(Product_ID)
);

CREATE TABLE PRODUCT_DESKTOP (
    Product_ID INT PRIMARY KEY,
    CPU_type VARCHAR(50),
    Weight DECIMAL(6,2),
    FOREIGN KEY (Product_ID) REFERENCES PRODUCT_ALL(Product_ID)
);

CREATE TABLE PRODUCT_PRINTER (
    Product_ID INT PRIMARY KEY,
    Printer_type VARCHAR(50),
    Weight DECIMAL(6,2),
    FOREIGN KEY (Product_ID) REFERENCES PRODUCT_ALL(Product_ID)
);

CREATE TABLE PRINTER_SOLUTIONS (
    Product_ID INT,
    Solutions VARCHAR(50),
    PRIMARY KEY (Product_ID, Solutions),
    FOREIGN KEY (Product_ID) REFERENCES PRODUCT_ALL(Product_ID)
);

CREATE TABLE OFFER (
    Product_ID INT,
    Member_tier VARCHAR(50),
    Discount DECIMAL(5,2),
    PRIMARY KEY (Product_ID, Member_tier),
    FOREIGN KEY (Product_ID) REFERENCES PRODUCT_ALL(Product_ID)
);

CREATE TABLE TRANSACT (
    Transact_ID INT AUTO_INCREMENT PRIMARY KEY,
    Transact_date DATETIME,
    Total_amount DECIMAL(10,2),
    Num_items INT,
    Credit_card VARCHAR(20),
    Delivered_tag BOOLEAN,
    Deliver_date DATETIME,
    Ship_date DATETIME,
    Date_created DATETIME,
    Customer_ID INT,
    FOREIGN KEY (Customer_ID) REFERENCES CUSTOMER(Customer_ID)
);



-- ============= TRIGGERS =============
-- Add triggers and application logic.
DELIMITER //

-- (1) Update basket quantity_items after insert into FILLED
CREATE DEFINER = CURRENT_USER TRIGGER update_basket_qtyitem_after_insert
AFTER INSERT ON `FILLED` 
FOR EACH ROW
BEGIN
    UPDATE BASKET
    SET Quantity_items = 
    (
        SELECT IFNULL(SUM(Quantity_product), 0)
        FROM FILLED
        WHERE Date_created = NEW.Date_created
          AND Customer_ID = NEW.Customer_ID
    )
    WHERE Date_created = NEW.Date_created
      AND Customer_ID = NEW.Customer_ID;
END;
//

-- (2) Update basket total_amount after insert into FILLED
CREATE DEFINER = CURRENT_USER TRIGGER update_basket_totamt_after_insert 
AFTER INSERT ON `FILLED` 
FOR EACH ROW
BEGIN
    UPDATE BASKET
    SET Total_amount = (
        SELECT IFNULL(SUM(Final_price), 0)
        FROM FILLED
        WHERE Date_created = NEW.Date_created
          AND Customer_ID = NEW.Customer_ID
    )
    WHERE Date_created = NEW.Date_created
      AND Customer_ID = NEW.Customer_ID;
END;
//

-- (3) Base the final price in FILLED on recommended price Rec_price in PRODUCT
CREATE TRIGGER set_filled_final_price
BEFORE INSERT ON FILLED
FOR EACH ROW
BEGIN
    DECLARE base_price DECIMAL(10,2);
    DECLARE discount_percent DECIMAL(5,2) DEFAULT 0.00;

    -- Get the base price
    SELECT Rec_price INTO base_price
    FROM PRODUCT_ALL
    WHERE Product_ID = NEW.Product_ID;

    -- Get the discount
    SELECT o.Discount INTO discount_percent
    FROM CUSTOMER c
    JOIN OFFER o ON o.Member_tier = c.Membership AND o.Product_ID = NEW.Product_ID
    WHERE c.Customer_ID = NEW.Customer_ID
    LIMIT 1;

    -- Calculate final price w/ discount
    SET NEW.Final_price = NEW.Quantity_product * base_price * (1 - (discount_percent / 100));
END;
//

-- (4) Update basket quantity_items after deletion from FILLED
CREATE DEFINER = CURRENT_USER TRIGGER update_basket_qtyitem_after_remove
AFTER DELETE ON `FILLED` 
FOR EACH ROW
BEGIN
    UPDATE BASKET
    SET Quantity_items = 
    (
        SELECT IFNULL(SUM(Quantity_product), 0)
        FROM FILLED
        WHERE Date_created = OLD.Date_created
          AND Customer_ID = OLD.Customer_ID
    )
    WHERE Date_created = OLD.Date_created
      AND Customer_ID = OLD.Customer_ID;
END;
//

-- (5) Update basket total_amount after deletion from FILLED
CREATE DEFINER = CURRENT_USER TRIGGER update_basket_totamt_after_removal 
AFTER DELETE ON `FILLED` 
FOR EACH ROW
BEGIN
    UPDATE BASKET
    SET Total_amount = 
    (
        SELECT IFNULL(SUM(Final_price), 0)
        FROM FILLED
        WHERE Date_created = OLD.Date_created
          AND Customer_ID = OLD.Customer_ID
    )
    WHERE Date_created = OLD.Date_created
      AND Customer_ID = OLD.Customer_ID;
END;
//

-- (6) Prevent duplicate email on CUSTOMER insert
CREATE DEFINER = CURRENT_USER TRIGGER check_if_user_exists 
BEFORE INSERT ON `CUSTOMER` 
FOR EACH ROW
BEGIN
    IF EXISTS 
    (
        SELECT 1 FROM CUSTOMER WHERE Email_address = NEW.Email_address
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'That email address is already being used.';
    END IF;
END;
//

-- (7) Create empty basket in BASKET when new user is registered in CUSTOMER
CREATE TRIGGER create_basket_after_customer
AFTER INSERT ON CUSTOMER
FOR EACH ROW
BEGIN
    INSERT INTO BASKET (Date_created, Customer_ID, Quantity_items, Total_amount)
    VALUES (NOW(), NEW.Customer_ID, 0, 0.00);
END;
//

DELIMITER ;



-- ============= DATA =============
-- Insert data into the tables.

-- CUSTOMER_MEMBERSHIP
INSERT INTO CUSTOMER_MEMBERSHIP VALUES 
('Gold', 10000.00, 'Free shipping'),
('Silver', 5000.00, '5% discount'),
('Bronze', 1000.00, 'None'),
('Platinum', 20000.00, 'Priority support'),
('Basic', 500.00, 'Limited offers');

-- CUSTOMER
INSERT INTO CUSTOMER VALUES 
(1, 'Taylor', 'Swift', 'taylor@gmail.com', '101 Main St', '212', '555', '3812', 'Gold'),
(2, 'Dwayne', 'Johnson', 'dwayne@gmail.com', '202 Oak Ave', '310', '555', '7482', 'Silver'),
(3, 'Zendaya', 'Coleman', 'zendaya@gmail.com', '303 Pine Rd', '213', '555', '1283', 'Bronze'),
(4, 'Drake', 'Graham', 'drake@gmail.com', '404 Elm Blvd', '416', '555', '9332', 'Gold'),
(5, 'Ariana', 'Grande', 'ariana@gmail.com', '505 Cedar Ln', '305', '555', '6721', 'Platinum'),
(6, 'Chris', 'Hemsworth', 'chris@gmail.com', '606 Maple Dr', '213', '555', '8843', 'Silver'),
(7, 'Emma', 'Watson', 'emma@gmail.com', '707 Birch Pl', '212', '555', '1174', 'Bronze'),
(8, 'Bruno', 'Mars', 'bruno@gmail.com', '808 Ash Ct', '310', '555', '3349', 'Basic'),
(9, 'Gal', 'Gadot', 'gal@gmail.com', '909 Cherry St', '213', '555', '5920', 'Platinum'),
(10, 'Billie', 'Eilish', 'billie@gmail.com', '100 Apple Rd', '310', '555', '9011', 'Gold');

-- SHIP_ADDR
INSERT INTO SHIP_ADDR VALUES 
('TS_Home', 'Main St', '101', 'New York', 'NY', 'USA', '10001'),
('DJ_Home', 'Oak Ave', '202', 'Los Angeles', 'CA', 'USA', '90012'),
('Z_Home', 'Pine Rd', '303', 'San Francisco', 'CA', 'USA', '94102'),
('D_Home', 'Elm Blvd', '404', 'Toronto', 'ON', 'Canada', 'M5H2N2'),
('A_Home', 'Cedar Ln', '505', 'Miami', 'FL', 'USA', '33130'),
('C_Home', 'Maple Dr', '606', 'Sydney', 'NSW', 'Australia', '2000'),
('E_Home', 'Birch Pl', '707', 'London', 'ENG', 'UK', 'WC2N5DU'),
('B_Home', 'Ash Ct', '808', 'Austin', 'TX', 'USA', '73301'),
('G_Home', 'Cherry St', '909', 'Tel Aviv', 'TA', 'Israel', '61000'),
('BE_Home', 'Apple Rd', '100', 'Pasadena', 'CA', 'USA', '91101');

-- SHIP_CUST
INSERT INTO SHIP_CUST VALUES 
('TS_Home', 1),
('DJ_Home', 2),
('Z_Home', 3),
('D_Home', 4),
('A_Home', 5),
('C_Home', 6),
('E_Home', 7),
('B_Home', 8),
('G_Home', 9),
('BE_Home', 10);

-- CRED_CARD
INSERT INTO CRED_CARD VALUES 
('8342739472834723', '123', 'Visa', '2026-01-01', 'Taylor', 'Swift', '101 Main St', 1),
('9283749283749283', '234', 'MasterCard', '2027-02-02', 'Dwayne', 'Johnson', '202 Oak Ave', 2),
('8374928374928374', '345', 'Amex', '2025-03-03', 'Zendaya', 'Coleman', '303 Pine Rd', 3),
('9238479238479238', '456', 'Visa', '2026-04-04', 'Drake', 'Graham', '404 Elm Blvd', 4),
('1938471938471938', '567', 'Discover', '2027-05-05', 'Ariana', 'Grande', '505 Cedar Ln', 5),
('3847293847293847', '678', 'Visa', '2025-06-06', 'Chris', 'Hemsworth', '606 Maple Dr', 6),
('8172638172638172', '789', 'MasterCard', '2026-07-07', 'Emma', 'Watson', '707 Birch Pl', 7),
('1029381029381029', '890', 'Amex', '2025-08-08', 'Bruno', 'Mars', '808 Ash Ct', 8),
('5647385647385647', '901', 'Visa', '2027-09-09', 'Gal', 'Gadot', '909 Cherry St', 9),
('0192830192830192', '012', 'MasterCard', '2026-10-10', 'Billie', 'Eilish', '100 Apple Rd', 10);

-- PRODUCT_ALL
INSERT INTO PRODUCT_ALL VALUES 
(101, 'Laptop Pro', 'High-end laptop', 1500.00, 'Laptop'),
(102, 'Gaming Desktop', 'High-end gaming desktop', 1200.00, 'Desktop'),
(103, 'Office Printer', 'Compact inkjet printer', 200.00, 'Printer'),
(104, 'Tablet Mini', 'Portable tablet', 400.00, 'Laptop'),
(105, 'Graphic Workstation', 'Professional desktop', 2500.00, 'Desktop'),
(106, '3D Printer', 'Advanced 3D printing', 3500.00, 'Printer'),
(107, 'Business Laptop', 'Corporate use laptop', 1100.00, 'Laptop'),
(108, 'Budget Desktop', 'Entry-level desktop', 700.00, 'Desktop'),
(109, 'Photo Printer', 'High-resolution printer', 450.00, 'Printer'),
(110, 'Ultra Laptop', 'Lightweight laptop', 1800.00, 'Laptop');

-- PRODUCT_LAPTOP
INSERT INTO PRODUCT_LAPTOP VALUES 
(101, 'Intel i7', 2.5, '10 hours'),
(104, 'Intel M3', 1.2, '12 hours'),
(107, 'Intel i5', 2.0, '8 hours'),
(110, 'AMD Ryzen 5', 1.8, '11 hours');

-- PRODUCT_DESKTOP
INSERT INTO PRODUCT_DESKTOP VALUES 
(102, 'AMD Ryzen 7', 5.0),
(105, 'Intel Xeon', 7.5),
(108, 'Intel i3', 4.2);

-- PRODUCT_PRINTER
INSERT INTO PRODUCT_PRINTER VALUES 
(103, 'Inkjet', 3.2),
(106, '3D Resin', 15.0),
(109, 'Laser', 5.0);

-- PRINTER_SOLUTIONS
INSERT INTO PRINTER_SOLUTIONS VALUES 
(103, 'AirPrint'),
(103, 'Wi-Fi Direct'),
(106, '3D Model Slicer'),
(109, 'High Speed'),
(109, 'Color Photo Quality');

-- OFFER
INSERT INTO OFFER VALUES 
(104, 'Gold', 12.00),
(101, 'Gold', 10.00),
(102, 'Silver', 5.00),
(103, 'Bronze', 3.00),
(104, 'Platinum', 12.00),
(105, 'Gold', 15.00),
(106, 'Silver', 7.00),
(107, 'Basic', 2.00),
(108, 'Bronze', 4.00),
(109, 'Platinum', 9.00),
(110, 'Gold', 11.00);

-- BASKET
INSERT INTO BASKET VALUES 
('2025-04-01 10:00:00', 1800.00, '2025-04-02 15:00:00', 2, 1),
('2025-04-02 11:00:00', 700.00, NULL, 1, 2),
('2025-04-03 09:30:00', 650.00, '2025-04-04 10:00:00', 1, 3),
('2025-04-04 14:00:00', 3500.00, NULL, 1, 4),
('2025-04-05 16:30:00', 1200.00, '2025-04-06 18:00:00', 1, 5),
('2025-04-06 13:45:00', 200.00, '2025-04-07 14:30:00', 1, 6),
('2025-04-07 12:15:00', 400.00, NULL, 1, 7),
('2025-04-08 15:50:00', 2500.00, '2025-04-09 17:00:00', 1, 8),
('2025-04-09 10:20:00', 450.00, NULL, 1, 9),
('2025-04-10 09:00:00', 1800.00, '2025-04-11 11:00:00', 1, 10);

-- FILLED
INSERT INTO FILLED VALUES 
('2025-04-01 10:00:00', 1, 101, 1, 1500.00),
('2025-04-01 10:00:00', 1, 110, 1, 1800.00),
('2025-04-02 11:00:00', 2, 108, 1, 700.00),
('2025-04-03 09:30:00', 3, 109, 1, 450.00),
('2025-04-03 09:30:00', 3, 103, 1, 200.00),
('2025-04-04 14:00:00', 4, 106, 1, 3500.00),
('2025-04-05 16:30:00', 5, 102, 1, 1200.00),
('2025-04-06 13:45:00', 6, 103, 1, 200.00),
('2025-04-07 12:15:00', 7, 104, 1, 400.00),
('2025-04-08 15:50:00', 8, 105, 1, 2500.00);

-- TRANSACT
INSERT INTO TRANSACT VALUES
(1, '2025-04-01 12:00:00', 1800.00, 2, '8342739472834723', TRUE, '2025-04-04 12:00:00', '2025-04-02 10:00:00', '2025-04-01 10:00:00', 1),
(2, '2025-04-02 14:30:00', 700.00, 1, '9283749283749283', FALSE, NULL, '2025-04-03 09:00:00', '2025-04-02 11:00:00', 2),
(3, '2025-04-03 09:30:00', 650.00, 2, '8374928374928374', TRUE, '2025-04-05 11:00:00', '2025-04-04 08:00:00', '2025-04-03 09:30:00', 3),
(4, '2025-04-04 15:00:00', 3500.00, 1, '9238479238479238', FALSE, NULL, '2025-04-05 10:00:00', '2025-04-04 14:00:00', 4),
(5, '2025-04-05 16:00:00', 1200.00, 1, '1938471938471938', TRUE, '2025-04-08 10:00:00', '2025-04-06 12:00:00', '2025-04-05 16:30:00', 5),
(6, '2025-04-06 13:15:00', 200.00, 1, '3847293847293847', TRUE, '2025-04-08 09:30:00', '2025-04-07 08:30:00', '2025-04-06 13:45:00', 6),
(7, '2025-04-07 11:30:00', 400.00, 1, '8172638172638172', FALSE, NULL, '2025-04-08 09:00:00', '2025-04-07 12:15:00', 7),
(8, '2025-04-08 15:00:00', 2500.00, 1, '1111222233334444', TRUE, '2025-04-10 12:00:00', '2025-04-09 10:00:00', '2025-04-08 15:50:00', 8),
(9, '2025-04-09 10:45:00', 450.00, 1, '4729384729384729', TRUE, '2025-04-12 11:00:00', '2025-04-10 09:00:00', '2025-04-09 10:20:00', 9),
(10, '2025-04-10 09:30:00', 1800.00, 1, '0192830192830192', TRUE, '2025-04-13 12:30:00', '2025-04-11 10:00:00', '2025-04-10 09:00:00', 10);






