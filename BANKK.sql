CREATE DATABASE BANKK;
USE BANKK;

-- CREATING A STAGING TABLE FOR PERFORMING OPERATIONS 
CREATE TABLE BANK_STAGING
LIKE `bank unclean dataset`;

-- INSERTING VALUES IN STAGING TABLE
INSERT INTO BANK_STAGING
SELECT * FROM `bank unclean dataset`;

-- REMOVING THE ROWS WHERE ACCOUNT_ID IS MISSING
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

SET SQL_SAFE_UPDATES = 0;

SELECT COUNT(*)
FROM bank_staging;

-- TRIMING THE SPACES FROM COLUMNS 
UPDATE bank_staging
SET
    Account_ID = TRIM(Account_ID),
    Customer_Name = TRIM(Customer_Name),
    Gender = TRIM(Gender),
    Account_Type = TRIM(Account_Type),
    Transaction_Type = TRIM(Transaction_Type),
    Branch = TRIM(Branch),
    IFSC_Code = TRIM(IFSC_Code),
    Loan_Status = TRIM(Loan_Status),
    KYC_Status = TRIM(KYC_Status),
    Account_Status = TRIM(Account_Status);
   
-- HANDLING MISSING CUSTOMER NAME BY REPALCING NULL VALUES WITH UNKNOWN
SELECT COUNT(*)
FROM bank_staging
WHERE Customer_Name IS NULL
   OR Customer_Name = '';

UPDATE bank_staging
SET Customer_Name = 'Unknown'
WHERE Customer_Name IS NULL
   OR Customer_Name = '';

-- HANDLING MISSING AGES WITH THE AVERAGE AGES
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

-- CHANGING THE DATATYPE FROM TEXT TO INT OF AGE COLUMN
ALTER TABLE bank_staging
MODIFY COLUMN Age INT;

-- SAME ACC ID HAVE MORE THAN 1 CUSTOMER NAME AND AGE 
-- IT IS A DATA QUALITY ISSUE
SELECT Account_ID,
       COUNT(DISTINCT Customer_Name) AS Name_Count,
       COUNT(DISTINCT Age) AS Age_Count
FROM bank_staging
GROUP BY Account_ID
HAVING Name_Count > 1
    OR Age_Count > 1;

-- OBSERVED INCONSISTENCIES IN CUSTOMER-RELATED FIELDS SUCH AS:
-- CUSTOMER_NAME
-- AGE
-- GENDER
-- ACCOUNT_TYPE
-- BRANCH
-- IFSC_CODE
-- KYC_STATUS

-- THESE FIELDS SHOULD NORMALLY REMAIN CONSTANT FOR A SINGLE BANK ACCOUNT.

-- STANDARDIZED CUSTOMER-RELATED INFORMATION BY RETAINING A SINGLE CONSISTENT VALUE FOR EACH ACCOUNT_ID.

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
    b1.Customer_Name = b2.Customer_Name,
    b1.Age = b2.Age,
    b1.Gender = b2.Gender,
    b1.Account_Type = b2.Account_Type,
    b1.Branch = b2.Branch,
    b1.IFSC_Code = b2.IFSC_Code,
    b1.KYC_Status = b2.KYC_Status;

-- HANDLING MISSING GENDERS 
UPDATE bank_staging
SET Gender = 'Other'
WHERE Gender IS NULL
   OR Gender = '';
  
-- HANDLING MISSING ACCOUNT TYPE
UPDATE bank_staging
SET Account_Type = 'Unknown'
WHERE Account_Type IS NULL
   OR Account_Type = '';

SELECT COUNT(*)
FROM bank_staging
WHERE Balance IS NULL
   OR Balance = '';
   
SELECT COUNT(*)
FROM bank_staging
WHERE Transaction_Amount IS NULL
   OR Transaction_Amount = '';
-- NO MISSING DATA FOR BALANCE AND Transaction_Amount

-- FOR Transaction_Type
-- CREDIT → positive amount(+)
-- DEBIT → negative amount(-)

UPDATE bank_staging
SET Transaction_Amount = 
    CASE
        WHEN UPPER(Transaction_Type) = 'CREDIT'
             THEN ABS(Transaction_Amount)

        WHEN UPPER(Transaction_Type) = 'DEBIT'
             THEN -ABS(Transaction_Amount)

        ELSE Transaction_Amount
    END;

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

-- HANDLING MISSING BRANCH
UPDATE bank_staging
SET Branch = 'Unknown'
WHERE Branch IS NULL
   OR Branch = '';

-- HANDLING MISSING IFSC CODE
UPDATE bank_staging
SET IFSC_Code = 'Unknown'
WHERE IFSC_Code IS NULL
   OR IFSC_Code = '';

-- LOAN STATUS 
-- IF KYC IS PENDING OR REJECTED THEN LOAN IS NOT APPROVED
UPDATE bank_staging
SET Loan_Status = 'Rejected'
WHERE (KYC_Status) IN ('Pending', 'Rejected');

SET SQL_SAFE_UPDATES = 0;

-- CREDIT_SCORE >= 750 AND KYC_STATUS IS VERIFIED THEN LOAN APPROVED 
UPDATE bank_staging
SET Loan_Status = 'Approved'
WHERE CREDIT_SCORE >= 750
AND KYC_Status = 'Verified';

SELECT COUNT(LOAN_STATUS)
FROM bank_staging
WHERE LOAN_STATUS IS NULL 
OR LOAN_STATUS = '';

SELECT COUNT(KYC_STATUS)
FROM bank_staging
WHERE KYC_STATUS IS NULL 
OR KYC_STATUS = '';

SELECT COUNT(ACCOUNT_STATUS)
FROM bank_staging
WHERE ACCOUNT_STATUS IS NULL 
OR ACCOUNT_STATUS = '';

-- IF LOAN IS APPROVED AND KYC IS NULL THEN KYC SET TO VERIFIED
UPDATE bank_staging
SET KYC_Status = 'Verified'
WHERE Loan_Status = 'Approved'
AND (KYC_Status IS NULL OR KYC_Status = '');

-- IF LOAN IS APPROVED KYC IS VERIFIED AND CREDIT SCORE IS >= 750 THEN ACCOUNT IS ACTIVE
UPDATE bank_staging
SET Account_Status = 'Active'
WHERE Loan_Status = 'Approved'
AND KYC_Status = 'Verified'
AND Credit_Score >= 750;

-- ACCOUNT IS ACTIVE WHEN LOAN IS APPROVED AND KYC IS VERIFIED
UPDATE bank_staging
SET Account_Status = 'Active'
WHERE Loan_Status = 'Approved'
AND KYC_Status = 'Verified'
AND Account_Status = 'Closed';

-- IF CREDIT SCORE <500 AND ACCOUNT IS ALSO CLOSED THEN KYC AND LOAN ARE REJECTED
UPDATE bank_staging
SET 
    Loan_Status = 'Rejected',
    KYC_Status = 'Rejected'
WHERE Credit_Score < 500
AND Account_Status = 'Closed';

-- IF LOAN IS REJECTED, KYC IS PENDING AND CREDIT SCORE <580 THEN ACCOUNT IS INACTIVE 
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

-- IF ACCOUNT IS ACTIVE AND CREDIT SCORE >=750 THEN KYC AND LOAN ARE VERIFIED AND APPROVED
UPDATE bank_staging
SET 
    KYC_Status = 'Verified',
    Loan_Status = 'Approved'
WHERE Credit_Score >= 750
AND Account_Status = 'Active'
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Loan_Status IS NULL OR Loan_Status = '');

-- IF CREDIT SCORE >= 750 BUT LOAN IS REJECTED AND KYC IS REJECTED OR PENDING THEN ACCOUNT IS INACTIVE
UPDATE bank_staging
SET Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND (KYC_Status) IN ('Pending', 'Rejected')
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
-- KYC_Status → Verified
-- Account_Status → Active
UPDATE bank_staging
SET 
    KYC_Status = 'Verified',
    Account_Status = 'Active'
WHERE Loan_Status = 'Pending'
AND Credit_Score >= 750
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- LOW CREDIT SCORE + PENDING LOAN ->
-- KYC_Status → Pending
-- Account_Status → Inactive
UPDATE bank_staging
SET 
    KYC_Status = 'Pending',
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
-- KYC_Status → Pending
-- Account_Status → Inactive
UPDATE bank_staging
SET 
    KYC_Status = 'Pending',
    Account_Status = 'Inactive'
WHERE Loan_Status = 'Rejected'
AND Credit_Score >= 700
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- IF CREDIT SCORE >= 750
-- KYC_Status → Verified
-- Loan_Status → Approved
-- Account_Status → Active
UPDATE bank_staging
SET
    KYC_Status = 'Verified',
    Loan_Status = 'Approved',
    Account_Status = 'Active'
WHERE Credit_Score >= 750
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- IF CREDIT SCORE < 580
-- KYC_Status → Pending
-- Loan_Status → Rejected
-- Account_Status → Inactive

UPDATE bank_staging
SET
    KYC_Status = 'Pending',
    Loan_Status = 'Rejected',
    Account_Status = 'Inactive'
WHERE Credit_Score < 580
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- MID-RANGE CREDIT SCORE (580–749)
-- KYC_Status → Pending
-- Loan_Status → Pending
-- Account_Status → Inactive

UPDATE bank_staging
SET
    KYC_Status = 'Pending',
    Loan_Status = 'Pending',
    Account_Status = 'Inactive'
WHERE Credit_Score BETWEEN 580 AND 749
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- PENDING LOAN + GOOD CREDIT SCORE (>= 650)
-- KYC_Status → Pending
-- Account_Status → Active
UPDATE bank_staging
SET
    KYC_Status = 'Pending',
    Account_Status = 'Active'
WHERE Loan_Status = 'Pending'
AND Credit_Score >= 650
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- PENDING LOAN + LOW CREDIT SCORE (< 650)
-- KYC_Status → Pending
-- Account_Status → Inactive
UPDATE bank_staging
SET
    KYC_Status = 'Pending',
    Account_Status = 'Inactive'
WHERE Loan_Status = 'Pending'
AND Credit_Score < 650
AND (KYC_Status IS NULL OR KYC_Status = '')
AND (Account_Status IS NULL OR Account_Status = '');

-- REJECTED LOAN
-- KYC_Status → Rejected
-- Account_Status → Inactive
UPDATE bank_staging
SET
    KYC_Status = 'Rejected',
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
-- KYC_Status → Verified
-- Loan_Status → Approved
UPDATE bank_staging
SET
    KYC_Status = 'Verified',
    Loan_Status = 'Approved'
WHERE Credit_Score >= 750
AND LOWER(Account_Status) = 'active'
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- CLOSED OR DORMANT ACCOUNT + LOW/MID CREDIT SCORE (< 750)
-- KYC_Status → Pending
-- Loan_Status → Rejected
UPDATE bank_staging
SET
    KYC_Status = 'Pending',
    Loan_Status = 'Rejected'
WHERE Credit_Score < 750
AND LOWER(Account_Status) IN ('closed', 'dormant')
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- DORMANT ACCOUNT + VERY HIGH CREDIT SCORE
-- KYC_Status → Verified
-- Loan_Status → Pending
UPDATE bank_staging
SET
    KYC_Status = 'Verified',
    Loan_Status = 'Pending'
WHERE Credit_Score >= 750
AND LOWER(Account_Status) = 'dormant'
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- ACTIVE ACCOUNT + LOW/MID CREDIT SCORE (< 750)
-- KYC_Status → Pending
-- Loan_Status → Pending
UPDATE bank_staging
SET
    KYC_Status = 'Pending',
    Loan_Status = 'Pending'
WHERE Credit_Score < 750
AND LOWER(Account_Status) = 'active'
AND (Loan_Status IS NULL OR Loan_Status = '')
AND (KYC_Status IS NULL OR KYC_Status = '');

-- CLOSED ACCOUNT + HIGH CREDIT SCORE
-- KYC_Status → Verified
-- Loan_Status → Rejected
UPDATE bank_staging
SET
    KYC_Status = 'Verified',
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

-- VERIFIED KYC + ACTIVE ACCOUNT + CREDIT SCORE 580–749
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
UPDATE bank_staging
SET Loan_Status = 'Rejected'
WHERE LOWER(KYC_Status) = 'verified'
AND LOWER(Account_Status) IN ('closed', 'dormant')
AND (Loan_Status IS NULL OR Loan_Status = '');

SELECT LOAN_Status, COUNT(*)
FROM bank_staging
GROUP BY LOAN_Status;

-- HIGH RISK CUSTOMERS 
-- CUSTOMERS WITH LOW CREDIT SCORE, KYC PENDING OR REJECTED
-- LOAN STATUS IS REJECTED AND ACCOUNT IS INACTIVE OR CLOSED
SELECT COUNT(DISTINCT Account_ID) AS High_Risk_Customers
FROM bank_staging
WHERE Credit_Score < 580
   OR KYC_Status IN ('Pending', 'Rejected')
   OR Loan_Status = 'Rejected'
   OR Account_Status IN ('Inactive', 'Closed');

-- Detect fraudulent transactions
-- IF Transaction_Amount IS > 100000 THEN IT CAN BE SUSPICIOUS, FLAGED FOR FRAUD NOT COMPLETLY FRAUD
-- IF AFTER THE AMT IS REMOVED I.E DEBIT AND THE BALANCE BECOMES NEGATIVE THAN IT IS ALSO FLAGGED AS SUSPICIOUS
-- IF THE TRANSACTION IS HAPPENING IN CLOSED OR INACTIVE ACCOUNT THEN IT CAN BE CONSIDERD AS FRAUD
SELECT * FROM bank_staging
WHERE ABS(Transaction_Amount) > 100000
    OR Transaction_Type = 'Debit' AND Balance < 0
    OR ACCOUNT_STATUS IN ('Closed' OR 'Inactive')
		AND ABS(Transaction_Amount) > 50000;

SELECT COUNT(*)
FROM bank_staging
WHERE ABS(Transaction_Amount) > 100000
    OR Transaction_Type = 'Debit' AND Balance < 0
    OR ACCOUNT_STATUS IN ('Closed' OR 'Inactive')
		AND ABS(Transaction_Amount) > 50000;
        
-- Analyze customer segmentation

-- GROUPED CUSTOMERS BASED ON ACCOUNT TYPE, ACCOUNT STATUS, AND LOAN STATUS.
-- COUNTED TOTAL CUSTOMERS IN EACH SEGMENT.		
SELECT 
	ACCOUNT_STATUS,
    LOAN_STATUS,
    ACCOUNT_TYPE,
    COUNT(DISTINCT ACCOUNT_ID) AS TOTAL_CUSTOMERS 
FROM bank_staging
GROUP BY ACCOUNT_STATUS, LOAN_STATUS, ACCOUNT_TYPE
ORDER BY TOTAL_CUSTOMERS DESC;

-- CUSTOMER SEGMENTATION BASED ON AGE
SELECT 
	CASE
		WHEN AGE < 18 THEN 'MINOR'
        WHEN AGE BETWEEN 18 AND 59 THEN 'ADULTS'
        ELSE 'SENIOR CITIZEN'
	END AS AGE_GRP,
    COUNT(DISTINCT ACCOUNT_ID) AS TOTAL_CUSTOMERS
FROM bank_staging
GROUP BY AGE_GRP;
    
-- CUSTOMERS WITH POSITIVE AND NEGATIVE BANK BALANCE
SELECT 
	CASE 
		WHEN BALANCE > 0 THEN 'POSITIVE AMT'
        ELSE 'NEGATIVE AMT'
	END AS BALANACE_TYPE,
    COUNT(DISTINCT ACCOUNT_ID) AS TOTAL_CUSTOMERS
FROM bank_staging
GROUP BY BALANACE_TYPE;

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

-- Monitor account health & inactivity			
SELECT 
	ACCOUNT_STATUS,
    COUNT(ACCOUNT_ID) AS TOTAL_ACCOUNT_TYPES
FROM bank_staging
GROUP BY ACCOUNT_STATUS
ORDER BY TOTAL_ACCOUNT_TYPES;

-- Evaluate branch performance		
-- COUNTED TOTAL CUSTOMERS IN EVERY BRANCH.
-- CALCULATED TOTAL ACCOUNT BALANCE PER BRANCH.
-- COUNTED TOTAL APPROVED LOANS.
SELECT 
    Branch,
    COUNT(DISTINCT Account_ID) AS Total_Customers,
    SUM(Balance) AS Total_Balance,
    COUNT(CASE WHEN Loan_Status = 'Approved' THEN 1 END) AS Approved_Loans
FROM bank_staging
GROUP BY Branch
ORDER BY Total_Balance DESC;

-- THE DATE COLUMN HAD TEXT DATATYPE 
-- CHANGED IT TO DATE '%Y-%m-%d'
UPDATE bank_staging
SET Transaction_Date = STR_TO_DATE(Transaction_Date, '%Y-%m-%d');

ALTER TABLE bank_staging
MODIFY COLUMN Transaction_Date DATE;

SET SQL_SAFE_UPDATES = 0;

DESCRIBE bank_staging;