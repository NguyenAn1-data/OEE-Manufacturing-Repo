import os
import pandas as pd
import pyodbc
from sqlalchemy import create_engine, text

# Cấu hình Database
db_name = "OEE_Manufacturing"
server = r"localhost\SQLEXPRESS"
driver = "ODBC Driver 18 for SQL Server"

# Thư mục chứa các file CSV (thư mục hiện tại của project)
workspace_dir = r"d:\Project  OEE Manufacturing"

# Định nghĩa danh sách các file cần import và bảng tương ứng
files_to_import = [
    {
        "filename": "Copy of OEE Manufacturing Report.xlsx - Fact.csv",
        "table_name": "Fact_OEE",
        "parse_dates": ["StartDateTime", "EndDateTime"],
        "date_format": "%m/%d/%y %H:%M"
    },
    {
        "filename": "Copy of OEE Manufacturing Report.xlsx - Machine.csv",
        "table_name": "Dim_Machine",
        "parse_dates": None,
        "date_format": None
    },
    {
        "filename": "Copy of OEE Manufacturing Report.xlsx - Product.csv",
        "table_name": "Dim_Product",
        "parse_dates": None,
        "date_format": None
    },
    {
        "filename": "Copy of OEE Manufacturing Report.xlsx - Target Speeds.csv",
        "table_name": "Dim_TargetSpeeds",
        "parse_dates": None,
        "date_format": None
    }
]

print("--- BẮT ĐẦU QUÁ TRÌNH IMPORT TOÀN BỘ FILES ---")

# 1. Kết nối tới SQL Server (master) để kiểm tra/tạo database
conn_str_master = (
    f"DRIVER={{{driver}}};"
    f"SERVER={server};"
    f"DATABASE=master;"
    f"Trusted_Connection=yes;"
    f"TrustServerCertificate=yes;"
)

try:
    conn = pyodbc.connect(conn_str_master, autocommit=True)
    cursor = conn.cursor()
    cursor.execute(f"SELECT database_id FROM sys.databases WHERE name = '{db_name}'")
    db_exists = cursor.fetchone()
    if not db_exists:
        print(f"Database '{db_name}' chưa tồn tại. Đang tạo database mới...")
        cursor.execute(f"CREATE DATABASE {db_name}")
        print(f"Đã tạo thành công database '{db_name}'.")
    else:
        print(f"Database '{db_name}' đã sẵn sàng.")
    cursor.close()
    conn.close()
except Exception as e:
    # Nếu ODBC Driver 18 lỗi thì thử Driver 17
    driver = "ODBC Driver 17 for SQL Server"
    print(f"Đang thử lại kết nối với: {driver}...")
    conn_str_master = (
        f"DRIVER={{{driver}}};"
        f"SERVER={server};"
        f"DATABASE=master;"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate=yes;"
    )
    conn = pyodbc.connect(conn_str_master, autocommit=True)
    cursor = conn.cursor()
    cursor.execute(f"SELECT database_id FROM sys.databases WHERE name = '{db_name}'")
    db_exists = cursor.fetchone()
    if not db_exists:
        cursor.execute(f"CREATE DATABASE {db_name}")
    cursor.close()
    conn.close()

# Khởi tạo engine SQLAlchemy kết nối trực tiếp vào database đích
sqlalchemy_conn_str = f"mssql+pyodbc://{server}/{db_name}?driver={driver.replace(' ', '+')}&trusted_connection=yes&TrustServerCertificate=yes"
engine = create_engine(sqlalchemy_conn_str)

# 2. Vòng lặp import từng file
for file_info in files_to_import:
    csv_file_path = os.path.join(workspace_dir, file_info["filename"])
    table_name = file_info["table_name"]
    
    if not os.path.exists(csv_file_path):
        print(f"Lỗi: Không tìm thấy file {csv_file_path}. Bỏ qua...")
        continue
        
    print(f"\n[XỬ LÝ] Đang đọc file: {file_info['filename']}...")
    df = pd.read_csv(csv_file_path)
    
    # Chuẩn hóa tên các cột (thay khoảng trắng thành dấu gạch dưới)
    df.columns = [col.replace(' ', '_') for col in df.columns]
    
    # Xử lý các cột ngày tháng nếu có cấu hình
    if file_info["parse_dates"]:
        for date_col in file_info["parse_dates"]:
            if date_col in df.columns:
                df[date_col] = pd.to_datetime(df[date_col], format=file_info["date_format"], errors='coerce')
    
    print(f"-> Đã đọc {len(df)} dòng dữ liệu. Đang đẩy vào bảng '{table_name}'...")
    
    try:
        df.to_sql(
            name=table_name,
            con=engine,
            if_exists='replace',
            index=False,
            chunksize=1000
        )
        print(f"-> THÀNH CÔNG: Đã import vào bảng '{table_name}' ({len(df)} dòng).")
        
        # In ra 3 dòng dữ liệu đầu để kiểm tra
        with engine.connect() as connection:
            result = connection.execute(text(f"SELECT TOP 3 * FROM {table_name}"))
            print(f"   Mẫu dữ liệu trong bảng '{table_name}':")
            for row in result:
                print(f"   {row}")
    except Exception as e:
        print(f"-> THẤT BẠI khi import bảng '{table_name}': {e}")

print("\n--- QUÁ TRÌNH IMPORT TẤT CẢ FILE ĐÃ HOÀN THÀNH ---")
