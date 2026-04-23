/* PROJECT: Automated SQL Data Integrity Audit
   AUTHOR: Gunel Ayyubova
   DESCRIPTION: Bu skript data bütövlüyünü yoxlayır və sistemin "Məlumatın Dəqiqlik Səviyyəsi"ni hesablayır.
*/

-- 1. DATABASE STRUCTURE (Bünövrə)
IF OBJECT_ID('Transaction_Details') IS NOT NULL DROP TABLE Transaction_Details;
IF OBJECT_ID('Main_Summary') IS NOT NULL DROP TABLE Main_Summary;
IF OBJECT_ID('Data_Integrity_Logs') IS NOT NULL DROP TABLE Data_Integrity_Logs;

CREATE TABLE Main_Summary (
    ParentID INT PRIMARY KEY,
    TotalAmount DECIMAL(18, 2)
);

CREATE TABLE Transaction_Details (
    DetailID INT IDENTITY PRIMARY KEY,
    ParentID INT FOREIGN KEY REFERENCES Main_Summary(ParentID),
    Amount DECIMAL(18, 2)
);

CREATE TABLE Data_Integrity_Logs (
    LogID INT IDENTITY PRIMARY KEY,
    IssueDescription NVARCHAR(MAX),
    DetectedDate DATETIME DEFAULT GETDATE(),
    SeverityLevel NVARCHAR(50)
);
GO

-- 2. AUDIT PROCEDURE (Məntiq və Hesabatlılıq)
CREATE OR ALTER PROCEDURE sp_RunDataIntegrityCheck
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TotalAccounts INT, @FailedAccounts INT, @SuccessPercentage DECIMAL(5,2);

    TRUNCATE TABLE Data_Integrity_Logs;
    SELECT @TotalAccounts = COUNT(*) FROM Main_Summary;

    INSERT INTO Data_Integrity_Logs (IssueDescription, SeverityLevel)
    SELECT 
        'KRİTİK: Uyğunsuzluq! Ana Balans: ' + CAST(M.TotalAmount AS NVARCHAR) + 
        ', Detalların Cəmi: ' + CAST(ISNULL(SUM(D.Amount), 0) AS NVARCHAR) + 
        ' (ID: ' + CAST(M.ParentID AS NVARCHAR) + ')',
        'CRITICAL'
    FROM Main_Summary M
    LEFT JOIN Transaction_Details D ON M.ParentID = D.ParentID
    GROUP BY M.ParentID, M.TotalAmount
    HAVING M.TotalAmount <> ISNULL(SUM(D.Amount), 0);

    SET @FailedAccounts = @@ROWCOUNT;

    IF @TotalAccounts > 0
    BEGIN
        SET @SuccessPercentage = ((@TotalAccounts - @FailedAccounts) * 100.0) / @TotalAccounts;
        PRINT '-------------------------------------------';
        PRINT 'DATA BÜTÖVLÜYÜ HESABATI:';
        PRINT 'Yoxlanılan cəmi hesab: ' + CAST(@TotalAccounts AS NVARCHAR);
        PRINT 'Xətalı hesabların sayı: ' + CAST(@FailedAccounts AS NVARCHAR);
        PRINT 'Məlumatın Sağlamlıq Faizi: ' + CAST(@SuccessPercentage AS NVARCHAR) + '%';
        PRINT '-------------------------------------------';
    END
END;
GO

-- 3. TEST DATA (Yoxlama üçün)
INSERT INTO Main_Summary (ParentID, TotalAmount) VALUES (1, 100), (2, 200), (3, 300), (4, 400);
INSERT INTO Transaction_Details (ParentID, Amount) VALUES (1, 100), (2, 200), (3, 300), (4, 350); -- ID 4 xətalıdır

-- 4. EXECUTION (İcra)
EXEC sp_RunDataIntegrityCheck;
