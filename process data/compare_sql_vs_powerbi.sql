USE OEE_Manufacturing;
GO

-- =========================================================================
-- TRUY VẤN KIỂM CHỨNG: So sánh trực tiếp với các Measures trong Power BI
-- =========================================================================
SELECT 
    -- 1. Planned_Production_Min (Tổng thời gian sản xuất kế hoạch - loại trừ 'NO' và '0')
    SUM(CASE 
        WHEN OEE_Category NOT IN ('NO (No Order)', '0') THEN Duration 
        ELSE 0 
    END) AS [Planned_Production_Min (SQL)],

    -- 2. Downtime_Min (Thời gian dừng máy - chỉ tính CC và PM)
    SUM(CASE 
        WHEN OEE_Category IN ('CC (Changeover Cleaning)', 'PM (Maintenance)') THEN Duration 
        ELSE 0 
    END) AS [Downtime_Min (SQL)],

    -- 3. Run_Time_Min (Thời gian thực chạy = Planned - Downtime)
    SUM(CASE 
        WHEN OEE_Category NOT IN ('NO (No Order)', '0') THEN Duration 
        ELSE 0 
    END) - 
    SUM(CASE 
        WHEN OEE_Category IN ('CC (Changeover Cleaning)', 'PM (Maintenance)') THEN Duration 
        ELSE 0 
    END) AS [Run_Time_Min (SQL)],

    -- 4. Total_Output (Tổng sản lượng làm ra)
    SUM(TotalBiscuitsMade) AS [Total_Output (SQL)],

    -- 5. Good_Output (Tổng sản lượng đạt chất lượng)
    SUM(GoodMadeBiscuits) AS [Good_Output (SQL)]

FROM dbo.v_Fact_OEE_Cleaned;
GO
--
USE OEE_Manufacturing;
GO

-- =========================================================================
-- KIỂM CHỨNG 1: Phân tích Sản lượng (Output) phát sinh ở từng trạng thái máy
-- (Để xem có sản lượng ghi nhận khi máy đang dừng CC, PM hoặc NO không)
-- =========================================================================
SELECT 
    OEE_Category,
    COUNT(*) AS [So_Dong_Du_Lieu],
    SUM(Duration) AS [Tong_Thoi_Gian_Phut],
    SUM(TotalBiscuitsMade) AS [Tong_San_Luong],
    SUM(GoodMadeBiscuits) AS [San_Luong_Dat_Chuan]
FROM dbo.v_Fact_OEE_Cleaned
GROUP BY OEE_Category;
GO

-- =========================================================================
-- KIỂM CHỨNG 2: Hiệu suất (Performance) chi tiết theo từng Máy
-- (Để xem máy nào đang có sản lượng và tốc độ bất thường)
-- =========================================================================
SELECT 
    f.Machine,
    SUM(CASE WHEN f.OEE_Category NOT IN ('NO (No Order)', '0') THEN f.Duration ELSE 0 END) AS Planned_Min,
    SUM(CASE WHEN f.OEE_Category IN ('CC (Changeover Cleaning)', 'PM (Maintenance)') THEN f.Duration ELSE 0 END) AS Downtime_Min,
    SUM(f.TotalBiscuitsMade) AS Total_Output,
    SUM(f.GoodMadeBiscuits) AS Good_Output,
    SUM(CASE 
        WHEN f.OEE_Category NOT IN ('NO (No Order)', '0') 
        THEN f.Duration * ISNULL(t.TARGET_Biscuits_per_hour, 0) / 60.0 
        ELSE 0 
    END) AS Expected_Output,
    -- Performance
    CASE 
        WHEN SUM(CASE WHEN f.OEE_Category NOT IN ('NO (No Order)', '0') THEN f.Duration * ISNULL(t.TARGET_Biscuits_per_hour, 0) / 60.0 ELSE 0 END) > 0 
        THEN SUM(f.TotalBiscuitsMade) / SUM(CASE WHEN f.OEE_Category NOT IN ('NO (No Order)', '0') THEN f.Duration * ISNULL(t.TARGET_Biscuits_per_hour, 0) / 60.0 ELSE 0 END)
        ELSE 0 
    END AS [Performance (OEE)]
FROM dbo.v_Fact_OEE_Cleaned f
LEFT JOIN dbo.v_Dim_TargetSpeeds_Cleaned t ON f.Machine_Product_Key = t.Machine_Product_Key
GROUP BY f.Machine
ORDER BY [Performance (OEE)] DESC;
GO
--
USE OEE_Manufacturing;
GO

SELECT 
    -- 1. CC_Minutes
    SUM(CASE WHEN OEE_Category = 'CC (Changeover Cleaning)' THEN Duration ELSE 0 END) AS [CC_Minutes (SQL)],
    
    -- 2. PM_Minutes
    SUM(CASE WHEN OEE_Category = 'PM (Maintenance)' THEN Duration ELSE 0 END) AS [PM_Minutes (SQL)],
    
    -- 3. Downtime_Hours
    (SUM(CASE WHEN OEE_Category = 'CC (Changeover Cleaning)' THEN Duration ELSE 0 END) + 
     SUM(CASE WHEN OEE_Category = 'PM (Maintenance)' THEN Duration ELSE 0 END)) / 60.0 AS [Downtime_Hours (SQL)],
     
    -- 4. CC_Percentage
    SUM(CASE WHEN OEE_Category = 'CC (Changeover Cleaning)' THEN Duration ELSE 0 END) / 
    NULLIF(SUM(CASE WHEN OEE_Category IN ('CC (Changeover Cleaning)', 'PM (Maintenance)') THEN Duration ELSE 0 END), 0) AS [CC_Percentage (SQL)],
    
    -- 5. PM_Percentage
    SUM(CASE WHEN OEE_Category = 'PM (Maintenance)' THEN Duration ELSE 0 END) / 
    NULLIF(SUM(CASE WHEN OEE_Category IN ('CC (Changeover Cleaning)', 'PM (Maintenance)') THEN Duration ELSE 0 END), 0) AS [PM_Percentage (SQL)]
FROM dbo.v_Fact_OEE_Cleaned;
GO
