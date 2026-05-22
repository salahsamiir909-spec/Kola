# 🥤 Shams Cola — FMCG End-to-End Data Analytics Project

> A full-cycle data analytics project covering raw data collection, ETL pipeline with SSIS, data warehousing in SQL Server, and interactive business dashboarding in Power BI — built for the Fast-Moving Consumer Goods industry.

---

## 📌 Project Overview

This project is a comprehensive, end-to-end **Data Analytics portfolio piece** designed for the **FMCG (Fast-Moving Consumer Goods)** industry. We simulate a real-world business scenario for **"Shams Cola"** — a beverage brand operating across multiple sales regions — addressing complex data challenges from raw data extraction all the way to strategic Power BI dashboarding.

The pipeline follows industry-standard practices:

```
Raw Data Sources
      │
      ▼
SSIS (ETL Pipeline)
      │
      ▼
SQL Server (Data Warehouse)
      │
      ▼
Power BI (Business Dashboard)
```

---

## 🎯 Business Problem

FMCG companies generate massive amounts of daily operational data across sales, returns, field visits, and market activity. The challenge is that this data lives in silos — Excel sheets, ERP exports, POS systems — making it impossible for decision-makers to act on a unified picture.

This project bridges that gap by building a clean, scalable data pipeline and delivering actionable insights across **5 key business pillars:**

| # | Pillar | Key Questions Answered |
|---|--------|------------------------|
| 1 | **💰 Financial Performance** | What is total revenue, COGS, and gross margin? |
| 2 | **🎯 Targets & Growth** | Are sales reps hitting their targets? What is YoY growth? |
| 3 | **🔄 Quality & Returns** | What are return rates? Which SKUs and regions are danger zones? |
| 4 | **🏪 Field Force Execution** | What is the Out-of-Stock rate? How effective is salesmen strike rate? |
| 5 | **📊 Market Share & Competition** | How does shelf space compare to competitors? What is competitor pricing impact? |

---

## 🗂️ Step 1 — Data Collection

### Sources
Raw data was collected from multiple operational sources representing real FMCG business activity:

| Dataset | Description | Format |
|---------|-------------|--------|
| `Sales` | Daily invoices — SKU, quantity, price, rep, region | Excel / CSV |
| `Returns` | Product return records with reason codes | Excel / CSV |
| `Targets` | Monthly sales targets per rep and region | Excel / CSV |
| `Field Visits` | Salesmen visit logs, OOS incidents, strike rate | Excel / CSV |
| `Market Share` | Shelf-space audits and competitor SKU pricing | Excel / CSV |
| `Dimensions` | Lookup tables — Products, Customers, Regions, Reps, Calendar | Excel / CSV |

### Data Challenges Identified
- Duplicate transaction records across daily exports
- Inconsistent date formats (DD/MM/YYYY vs MM-DD-YYYY)
- NULL values in critical columns (price, rep ID, region code)
- Mismatched product codes between sales and returns tables
- Mixed data types in numeric columns (text stored as numbers)

---

## ⚙️ Step 2 — ETL Pipeline with SSIS

**Tool:** SQL Server Integration Services (SSIS) via Visual Studio

The ETL pipeline was built to automate the extraction, transformation, and loading of all raw files into a centralized SQL Server staging area.

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   SSIS Package                          │
│                                                         │
│  ┌──────────────┐    ┌───────────────┐    ┌──────────┐  │
│  │ Flat File /  │───▶│  Data Flow    │───▶│  OLE DB  │  │
│  │ Excel Source │    │  Transformations   │  Dest.   │  │
│  └──────────────┘    └───────────────┘    └──────────┘  │
│                                                         │
│  Transformations Applied:                               │
│  ✔ Derived Column  → Standardize date formats          │
│  ✔ Data Conversion → Fix data type mismatches          │
│  ✔ Conditional Split → Route bad rows to error log     │
│  ✔ Lookup           → Validate foreign keys            │
│  ✔ Aggregate        → Pre-aggregate daily totals       │
│  ✔ Sort             → Order before merge joins         │
└─────────────────────────────────────────────────────────┘
```

### SSIS Tasks Used

| Task / Component | Purpose |
|------------------|---------|
| `Flat File Source` | Ingest raw CSV exports |
| `Excel Source` | Ingest Excel-format data files |
| `OLE DB Destination` | Load clean data into SQL Server staging tables |
| `Derived Column` | Standardize date formats, create calculated fields |
| `Data Conversion` | Convert varchar → int/decimal/date where needed |
| `Conditional Split` | Separate valid rows from error/null rows |
| `Lookup Transform` | Validate product codes, customer IDs against dimension tables |
| `Row Count` | Log record counts per load for audit trail |
| `Execute SQL Task` | Truncate staging tables before each reload |
| `For Each Loop` | Iterate over multiple daily files in a folder |

### Error Handling
- All rejected rows routed to a `stg_ErrorLog` table with timestamp and reason
- Package-level event handlers configured for `OnError` to send failure alerts
- Audit columns (`LoadDate`, `SourceFile`) added to every staging table

---

## 🗄️ Step 3 — SQL Server Data Warehouse

**Tool:** SQL Server Management Studio (SSMS)

After staging, data was modeled into a clean **Star Schema** data warehouse optimized for Power BI query performance.

### Star Schema Design

```
                    ┌──────────────┐
                    │  dim_Date    │
                    └──────┬───────┘
                           │
┌──────────────┐    ┌──────▼───────┐    ┌──────────────────┐
│  dim_Product │───▶│              │◀───│  dim_Customer    │
└──────────────┘    │  fact_Sales  │    └──────────────────┘
                    │              │
┌──────────────┐    │  fact_Returns│    ┌──────────────────┐
│  dim_Region  │───▶│              │◀───│  dim_SalesRep    │
└──────────────┘    └──────────────┘    └──────────────────┘
```

### SQL Techniques Used

| Technique | Application |
|-----------|-------------|
| **CTEs** | Multi-step transformations and deduplication logic |
| **Window Functions** | `ROW_NUMBER()` to remove duplicate invoices |
| **CASE WHEN** | Classify return reasons, flag danger-zone SKUs |
| **Views** | `vw_Fact_Sales_Clean` — final clean view used for Power BI Query Folding |
| **Stored Procedures** | Automate post-load aggregation and mart refresh |
| **Indexes** | Clustered indexes on fact table foreign keys for query speed |
| **JOINS** | Multi-table joins linking facts to all dimension tables |

### Key SQL Objects Created

```sql
-- Deduplicate raw sales using ROW_NUMBER
WITH CTE_Dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY InvoiceID, ProductID, CustomerID
               ORDER BY LoadDate DESC
           ) AS rn
    FROM stg_Sales
)
SELECT * INTO fact_Sales_Clean
FROM CTE_Dedup WHERE rn = 1;

-- Final clean view for Power BI
CREATE VIEW vw_Fact_Sales_Clean AS
SELECT
    s.InvoiceID, s.InvoiceDate, s.Quantity, s.UnitPrice,
    s.Quantity * s.UnitPrice AS Revenue,
    s.Quantity * p.COGS        AS TotalCOGS,
    (s.Quantity * s.UnitPrice) - (s.Quantity * p.COGS) AS GrossMargin,
    s.ProductID, s.CustomerID, s.RegionID, s.RepID
FROM fact_Sales_Clean s
JOIN dim_Product p ON s.ProductID = p.ProductID;
```

---

## 📊 Step 4 — Power BI Dashboard

**Tool:** Microsoft Power BI Desktop

Data was imported via **DirectQuery / Import mode** from `vw_Fact_Sales_Clean` and all dimension tables, enabling Query Folding back to SQL Server for optimal performance.

### Data Model
- **Star Schema** enforced in Power BI Model view
- Single-direction relationships from all dimensions to fact tables
- Date table marked as official date table for Time Intelligence

### DAX Measures Written

```dax
-- Total Revenue
Total Revenue = SUMX(fact_Sales, fact_Sales[Quantity] * fact_Sales[UnitPrice])

-- Gross Margin %
Gross Margin % = DIVIDE([Total Revenue] - [Total COGS], [Total Revenue])

-- YoY Growth
YoY Growth % =
DIVIDE(
    [Total Revenue] - CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dim_Date[Date])),
    CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dim_Date[Date]))
)

-- Target Achievement %
Target Achievement % = DIVIDE([Total Revenue], SUM(fact_Targets[TargetValue]))

-- Return Rate
Return Rate % = DIVIDE(SUM(fact_Returns[ReturnQty]), SUM(fact_Sales[Quantity]))

-- Salesmen Strike Rate
Strike Rate % = DIVIDE(COUNTROWS(FILTER(fact_Visits, fact_Visits[OrderPlaced] = "Yes")),
                        COUNTROWS(fact_Visits))
```

---

## 📑 Dashboard Pages

### Page 1 — 💰 Financial Performance
**Purpose:** Executive-level revenue, cost, and margin overview.

**Visuals:**
- KPI Cards: Total Revenue, Total COGS, Gross Margin %, Avg Selling Price
- Line Chart: Monthly Revenue vs. COGS trend
- Bar Chart: Revenue by Region and by Product Category
- Matrix: SKU-level margin breakdown with conditional formatting (green/red)
- Slicer: Year, Month, Region, Product Category

---

### Page 2 — 🎯 Targets & Growth
**Purpose:** Sales rep performance vs. targets and year-over-year growth tracking.

**Visuals:**
- Gauge Chart: Overall Target Achievement %
- Bar Chart: Rep-level target vs. actual (sorted descending)
- Line Chart: YoY Revenue Growth by Month
- Table: Rep scorecard — Revenue, Target, Achievement %, Rank
- Conditional Formatting: Red (<80%), Yellow (80–99%), Green (≥100%)
- Slicer: Rep Name, Region, Month

---

### Page 3 — 🔄 Quality & Returns
**Purpose:** Identify high-return SKUs, regions, and promotional impact on returns.

**Visuals:**
- KPI Cards: Total Returns, Return Rate %, Revenue Lost to Returns
- Bar Chart: Top 10 SKUs by Return Volume
- Map Visual: Return Rate % by Region (bubble size = volume)
- Scatter Chart: Promotional Period vs. Return Rate correlation
- Donut Chart: Return reason breakdown (Damaged / Expired / Wrong Item / Other)
- Danger Zone Table: SKUs exceeding 5% return rate highlighted in red
- Slicer: Return Reason, Region, Product, Month

---

### Page 4 — 🏪 Field Force Execution (Trade Marketing)
**Purpose:** Monitor salesmen effectiveness, OOS incidents, and visit quality.

**Visuals:**
- KPI Cards: Total Visits, Strike Rate %, OOS Incidents, Avg Visits per Rep
- Bar Chart: Strike Rate by Rep (ranked)
- Line Chart: OOS Incidents trend by Month
- Heatmap Matrix: Rep × Region OOS frequency
- Table: Visit log summary — Rep, Customer, Visit Date, Order Placed (Y/N)
- Slicer: Rep, Region, Month, Customer Type

---

### Page 5 — 📊 Market Share & Competition
**Purpose:** Analyze shelf space ownership and competitor pricing impact on Shams Cola sales.

**Visuals:**
- KPI Cards: Avg Shelf Share %, SKUs in Distribution, Competitor Price Gap
- Bar Chart: Shelf Space % — Shams Cola vs. Top 3 Competitors by Region
- Line Chart: Shams Cola Revenue vs. Competitor Avg Price over time
- Scatter Chart: Competitor Price vs. Shams Cola Volume (correlation)
- Table: Store-level shelf audit — Location, Shams Share %, Competitor Brand, Gap
- Slicer: Region, Store Type, Competitor Brand, Month

---

## 📂 Repository Structure

```
📦 FMCG-ShamsCola-Analytics
 ┣ 📁 Data/
 ┃  ├── Sales_Raw.csv
 ┃  ├── Returns_Raw.csv
 ┃  ├── Targets_Raw.csv
 ┃  ├── FieldVisits_Raw.csv
 ┃  ├── MarketShare_Raw.csv
 ┃  └── Dimensions/
 ┃       ├── dim_Product.csv
 ┃       ├── dim_Customer.csv
 ┃       ├── dim_Region.csv
 ┃       ├── dim_SalesRep.csv
 ┃       └── dim_Date.csv
 ┣ 📁 SSIS/
 ┃  ├── ShamsCola_ETL.dtsx          ← Main SSIS package
 ┃  └── ShamsCola_ETL_Config.dtsConfig
 ┣ 📁 SQL_Scripts/
 ┃  ├── 01_Create_Staging_Tables.sql
 ┃  ├── 02_EDA_and_Profiling.sql
 ┃  ├── 03_Dedup_and_Cleanse.sql
 ┃  ├── 04_Build_StarSchema.sql
 ┃  └── 05_Create_vw_Fact_Sales_Clean.sql
 ┣ 📁 PowerBI/
 ┃  └── ShamsCola_Dashboard.pbix    ← Final Power BI file
 ┣ 📁 Screenshots/
 ┃  ├── 01_Financial_Performance.png
 ┃  ├── 02_Targets_Growth.png
 ┃  ├── 03_Quality_Returns.png
 ┃  ├── 04_Field_Force.png
 ┃  └── 05_Market_Share.png
 ┗── README.md
```

---

## 🚀 How to Use

1. **Download** the raw datasets from the `/Data` folder.
2. **Run SSIS:** Open `ShamsCola_ETL.dtsx` in Visual Studio (with SSDT installed). Update connection strings to point to your local SQL Server instance. Execute the package to load staging tables.
3. **Run SQL Scripts** in order (01 → 05) inside SSMS to build the star schema and create the clean view.
4. **Open Power BI:** Launch `ShamsCola_Dashboard.pbix`. Update the SQL Server data source to your local instance. Refresh the data model.
5. **Explore** all 5 dashboard pages using the slicers for Region, Month, Year, and Rep filters.

> ⚠️ Requires: SQL Server 2019+, SSMS 18+, Visual Studio 2019 with SSIS extension, Power BI Desktop (latest).

---

## 📈 Key Metrics Snapshot

| Metric | Value |
|--------|-------|
| Total Revenue | To be populated after data load |
| Gross Margin % | To be populated after data load |
| Overall Target Achievement | To be populated after data load |
| Return Rate % | To be populated after data load |
| Salesmen Strike Rate | To be populated after data load |
| Avg Shelf Share % | To be populated after data load |

---

## 🎥 Full Tutorial Series

Watch the complete step-by-step build on YouTube:
👉 **[youtube.com/@abdulkhalekshams](https://youtube.com/@abdulkhalekshams?si=Xc1HMUuDsxgTApD7)**

The series covers:
- 📦 Data collection and source file walkthrough
- ⚙️ Building the SSIS ETL package from scratch
- 🗄️ SQL Server EDA, cleansing, and star schema design
- 📊 Power BI data modeling and DAX measures
- 🎨 Dashboard design, storytelling, and publishing


`fmcg` `data-analytics` `sql-server` `ssis` `etl` `power-bi` `dax` `star-schema` `data-warehouse` `business-intelligence` `end-to-end` `portfolio-project`

---

## ⭐ If this project helped you, consider giving it a star!

> *"Good data architecture isn't just technical — it's the foundation of every business decision."*
