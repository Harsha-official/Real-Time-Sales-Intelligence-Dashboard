#  Real-Time Sales Intelligence Dashboard
<img width="92" height="28" alt="image" src="https://github.com/user-attachments/assets/6dc5b6bf-b70a-4814-9ad0-f1e37ab11617" />
<img width="98" height="28" alt="image" src="https://github.com/user-attachments/assets/9b7b5b01-4134-4ee2-a100-9378d6abce2c" />
<img width="88" height="28" alt="image" src="https://github.com/user-attachments/assets/5c9a2b0c-47cf-41d2-9e2a-4fe0780491de" />



business intelligence project that simulates live sales transactions,
stores them in MySQL, visualizes real-time KPIs in Power BI, and sends automated
alerts via Power Automate.

<img width="1134" height="644" alt="image" src="https://github.com/user-attachments/assets/11fb2eca-e21b-4290-b0c9-e504d97d700a" />


---

## Project Structure

```
SalesDashboard/
├── sales_dashboard_mysql.sql   # Database schema, tables, views, seed data
├── Sales.py                    # Python real-time data simulator
├── requirements.txt            # Python dependencies
├── simulator.log               # Auto-generated runtime log
└── SalesDashboard.pbix         # Power BI dashboard file
```

---

##  Architecture

```
[Python Simulator]
      │  Inserts 3-5 sales every 5 seconds
      ▼
[MySQL Database — SalesDashboard]
      │  Tables:  Sales, Products, Customers, SalesReps, Targets
      │  Views:   vw_DailySalesSummary, vw_RepPerformance, vw_TodayKPI
      │  Indexes: 5 indexes for fast query performance
      ▼
[Power BI Desktop]
      │  Import Mode + Manual/Scheduled Refresh
      │  8 DAX Measures + 6 Visuals
      ▼
[Power BI Service — app.powerbi.com]
      │  Published dashboard
      │  Data alerts configured on Total Revenue tile
      ▼
[Power Automate]
      ├── Flow 1: Revenue Alert (Recurrence → Query → Condition → Email)
      └── Flow 2: Weekly PDF Report (Scheduled → Export → Email)
```

---

## ⚙️ Tech Stack

| Layer          | Technology                              |
|----------------|-----------------------------------------|
| Database       | MySQL 8.0+ / MySQL Workbench            |
| Data Simulator | Python 3.x                              |
| BI Tool        | Power BI Desktop + Power BI Service     |
| Automation     | Power Automate                          |
| Libraries      | mysql-connector-python, faker, schedule |

---

##  Setup Guide

### Prerequisites
- MySQL 8.0+ installed and running locally
- MySQL Workbench
- Python 3.8+
- Power BI Desktop (free download from Microsoft)
- Microsoft account (for Power BI Service + Power Automate)

---

### Phase 1 — Database Setup

1. Open **MySQL Workbench**
2. Connect to local server (`127.0.0.1:3306`)
3. Open `sales_dashboard_mysql.sql`
4. Execute the full script (`Ctrl + Shift + Enter`)

This creates:
- **5 tables**: Products, Customers, SalesReps, Targets, Sales
- **3 views**: vw_DailySalesSummary, vw_RepPerformance, vw_TodayKPI
- **5 indexes** for DirectQuery performance
- **1 stored procedure**: sp_GenerateSampleSales
- **2,000 rows** of historical sample data (last 90 days)

Verify setup in MySQL Workbench:
```sql
USE SalesDashboard;

-- Check row counts
SELECT 'Products'  AS TableName, COUNT(*) AS Rows FROM Products  UNION ALL
SELECT 'Customers'             , COUNT(*) FROM Customers UNION ALL
SELECT 'SalesReps'             , COUNT(*) FROM SalesReps UNION ALL
SELECT 'Targets'               , COUNT(*) FROM Targets   UNION ALL
SELECT 'Sales'                 , COUNT(*) FROM Sales;

-- Check views
SELECT * FROM vw_TodayKPI;
SELECT * FROM vw_DailySalesSummary ORDER BY SaleDay DESC LIMIT 5;
SELECT RepName, ActualRevenue, RevenueTarget, TargetAchievedPct
FROM vw_RepPerformance ORDER BY TargetAchievedPct DESC;
```

---

### Phase 2 — Python Data Simulator

**Install dependencies:**
```bash
pip install mysql-connector-python faker schedule
```

**Update credentials** in `Sales.py`:
```python
DB_CONFIG = {
    "host"    : "127.0.0.1",       # use IP not localhost
    "port"    : 3306,
    "user"    : "root",
    "password": "your_password",    # your MySQL root password
    "database": "SalesDashboard"    # exact database name
}
```

**Fix for Windows encoding (add at top of file):**
```python
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')
```

**Fix for MySQL Decimal type error:**
```python
# When fetching product prices, convert Decimal to float
products = [
    {
        "ProductID" : r["ProductID"],
        "UnitPrice" : float(r["UnitPrice"]),   # must convert!
        "CostPrice" : float(r["CostPrice"])    # must convert!
    }
    for r in raw
]
```

**Run the simulator:**
```bash
python Sales.py
```

Expected output:
```
[DB]    Connected to MySQL SalesDashboard
[KPI]   TODAY KPI | Orders=5 | Revenue=12430.00 | Profit=4210.00
[OK]    Sale inserted | ProductID=3 | Qty=4 | Price=49.99 | Channel=Online
[OK]    Sale inserted | ProductID=1 | Qty=1 | Price=1289.99 | Channel=Direct
```

Simulator features:
- Inserts **3–5 sales every 5 seconds**
- **Peak hours** (10am–4pm): higher volume (qty 3–15)
- **Slow hours** (midnight–6am): lower volume (qty 1–3)
- Weighted status: 70% Completed, 20% Pending, 10% Returned
- Random channels: 50% Direct, 30% Online, 20% Partner
- ±5% price variation per transaction
- Auto-reconnect if MySQL connection drops
- Logs to both console and `simulator.log`

---

### Phase 3 — Power BI Dashboard

**Connect to MySQL:**
```
Home → Get Data → MySQL Database
Server:   127.0.0.1
Database: SalesDashboard
Mode:     Import  (DirectQuery requires ODBC driver)
```

**Load these tables/views:**
```
☑ vw_dailysalessummary    → main charts
☑ vw_repperformance       → rep performance table
☑ vw_todaykpi             → today's KPI cards
☑ targets                 → monthly targets
```

**Create DAX Measures:**

Right-click `salesdashboard vw_dailysalessummary` → New Measure
(create in this exact order):

```dax
-- Step 1: Base measures first
Total Revenue = SUM('salesdashboard vw_dailysalessummary'[TotalRevenue])

Total Profit = SUM('salesdashboard vw_dailysalessummary'[TotalProfit])

Total Orders = SUM('salesdashboard vw_dailysalessummary'[TotalOrders])

Total Units Sold = SUM('salesdashboard vw_dailysalessummary'[TotalUnits])

-- Step 2: Calculated measures (after base measures exist)
Profit Margin % = DIVIDE([Total Profit], [Total Revenue], 0) * 100

Avg Order Value = DIVIDE([Total Revenue], [Total Orders], 0)
```

Right-click `salesdashboard targets` → New Measure:
```dax
Total Target Revenue = SUM('salesdashboard targets'[RevenueTarget])

Target Achievement % = DIVIDE([Total Revenue], [Total Target Revenue], 0) * 100
```

**Dashboard Visuals:**

| Visual | Type | Fields |
|--------|------|--------|
| Revenue KPI | Card | Total Revenue |
| Avg Order Value KPI | Card | Avg Order Value |
| Profit Margin KPI | Card | Profit Margin % |
| Total Orders KPI | Card | Total Orders |
| Revenue Trend | Line Chart | X: SaleDay, Y: Total Revenue, Legend: Channel |
| Revenue by Category | Bar Chart | Y: Category, X: Total Revenue, Legend: SubCategory |
| Rep Performance | Table | RepName, ActualRevenue, RevenueTarget, TargetAchievedPct |
| Sales by Region | Donut Chart | Legend: Region, Values: Total Revenue |
| Region Filter | Slicer | Region (Dropdown style) |

**Enable Refresh:**
```
Home → Refresh (manual, press F5)
OR
Format panel → Page refresh → ON → 30 seconds (Import mode)
```

**Publish to Power BI Service:**
```
Home → Publish → My Workspace → Select → wait for Success
→ Click "Open in Power BI" link
```

---

### Phase 4 — Power Automate Alerts

#### Set Up Power BI Data Alert First
```
app.powerbi.com → My Workspace
→ Pin "Total Revenue" card to a new Dashboard
→ Open Dashboard → click Revenue tile
→ Bell icon  → Add alert rule
→ Condition: Less than
→ Value: 500000
→ Send email notification: ON
→ Save and close
```

#### Flow 1 — Revenue Alert (Recurrence-based)

Go to `powerautomate.microsoft.com`:
```
Create → Scheduled cloud flow
Name: Sales Revenue Alert
Repeat: Every 1 Hour

Step 1: Power BI → "Run a query against a dataset"
  Workspace:  My Workspace
  Dataset:    Sales
  Query text: EVALUATE ROW("Revenue", [Total Revenue])

Step 2: Control → Condition
  Left:     [Revenue] (dynamic content from Step 1)
  Operator: is less than
  Right:    500000

  If YES → Office 365 Outlook → Send an email (V2)
    To:      your-email@outlook.com
    Subject: ALERT - Sales Revenue Below Target!
    Body:    Revenue has dropped below Rs.5,00,000!
             Check dashboard: https://app.powerbi.com

Save → Turn on
```

#### Flow 2 — Weekly PDF Report

```
Create → Scheduled cloud flow
Name: Weekly Sales PDF Report
Repeat: Every 1 Week → Monday → 8:00 AM

Step 1: Power BI → "Export To File for Reports"
  Workspace: My Workspace
  Report:    Sales
  Format:    PDF

Step 2: Office 365 Outlook → Send an email (V2)
  To:                  your-email@outlook.com
  Subject:             Weekly Sales Report
  Body:                Please find this week's sales report attached.
  Attachments Name:    SalesReport.pdf
  Attachments Content: [File Content] from Step 1

Save → Turn on
```

---

##  Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Unknown database 'sales'` | Wrong DB name in config | Change to `SalesDashboard` |
| `TypeError: decimal × float` | MySQL DECIMAL vs Python float | Wrap with `float()` when fetching |
| Emoji crash on Windows | Default cp1252 encoding | Add `sys.stdout.reconfigure(encoding='utf-8')` |
| Power BI measure not found | Wrong table or wrong order | Right-click correct table → New Measure, create base measures first |
| DirectQuery not available | MySQL connector limitation | Use Import mode + scheduled refresh |
| Power Automate 401 Unauthorized | Account mismatch | Use same Microsoft account for Power BI and Power Automate |
| Flow trigger not firing | Alert not linked | Use Recurrence trigger + Power BI query instead |
| Gmail connector 404 error | Free account limitation | Use Office 365 Outlook connector instead |

---

##  Database Schema

```
Products ──┐
           ├──► Sales (fact table) ◄── SalesReps ──► Targets
Customers ─┘
```

**Sales table generated columns (auto-calculated by MySQL):**
```sql
Revenue = Quantity × UnitPrice × (1 - Discount)   [STORED]
Profit  = Quantity × (UnitPrice × (1 - Discount) - CostPrice)  [STORED]
```

**Views summary:**
| View | Purpose | Used in |
|------|---------|---------|
| vw_DailySalesSummary | Joins all tables, groups by day/category/region | Main dashboard charts |
| vw_RepPerformance | Actual vs target per rep per month | Rep performance table |
| vw_TodayKPI | Today's orders, revenue, profit, returns | KPI cards + Automate alerts |

---

##  KPIs Tracked

| KPI | Description |
|-----|-------------|
| Total Revenue | Sum of all completed sales revenue |
| Total Profit | Net profit after cost deduction |
| Profit Margin % | Profit as % of Revenue |
| Avg Order Value | Revenue ÷ number of orders |
| Target Achievement % | Actual revenue vs monthly target |
| Total Orders | Count of all transactions |
| Revenue by Region | North / South / East / West split |
| Rep Performance | Individual rep vs target comparison |

---




