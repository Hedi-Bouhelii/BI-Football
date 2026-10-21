USE FootballBI;
GO

CREATE OR ALTER PROCEDURE etl.usp_CheckUpstream
    @upstream_package NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @run_id INT, @status NVARCHAR(20), @msg NVARCHAR(400);

    SELECT TOP (1) @run_id = run_id, @status = status
    FROM etl.Run
    WHERE package_name = @upstream_package
    ORDER BY run_id DESC;

    IF @run_id IS NULL
    BEGIN
        SET @msg = CONCAT(N'Upstream check failed: ', @upstream_package, N' has never run.');
        THROW 50010, @msg, 1;
    END;

    IF @status <> N'Success'
    BEGIN
        SET @msg = CONCAT(N'Upstream check failed: the last run of ', @upstream_package,
                          N' (run ', @run_id, N') has status "', @status,
                          N'". Run it again completely, then run this package.');
        THROW 50011, @msg, 1;
    END;
END;
GO

UPDATE etl.Run
   SET status = N'Aborted', ended_at = COALESCE(ended_at, started_at),
       error_message = COALESCE(error_message, N'Interrupted before SQL End run (closed manually).')
 WHERE status = N'Running'
   AND started_at < DATEADD(MINUTE, -30, SYSDATETIME());   -- leave a run that is genuinely running now
GO
EXEC etl.usp_CheckUpstream N'01_Extract_Staging';
SELECT 'Upstream check passed for 01_Extract_Staging' AS result;

SELECT run_id, package_name, started_at, ended_at, status
FROM etl.Run ORDER BY run_id DESC;
