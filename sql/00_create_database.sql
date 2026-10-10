
-- 1. Create the database (only if it does not exist yet)
IF DB_ID('FootballBI') IS NULL
    CREATE DATABASE FootballBI;
GO

-- 2. SIMPLE recovery: no need for log backups in a dev project,
--    and large loads won't fill the disk with log files
ALTER DATABASE FootballBI SET RECOVERY SIMPLE;
GO

USE FootballBI;
GO

-- 3. Create the 5 schemas (layers)
IF SCHEMA_ID('stg')  IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('etl')  IS NULL EXEC('CREATE SCHEMA etl');
IF SCHEMA_ID('dw')   IS NULL EXEC('CREATE SCHEMA dw');
IF SCHEMA_ID('mart') IS NULL EXEC('CREATE SCHEMA mart');
IF SCHEMA_ID('ml')   IS NULL EXEC('CREATE SCHEMA ml');
GO

-- 4. Checks: schemas, SQL Server edition, Agent status
SELECT name AS schema_name
FROM sys.schemas
WHERE name IN ('stg','etl','dw','mart','ml');

SELECT SERVERPROPERTY('ProductVersion') AS version,
       SERVERPROPERTY('Edition')        AS edition;

SELECT servicename, status_desc, startup_type_desc
FROM sys.dm_server_services;