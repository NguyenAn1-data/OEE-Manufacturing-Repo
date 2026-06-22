USE OEE_Manufacturing 
GO

SELECT * 
FROM dbo.Fact_OEE

--
SELECT 
    COUNT(*) AS [Tong_So_Dong_Du_Lieu],
    MIN(StartDateTime) AS [Ngay_Bat_Dau_Ghi_Nhan],
    MAX(EndDateTime) AS [Ngay_Ket_Thuc_Ghi_Nhan],
    DATEDIFF(day, MIN(StartDateTime), MAX(EndDateTime)) AS [Tong_So_Ngay_Quan_Sat]
FROM OEE_Manufacturing.dbo.Fact_OEE;
--
SELECT 
    LTRIM(RTRIM(Machine)) AS [Ten_May],
    COUNT(*) AS [So_Lan_Ghi_Nhan_Trang_Thai],
    ROUND(SUM(Duration), 2) AS [Tong_Thoi_Gian_Hoat_Dong_Phut],
    ROUND(SUM(Duration) / 60.0, 2) AS [Tong_Thoi_Gian_Hoat_Dong_Gio]
FROM OEE_Manufacturing.dbo.Fact_OEE
GROUP BY LTRIM(RTRIM(Machine))
ORDER BY [Tong_Thoi_Gian_Hoat_Dong_Gio] DESC;
--
SELECT 
    LTRIM(RTRIM(Product)) AS [San_Pham],
    SUM(TotalBiscuitsMade) AS [Tong_San_Luong],
    SUM(GoodMadeBiscuits) AS [San_Luong_Dat_Chuan],
    SUM(TotalBiscuitsMade) - SUM(GoodMadeBiscuits) AS [San_Luong_Loi_Phe_Pham],
    -- Tính tỷ lệ chất lượng (Quality Rate)
    ROUND(
        SUM(GoodMadeBiscuits) * 100.0 / NULLIF(SUM(TotalBiscuitsMade), 0), 
        2
    ) AS [Ty_Le_Dat_Chuan_Percent]
FROM OEE_Manufacturing.dbo.Fact_OEE
GROUP BY LTRIM(RTRIM(Product))
ORDER BY [Ty_Le_Dat_Chuan_Percent] ASC; -- Sắp xếp từ sản phẩm lỗi nhiều nhất đến ít nhất
-- Kiểm tra dữ liệu 
--
SELECT 
    SUM(CASE WHEN Machine IS NULL THEN 1 ELSE 0 END) AS [Null_Machine],
    SUM(CASE WHEN StartDateTime IS NULL THEN 1 ELSE 0 END) AS [Null_StartDateTime],
    SUM(CASE WHEN EndDateTime IS NULL THEN 1 ELSE 0 END) AS [Null_EndDateTime],
    SUM(CASE WHEN Duration IS NULL THEN 1 ELSE 0 END) AS [Null_Duration],
    SUM(CASE WHEN TotalBiscuitsMade IS NULL THEN 1 ELSE 0 END) AS [Null_TotalBiscuits],
    SUM(CASE WHEN GoodMadeBiscuits IS NULL THEN 1 ELSE 0 END) AS [Null_GoodBiscuits],
    SUM(CASE WHEN OEE_Category IS NULL THEN 1 ELSE 0 END) AS [Null_OEE_Category],
    SUM(CASE WHEN Product IS NULL THEN 1 ELSE 0 END) AS [Null_Product]
FROM OEE_Manufacturing.dbo.Fact_OEE;
-- kiểm tra trùng lặp
SELECT 
    Machine, StartDateTime, EndDateTime, Duration, 
    TotalBiscuitsMade, GoodMadeBiscuits, OEE_Category, Product,
    COUNT(*) AS [So_Lan_Lap_Lai]
FROM OEE_Manufacturing.dbo.Fact_OEE
GROUP BY 
    Machine, StartDateTime, EndDateTime, Duration, 
    TotalBiscuitsMade, GoodMadeBiscuits, OEE_Category, Product
HAVING COUNT(*) > 1;
--
-- Kiểm tra trùng tên máy trong Dim_Machine
SELECT Machine_Name, COUNT(*) AS [So_Lan_Lap]
FROM OEE_Manufacturing.dbo.Dim_Machine
GROUP BY Machine_Name
HAVING COUNT(*) > 1;

-- Kiểm tra trùng tên sản phẩm trong Dim_Product
SELECT Product_Name, COUNT(*) AS [So_Lan_Lap]
FROM OEE_Manufacturing.dbo.Dim_Product
GROUP BY Product_Name
HAVING COUNT(*) > 1;
--
SELECT *
FROM OEE_Manufacturing.dbo.Fact_OEE
WHERE EndDateTime < StartDateTime 
   OR Duration < 0;
--
SELECT *
FROM OEE_Manufacturing.dbo.Fact_OEE
WHERE GoodMadeBiscuits > TotalBiscuitsMade; -- có vấn đề
--
SELECT *
FROM OEE_Manufacturing.dbo.Fact_OEE
WHERE TotalBiscuitsMade < 0 
   OR GoodMadeBiscuits < 0;
--
SELECT DISTINCT LTRIM(RTRIM(f.Machine)) AS [Machine_In_Fact]
FROM OEE_Manufacturing.dbo.Fact_OEE f
LEFT JOIN OEE_Manufacturing.dbo.Dim_Machine m 
    ON LTRIM(RTRIM(f.Machine)) = LTRIM(RTRIM(m.Machine_Name))
WHERE m.Machine_Name IS NULL;
--
SELECT DISTINCT LTRIM(RTRIM(f.Product)) AS [Product_In_Fact]
FROM OEE_Manufacturing.dbo.Fact_OEE f
LEFT JOIN OEE_Manufacturing.dbo.Dim_Product p 
    ON LTRIM(RTRIM(f.Product)) = LTRIM(RTRIM(p.Product_Name))
WHERE p.Product_Name IS NULL;
--
-- Kiểm tra khoảng trắng thừa trong bảng Fact_OEE
SELECT DISTINCT
    Machine,
    CASE 
        WHEN Machine LIKE ' %' OR Machine LIKE '% ' THEN N'Bị thừa khoảng trắng'
        ELSE N'Bình thường' 
    END AS [Trang_Thai_Machine],
    Product,
    CASE 
        WHEN Product LIKE ' %' OR Product LIKE '% ' THEN N'Bị thừa khoảng trắng'
        ELSE N'Bình thường' 
    END AS [Trang_Thai_Product]
FROM OEE_Manufacturing.dbo.Fact_OEE
WHERE Machine LIKE ' %' OR Machine LIKE '% ' 
   OR Product LIKE ' %' OR Product LIKE '% ';
   -- Kiểm tra xem có sản phẩm nào bị ghi nhận nhiều kiểu viết hoa thường khác nhau không
SELECT 
    LOWER(LTRIM(RTRIM(Product_Name))) AS [San_Pham_Chuan_Hoa],
    COUNT(DISTINCT Product_Name) AS [So_Bien_The_Casing],
    STRING_AGG(Product_Name, ', ') AS [Cac_Bien_The_Tim_Thay]
FROM OEE_Manufacturing.dbo.Dim_Product
GROUP BY LOWER(LTRIM(RTRIM(Product_Name)))
HAVING COUNT(DISTINCT Product_Name) > 1;
--
SELECT 
    Product_Name,
    COUNT(*) AS [So_Dong_Trung]
FROM OEE_Manufacturing.dbo.Dim_Product
GROUP BY Product_Name
HAVING COUNT(*) > 1;
-- Nếu kết quả trả về rỗng, cột Product_Name đủ tiêu chuẩn làm Khóa Chính (Primary Key) cho bảng Dim_Product.

--
SELECT 
    TABLE_NAME AS [Ten_Bang],
    COLUMN_NAME AS [Ten_Cot],
    DATA_TYPE AS [Kieu_Du_Lieu],
    CHARACTER_MAXIMUM_LENGTH AS [Do_Dai_Toi_Da_Cau_Hinh]
FROM OEE_Manufacturing.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('Fact_OEE', 'Dim_Machine', 'Dim_Product', 'Dim_TargetSpeeds')
ORDER BY TABLE_NAME, ORDINAL_POSITION;


-- Chỉ định sử dụng database OEE_Manufacturing
USE OEE_Manufacturing;
GO

-- 1. Kiểm tra giá trị NULL trong bảng Fact_OEE
SELECT 
    'Fact_OEE - Null Values' AS [Check_Name],
    N'Kiểm tra xem có cột nào bị trống (NULL) không' AS [Description],
    COUNT(*) AS [Error_Count],
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END AS [Status]
FROM dbo.Fact_OEE
WHERE Machine IS NULL OR StartDateTime IS NULL OR EndDateTime IS NULL OR Duration IS NULL 
   OR TotalBiscuitsMade IS NULL OR GoodMadeBiscuits IS NULL OR OEE_Category IS NULL OR Product IS NULL

UNION ALL

-- 2. Kiểm tra trùng lặp dữ liệu trong bảng Fact_OEE
SELECT 
    'Fact_OEE - Duplicate Rows',
    N'Kiểm tra số dòng bị trùng lặp hoàn toàn 100%',
    ISNULL(SUM(Duplicate_Count - 1), 0),
    CASE WHEN ISNULL(SUM(Duplicate_Count - 1), 0) = 0 THEN 'OK' ELSE 'ERROR' END
FROM (
    SELECT COUNT(*) AS Duplicate_Count
    FROM dbo.Fact_OEE
    GROUP BY Machine, StartDateTime, EndDateTime, Duration, TotalBiscuitsMade, GoodMadeBiscuits, OEE_Category, Product
    HAVING COUNT(*) > 1
) t

UNION ALL

-- 3. Kiểm tra lỗi thời lượng chạy máy vô lý (Duration <= 0)
SELECT 
    'Fact_OEE - Invalid Duration',
    N'Kiểm tra các dòng có thời lượng Duration <= 0',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END
FROM dbo.Fact_OEE
WHERE Duration <= 0

UNION ALL

-- 4. Kiểm tra lỗi logic số lượng bánh (Good > Total)
SELECT 
    'Fact_OEE - Logical Error (Good > Total)',
    N'Kiểm tra bánh đạt chuẩn vượt quá tổng sản lượng sản xuất',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END
FROM dbo.Fact_OEE
WHERE GoodMadeBiscuits > TotalBiscuitsMade

UNION ALL

-- 5. Kiểm tra khoảng trắng thừa đầu/cuối của các cột dữ liệu chuỗi (ở tất cả các bảng)
SELECT 
    'Database - Trailing/Leading Spaces',
    N'Kiểm tra khoảng trắng thừa ở đầu/cuối của Machine hoặc Product',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END
FROM (
    SELECT Machine FROM dbo.Fact_OEE WHERE Machine LIKE ' %' OR Machine LIKE '% '
    UNION ALL
    SELECT Product FROM dbo.Fact_OEE WHERE Product LIKE ' %' OR Product LIKE '% '
    UNION ALL
    SELECT Machine_Name FROM dbo.Dim_Machine WHERE Machine_Name LIKE ' %' OR Machine_Name LIKE '% '
    UNION ALL
    SELECT Product_Name FROM dbo.Dim_Product WHERE Product_Name LIKE ' %' OR Product_Name LIKE '% '
) t

UNION ALL

-- 6. Kiểm tra tính liên kết của máy (Nối Fact_OEE sang Dim_Machine)
SELECT 
    'Referential Integrity - Machine',
    N'Kiểm tra máy trong bảng Fact không khớp với danh mục Dim_Machine',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END
FROM dbo.Fact_OEE f
LEFT JOIN dbo.Dim_Machine m ON f.Machine = m.Machine_Name
WHERE m.Machine_Name IS NULL

UNION ALL

-- 7. Kiểm tra tính liên kết của sản phẩm (Nối Fact_OEE sang Dim_Product)
SELECT 
    'Referential Integrity - Product',
    N'Kiểm tra sản phẩm trong bảng Fact không khớp với danh mục Dim_Product',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END
FROM dbo.Fact_OEE f
LEFT JOIN dbo.Dim_Product p ON f.Product = p.Product_Name
WHERE p.Product_Name IS NULL;
