import pyodbc
import pandas as pd

server = r"localhost\SQLEXPRESS"
database = "OEE_Manufacturing"
driver = "ODBC Driver 18 for SQL Server"

conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};Trusted_Connection=yes;TrustServerCertificate=yes;"

try:
    conn = pyodbc.connect(conn_str)
except Exception as e:
    driver = "ODBC Driver 17 for SQL Server"
    conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};Trusted_Connection=yes;TrustServerCertificate=yes;"
    conn = pyodbc.connect(conn_str)

cursor = conn.cursor()

print("=========================================")
print("BẮT ĐẦU KIỂM TRA CHẤT LƯỢNG DỮ LIỆU")
print("=========================================\n")

# --- 1. KIỂM TRA NULL ---
print("1. KIỂM TRA GIÁ TRỊ NULL:")
tables = ["Fact_OEE", "Dim_Machine", "Dim_Product", "Dim_TargetSpeeds"]
for table in tables:
    cursor.execute(f"SELECT TOP 1 * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='{table}'")
    if not cursor.fetchone():
        print(f"  [!] Bảng {table} không tồn tại.")
        continue
        
    cursor.execute(f"SELECT * FROM {table}")
    columns = [column[0] for column in cursor.description]
    
    null_queries = [f"SUM(CASE WHEN [{col}] IS NULL THEN 1 ELSE 0 END) AS [{col}]" for col in columns]
    query = f"SELECT {', '.join(null_queries)} FROM {table}"
    cursor.execute(query)
    row = cursor.fetchone()
    
    has_null = False
    for col, val in zip(columns, row):
        if val > 0:
            print(f"  - Bảng [{table}], cột [{col}]: Có {val} dòng bị NULL.")
            has_null = True
    if not has_null:
        print(f"  - Bảng [{table}]: Hoàn hảo (Không có giá trị NULL).")

# --- 2. KIỂM TRA TRÙNG LẶP ---
print("\n2. KIỂM TRA TRÙNG LẶP (DUPLICATES):")
# Fact_OEE duplicates
query_dup_fact = """
SELECT COUNT(*) FROM (
    SELECT Machine, StartDateTime, EndDateTime, Duration, TotalBiscuitsMade, GoodMadeBiscuits, OEE_Category, Product
    FROM Fact_OEE
    GROUP BY Machine, StartDateTime, EndDateTime, Duration, TotalBiscuitsMade, GoodMadeBiscuits, OEE_Category, Product
    HAVING COUNT(*) > 1
) t;
"""
cursor.execute(query_dup_fact)
dup_fact_count = cursor.fetchone()[0]
print(f"  - Bảng [Fact_OEE]: Có {dup_fact_count} nhóm dòng bị trùng lặp hoàn toàn.")

# Dim_Machine duplicates
cursor.execute("SELECT Machine_Name, COUNT(*) FROM Dim_Machine GROUP BY Machine_Name HAVING COUNT(*) > 1")
dup_machines = cursor.fetchall()
if dup_machines:
    print(f"  - Bảng [Dim_Machine] bị trùng lặp Machine_Name:")
    for row in dup_machines:
        print(f"    * Máy '{row[0]}' bị lặp {row[1]} lần.")
else:
    print("  - Bảng [Dim_Machine]: Không trùng lặp Machine_Name.")

# Dim_Product duplicates
cursor.execute("SELECT Product_Name, COUNT(*) FROM Dim_Product GROUP BY Product_Name HAVING COUNT(*) > 1")
dup_products = cursor.fetchall()
if dup_products:
    print(f"  - Bảng [Dim_Product] bị trùng lặp Product_Name:")
    for row in dup_products:
        print(f"    * Sản phẩm '{row[0]}' bị lặp {row[1]} lần.")
else:
    print("  - Bảng [Dim_Product]: Không trùng lặp Product_Name.")

# --- 3. KIỂM TRA LỖI LOGIC ---
print("\n3. KIỂM TRA CÁC LỖI LOGIC:")
# EndDateTime < StartDateTime
cursor.execute("SELECT COUNT(*) FROM Fact_OEE WHERE EndDateTime < StartDateTime")
err_time = cursor.fetchone()[0]
print(f"  - Lỗi thời gian (EndDateTime < StartDateTime): Có {err_time} dòng.")

# GoodMadeBiscuits > TotalBiscuitsMade
cursor.execute("SELECT COUNT(*) FROM Fact_OEE WHERE GoodMadeBiscuits > TotalBiscuitsMade")
err_good = cursor.fetchone()[0]
print(f"  - Lỗi sản lượng (GoodMadeBiscuits > TotalBiscuitsMade): Có {err_good} dòng.")

# Duration <= 0
cursor.execute("SELECT COUNT(*) FROM Fact_OEE WHERE Duration <= 0")
err_dur = cursor.fetchone()[0]
print(f"  - Lỗi khoảng thời gian chạy máy <= 0: Có {err_dur} dòng.")

# TotalBiscuitsMade < 0 or GoodMadeBiscuits < 0
cursor.execute("SELECT COUNT(*) FROM Fact_OEE WHERE TotalBiscuitsMade < 0 OR GoodMadeBiscuits < 0")
err_neg = cursor.fetchone()[0]
print(f"  - Lỗi sản lượng bị âm: Có {err_neg} dòng.")

# --- 4. KIỂM TRA KHOẢNG TRẮNG THỪA (SPACES) ---
print("\n4. KIỂM TRA KHOẢNG TRẮNG THỪA ĐẦU/CUỐI (SPACES):")
# Check trailing/leading spaces in Fact_OEE
cursor.execute("SELECT DISTINCT Machine FROM Fact_OEE WHERE Machine LIKE ' %' OR Machine LIKE '% '")
spaces_m_fact = [r[0] for r in cursor.fetchall()]
if spaces_m_fact:
    print(f"  - Bảng [Fact_OEE], cột [Machine] có khoảng trắng thừa:")
    for val in spaces_m_fact:
        print(f"    * '{val}'")

cursor.execute("SELECT DISTINCT Product FROM Fact_OEE WHERE Product LIKE ' %' OR Product LIKE '% '")
spaces_p_fact = [r[0] for r in cursor.fetchall()]
if spaces_p_fact:
    print(f"  - Bảng [Fact_OEE], cột [Product] có khoảng trắng thừa:")
    for val in spaces_p_fact:
        print(f"    * '{val}'")

cursor.execute("SELECT DISTINCT Machine_Name FROM Dim_Machine WHERE Machine_Name LIKE ' %' OR Machine_Name LIKE '% '")
spaces_m_dim = [r[0] for r in cursor.fetchall()]
if spaces_m_dim:
    print(f"  - Bảng [Dim_Machine], cột [Machine_Name] có khoảng trắng thừa:")
    for val in spaces_m_dim:
        print(f"    * '{val}'")

cursor.execute("SELECT DISTINCT Product_Name FROM Dim_Product WHERE Product_Name LIKE ' %' OR Product_Name LIKE '% '")
spaces_p_dim = [r[0] for r in cursor.fetchall()]
if spaces_p_dim:
    print(f"  - Bảng [Dim_Product], cột [Product_Name] có khoảng trắng thừa:")
    for val in spaces_p_dim:
        print(f"    * '{val}'")

# --- 5. KIỂM TRA TÍNH LIÊN KẾT (REFERENTIAL INTEGRITY) ---
print("\n5. KIỂM TRA TÍNH LIÊN KẾT (REFERENTIAL INTEGRITY) SAU KHI STRIP KHOẢNG TRẮNG:")
# Check machine references
cursor.execute("""
SELECT DISTINCT LTRIM(RTRIM(f.Machine)) 
FROM Fact_OEE f
LEFT JOIN Dim_Machine m ON LTRIM(RTRIM(f.Machine)) = LTRIM(RTRIM(m.Machine_Name))
WHERE m.Machine_Name IS NULL
""")
missing_m = [r[0] for r in cursor.fetchall()]
if missing_m:
    print(f"  - Có các máy trong Fact_OEE không tồn tại trong danh mục Dim_Machine:")
    for m in missing_m:
        print(f"    * '{m}'")
else:
    print("  - Liên kết bảng Máy (Machine): Hoàn hảo (Tất cả máy trong Fact đều có trong Dim_Machine).")

# Check product references
cursor.execute("""
SELECT DISTINCT LTRIM(RTRIM(f.Product)) 
FROM Fact_OEE f
LEFT JOIN Dim_Product p ON LTRIM(RTRIM(f.Product)) = LTRIM(RTRIM(p.Product_Name))
WHERE p.Product_Name IS NULL
""")
missing_p = [r[0] for r in cursor.fetchall()]
if missing_p:
    print(f"  - Có các sản phẩm trong Fact_OEE không tồn tại trong danh mục Dim_Product:")
    for p in missing_p:
        print(f"    * '{p}'")
else:
    print("  - Liên kết bảng Sản phẩm (Product): Hoàn hảo (Tất cả sản phẩm trong Fact đều có trong Dim_Product).")

cursor.close()
conn.close()
