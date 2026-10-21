USE FootballBI;
GO
SET LANGUAGE us_english;   -- so month and day names are in English whatever the server language
SET NOCOUNT ON;
GO


-- 1a. The Unknown date (used e.g. when a contract end date is missing)
IF NOT EXISTS (SELECT 1 FROM dw.DimDate WHERE date_key = -1)
INSERT INTO dw.DimDate (date_key, full_date, [year], [quarter], [month], month_name,
                        day_of_month, day_of_week, day_name, is_weekend,
                        season_start_year, season_label, season_month_no,
                        transfer_window, is_transfer_window)
VALUES (-1, '1900-01-01', 0, 0, 0, N'Unknown', 0, 0, N'Unknown', 0, 0, N'Unknown', 0, N'Unknown', 0);

DECLARE @start DATE = '1990-01-01',
        @end   DATE = '2035-12-31';

WITH numbers AS (
    SELECT TOP (DATEDIFF(DAY, @start, @end) + 1)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
),
days AS (
    SELECT DATEADD(DAY, n, @start) AS d FROM numbers
),
attrs AS (
    SELECT d,
           YEAR(d)  AS y,
           MONTH(d) AS m,
           -- football season July-June: Aug 2025 -> 2025 (2025/26), Mar 2026 -> 2025 (2025/26)
           CASE WHEN MONTH(d) >= 7 THEN YEAR(d) ELSE YEAR(d) - 1 END AS ssy,
           -- 1 = Monday ... 7 = Sunday (1900-01-01 was a Monday; independent of server settings)
           DATEDIFF(DAY, '19000101', d) % 7 + 1 AS dow
    FROM days
)
INSERT INTO dw.DimDate (date_key, full_date, [year], [quarter], [month], month_name,
                        day_of_month, day_of_week, day_name, is_weekend,
                        season_start_year, season_label, season_month_no,
                        transfer_window, is_transfer_window)
SELECT
    YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d)              AS date_key,        -- 20260706
    d                                                      AS full_date,
    y,
    DATEPART(QUARTER, d),
    m,
    DATENAME(MONTH, d),
    DAY(d),
    dow,
    DATENAME(WEEKDAY, d),
    CASE WHEN dow IN (6, 7) THEN 1 ELSE 0 END              AS is_weekend,
    ssy                                                    AS season_start_year,
    CONCAT(ssy, N'/', RIGHT(CAST(ssy + 1 AS VARCHAR(4)), 2)) AS season_label,  -- '2025/26'
    (m + 5) % 12 + 1                                       AS season_month_no,  -- July = 1 ... June = 12
    -- Approximation of the European windows: summer = June-August, winter = January
    CASE WHEN m IN (6, 7, 8) THEN N'Summer'
         WHEN m = 1          THEN N'Winter'
         ELSE N'Closed' END                                AS transfer_window,
    CASE WHEN m IN (1, 6, 7, 8) THEN 1 ELSE 0 END          AS is_transfer_window
FROM attrs
WHERE NOT EXISTS (SELECT 1 FROM dw.DimDate x WHERE x.full_date = attrs.d);
GO

/* ---------- 2. DimAgeBand (business rule: bands used to compare players fairly, KPI MV4) ---------- */
INSERT INTO dw.DimAgeBand (age_band_key, age_band, min_age, max_age, sort_order)
SELECT v.age_band_key, v.age_band, v.min_age, v.max_age, v.sort_order
FROM (VALUES
        (-1, N'Unknown', NULL, NULL, 99),
        ( 1, N'U21',        0,   20,  1),
        ( 2, N'21-24',     21,   24,  2),
        ( 3, N'25-28',     25,   28,  3),
        ( 4, N'29+',       29,   99,  4)
     ) v(age_band_key, age_band, min_age, max_age, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM dw.DimAgeBand x WHERE x.age_band_key = v.age_band_key);
GO

/* ---------- 3. DimTransferType (the output vocabulary of the classification rule) ----------
   transfer_subclass must match EXACTLY the labels produced by the rule in package 02
   (same texts as transfer_subclass in scripts/checklib.py).                         */
INSERT INTO dw.DimTransferType (transfer_type_key, transfer_class, transfer_subclass, is_permanent, sort_order)
SELECT v.k, v.cls, v.sub, v.perm, v.so
FROM (VALUES
        (-1, N'unknown',     N'Unknown (not classified)',          0, 99),
        ( 1, N'paid',        N'paid',                               1,  1),
        ( 2, N'loan',        N'loan',                               0,  2),
        ( 3, N'loan',        N'loan with fee',                      0,  3),
        ( 4, N'end of loan', N'end of loan',                        0,  4),
        ( 5, N'free',        N'free: club to club',                 1,  5),
        ( 6, N'free',        N'free: free agent signed',            1,  6),
        ( 7, N'free',        N'free: released / contract ended',    1,  7),
        ( 8, N'free',        N'free: retired',                      1,  8),
        ( 9, N'internal',    N'internal: youth/reserve move',       0,  9),
        (10, N'unknown',     N'unknown club',                       0, 10),
        (11, N'unknown',     N'unknown: fee not disclosed',         0, 11)
     ) v(k, cls, sub, perm, so)
WHERE NOT EXISTS (SELECT 1 FROM dw.DimTransferType x WHERE x.transfer_type_key = v.k);
GO

/* ---------- 4. Unknown member (-1) in the dimensions that SSIS fills ----------
   These tables use IDENTITY keys (1, 2, 3...). To force the value -1 we switch
   IDENTITY_INSERT on for one insert, then off again.
   Note: Transfermarkt also has a REAL pseudo-club called "Unknown" (club_id 75).
   That one gets a normal row from the ETL; key -1 means "no match found at all". */

IF NOT EXISTS (SELECT 1 FROM dw.DimPlayer WHERE player_key = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimPlayer ON;
    INSERT INTO dw.DimPlayer (player_key, player_id, player_name, position_group, sub_position, contract_status)
    VALUES (-1, -1, N'Unknown', N'Unknown', N'Unknown', N'Unknown');
    SET IDENTITY_INSERT dw.DimPlayer OFF;
END;

IF NOT EXISTS (SELECT 1 FROM dw.DimClub WHERE club_key = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimClub ON;
    INSERT INTO dw.DimClub (club_key, club_id, club_name, club_type, is_youth_or_reserve,
                            is_big5_2025_26, has_club_details)
    VALUES (-1, -1, N'Unknown', N'Unknown', 0, 0, 0);
    SET IDENTITY_INSERT dw.DimClub OFF;
END;

IF NOT EXISTS (SELECT 1 FROM dw.DimCompetition WHERE competition_key = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimCompetition ON;
    INSERT INTO dw.DimCompetition (competition_key, competition_id, competition_name, competition_type,
                                   is_big5, is_seeded)
    VALUES (-1, N'UNK', N'Unknown', N'unknown', 0, 1);
    SET IDENTITY_INSERT dw.DimCompetition OFF;
END;
GO

/* ---------- 5. Checks ---------- */

-- 5a. Row counts. Expected: DimDate 16,802 | DimAgeBand 5 | DimTransferType 12 | others 1 (the -1 row)
SELECT 'DimDate' AS table_name, COUNT(*) AS rows FROM dw.DimDate
UNION ALL SELECT 'DimAgeBand',      COUNT(*) FROM dw.DimAgeBand
UNION ALL SELECT 'DimTransferType', COUNT(*) FROM dw.DimTransferType
UNION ALL SELECT 'DimPlayer',       COUNT(*) FROM dw.DimPlayer
UNION ALL SELECT 'DimClub',         COUNT(*) FROM dw.DimClub
UNION ALL SELECT 'DimCompetition',  COUNT(*) FROM dw.DimCompetition;

-- 5b. Spot-check DimDate on dates you know
SELECT date_key, full_date, day_name, month_name, season_label, season_month_no, transfer_window
FROM dw.DimDate
WHERE date_key IN (-1, 20190223, 20250830, 20260115, 20260706)
ORDER BY date_key;

-- 5c. The two small reference tables in full
SELECT * FROM dw.DimAgeBand      ORDER BY sort_order;
SELECT * FROM dw.DimTransferType ORDER BY sort_order;
