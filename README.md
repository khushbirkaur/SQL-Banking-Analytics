# Bank Data Cleaning & Analysis Using SQL

A complete end-to-end SQL data cleaning project on a raw, unclean bank dataset — covering null handling, type corrections, data consistency, business rule enforcement, fraud detection, and customer analytics.

![MySQL](https://img.shields.io/badge/MySQL-00618A?style=for-the-badge&logo=mysql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)
![Data Cleaning](https://img.shields.io/badge/Data%20Cleaning-1D9E75?style=for-the-badge&logo=databricks&logoColor=white)
![Analytics](https://img.shields.io/badge/Analytics-185FA5?style=for-the-badge&logo=chartdotjs&logoColor=white)

---

## 📋 Project Overview

This project takes a messy, real-world bank dataset and systematically cleans it using MySQL. A **staging table** is created first so the original data is never modified. All transformations, business rules, and analytical queries are applied on the copy.

| Key | Value |
|-----|-------|
| Database | BANKKK (MySQL) |
| Source Table | `bank unclean dataset` |
| Working Table | `bank_staging` |
| SQL Dialect | MySQL 8+ |
| Key Columns | Account_ID, Customer_Name, Age, Gender, Balance, Transaction_Amount, Transaction_Type, KYC_Status, Loan_Status, Account_Status, Credit_Score |

---

## 🗂️ Pipeline Overview

| Step | Name | What it does |
|------|------|--------------|
| 01 | Staging Table | Clone raw table into `bank_staging`. All changes happen here — original stays safe. |
| 02 | Null & Blank Removal | Rows with missing `Account_ID` deleted. Other nulls filled with logical defaults. |
| 03 | Data Type Fixes | `Age` was stored as TEXT. Converted to INT via `ALTER TABLE … MODIFY COLUMN`. |
| 04 | Consistency Fix | Same `Account_ID` had multiple names/ages/branches. Standardized using `MIN()` per account. |
| 05 | Transaction Logic | CREDIT → positive amount, DEBIT → negative. Missing types inferred from sign. Lowercased. |
| 06 | Business Rules | KYC, Loan Status, and Account Status filled using banking logic based on Credit Score. |
| 07 | Fraud Detection | Transactions flagged if amount > ₹1L, balance goes negative on debit, or activity on closed accounts. |
| 08 | Analytics | Customer segmentation by age/type/balance. High-risk identification. Branch performance evaluation. |

---

## 🧹 Data Cleaning — What Was Fixed

| Issue | Column(s) | Fix Applied |
|-------|-----------|-------------|
| Missing primary key | `Account_ID` | Rows deleted — no identity, unusable |
| Leading/trailing spaces | All text columns | `TRIM()` applied in bulk UPDATE |
| Missing customer name | `Customer_Name` | Replaced with `'Unknown'` |
| Missing age | `Age` | Filled with computed average (45) |
| Wrong data type | `Age` | TEXT → INT via ALTER TABLE |
| Missing gender | `Gender` | Set to `'Other'` |
| Missing account type | `Account_Type` | Set to `'Unknown'` |
| Missing branch / IFSC | `Branch`, `IFSC_Code` | Set to `'Unknown'` |
| Multi-value conflicts per account | Name, Age, Gender, Branch, IFSC, KYC | `MIN()` grouped by `Account_ID` via JOIN UPDATE |
| Inconsistent transaction signs | `Transaction_Amount` | `ABS()` + sign from type; infer type from sign |
| Mixed case transaction type | `Transaction_Type` | Standardized to lowercase via `LOWER()` |

---

## ⚙️ Business Rule Logic — KYC / Loan / Account

These three fields are tightly coupled. Missing values in any one were inferred from the other two plus `Credit_Score`.

| Credit Score | KYC Status | Account Status | Loan Decision |
|--------------|------------|----------------|---------------|
| ≥ 750 | Verified | Active | ✅ Approved |
| 580 – 749 | Verified / Pending | Active | 🟡 Pending |
| < 580 | Pending / Rejected | Inactive / Closed | ❌ Rejected |
| ≥ 750 | Verified | Dormant | 🟡 Pending |
| Any | Rejected or Pending | Any | ❌ Rejected |
| ≥ 750 | Verified | Closed | ❌ Rejected |

> **Key Rule:** KYC Pending or Rejected always overrides a high credit score and triggers loan rejection.

---

## 🚨 Fraud Detection Logic

Three conditions flag a transaction as suspicious:

**1. Large Transaction Amount**
```sql
ABS(Transaction_Amount) > 100000
```
Transactions above ₹1,00,000 are flagged for manual review.

**2. Overdraft on Debit**
```sql
Transaction_Type = 'debit' AND Balance < 0
```
A debit that results in a negative balance is a potential fraud signal.

**3. Activity on Closed / Inactive Account**
```sql
Account_Status IN ('Closed', 'Inactive') AND ABS(Transaction_Amount) > 50000
```
Any significant activity on a closed or inactive account is highly suspicious.

**Full fraud detection query:**
```sql
SELECT * FROM bank_staging
WHERE ABS(Transaction_Amount) > 100000
   OR (Transaction_Type = 'Debit' AND Balance < 0)
   OR (Account_Status IN ('Closed', 'Inactive') AND ABS(Transaction_Amount) > 50000);
```

---

## 📊 Analytics Queries

- **Customer segmentation** — grouped by Account Type × Account Status × Loan Status
- **Age segmentation** — Minor (<18), Adults (18–59), Senior Citizen (60+) using `CASE WHEN`
- **Balance segmentation** — Positive vs Negative balance customers
- **High-risk identification** — customers with Credit Score <580, KYC Pending/Rejected, Loan Rejected, or Inactive/Closed account
- **Branch performance** — total customers, total balance (`SUM`), and approved loan count per branch, ordered by balance `DESC`


## 🚀 How to Run

```sql
-- 1. Open MySQL Workbench or any MySQL client
-- 2. Run the full script:
SOURCE BANKK.sql;

-- All steps execute in order:
--   → Creates database BANKK
--   → Creates and populates bank_staging
--   → Applies all cleaning and business rule updates
--   → Runs analytical SELECT queries at the end
```

---

## 🛠️ Tech Stack

![MySQL](https://img.shields.io/badge/MySQL-00618A?style=for-the-badge&logo=mysql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)

---

## 📝 Key SQL Concepts Used

- `CREATE TABLE … LIKE` — clone table structure for staging
- `UPDATE … JOIN (subquery)` — standardize multi-value conflicts per account
- `CASE WHEN` — conditional logic for sign convention and segmentation
- `ABS()`, `TRIM()`, `LOWER()`, `ROUND(AVG())` — data normalization functions
- `ALTER TABLE … MODIFY COLUMN` — fix wrong data types
- `GROUP BY … HAVING` — detect accounts with inconsistent fields
- `COUNT(DISTINCT …)`, `SUM()` — aggregation for analytics
- `SET SQL_SAFE_UPDATES = 0` — allow bulk updates without WHERE on key

---



