-- ============================================================
-- PROJECT  : Bank Data Cleaning & Analysis
-- DATABASE : BANKK
-- DIALECT  : MySQL 8+
-- DATASET  : 'bank unclean dataset'
-- COLUMNS  : Account_ID, Customer_Name, Age, Gender,
--            Account_Type, Balance, Transaction_Amount,
--            Transaction_Type, Branch, IFSC_Code,
--            Loan_Status, KYC_Status, Account_Status, Credit_Score
-- PURPOSE  : Data cleaning practice + banking business logic implementation
-- ============================================================

CREATE DATABASE BANKKK;
USE BANKKK;

-- ============================================================
-- SECTION 1 : STAGING TABLE SETUP
-- ============================================================

-- CREATING A STAGING TABLE FOR PERFORMING OPERATIONS
-- REASON: WE NEVER MODIFY THE ORIGINAL RAW TABLE.
-- ALL CLEANING HAPPENS ON THIS COPY SO THE SOURCE IS ALWAYS SAFE.
CREATE TABLE BANK_STAGING
LIKE `bank unclean dataset`;

-- INSERTING VALUES IN STAGING TABLE
INSERT INTO BANK_STAGING
SELECT * FROM `bank unclean dataset`;

SET SQL_SAFE_UPDATES = 0;

-- ============================================================
-- SECTION 2 : BEFORE CLEANING SNAPSHOT
-- RUN THIS BEFORE ANY CHANGES TO SEE THE ORIGINAL DIRTY STATE.
-- COMPARE WITH THE AFTER SNAPSHOT AT THE END TO PROVE CLEANING WORKED.
-- ============================================================

SELECT
    COUNT(*) AS Total_Rows,
    SUM(CASE WHEN Account_ID IS NULL OR Account_ID = ''  THEN 1 ELSE 0 END) AS Null_Account_IDs,
    SUM(CASE WHEN Customer_Name IS NULL OR Customer_Name = '' THEN 1 ELSE 0 END) AS Null_Customer_Names,
    SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS Null_Ages,
    SUM(CASE WHEN Gender IS NULL OR Gender = ''  THEN 1 ELSE 0 END) AS Null_Genders,
    SUM(CASE WHEN Account_Type IS NULL OR Account_Type = '' THEN 1 ELSE 0 END) AS Null_Account_Types,
    SUM(CASE WHEN Branch IS NULL OR Branch = '' THEN 1 ELSE 0 END) AS Null_Branches,
    SUM(CASE WHEN IFSC_Code IS NULL OR IFSC_Code = '' THEN 1 ELSE 0 END) AS Null_IFSC_Codes,
    SUM(CASE WHEN Transaction_Type IS NULL OR Transaction_Type='' THEN 1 ELSE 0 END) AS Null_Transaction_Types,
    SUM(CASE WHEN Loan_Status IS NULL OR Loan_Status = ''  THEN 1 ELSE 0 END) AS Null_Loan_Statuses,
    SUM(CASE WHEN KYC_Status IS NULL OR KYC_Status = '' THEN 1 ELSE 0 END) AS Null_KYC_Statuses,
    SUM(CASE WHEN Account_Status IS NULL OR Account_Status = '' THEN 1 ELSE 0 END) AS Null_Account_Statuses
FROM bank_staging;

-- ============================================================
-- SECTION 3 : DATA CLEANING
-- ============================================================

-- ------------------------------------------------------------
-- STEP 1: REMOVE THE ROWS WHERE ACCOUNT_ID IS MISSING
-- REASON: ACCOUNT_ID IS THE PRIMARY IDENTIFIER.
-- A ROW WITH NO ACCOUNT_ID HAS NO IDENTITY AND IS COMPLETELY UNUSABLE.
-- ------------------------------------------------------------
SELECT COUNT(Account_ID)
FROM BANK_STAGING;

SELECT COUNT(DISTINCT Account_ID)
FROM bank_staging;

SELECT *
FROM bank_staging
WHERE Account_ID IS NULL
   OR Account_ID = '';

DELETE FROM bank_staging
WHERE Account_ID IS NULL
   OR Account_ID = '';

SELECT COUNT(*)
FROM bank_staging;

-- ------------------------------------------------------------
-- STEP 2: TRIM WHITESPACE FROM ALL TEXT COLUMNS
-- REASON: LEADING/TRAILING SPACES CAUSE MISMATCHES IN JOINS,
-- GROUP BY, AND WHERE CLAUSES. E.G. 'Active' != 'Active '.
-- ------------------------------------------------------------
UPDATE bank_staging
SET
    Account_ID       = TRIM(Account_ID),
    Customer_Name    = TRIM(Customer_Name),
    Gender           = TRIM(Gender),
    Account_Type     = TRIM(Account_Type),
    Transaction_Type = TRIM(Transaction_Type),
    Branch           = TRIM(Branch),
    IFSC_Code        = TRIM(IFSC_Code),
    Loan_Status      = TRIM(Loan_Status),
    KYC_Status       = TRIM(KYC_Status),
    Account_Status   = TRIM(Account_Status);

-- ------------------------------------------------------------
-- STEP 3: HANDLING MISSING CUSTOMER NAME
-- REASON: REPLACING NULL VALUES WITH 'Unknown' INSTEAD OF
-- DELETING THE ROW BECAUSE THE TRANSACTION DATA IS STILL VALUABLE.
-- ------------------------------------------------------------
SELECT COUNT(*)
FROM bank_staging
WHERE Customer_Name IS NULL
   OR Customer_Name = '';

UPDATE bank_staging
SET Customer_Name = 'Unknown'
WHERE Customer_Name IS NULL
   OR Customer_Name = '';

-- ------------------------------------------------------------
-- STEP 4: HANDLING MISSING AGES WITH THE AVERAGE AGE
-- REASON: DROPPING ROWS WITH NULL AGE WOULD LOSE TRANSACTION DATA.
-- FILLING WITH THE AVERAGE IS A STANDARD IMPUTATION TECHNIQUE.
-- ------------------------------------------------------------
SELECT COUNT(*)
FROM bank_staging
WHERE Age IS NULL
   OR Age = '';

SELECT ROUND(AVG(Age))
FROM bank_staging
WHERE Age IS NOT NULL;
-- 45 IS THE AVG AGE

UPDATE bank_staging
SET Age = 45
WHERE Age IS NULL
    OR Age = '';

-- ------------------------------------------------------------
-- STEP 5: CHANGING THE DATATYPE FROM TEXT TO INT FOR AGE COLUMN
-- REASON: AGE WAS STORED AS TEXT IN THE RAW DATASET.
-- CONVERTING TO INT ALLOWS PROPER NUMERIC COMPARISONS AND SORTING.
-- ------------------------------------------------------------
ALTER TABLE bank_staging
MODIFY COLUMN Age INT;

-- ------------------------------------------------------------
-- STEP 6: DETECT AND FIX MULTI-VALUE CONFLICTS PER ACCOUNT_ID
-- REASON: SAME ACCOUNT_ID HAD MORE THAN 1 CUSTOMER NAME AND AGE.
-- THIS IS A DATA QUALITY ISSUE — ONE ACCOUNT SHOULD HAVE ONE OWNER.
-- FIELDS THAT SHOULD REMAIN CONSTANT FOR A SINGLE BANK ACCOUNT:
--   CUSTOMER_NAME, AGE, GENDER, ACCOUNT_TYPE, BRANCH, IFSC_CODE, KYC_STATUS
-- SOLUTION: RETAIN A SINGLE CONSISTENT VALUE PER ACCOUNT_ID USING MIN().
-- ------------------------------------------------------------
SELECT Account_ID,
       COUNT(DISTINCT Customer_Name) AS Name_Count,
       COUNT(DISTINCT Age) AS Age_Count
FROM bank_staging
GROUP BY Account_ID
HAVING Name_Count > 1
    OR Age_Count > 1;

-- STANDARDIZED CUSTOMER-RELATED INFORMATION BY RETAINING A SINGLE
-- CONSISTENT VALUE FOR EACH ACCOUNT_ID USING A JOIN UPDATE.
UPDATE bank_staging b1
JOIN (
    SELECT
        Account_ID,
        MIN(Customer_Name) AS Customer_Name,
        MIN(Age) AS Age,
        MIN(Gender) AS Gender,
        MIN(Account_Type) AS Account_Type,
        MIN(Branch) AS Branch,
        MIN(IFSC_Code) AS IFSC_Code,
        MIN(KYC_Status) AS KYC_Status
    FROM bank_staging
    GROUP BY Account_ID
) b2
ON b1.Account_ID = b2.Account_ID
SET
    b1.Customer_Name  = b2.Customer_Name,
    b1.Age = b2.Age,
    b1.Gender = b2.Gender,
    b1.Account_Type  = b2.Account_Type,
    b1.Branch  = b2.Branch,
    b1.IFSC_Code  = b2.IFSC_Code,
    b1.KYC_Status  = b2.KYC_Status;

-- ------------------------------------------------------------
-- STEP 7: HANDLING MISSING GENDERS
-- REASON: 'Other' IS A NEUTRAL AND INCLUSIVE FALLBACK.
-- AVOIDS ASSUMPTIONS WHILE KEEPING THE ROW USABLE.
-- ------------------------------------------------------------
UPDATE bank_staging
SET Gender = 'Other'
WHERE Gender IS NULL
   OR Gender = '';

-- ------------------------------------------------------------
-- STEP 8: HANDLING MISSING ACCOUNT TYPE
-- ------------------------------------------------------------
UPDATE bank_staging
SET Account_Type = 'Unknown'
WHERE Account_Type IS NULL
   OR Account_Type = '';

-- CHECK: BALANCE AND TRANSACTION_AMOUNT FOR MISSING VALUES
SELECT COUNT(*)
FROM bank_staging
WHERE Balance IS NULL
   OR Balance = '';

SELECT COUNT(*)
FROM bank_staging
WHERE Transaction_Amount IS NULL
   OR Transaction_Amount = '';
-- NO MISSING DATA FOR BALANCE AND Transaction_Amount

-- ------------------------------------------------------------
-- STEP 9: FIXING TRANSACTION AMOUNT SIGN CONVENTION
-- REASON: CREDIT AND DEBIT AMOUNTS SHOULD HAVE CONSISTENT SIGNS.
-- CREDIT → POSITIVE AMOUNT (+)
-- DEBIT  → NEGATIVE AMOUNT (-)
-- USING ABS() FIRST TO NORMALIZE, THEN APPLY CORRECT SIGN.
-- ------------------------------------------------------------
UPDATE bank_staging
SET Transaction_Amount =
    CASE
        WHEN UPPER(Transaction_Type) = 'CREDIT'
             THEN ABS(Transaction_Amount)
        WHEN UPPER(Transaction_Type) = 'DEBIT'
             THEN -ABS(Transaction_Amount)
        ELSE Transaction_Amount
    END;

-- ------------------------------------------------------------
-- STEP 10: FILLING MISSING TRANSACTION_TYPE USING AMOUNT SIGN
-- REASON: IF TYPE IS MISSING, WE CAN INFER IT FROM THE AMOUNT.
-- POSITIVE AMOUNT = CREDIT, NEGATIVE AMOUNT = DEBIT.
-- THEN STANDARDIZE ALL VALUES TO LOWERCASE FOR CONSISTENCY.
-- ------------------------------------------------------------
UPDATE bank_staging
SET Transaction_Type =
    CASE
        WHEN Transaction_Amount > 0 THEN 'credit'
        WHEN Transaction_Amount < 0 THEN 'debit'
    END
WHERE Transaction_Type IS NULL
   OR Transaction_Type = '';

UPDATE bank_staging
SET Transaction_Type = LOWER(Transaction_Type);

-- ------------------------------------------------------------
-- STEP 11: HANDLING MISSING BRANCH
-- ------------------------------------------------------------
UPDATE bank_staging
SET Branch = 'Unknown'
WHERE Branch IS NULL
   OR Branch = '';

-- ------------------------------------------------------------
-- STEP 12: HANDLING MISSING IFSC CODE
-- ------------------------------------------------------------
UPDATE bank_staging
SET IFSC_Code = 'Unknown'
WHERE IFSC_Code IS NULL
   OR IFSC_Code = '';

-- ============================================================
-- SECTION 4 : BUSINESS RULE ENFORCEMENT
-- KYC_STATUS, LOAN_STATUS, AND ACCOUNT_STATUS ARE ALL INTERLINKED.
-- MISSING VALUES IN ONE FIELD ARE INFERRED FROM THE OTHERS
-- USING REAL BANKING LOGIC AND CREDIT SCORE THRESHOLDS.
-- CREDIT SCORE BANDS:
--   >= 750  → EXCELLENT (Verified KYC, Approved Loan, Active Account)
--   580-749 → GOOD/FAIR (Pending review)
--   < 580   → POOR (Rejected Loan, Inactive Account)
-- ============================================================

-- ------------------------------------------------------------
-- LOAN STATUS RULES
-- ------------------------------------------------------------

-- LOAN STATUS
-- IF KYC IS PENDING OR REJECTED THEN LOAN IS NOT APPROVED
-- REASON: BANK CANNOT APPROVE A LOAN WITHOUT A COMPLETED KYC VERIFICATION.
UPDATE bank_staging
SET Loan_Status = 'Rejected'
WHERE KYC_Status IN ('Pending', 'Rejected');

SET SQL_SAFE_UPDATES = 0;

-- CREDIT_SCORE >= 750 AND KYC_STATUS IS VERIFIED THEN LOAN APPROVED
-- REASON: EXCELLENT CREDIT + VERIFIED IDENTITY = ELIGIBLE FOR LOAN.
UPDATE bank_staging
SET Loan_Status = 'Approved'
WHERE Credit_Score >= 750
AND KYC_Status = 'Verified';

SELECT COUNT(Loan_Status)
FROM bank_staging
WHERE Loan_Status IS NULL
OR Loan_Status = '';

SELECT COUNT(KYC_Status)
FROM bank_staging
WHERE KYC_Status IS NULL
OR KYC_Status = '';

SELECT COUNT(Account_Status)
FROM bank_staging
WHERE Account_Status IS NULL
OR Account_Status = '';

-- ------------------------------------------------------------
-- KYC STATUS RULES
-- ------------------------------------------------------------

-- IF LOAN IS APPROVED AND KYC IS NULL THEN KYC SET TO VERIFIED
-- REASON: AN APPROVED LOAN IMPLIES KYC WAS ALREADY VERIFIED.
UPDATE bank_staging
SET KYC_Status = 'Verified'
WHERE Loan_Status = 'Approved'
AND (KYC_Status IS NULL OR KYC_Status = '');

-- ------------------------------------------------------------
-- ACCOUNT STATUS RULES
-- ------------------------------------------------------------

-- IF LOAN IS APPROVED, KYC IS VERIFIED AND CREDIT SCORE IS >= 750 THEN ACCOUNT IS ACTIVE
-- REASON: A CUSTOMER WITH APPROVED LOAN AND VERIFIED KYC IS ACTIVELY BANKING.
UPDATE bank_staging
SET Account_Status = 'Active'
WHERE Loan_Status = 'Approved'
AND KYC_Status = 'Verified'
AND Credit_Score >= 750;

-- ACCOUNT IS ACTIVE WHEN LOAN IS APPROVED AND KYC IS VERIFIED
-- EVEN IF ACCOUNT WAS PREVIOUSLY MARKED AS CLOSED — LOAN APPROVAL REACTIVATES IT.
UPDATE bank_staging
SET Account_Status = 'Active'
WHERE Loan_Status = 'Approved'
AND KYC_Status = 'Verified'
AND Account_Status = 'Closed';

-- IF CREDIT SCORE < 500 AND ACCOUNT IS ALSO CLOSED THEN KYC AND LOAN ARE REJECTED
-- REASON: VERY LOW CREDIT SCORE + CLOSED ACCOUNT = HIGH RISK, REJECT EVERYTHING.
UPDATE bank_staging
SET
    Loan_Status = 'Rejected',
    KYC_Status  = 'Rejected'
WHERE Credit_Score < 500
AND Account_Status = 'Closed';

-- IF LOAN IS REJECTED, KYC IS PENDING AND CREDIT SCORE < 580 THEN ACCOUNT IS INACTIVE
-- REASON: POOR CREDIT + PENDING VERIFICATION = ACCOUNT SHOULD NOT BE ACTIVE.
UPDATE bank_staging
SET Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND KYC_Status = 'Pending'
AND Credit_Score < 580;

UPDATE bank_staging
SET Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND KYC_Status = 'Rejected'
AND Credit_Score < 580;

-- ACCOUNT IS INACTIVE WHEN LOAN AND KYC BOTH ARE REJECTED
UPDATE bank_staging
SET Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND KYC_Status = 'Rejected';

-- IF ACCOUNT IS ACTIVE AND CREDIT SCORE >= 750 THEN KYC AND LOAN ARE VERIFIED AND APPROVED
UPDATE bank_staging
SET
    KYC_Status  = 'Verified',
    Loan_Status = 'Approved'
WHERE Credit_Score >= 750
AND Account_Status = 'Active'
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Loan_Status IS NULL OR Loan_Status = '');

-- IF CREDIT SCORE >= 750 BUT LOAN IS REJECTED AND KYC IS REJECTED OR PENDING THEN ACCOUNT IS INACTIVE
-- REASON: HIGH SCORE DOESN'T OVERRIDE A KYC REJECTION.
UPDATE bank_staging
SET Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND KYC_Status IN ('Pending', 'Rejected')
AND Credit_Score >= 750;

-- LOAN IS PENDING, CREDIT SCORE < 580, ACCOUNT IS CLOSED THEN KYC IS PENDING
UPDATE bank_staging
SET KYC_Status = 'Pending'
WHERE Loan_Status = 'Pending'
AND Credit_Score < 580
AND Account_Status = 'Closed'
AND (KYC_Status IS NULL OR KYC_Status = '');

-- IF KYC IS VERIFIED THEN ACCOUNT IS ACTIVE
UPDATE bank_staging
SET Account_Status = 'Active'
WHERE KYC_Status = 'Verified'
AND (Account_Status IS NULL OR Account_Status = '');

-- HIGH CREDIT SCORE + PENDING LOAN ->
-- KYC_Status  → Verified
-- Account_Status → Active
UPDATE bank_staging
SET
    KYC_Status     = 'Verified',
    Account_Status = 'Active'
WHERE Loan_Status = 'Pending'
AND Credit_Score >= 750
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- LOW CREDIT SCORE + PENDING LOAN ->
-- KYC_Status  → Pending
-- Account_Status → Inactive
UPDATE bank_staging
SET
    KYC_Status     = 'Pending',
    Account_Status = 'Inactive'
WHERE Loan_Status = 'Pending'
AND Credit_Score < 580
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- REJECTED LOAN + PENDING KYC
-- Account_Status → Inactive
UPDATE bank_staging
SET Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND KYC_Status = 'Pending'
AND (Account_Status IS NULL OR Account_Status = '');

-- REJECTED LOAN + HIGH CREDIT SCORE
-- KYC_Status  → Pending
-- Account_Status → Inactive
UPDATE bank_staging
SET
    KYC_Status     = 'Pending',
    Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND Credit_Score >= 700
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- IF CREDIT SCORE >= 750
-- KYC_Status  → Verified
-- Loan_Status → Approved
-- Account_Status → Active
UPDATE bank_staging
SET
    KYC_Status     = 'Verified',
    Loan_Status    = 'Approved',
    Account_Status = 'Active'
WHERE Credit_Score >= 750
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- IF CREDIT SCORE < 580
-- KYC_Status  → Pending
-- Loan_Status → Rejected
-- Account_Status → Inactive
UPDATE bank_staging
SET
    KYC_Status     = 'Pending',
    Loan_Status    = 'Rejected',
    Account_Status = 'Inactive'
WHERE Credit_Score < 580
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- MID-RANGE CREDIT SCORE (580-749)
-- KYC_Status  → Pending
-- Loan_Status → Pending
-- Account_Status → Inactive
UPDATE bank_staging
SET
    KYC_Status     = 'Pending',
    Loan_Status    = 'Pending',
    Account_Status = 'Inactive'
WHERE Credit_Score BETWEEN 580 AND 749
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- PENDING LOAN + GOOD CREDIT SCORE (>= 650)
-- KYC_Status  → Pending
-- Account_Status → Active
UPDATE bank_staging
SET
    KYC_Status     = 'Pending',
    Account_Status = 'Active'
WHERE Loan_Status = 'Pending'
AND Credit_Score >= 650
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- PENDING LOAN + LOW CREDIT SCORE (< 650)
-- KYC_Status  → Pending
-- Account_Status → Inactive
UPDATE bank_staging
SET
    KYC_Status     = 'Pending',
    Account_Status = 'Inactive'
WHERE Loan_Status = 'Pending'
AND Credit_Score < 650
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- REJECTED LOAN
-- KYC_Status  → Rejected
-- Account_Status → Inactive
UPDATE bank_staging
SET
    KYC_Status     = 'Rejected',
    Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

SELECT Account_Status, COUNT(*)
FROM bank_staging
GROUP BY Account_Status;

-- PENDING LOAN + ACTIVE ACCOUNT + HIGH CREDIT SCORE
-- KYC_Status → Verified
UPDATE bank_staging
SET KYC_Status = 'Verified'
WHERE Loan_Status = 'Pending'
AND Credit_Score >= 750
AND Account_Status = 'Active'
AND (KYC_Status IS NULL OR KYC_Status = '');

-- PENDING LOAN + DORMANT/CLOSED ACCOUNT
-- KYC_Status → Pending
UPDATE bank_staging
SET KYC_Status = 'Pending'
WHERE Loan_Status = 'Pending'
AND LOWER(Account_Status) IN ('closed', 'dormant')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- PENDING LOAN + LOW CREDIT SCORE
-- KYC_Status → Pending
UPDATE bank_staging
SET KYC_Status = 'Pending'
WHERE Loan_Status = 'Pending'
AND Credit_Score < 750
AND (KYC_Status IS NULL OR KYC_Status = '');

-- REJECTED LOAN
-- KYC_Status → Rejected
UPDATE bank_staging
SET KYC_Status = 'Rejected'
WHERE Loan_Status = 'Rejected'
AND (KYC_Status IS NULL OR KYC_Status = '');

-- ACTIVE ACCOUNT + GOOD CREDIT SCORE (>= 750)
-- KYC_Status  → Verified
-- Loan_Status → Approved
UPDATE bank_staging
SET
    KYC_Status  = 'Verified',
    Loan_Status = 'Approved'
WHERE Credit_Score >= 750
AND LOWER(Account_Status) = 'active'
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- CLOSED OR DORMANT ACCOUNT + LOW/MID CREDIT SCORE (< 750)
-- KYC_Status  → Pending
-- Loan_Status → Rejected
UPDATE bank_staging
SET
    KYC_Status  = 'Pending',
    Loan_Status = 'Rejected'
WHERE Credit_Score < 750
AND LOWER(Account_Status) IN ('closed', 'dormant')
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- DORMANT ACCOUNT + VERY HIGH CREDIT SCORE
-- KYC_Status  → Verified
-- Loan_Status → Pending
UPDATE bank_staging
SET
    KYC_Status  = 'Verified',
    Loan_Status = 'Pending'
WHERE Credit_Score >= 750
AND LOWER(Account_Status) = 'dormant'
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- ACTIVE ACCOUNT + LOW/MID CREDIT SCORE (< 750)
-- KYC_Status  → Pending
-- Loan_Status → Pending
UPDATE bank_staging
SET
    KYC_Status  = 'Pending',
    Loan_Status = 'Pending'
WHERE Credit_Score < 750
AND LOWER(Account_Status) = 'active'
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- CLOSED ACCOUNT + HIGH CREDIT SCORE
-- KYC_Status  → Verified
-- Loan_Status → Rejected
-- REASON: HIGH CREDIT SCORE BUT CLOSED ACCOUNT = KYC CAN BE VERIFIED
-- BUT LOAN IS REJECTED BECAUSE THE ACCOUNT IS NO LONGER ACTIVE.
UPDATE bank_staging
SET
    KYC_Status  = 'Verified',
    Loan_Status = 'Rejected'
WHERE Credit_Score >= 750
AND LOWER(Account_Status) = 'closed'
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

SELECT KYC_Status, COUNT(*)
FROM bank_staging
GROUP BY KYC_Status;

-- VERIFIED KYC + ACTIVE ACCOUNT + CREDIT SCORE >= 750
-- Loan_Status → Approved
UPDATE bank_staging
SET Loan_Status = 'Approved'
WHERE Credit_Score >= 750
AND LOWER(KYC_Status) = 'verified'
AND LOWER(Account_Status) = 'active'
AND (Loan_Status IS NULL OR Loan_Status = '');

-- VERIFIED KYC + ACTIVE ACCOUNT + CREDIT SCORE 580-749
-- Loan_Status → Pending
UPDATE bank_staging
SET Loan_Status = 'Pending'
WHERE Credit_Score BETWEEN 580 AND 749
AND LOWER(KYC_Status) = 'verified'
AND LOWER(Account_Status) = 'active'
AND (Loan_Status IS NULL OR Loan_Status = '');

-- VERIFIED KYC + LOW CREDIT SCORE (< 580)
-- Loan_Status → Rejected
UPDATE bank_staging
SET Loan_Status = 'Rejected'
WHERE Credit_Score < 580
AND LOWER(KYC_Status) = 'verified'
AND (Loan_Status IS NULL OR Loan_Status = '');

-- VERIFIED KYC + CLOSED/DORMANT ACCOUNT
-- Loan_Status → Rejected
-- REASON: EVEN WITH VERIFIED KYC, A CLOSED/DORMANT ACCOUNT
-- CANNOT RECEIVE A LOAN DISBURSEMENT.
UPDATE bank_staging
SET Loan_Status = 'Rejected'
WHERE LOWER(KYC_Status) = 'verified'
AND LOWER(Account_Status) IN ('closed', 'dormant')
AND (Loan_Status IS NULL OR Loan_Status = '');

SELECT Loan_Status, COUNT(*)
FROM bank_staging
GROUP BY Loan_Status;

-- ============================================================
-- SECTION 5 : AFTER CLEANING SNAPSHOT
-- COMPARE THESE NUMBERS WITH THE BEFORE SNAPSHOT ABOVE.
-- EVERY VALUE SHOULD BE 0 — THAT PROVES THE CLEANING WORKED.
-- ============================================================

SELECT
    'Null Account IDs' AS Check_Name, COUNT(*) AS Remaining_Issues FROM bank_staging WHERE Account_ID IS NULL OR Account_ID = ''
UNION ALL
SELECT 'Null Customer Names',  COUNT(*) FROM bank_staging WHERE Customer_Name IS NULL OR Customer_Name = ''
UNION ALL
SELECT 'Invalid Ages',  COUNT(*) FROM bank_staging WHERE Age IS NULL OR Age < 0 OR Age > 120
UNION ALL
SELECT 'Null Genders',  COUNT(*) FROM bank_staging WHERE Gender IS NULL OR Gender = ''
UNION ALL
SELECT 'Null Account Types', COUNT(*) FROM bank_staging WHERE Account_Type IS NULL OR Account_Type = ''
UNION ALL
SELECT 'Null Branches',  COUNT(*) FROM bank_staging WHERE Branch IS NULL OR Branch = ''
UNION ALL
SELECT 'Null IFSC Codes', COUNT(*) FROM bank_staging WHERE IFSC_Code IS NULL OR IFSC_Code = ''
UNION ALL
SELECT 'Null Transaction Types',COUNT(*) FROM bank_staging WHERE Transaction_Type IS NULL OR Transaction_Type = ''
UNION ALL
SELECT 'Null Loan Statuses', COUNT(*) FROM bank_staging WHERE Loan_Status IS NULL OR Loan_Status = ''
UNION ALL
SELECT 'Null KYC Statuses', COUNT(*) FROM bank_staging WHERE KYC_Status IS NULL OR KYC_Status = ''
UNION ALL
SELECT 'Null Account Statuses',COUNT(*) FROM bank_staging WHERE Account_Status IS NULL OR Account_Status = '';

-- ============================================================
-- SECTION 6 : FRAUD DETECTION
-- TRANSACTIONS ARE FLAGGED AS SUSPICIOUS (NOT NECESSARILY FRAUD).
-- FLAGGING CONDITIONS:
--   1. TRANSACTION AMOUNT > 100,000 → UNUSUALLY LARGE, NEEDS REVIEW
--   2. DEBIT TRANSACTION + NEGATIVE BALANCE → OVERDRAFT / SUSPICIOUS
--   3. TRANSACTION ON CLOSED/INACTIVE ACCOUNT > 50,000 → STRONG FRAUD SIGNAL
-- NOTE: PARENTHESES ADDED TO FIX OPERATOR PRECEDENCE (AND BINDS BEFORE OR).
-- BUG FIX: CHANGED IN ('Closed' OR 'Inactive') → IN ('Closed', 'Inactive')
-- ============================================================

-- IF Transaction_Amount IS > 100000 THEN IT CAN BE SUSPICIOUS, FLAGGED FOR FRAUD NOT COMPLETELY FRAUD
-- IF AFTER THE AMT IS REMOVED I.E DEBIT AND THE BALANCE BECOMES NEGATIVE THAN IT IS ALSO FLAGGED AS SUSPICIOUS
-- IF THE TRANSACTION IS HAPPENING IN CLOSED OR INACTIVE ACCOUNT THEN IT CAN BE CONSIDERED AS FRAUD
SELECT *
FROM bank_staging
WHERE ABS(Transaction_Amount) > 100000
   OR (Transaction_Type = 'debit' AND Balance < 0)
   OR (Account_Status IN ('Closed', 'Inactive') AND ABS(Transaction_Amount) > 50000);

SELECT COUNT(*) AS Total_Suspicious_Transactions
FROM bank_staging
WHERE ABS(Transaction_Amount) > 100000
   OR (Transaction_Type = 'debit' AND Balance < 0)
   OR (Account_Status IN ('Closed', 'Inactive') AND ABS(Transaction_Amount) > 50000);

-- ============================================================
-- SECTION 7 : ANALYTICS & REPORTING
-- ============================================================

-- ------------------------------------------------------------
-- Improve loan approval decisions
-- THIS DECISION WAS MADE BEFORE SOLVING PROBLEM STATEMENTS
-- LOGIC BEHIND THAT:
-- ANALYZED CUSTOMER CREDIT SCORES TO DETERMINE LOAN ELIGIBILITY.
-- VERIFIED CUSTOMER KYC STATUS BEFORE APPROVING LOANS.
-- APPROVED LOANS FOR CUSTOMERS WITH HIGH CREDIT SCORES AND VERIFIED KYC.
-- REJECTED LOANS FOR CUSTOMERS WITH LOW CREDIT SCORES OR REJECTED/PENDING KYC.
-- KEPT SOME LOANS IN PENDING STATUS FOR MID-RANGE CREDIT SCORES OR INCOMPLETE VERIFICATION.
-- CONSIDERED ACCOUNT STATUS SUCH AS ACTIVE, INACTIVE, CLOSED, AND DORMANT DURING LOAN DECISION MAKING.
-- USED LOGICAL BANKING RULES TO HANDLE MISSING LOAN AND KYC VALUES.
-- ------------------------------------------------------------

-- HIGH RISK CUSTOMERS
-- CUSTOMERS WITH LOW CREDIT SCORE, KYC PENDING OR REJECTED
-- LOAN STATUS IS REJECTED AND ACCOUNT IS INACTIVE OR CLOSED
SELECT COUNT(DISTINCT Account_ID) AS High_Risk_Customers
FROM bank_staging
WHERE Credit_Score < 580
   OR KYC_Status IN ('Pending', 'Rejected')
   OR Loan_Status = 'Rejected'
   OR Account_Status IN ('Inactive', 'Closed');

-- Analyze customer segmentation

-- GROUPED CUSTOMERS BASED ON ACCOUNT TYPE, ACCOUNT STATUS, AND LOAN STATUS.
-- COUNTED TOTAL CUSTOMERS IN EACH SEGMENT.
SELECT
    Account_Status,
    Loan_Status,
    Account_Type,
    COUNT(DISTINCT Account_ID) AS Total_Customers
FROM bank_staging
GROUP BY Account_Status, Loan_Status, Account_Type
ORDER BY Total_Customers DESC;

-- CUSTOMER SEGMENTATION BASED ON AGE
SELECT
    CASE
        WHEN Age < 18 THEN 'Minor'
        WHEN Age BETWEEN 18 AND 59 THEN 'Adults'
        ELSE  'Senior Citizen'
    END AS Age_Group,
    COUNT(DISTINCT Account_ID) AS Total_Customers
FROM bank_staging
GROUP BY Age_Group;

-- CUSTOMERS WITH POSITIVE AND NEGATIVE BANK BALANCE
SELECT
    CASE
        WHEN Balance > 0 THEN 'Positive Balance'
        ELSE  'Negative Balance'
    END AS Balance_Type,
    COUNT(DISTINCT Account_ID) AS Total_Customers
FROM bank_staging
GROUP BY Balance_Type;

-- Monitor account health & inactivity
SELECT
    Account_Status,
    COUNT(Account_ID) AS Total_Accounts
FROM bank_staging
GROUP BY Account_Status
ORDER BY Total_Accounts;

-- Evaluate branch performance
-- COUNTED TOTAL CUSTOMERS IN EVERY BRANCH.
-- CALCULATED TOTAL ACCOUNT BALANCE PER BRANCH.
-- COUNTED TOTAL APPROVED LOANS.
SELECT
    Branch,
    COUNT(DISTINCT Account_ID) AS Total_Customers,
    ROUND(SUM(Balance), 2) AS Total_Balance,
    COUNT(CASE WHEN Loan_Status = 'Approved' THEN 1 END) AS Approved_Loans
FROM bank_staging
GROUP BY Branch
ORDER BY Total_Balance DESC;

-- ------------------------------------------------------------
-- ADDITIONAL EDA: CREDIT SCORE DISTRIBUTION
-- REASON: UNDERSTANDING HOW CUSTOMERS ARE SPREAD ACROSS CREDIT
-- SCORE BANDS HELPS IDENTIFY THE RISK PROFILE OF THE PORTFOLIO.
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN Credit_Score < 580          THEN 'Poor (< 580)'
        WHEN Credit_Score BETWEEN 580 AND 669 THEN 'Fair (580-669)'
        WHEN Credit_Score BETWEEN 670 AND 749 THEN 'Good (670-749)'
        WHEN Credit_Score >= 750         THEN 'Excellent (750+)'
    END AS Credit_Category,
    COUNT(DISTINCT Account_ID) AS Total_Customers,
    ROUND(AVG(Balance), 2)     AS Avg_Balance
FROM bank_staging
GROUP BY Credit_Category
ORDER BY MIN(Credit_Score);

-- ------------------------------------------------------------
-- ADDITIONAL EDA: AVERAGE BALANCE BY ACCOUNT TYPE
-- REASON: SHOWS WHICH ACCOUNT TYPE HOLDS THE MOST VALUE.
-- ------------------------------------------------------------
SELECT
    Account_Type,
    COUNT(DISTINCT Account_ID) AS Total_Customers,
    ROUND(AVG(Balance), 2)     AS Avg_Balance,
    ROUND(SUM(Balance), 2)     AS Total_Balance
FROM bank_staging
GROUP BY Account_Type
ORDER BY Total_Balance DESC;

-- ------------------------------------------------------------
-- ADDITIONAL EDA: TRANSACTION VOLUME BY BRANCH
-- REASON: IDENTIFIES HIGH-ACTIVITY BRANCHES VS LOW-ACTIVITY ONES.
-- USEFUL FOR RESOURCE ALLOCATION AND PERFORMANCE BENCHMARKING.
-- ------------------------------------------------------------
SELECT
    Branch,
    COUNT(*) AS Total_Transactions,
    ROUND(SUM(ABS(Transaction_Amount)), 2) AS Total_Volume,
    ROUND(AVG(ABS(Transaction_Amount)), 2) AS Avg_Transaction
FROM bank_staging
GROUP BY Branch
ORDER BY Total_Volume DESC;

-- CHANGING THE DATATYPE OF DATE COLUMN FROM TEXT TO DATE
-- REASON: DATE WAS STORED AS TEXT IN THE RAW DATASET.

ALTER TABLE bank_staging
MODIFY COLUMN Transaction_Date DATE;
