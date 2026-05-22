SELECT * FROM dbo.Dim_Calendar ;
SELECT * FROM dbo.Dim_Products ;
select * from dbo.Dim_Geography;
select * from dbo.Dim_Promotions;
select * from dbo.Fact_Market_Share;
select * from dbo.Fact_Targets;
select * from dbo.Dim_Salesmen;
select * from dbo.Dim_Stores;
select * from dbo.Fact_Visits;
select * from dbo.Fact_Sales;


USE ShamsCola_FMCG;
GO
ALTER AUTHORIZATION ON DATABASE::ShamsCola_FMCG TO sa;
GO


-- فحص الفواتير المكررة
SELECT 
    Transaction_ID, 
    COUNT(*) AS Number_Of_Copies
FROM Fact_Sales
GROUP BY Transaction_ID
HAVING COUNT(*) > 1
ORDER BY Number_Of_Copies DESC;


-- 2. فحص أشكال التواريخ الغريبة
SELECT TOP 20 
    Transaction_ID, 
    Date_Key 
FROM Fact_Sales
WHERE Date_Key LIKE '%/%'  -- بنصطاد التواريخ المكتوبة بفورمات مصري بدل الأمريكي
   OR ISDATE(Date_Key) = 0; -- أو التواريخ اللي الـ SQL مش معترف بيها أصلاً



-- 3. فحص الروابط المقطوعة (الفواتير اللي ملهاش محل في جدول المحلات)
SELECT DISTINCT 
    fs.Store_Key AS Ghost_Store_Key
FROM Fact_Sales fs
LEFT JOIN Dim_Stores ds ON fs.Store_Key = ds.Store_Key
WHERE ds.Store_Key IS NULL;



-- 4. فحص المنطق التجاري (هل المرتجع أكبر من المباع؟)
SELECT 
    Transaction_ID, 
    Quantity_Cases, 
    Qty_Returned,
    Return_Reason
FROM Fact_Sales
WHERE Qty_Returned > Quantity_Cases;






-- =========================================
--  (Clean View)
-- =========================================

CREATE VIEW vw_Fact_Sales_Clean AS

WITH RankedSales AS (
    -- 1. حل مشكلة المكرر: إعطاء رقم تسلسلي لكل فاتورة
    SELECT 
        *,
        ROW_NUMBER() OVER(PARTITION BY Transaction_ID ORDER BY Date_Key DESC) as row_num
    FROM Fact_Sales
)
SELECT 
    Transaction_ID,
    
    -- 2. حل مشكلة التواريخ: تحويل النصوص لتواريخ صحيحة، وتوحيد الفورمات المصري (103) والأمريكي
    COALESCE(TRY_CAST(Date_Key AS DATE), TRY_CONVERT(DATE, Date_Key, 103)) AS Clean_Date,
    
    fs.Store_Key,
    fs.Product_Key,
    fs.Salesman_Key,
    fs.Promo_Key,
    Order_Source,
    Quantity_Cases,
    
    -- 3. حل مشكلة المنطق التجاري: لو المرتجع أكبر من المباع، خليه يساوي المباع كحد أقصى
    CASE 
        WHEN Qty_Returned > Quantity_Cases THEN Quantity_Cases 
        ELSE Qty_Returned 
    END AS Qty_Returned,
    
    Return_Reason,
    Gross_Sales,
    Discount_Amount,
    Net_Sales,
    COGS

FROM RankedSales fs
-- 4. حل مشكلة المحلات الوهمية: عرض الفواتير المربوطة بمحلات حقيقية فقط (INNER JOIN)
INNER JOIN Dim_Stores ds ON fs.Store_Key = ds.Store_Key

-- تفعيل فلتر المكرر: اختيار النسخة الأولى فقط من كل فاتورة
WHERE row_num = 1;


















