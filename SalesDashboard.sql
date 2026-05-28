
--  Real-Time Sales Intelligence Dashboard



-- 1. CREATE & USE DATABASE

CREATE DATABASE SalesDashboard
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE SalesDashboard;


-- 2. DIMENSION TABLES


-- Products table
CREATE TABLE Products (
    ProductID       INT             AUTO_INCREMENT PRIMARY KEY,
    ProductName     VARCHAR(100)    NOT NULL,
    Category        VARCHAR(50)     NOT NULL,
    SubCategory     VARCHAR(50)     NULL,
    UnitPrice       DECIMAL(10,2)   NOT NULL,
    CostPrice       DECIMAL(10,2)   NOT NULL,
    IsActive        TINYINT(1)      NOT NULL DEFAULT 1,
    CreatedAt       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Customers table
CREATE TABLE Customers (
    CustomerID      INT             AUTO_INCREMENT PRIMARY KEY,
    CustomerName    VARCHAR(150)    NOT NULL,
    Email           VARCHAR(150)    NULL,
    City            VARCHAR(100)    NOT NULL,
    State           VARCHAR(50)     NOT NULL,
    Region          VARCHAR(50)     NOT NULL,
    Segment         VARCHAR(50)     NOT NULL,
    CreatedAt       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Sales Representatives table
CREATE TABLE SalesReps (
    RepID           INT             AUTO_INCREMENT PRIMARY KEY,
    RepName         VARCHAR(100)    NOT NULL,
    Department      VARCHAR(50)     NOT NULL,
    ManagerName     VARCHAR(100)    NULL,
    Region          VARCHAR(50)     NOT NULL,
    IsActive        TINYINT(1)      NOT NULL DEFAULT 1
);

-- Monthly Targets table
CREATE TABLE Targets (
    TargetID        INT             AUTO_INCREMENT PRIMARY KEY,
    RepID           INT             NOT NULL,
    TargetMonth     DATE            NOT NULL,
    RevenueTarget   DECIMAL(12,2)   NOT NULL,
    UnitTarget      INT             NOT NULL,
    CONSTRAINT FK_Targets_Rep FOREIGN KEY (RepID) REFERENCES SalesReps(RepID)
);


-- 3. FACT TABLE — SALES TRANSACTIONS


CREATE TABLE Sales (
    SaleID          BIGINT          AUTO_INCREMENT PRIMARY KEY,
    SaleDate        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CustomerID      INT             NOT NULL,
    ProductID       INT             NOT NULL,
    RepID           INT             NOT NULL,
    Quantity        INT             NOT NULL,
    UnitPrice       DECIMAL(10,2)   NOT NULL,
    Discount        DECIMAL(5,2)    NOT NULL DEFAULT 0.00,
    Revenue         DECIMAL(12,2)   GENERATED ALWAYS AS
                        (ROUND(Quantity * UnitPrice * (1 - Discount), 2)) STORED,
    CostPrice       DECIMAL(10,2)   NOT NULL,
    Profit          DECIMAL(12,2)   GENERATED ALWAYS AS
                        (ROUND(Quantity * (UnitPrice * (1 - Discount) - CostPrice), 2)) STORED,
    Status          VARCHAR(20)     NOT NULL DEFAULT 'Completed',
    Channel         VARCHAR(30)     NOT NULL DEFAULT 'Direct',
    CONSTRAINT FK_Sales_Customer FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CONSTRAINT FK_Sales_Product  FOREIGN KEY (ProductID)  REFERENCES Products(ProductID),
    CONSTRAINT FK_Sales_Rep      FOREIGN KEY (RepID)      REFERENCES SalesReps(RepID)
);


-- 4. INDEXES (critical for Power BI DirectQuery performance)


CREATE INDEX IX_Sales_SaleDate   ON Sales (SaleDate DESC);
CREATE INDEX IX_Sales_RepID      ON Sales (RepID, SaleDate);
CREATE INDEX IX_Sales_ProductID  ON Sales (ProductID, SaleDate);
CREATE INDEX IX_Sales_CustomerID ON Sales (CustomerID, SaleDate);
CREATE INDEX IX_Sales_Status     ON Sales (Status, SaleDate);
CREATE INDEX IX_Targets_Month    ON Targets (TargetMonth, RepID);


-- 5. VIEWS (used directly in Power BI)


-- Main dashboard view: daily summary
CREATE OR REPLACE VIEW vw_DailySalesSummary AS
SELECT
    DATE(s.SaleDate)        AS SaleDay,
    p.Category,
    p.SubCategory,
    c.Region,
    c.State,
    c.City,
    c.Segment,
    r.RepName,
    r.Department,
    s.Channel,
    s.Status,
    COUNT(s.SaleID)         AS TotalOrders,
    SUM(s.Quantity)         AS TotalUnits,
    SUM(s.Revenue)          AS TotalRevenue,
    SUM(s.Profit)           AS TotalProfit,
    ROUND(AVG(s.Discount),4)AS AvgDiscount
FROM Sales       s
JOIN Products    p ON s.ProductID  = p.ProductID
JOIN Customers   c ON s.CustomerID = c.CustomerID
JOIN SalesReps   r ON s.RepID      = r.RepID
GROUP BY
    DATE(s.SaleDate), p.Category, p.SubCategory,
    c.Region, c.State, c.City, c.Segment,
    r.RepName, r.Department, s.Channel, s.Status;

-- Rep performance vs target
CREATE OR REPLACE VIEW vw_RepPerformance AS
SELECT
    r.RepID,
    r.RepName,
    r.Region,
    r.Department,
    DATE_FORMAT(s.SaleDate, '%Y-%m-01') AS SaleMonth,
    SUM(s.Revenue)          AS ActualRevenue,
    SUM(s.Profit)           AS ActualProfit,
    COUNT(s.SaleID)         AS TotalOrders,
    t.RevenueTarget,
    t.UnitTarget,
    ROUND(SUM(s.Revenue) * 100.0 / NULLIF(t.RevenueTarget, 0), 2) AS TargetAchievedPct
FROM Sales       s
JOIN SalesReps   r ON s.RepID = r.RepID
LEFT JOIN Targets t ON r.RepID = t.RepID
    AND DATE_FORMAT(s.SaleDate, '%Y-%m-01') = DATE_FORMAT(t.TargetMonth, '%Y-%m-01')
GROUP BY
    r.RepID, r.RepName, r.Region, r.Department,
    DATE_FORMAT(s.SaleDate, '%Y-%m-01'),
    t.RevenueTarget, t.UnitTarget;

-- Live today's KPIs (used in Power Automate alerts)
CREATE OR REPLACE VIEW vw_TodayKPI AS
SELECT
    CURDATE()                   AS Today,
    COUNT(SaleID)               AS OrdersToday,
    IFNULL(SUM(Revenue),  0)    AS RevenueToday,
    IFNULL(SUM(Profit),   0)    AS ProfitToday,
    IFNULL(AVG(Revenue),  0)    AS AvgOrderValue,
    SUM(Status = 'Returned')    AS Returns
FROM Sales
WHERE DATE(SaleDate) = CURDATE();


-- 6. SEED DATA — Dimensions


INSERT INTO Products (ProductName, Category, SubCategory, UnitPrice, CostPrice) VALUES
('Laptop Pro 15'       , 'Electronics', 'Computers'  , 1299.99,  780.00),
('Wireless Mouse'      , 'Electronics', 'Accessories',   29.99,    8.00),
('USB-C Hub 7-in-1'   , 'Electronics', 'Accessories',   49.99,   15.00),
('Mechanical Keyboard' , 'Electronics', 'Accessories',   89.99,   30.00),
('27" Monitor 4K'      , 'Electronics', 'Monitors'   ,  449.99,  210.00),
('Standing Desk'       , 'Furniture'  , 'Desks'      ,  399.99,  160.00),
('Ergonomic Chair'     , 'Furniture'  , 'Chairs'     ,  299.99,  120.00),
('Desk Lamp LED'       , 'Furniture'  , 'Lighting'   ,   39.99,   12.00),
('Notebook A4 Pack'    , 'Stationery' , 'Paper'      ,    9.99,    2.50),
('Premium Pen Set'     , 'Stationery' , 'Writing'    ,   19.99,    5.00),
('Webcam HD 1080p'     , 'Electronics', 'Accessories',   79.99,   25.00),
('Headset Pro'         , 'Electronics', 'Audio'      ,  149.99,   55.00);

INSERT INTO SalesReps (RepName, Department, ManagerName, Region) VALUES
('Ravi Kumar'  , 'Inside Sales', 'Priya Sharma', 'South'),
('Anjali Mehta', 'Field Sales' , 'Priya Sharma', 'West' ),
('Suresh Naidu', 'Inside Sales', 'Priya Sharma', 'North'),
('Divya Rao'   , 'Field Sales' , 'Vikram Nair' , 'East' ),
('Arjun Pillai', 'Online Sales', 'Vikram Nair' , 'South'),
('Neha Singh'  , 'Online Sales', 'Vikram Nair' , 'North');

INSERT INTO Customers (CustomerName, Email, City, State, Region, Segment) VALUES
('Tech Solutions Pvt'    , 'buy@techsol.com'   , 'Hyderabad', 'Telangana'  , 'South', 'Wholesale'),
('Bright Office Supplies', 'orders@bright.com' , 'Mumbai'   , 'Maharashtra', 'West' , 'Retail'   ),
('NorthStar Corp'        , 'proc@northstar.com', 'Delhi'    , 'Delhi'      , 'North', 'Wholesale'),
('Eastern Traders'       , 'info@eastern.com'  , 'Kolkata'  , 'West Bengal', 'East' , 'Retail'   ),
('Digital Hub'           , 'sales@dhub.com'    , 'Bangalore', 'Karnataka'  , 'South', 'Online'   ),
('Prime Enterprises'     , 'buy@prime.com'     , 'Chennai'  , 'Tamil Nadu' , 'South', 'Wholesale'),
('Sunrise Retail'        , 'orders@sunrise.com', 'Pune'     , 'Maharashtra', 'West' , 'Retail'   ),
('Capital Goods Ltd'     , 'cg@capital.com'    , 'Jaipur'   , 'Rajasthan'  , 'North', 'Wholesale');

-- Targets for current month
INSERT INTO Targets (RepID, TargetMonth, RevenueTarget, UnitTarget) VALUES
(1, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 150000, 300),
(2, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 180000, 250),
(3, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 120000, 280),
(4, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 140000, 260),
(5, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 160000, 320),
(6, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 130000, 290);


-- 7. STORED PROCEDURE — Generate historical sample data


DROP PROCEDURE IF EXISTS sp_GenerateSampleSales;

DELIMITER $$
CREATE PROCEDURE sp_GenerateSampleSales(IN row_count INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_date      DATETIME;
    DECLARE v_custID    INT;
    DECLARE v_prodID    INT;
    DECLARE v_repID     INT;
    DECLARE v_qty       INT;
    DECLARE v_price     DECIMAL(10,2);
    DECLARE v_cost      DECIMAL(10,2);
    DECLARE v_discount  DECIMAL(5,2);
    DECLARE v_status    VARCHAR(20);
    DECLARE v_channel   VARCHAR(30);
    DECLARE v_rand      FLOAT;

    WHILE i < row_count DO
        -- Random date within last 90 days
        SET v_date   = DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 90 * 24 * 60) MINUTE);
        SET v_custID = FLOOR(RAND() * 8) + 1;
        SET v_prodID = FLOOR(RAND() * 12) + 1;
        SET v_repID  = FLOOR(RAND() * 6) + 1;
        SET v_qty    = FLOOR(RAND() * 10) + 1;

        SELECT UnitPrice, CostPrice INTO v_price, v_cost
        FROM Products WHERE ProductID = v_prodID;

        -- Random discount
        SET v_rand = RAND();
        SET v_discount = CASE
            WHEN v_rand < 0.15 THEN 0.10
            WHEN v_rand < 0.25 THEN 0.15
            ELSE 0.00
        END;

        -- Random status (weighted towards Completed)
        SET v_rand = RAND();
        SET v_status = CASE
            WHEN v_rand < 0.75 THEN 'Completed'
            WHEN v_rand < 0.90 THEN 'Pending'
            ELSE 'Returned'
        END;

        -- Random channel
        SET v_rand = RAND();
        SET v_channel = CASE
            WHEN v_rand < 0.50 THEN 'Direct'
            WHEN v_rand < 0.80 THEN 'Online'
            ELSE 'Partner'
        END;

        INSERT INTO Sales (SaleDate, CustomerID, ProductID, RepID,
                           Quantity, UnitPrice, Discount, CostPrice, Status, Channel)
        VALUES (v_date, v_custID, v_prodID, v_repID,
                v_qty, v_price, v_discount, v_cost, v_status, v_channel);

        SET i = i + 1;
    END WHILE;

    SELECT CONCAT('✅ Inserted ', row_count, ' sample sales rows.') AS Result;
END$$
DELIMITER ;

-- Run the procedure to insert 2000 historical rows
CALL sp_GenerateSampleSales(2000);


-- 8. VERIFY SETUP


SELECT 'Products'  AS TableName, COUNT(*) AS rowss FROM Products  UNION ALL
SELECT 'Customers'             , COUNT(*) FROM Customers UNION ALL
SELECT 'SalesReps'             , COUNT(*) FROM SalesReps UNION ALL
SELECT 'Targets'               , COUNT(*) FROM Targets   UNION ALL
SELECT 'Sales'                 , COUNT(*) FROM Sales;

SELECT * FROM vw_TodayKPI;
SELECT * FROM vw_DailySalesSummary ORDER BY SaleDay DESC LIMIT 10;


USE SalesDashboard;
SELECT * FROM vw_TodayKPI;