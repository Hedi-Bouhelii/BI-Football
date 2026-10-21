USE FootballBI;
GO


IF OBJECT_ID('etl.Run') IS NULL
CREATE TABLE etl.Run (
    run_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Run PRIMARY KEY,
    package_name   NVARCHAR(100)  NOT NULL,
    started_at     DATETIME2(0)   NOT NULL CONSTRAINT DF_Run_started DEFAULT SYSDATETIME(),
    ended_at       DATETIME2(0)   NULL,
    status         NVARCHAR(20)   NOT NULL CONSTRAINT DF_Run_status  DEFAULT N'Running',
    error_message  NVARCHAR(2000) NULL,
    run_by         NVARCHAR(128)  NOT NULL CONSTRAINT DF_Run_by      DEFAULT SUSER_SNAME(),
    host_name      NVARCHAR(128)  NULL     CONSTRAINT DF_Run_host    DEFAULT HOST_NAME()
);
GO

IF OBJECT_ID('etl.RunLog') IS NULL
CREATE TABLE etl.RunLog (
    run_log_id   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RunLog PRIMARY KEY,
    run_id       INT           NOT NULL CONSTRAINT FK_RunLog_Run REFERENCES etl.Run(run_id),
    table_name   NVARCHAR(128) NOT NULL,
    rows_read    INT           NOT NULL,   -- counted by SSIS while reading the file
    rows_loaded  INT           NOT NULL,   -- counted in SQL Server after the load
    status       NVARCHAR(20)  NOT NULL,   -- Success | Mismatch
    logged_at    DATETIME2(0)  NOT NULL CONSTRAINT DF_RunLog_logged DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('etl.RejectedRows') IS NULL
CREATE TABLE etl.RejectedRows (
    rejected_id  BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RejectedRows PRIMARY KEY,
    run_id       INT           NOT NULL CONSTRAINT FK_Rejected_Run REFERENCES etl.Run(run_id),
    table_name   NVARCHAR(128) NOT NULL,
    natural_key  NVARCHAR(200) NULL,       -- e.g. player_id, or player_id + date
    column_name  NVARCHAR(128) NULL,
    bad_value    NVARCHAR(500) NULL,
    reason_code  NVARCHAR(50)  NOT NULL,   -- e.g. DQ10_BAD_DATE (see quality_issues.csv)
    reason       NVARCHAR(500) NULL,
    rejected_at  DATETIME2(0)  NOT NULL CONSTRAINT DF_Rejected_at DEFAULT SYSDATETIME()
);
GO


CREATE OR ALTER PROCEDURE etl.usp_StartRun
    @package_name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO etl.Run (package_name) VALUES (@package_name);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS run_id;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_LogTable
    @run_id     INT,
    @table_name SYSNAME,
    @rows_read  INT
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID(N'stg.' + QUOTENAME(@table_name)) IS NULL
        THROW 50001, N'usp_LogTable: unknown staging table.', 1;

    DECLARE @rows_loaded INT;
    DECLARE @sql NVARCHAR(400) =
        N'SELECT @n = COUNT(*) FROM stg.' + QUOTENAME(@table_name) +
        N' WHERE etl_run_id = @r;';
    EXEC sp_executesql @sql, N'@n INT OUTPUT, @r INT',
                       @n = @rows_loaded OUTPUT, @r = @run_id;

    DECLARE @status NVARCHAR(20) =
        CASE WHEN @rows_loaded = @rows_read THEN N'Success' ELSE N'Mismatch' END;

    INSERT INTO etl.RunLog (run_id, table_name, rows_read, rows_loaded, status)
    VALUES (@run_id, @table_name, @rows_read, @rows_loaded, @status);

    IF @status = N'Mismatch'
    BEGIN
        DECLARE @msg NVARCHAR(400) = CONCAT(N'Row count mismatch on stg.', @table_name,
                                            N': read ', @rows_read, N', loaded ', @rows_loaded, N'.');
        THROW 50002, @msg, 1;
    END;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_EndRun
    @run_id        INT,
    @status        NVARCHAR(20),
    @error_message NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE etl.Run
       SET ended_at      = SYSDATETIME(),
           status        = @status,
           error_message = COALESCE(error_message, @error_message)
     WHERE run_id = @run_id;
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
       l.status                                   AS table_status,
       r.error_message
FROM etl.Run r
LEFT JOIN etl.RunLog l ON l.run_id = r.run_id;
GO


SELECT name, type_desc
FROM sys.objects
WHERE schema_id = SCHEMA_ID('etl')
  AND type IN ('U','P','V')          
ORDER BY type_desc, name;
