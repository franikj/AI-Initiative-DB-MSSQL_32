CREATE OR ALTER PROCEDURE sp_CustomerRevenue
    @FromYear INT = NULL,
    @ToYear INT = NULL,
    @Period VARCHAR(10) = 'Y',
    @CustomerID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE, @EndDate DATE;
    DECLARE @TableName NVARCHAR(128), @SQL NVARCHAR(MAX);
    DECLARE @CustomerName NVARCHAR(50);
    
    -- Set the start and end dates based on the input parameters
SET @StartDate = ISNULL(CAST(@FromYear AS CHAR(4)) + '-01-01', (SELECT MIN(CONVERT(date, [Date])) FROM [Dimension].[Date]));
SET @EndDate = ISNULL(CAST(@ToYear AS CHAR(4)) + '-12-31', (SELECT MAX(CONVERT(date, [Date])) FROM [Dimension].[Date]));


    
    -- Get the customer name if a CustomerID is provided
    SET @CustomerName = (SELECT [Customer] FROM [Dimension].[Customer] WHERE [Customer Key] = @CustomerID);
    
    -- Create the table name based on the input parameters
    -- Create the table name based on the input parameters
    SET @TableName = 'Revenue_';
    IF @CustomerID IS NULL
        SET @TableName += 'All';
    ELSE
    BEGIN
        SET @CustomerName = REPLACE(REPLACE(REPLACE(REPLACE(@CustomerName, '(', ''), ')', ''), ',', ''), ' ', '');
        SET @TableName += CAST(@CustomerID AS NVARCHAR) + '_' + @CustomerName;
    END
    IF @FromYear = @ToYear
        SET @TableName += '_' + CAST(@FromYear AS NVARCHAR);
    ELSE
        SET @TableName += '_' + CAST(@FromYear AS NVARCHAR) + '_' + CAST(@ToYear AS NVARCHAR);
    SET @TableName += '_' + LEFT(@Period, 1);

    
    -- Drop the table if it already exists
    SET @SQL = 'IF OBJECT_ID(''dbo.' + @TableName + ''', ''U'') IS NOT NULL ' +
               'DROP TABLE dbo.' + @TableName;
    EXEC sp_executesql @SQL;
    
    -- Create the table
    SET @SQL = 'CREATE TABLE dbo.' + @TableName + ' ' +
               '([CustomerID] INT, ' +
               '[CustomerName] NVARCHAR(50), ' +
               '[Period] NVARCHAR(8), ' +
               '[Revenue] NUMERIC(19,2))';
    EXEC sp_executesql @SQL;
    
    -- Insert the revenue data into the table
    SET @SQL = 'INSERT INTO dbo.' + @TableName + ' ' +
               'SELECT ' +
               '    c.[Customer Key] AS [CustomerID], ' +
               '    c.[Customer] AS [CustomerName], ' +
               '    CASE ' +
               '        WHEN @Period IN (''Month'', ''M'') THEN FORMAT(d.[Date], ''MMM yyyy'') ' +
               '        WHEN @Period IN (''Quarter'', ''Q'') THEN ''Q'' + CAST(DATEPART(QUARTER, d.[Date]) AS NVARCHAR) + '' '' + CAST(DATEPART(YEAR, d.[Date]) AS NVARCHAR) ' +
               '        ELSE CAST(DATEPART(YEAR, d.[Date]) AS NVARCHAR) ' +
               '    END AS [Period], ' +
               '    ISNULL(SUM(s.[Quantity] * s.[Unit Price]), 0) AS [Revenue] ' +
               'FROM ' +
               '    [Dimension].[Customer] c ' +
               'LEFT JOIN ' +
               '    [Fact].[Sale] s ON c.[Customer Key] = s.[Customer Key] ' +
               'LEFT JOIN ' +
               '    [Dimension].[Date] d ON s.[Invoice Date Key] = d.[Date] ' +
               'WHERE ' +
               '    d.[Date] BETWEEN @StartDate AND @EndDate ' +
               '    AND (@CustomerID IS NULL OR c.[Customer Key] = @CustomerID) ' +
               'GROUP BY ' +
				'    c.[Customer Key], c.[Customer], ' +
				'    CASE ' +
				'        WHEN @Period IN (''Month'', ''M'') THEN FORMAT(d.[Date], ''MMM yyyy'') ' +
				'        WHEN @Period IN (''Quarter'', ''Q'') THEN ''Q'' + CAST(DATEPART(QUARTER, d.[Date]) AS NVARCHAR) + '' '' + CAST(DATEPART(YEAR, d.[Date]) AS NVARCHAR) ' +
				'        ELSE CAST(DATEPART(YEAR, d.[Date]) AS NVARCHAR) ' +
				'    END';

    EXEC sp_executesql @SQL, N'@StartDate DATE, @EndDate DATE, @Period NVARCHAR(10), @CustomerID INT', @StartDate, @EndDate, @Period, @CustomerID;
    

	DECLARE @SQL_OUT NVARCHAR(MAX);
	SET @SQL_OUT=N'SELECT * FROM dbo.' + @TableName
	EXEC sp_executesql @SQL_OUT

    SET NOCOUNT OFF;

	
END

--EXEC sp_CustomerRevenue @FromYear=2013, @ToYear = 2016, @Period = 'Y', @CustomerID = 379;
--result table [dbo].[Revenue_379_WingtipToysBellAcresPA_2013_2016_Y]
--result
--CustomerID	CustomerName	Period	Revenue
--379	Wingtip Toys (Bell Acres, PA)	2013	70134.40
--379	Wingtip Toys (Bell Acres, PA)	2014	56654.60
--379	Wingtip Toys (Bell Acres, PA)	2015	80811.55
--379	Wingtip Toys (Bell Acres, PA)	2016	63619.00
