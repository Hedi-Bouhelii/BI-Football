/* =========================================================
   06_etl_clean_logging.sql
   Logging for package 02 (stg -> cln).

   The reconciliation rule for a cleaning step is:
        rows read from stg  =  rows written to cln  +  rows rejected
   Nothing may disappear silently: every staging row is either clean or rejected.

   Adds:
     - etl.RunLog.rows_rejected  (new column)
     - etl.usp_LogCleanTable     (counts stg, cln and rejects; fails the package on a mismatch)
     - etl.vw_RunSummary         (updated to show rows_rejected)
   Safe to run more than once.
   ========================================================= */

USE FootballBI;
GO

IF COL_LENGTH('etl.RunLog', 'rows_rejected') IS NULL
    ALTER TABLE etl.RunLog ADD rows_rejected INT NULL;
GO

CREATE OR ALTER PROCEDURE etl.usp_LogCleanTable
    @run_id     INT,
    @table_name SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID(N'stg.' + QUOTENAME(@table_name)) IS NULL
       OR OBJECT_ID(N'cln.' + QUOTENAME(@table_name)) IS NULL
        THROW 50003, N'usp_LogCleanTable: table must exist in both stg and cln.', 1;

    DECLARE @rows_read INT, @rows_loaded INT, @rows_rejected INT, @sql NVARCHAR(600);

    SET @sql = N'SELECT @n = COUNT(*) FROM stg.' + QUOTENAME(@table_name) + N';';
    EXEC sp_executesql @sql, N'@n INT OUTPUT', @n = @rows_read OUTPUT;

    SET @sql = N'SELECT @n = COUNT(*) FROM cln.' + QUOTENAME(@table_name) + N' WHERE etl_run_id = @r;';
    EXEC sp_executesql @sql, N'@n INT OUTPUT, @r INT', @n = @rows_loaded OUTPUT, @r = @run_id;

    SELECT @rows_rejected = COUNT(*)
    FROM etl.RejectedRows
    WHERE run_id = @run_id AND table_name = @table_name;

    DECLARE @status NVARCHAR(20) =
        CASE WHEN @rows_read = @rows_loaded + @rows_rejected THEN N'Success' ELSE N'Mismatch' END;

    INSERT INTO etl.RunLog (run_id, table_name, rows_read, rows_loaded, rows_rejected, status)
    VALUES (@run_id, @table_name, @rows_read, @rows_loaded, @rows_rejected, @status);

    IF @status = N'Mismatch'
    BEGIN
        DECLARE @msg NVARCHAR(400) = CONCAT(N'Clean mismatch on ', @table_name,
            N': read ', @rows_read, N', clean ', @rows_loaded, N', rejected ', @rows_rejected, N'.');
        THROW 50004, @msg, 1;
    END;
END;
GO

CREATE OR ALTER VIEW etl.vw_RunSummary
AS
SELECT r.run_id,
       r.package_name,
       r.status                                   AS run_status,
       r.started_at,
       r.ended_at,
       DATEDIFF(SECOND, r.started_at, r.ended_at) AS duration_sec,
       l.table_name,
       l.rows_read,
       l.rows_loaded,
       l.rows_rejected,
       l.status                                   AS table_status,
       r.error_message
FROM etl.Run r
LEFT JOIN etl.RunLog l ON l.run_id = r.run_id;
GO

-- Check
SELECT name, type_desc FROM sys.objects
WHERE schema_id = SCHEMA_ID('etl') AND name IN ('usp_LogCleanTable', 'vw_RunSummary');
SELECT COL_LENGTH('etl.RunLog', 'rows_rejected') AS rows_rejected_column_exists;
