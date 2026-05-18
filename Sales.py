# ============================================================
#  Real-Time Sales Intelligence Dashboard
#  Phase 2: Python Data Simulator
#  Continuously inserts live sales into MySQL every few seconds
# ============================================================
#
#  INSTALL DEPENDENCIES:
#  pip install mysql-connector-python faker schedule
#
# ============================================================

import mysql.connector
import random
import time
import schedule
import logging
from datetime import datetime
from faker import Faker

# ── Logging setup ────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(),                        # console
        logging.FileHandler("simulator.log")            # log file
    ]
)
log = logging.getLogger(__name__)
fake = Faker("en_IN")   # Indian locale for realistic names

# ============================================================
# 1. DATABASE CONFIG — update with your MySQL credentials
# ============================================================

DB_CONFIG = {
    "host"    : "127.0.0.1",
    "port"    : 3306,
    "user"    : "root",          # ← your MySQL username
    "password": "systemmanager", # ← your MySQL password
    "database": "SalesDashboard"
}

# ============================================================
# 2. SIMULATION CONFIG
# ============================================================

INTERVAL_SECONDS  = 5      # insert a sale every 5 seconds
BURST_SIZE        = 3      # number of rows per interval
PEAK_HOURS        = [10, 11, 12, 14, 15, 16]   # busier hours
SLOW_HOURS        = [0, 1, 2, 3, 4, 5, 6]      # very slow hours

STATUSES  = ["Completed"] * 7 + ["Pending"] * 2 + ["Returned"] * 1
CHANNELS  = ["Direct"] * 5  + ["Online"] * 3   + ["Partner"] * 2
DISCOUNTS = [0.00] * 7      + [0.10] * 2       + [0.15] * 1

# ============================================================
# 3. FETCH DIMENSION IDs FROM DB (cache once at startup)
# ============================================================

def fetch_dimensions(conn):
    """Load all valid IDs + prices from dimension tables."""
    cursor = conn.cursor(dictionary=True)

    cursor.execute("SELECT ProductID, UnitPrice, CostPrice FROM Products WHERE IsActive = 1")
    raw = cursor.fetchall()
    products = [
    {
        "ProductID" : r["ProductID"],
        "UnitPrice" : float(r["UnitPrice"]),   # ← convert Decimal → float
        "CostPrice" : float(r["CostPrice"])    # ← convert Decimal → float
    }
    for r in raw
]

    cursor.execute("SELECT CustomerID FROM Customers")
    customers = [r["CustomerID"] for r in cursor.fetchall()]

    cursor.execute("SELECT RepID FROM SalesReps WHERE IsActive = 1")
    reps = [r["RepID"] for r in cursor.fetchall()]

    cursor.close()
    log.info(f"Loaded {len(products)} products, {len(customers)} customers, {len(reps)} reps")
    return products, customers, reps

# ============================================================
# 4. GENERATE A SINGLE REALISTIC SALE
# ============================================================

def generate_sale(products, customers, reps):
    """Create one realistic sale record dict."""
    hour = datetime.now().hour

    # Adjust quantity by time of day
    if hour in PEAK_HOURS:
        qty = random.randint(3, 15)
    elif hour in SLOW_HOURS:
        qty = random.randint(1, 3)
    else:
        qty = random.randint(1, 8)

    product  = random.choice(products)
    discount = random.choice(DISCOUNTS)

    # Occasional price variation ± 5%
    unit_price = round(product["UnitPrice"] * random.uniform(0.95, 1.05), 2)

    return {
        "SaleDate"  : datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "CustomerID": random.choice(customers),
        "ProductID" : product["ProductID"],
        "RepID"     : random.choice(reps),
        "Quantity"  : qty,
        "UnitPrice" : unit_price,
        "Discount"  : discount,
        "CostPrice" : product["CostPrice"],
        "Status"    : random.choice(STATUSES),
        "Channel"   : random.choice(CHANNELS),
    }

# ============================================================
# 5. INSERT SALE INTO MySQL
# ============================================================

INSERT_SQL = """
    INSERT INTO Sales
        (SaleDate, CustomerID, ProductID, RepID,
         Quantity, UnitPrice, Discount, CostPrice, Status, Channel)
    VALUES
        (%(SaleDate)s, %(CustomerID)s, %(ProductID)s, %(RepID)s,
         %(Quantity)s, %(UnitPrice)s, %(Discount)s, %(CostPrice)s,
         %(Status)s, %(Channel)s)
"""

def insert_sales(conn, products, customers, reps, burst=1):
    """Insert `burst` sale rows in one transaction."""
    rows = [generate_sale(products, customers, reps) for _ in range(burst)]
    try:
        cursor = conn.cursor()
        cursor.executemany(INSERT_SQL, rows)
        conn.commit()
        cursor.close()
        for r in rows:
            log.info(
                f"[OK] Sale inserted | "
                f"ProductID={r['ProductID']} | "
                f"Qty={r['Quantity']} | "
                f"Price={r['UnitPrice']} | "
                f"Channel={r['Channel']} | "
                f"Status={r['Status']}"
            )
    except mysql.connector.Error as e:
        conn.rollback()
        log.error(f"[ERROR] Insert failed: {e}")

# ============================================================
# 6. DAILY KPI SUMMARY PRINT (runs every hour)
# ============================================================

def print_kpi_summary(conn):
    """Pull today's KPIs and log them."""
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM vw_TodayKPI")
        kpi = cursor.fetchone()
        cursor.close()
        if kpi:
            log.info(
                f"[KPL] TODAY KPI | "
                f"Orders={kpi['OrdersToday']} | "
                f"Revenue=₹{kpi['RevenueToday']:,.2f} | "
                f"Profit=₹{kpi['ProfitToday']:,.2f} | "
                f"AvgOrder=₹{kpi['AvgOrderValue']:,.2f} | "
                f"Returns={kpi['Returns']}"
            )
    except mysql.connector.Error as e:
        log.error(f"KPI fetch failed: {e}")

# ============================================================
# 7. CONNECTION HELPER WITH AUTO-RECONNECT
# ============================================================

def get_connection():
    """Create a MySQL connection with retry logic."""
    retries = 5
    for attempt in range(1, retries + 1):
        try:
            conn = mysql.connector.connect(**DB_CONFIG)
            log.info("🔗 Connected to MySQL SalesDashboard")
            return conn
        except mysql.connector.Error as e:
            log.warning(f"Connection attempt {attempt}/{retries} failed: {e}")
            time.sleep(3)
    raise RuntimeError(" [ERROR] Could not connect to MySQL after multiple retries.")

# ============================================================
# 8. MAIN LOOP
# ============================================================

def main():
    log.info("=" * 55)
    log.info("   Real-Time Sales Simulator — Starting")
    log.info("=" * 55)

    conn = get_connection()
    products, customers, reps = fetch_dimensions(conn)

    # Determine burst size by current hour
    def run_insert():
        nonlocal conn
        # Reconnect if connection dropped
        if not conn.is_connected():
            log.warning("Connection lost — reconnecting...")
            conn = get_connection()

        hour = datetime.now().hour
        burst = BURST_SIZE + (2 if hour in PEAK_HOURS else 0)
        insert_sales(conn, products, customers, reps, burst=burst)

    def run_kpi():
        print_kpi_summary(conn)

    # Schedule jobs
    schedule.every(INTERVAL_SECONDS).seconds.do(run_insert)
    schedule.every(1).hours.do(run_kpi)

    log.info(f"⏱  Inserting {BURST_SIZE} sales every {INTERVAL_SECONDS} seconds")
    log.info("   Press Ctrl+C to stop\n")

    # Print first KPI immediately
    run_kpi()

    try:
        while True:
            schedule.run_pending()
            time.sleep(1)
    except KeyboardInterrupt:
        log.info("\n[Stop] Simulator stopped by user.")
    finally:
        if conn.is_connected():
            conn.close()
            log.info("[Close] MySQL connection closed.")

if __name__ == "__main__":
    main()