USE FootballBI;
GO

/* ---------- 0. Logging: count the rows that needed an Unknown (-1) key ---------- */
IF COL_LENGTH('etl.RunLog', 'rows_unknown_key') IS NULL
    ALTER TABLE etl.RunLog ADD rows_unknown_key INT NULL;
GO

CREATE OR ALTER VIEW etl.vw_RunSummary
AS
SELECT r.run_id, r.package_name, r.status AS run_status, r.started_at, r.ended_at,
       DATEDIFF(SECOND, r.started_at, r.ended_at) AS duration_sec,
       l.table_name, l.rows_read, l.rows_loaded, l.rows_rejected,
       l.rows_inserted, l.rows_updated, l.rows_unknown_key,
       l.status AS table_status, r.error_message
FROM etl.Run r
LEFT JOIN etl.RunLog l ON l.run_id = r.run_id;
GO

CREATE OR ALTER FUNCTION etl.fn_AgeBandKey (@date_of_birth DATE, @on_date DATE)
RETURNS TABLE
AS
RETURN
SELECT CAST(CASE WHEN x.age IS NULL OR x.age < 0 THEN -1    -- no birth date, or event before birth
                                                              -- (ages under 12 are real: academy moves)
                 WHEN x.age < 21  THEN 1
                 WHEN x.age <= 24 THEN 2
                 WHEN x.age <= 28 THEN 3
                 ELSE 4 END AS SMALLINT) AS age_band_key,
       x.age
FROM (SELECT DATEDIFF(YEAR, @date_of_birth, @on_date)
             - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, @date_of_birth, @on_date), @date_of_birth) > @on_date
                    THEN 1 ELSE 0 END AS age) x;    
GO

CREATE OR ALTER PROCEDURE etl.usp_LogFactLoad
    @run_id INT, @table_name SYSNAME
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @read INT, @loaded INT, @unknown INT;

    IF @table_name = N'FactValuation'
    BEGIN
        SET @read = (SELECT COUNT(*) FROM cln.player_valuations);
        SELECT @loaded  = COUNT(*),
               @unknown = SUM(CASE WHEN -1 IN (date_key, player_key, club_key, competition_key, age_band_key) THEN 1 ELSE 0 END)
        FROM dw.FactValuation WHERE etl_run_id = @run_id;
    END
    ELSE IF @table_name = N'FactTransfer'
    BEGIN
        SET @read = (SELECT COUNT(*) FROM cln.transfers);
        SELECT @loaded  = COUNT(*),
               @unknown = SUM(CASE WHEN -1 IN (transfer_date_key, player_key, from_club_key, to_club_key,
                                               transfer_type_key, age_band_key) THEN 1 ELSE 0 END)
        FROM dw.FactTransfer WHERE etl_run_id = @run_id;
    END
    ELSE IF @table_name = N'FactAppearance'
    BEGIN
        SET @read = (SELECT COUNT(*) FROM cln.appearances);
        SELECT @loaded  = COUNT(*),
               @unknown = SUM(CASE WHEN -1 IN (date_key, player_key, club_key, opponent_club_key,
                                               competition_key, age_band_key) THEN 1 ELSE 0 END)
        FROM dw.FactAppearance WHERE etl_run_id = @run_id;
    END
    ELSE IF @table_name = N'FactContractSnapshot'
    BEGIN
        SET @read = (SELECT COUNT(*) FROM cln.players);
        SELECT @loaded  = COUNT(*),
               @unknown = SUM(CASE WHEN -1 IN (player_key, club_key, contract_end_date_key, age_band_key) THEN 1 ELSE 0 END)
        FROM dw.FactContractSnapshot WHERE etl_run_id = @run_id AND snapshot_date_key = 20260706;
    END
    ELSE
    BEGIN
        THROW 50007, N'usp_LogFactLoad: unknown fact table name.', 1;
    END;

    DECLARE @status NVARCHAR(20) = CASE WHEN @read = @loaded THEN N'Success' ELSE N'Mismatch' END;

    INSERT INTO etl.RunLog (run_id, table_name, rows_read, rows_loaded, rows_rejected,
                            rows_inserted, rows_updated, rows_unknown_key, status)
    VALUES (@run_id, @table_name, @read, @loaded, @read - @loaded, @loaded, 0, ISNULL(@unknown, 0), @status);

    IF @status = N'Mismatch'
    BEGIN
        DECLARE @msg NVARCHAR(400) = CONCAT(@table_name, N': read ', @read, N' clean rows but loaded ', @loaded, N'.');
        THROW 50006, @msg, 1;
    END;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_FactValuation @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    TRUNCATE TABLE dw.FactValuation;

    INSERT INTO dw.FactValuation WITH (TABLOCK)
           (date_key, player_key, club_key, competition_key, age_band_key, market_value_eur, etl_run_id)
    SELECT COALESCE(dd.date_key, -1),
           COALESCE(dp.player_key, -1),
           COALESCE(dcl.club_key, -1),
           COALESCE(dco.competition_key, -1),       -- NULL competition = club outside the covered leagues
           ab.age_band_key,
           v.market_value_eur,
           @run_id
    FROM cln.player_valuations v
    LEFT JOIN dw.DimDate        dd  ON dd.full_date       = v.valuation_date
    LEFT JOIN dw.DimPlayer      dp  ON dp.player_id       = v.player_id
    LEFT JOIN dw.DimClub        dcl ON dcl.club_id        = v.club_id
    LEFT JOIN dw.DimCompetition dco ON dco.competition_id = v.competition_id
    CROSS APPLY etl.fn_AgeBandKey(dp.date_of_birth, v.valuation_date) ab;

    EXEC etl.usp_LogFactLoad @run_id, N'FactValuation';
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_FactAppearance @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    TRUNCATE TABLE dw.FactAppearance;

    INSERT INTO dw.FactAppearance WITH (TABLOCK)
           (date_key, game_id, player_key, club_key, opponent_club_key, competition_key, age_band_key,
            minutes_played, goals, assists, yellow_cards, red_cards,
            is_starter, is_home, team_goals_for, team_goals_against, etl_run_id)
    SELECT COALESCE(dd.date_key, -1),
           a.game_id,                                -- degenerate dimension
           COALESCE(dp.player_key, -1),
           COALESCE(dcl.club_key, -1),
           COALESCE(opp.club_key, -1),               -- DimClub used a second time (role-playing)
           COALESCE(dco.competition_key, -1),
           ab.age_band_key,
           a.minutes_played, a.goals, a.assists, a.yellow_cards, a.red_cards,
           lu.is_starter,                            -- NULL = no line-up recorded for that game
           cg.is_home, cg.own_goals, cg.opponent_goals,
           @run_id
    FROM cln.appearances a
    LEFT JOIN cln.club_games    cg  ON cg.game_id  = a.game_id AND cg.club_id = a.player_club_id
    LEFT JOIN cln.game_lineups  lu  ON lu.game_id  = a.game_id AND lu.player_id = a.player_id
    LEFT JOIN dw.DimDate        dd  ON dd.full_date       = a.game_date
    LEFT JOIN dw.DimPlayer      dp  ON dp.player_id       = a.player_id
    LEFT JOIN dw.DimClub        dcl ON dcl.club_id        = a.player_club_id
    LEFT JOIN dw.DimClub        opp ON opp.club_id        = cg.opponent_id
    LEFT JOIN dw.DimCompetition dco ON dco.competition_id = a.competition_id
    CROSS APPLY etl.fn_AgeBandKey(dp.date_of_birth, a.game_date) ab;

    EXEC etl.usp_LogFactLoad @run_id, N'FactAppearance';
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_FactContractSnapshot @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @snapshot DATE = '2026-07-06',
            @snapshot_key INT = 20260706;

    BEGIN TRANSACTION;

    DELETE FROM dw.FactContractSnapshot WHERE snapshot_date_key = @snapshot_key;

    INSERT INTO dw.FactContractSnapshot
           (snapshot_date_key, player_key, club_key, contract_end_date_key, age_band_key,
            market_value_eur, months_to_expiry, is_expiring_12m, is_active_big5, etl_run_id)
    SELECT @snapshot_key,
           COALESCE(dp.player_key, -1),
           COALESCE(dcl.club_key, -1),
           COALESCE(de.date_key, -1),                -- -1 = contract end date unknown (DimDate used twice)
           ab.age_band_key,
           p.market_value_eur,
           CASE WHEN p.contract_expiration_date IS NULL THEN NULL
                ELSE DATEDIFF(MONTH, @snapshot, p.contract_expiration_date)
                     - CASE WHEN DAY(p.contract_expiration_date) < DAY(@snapshot) THEN 1 ELSE 0 END
           END,                                      -- KPI C1: full months left (negative = expired)
           CAST(CASE WHEN p.contract_expiration_date >= @snapshot
                      AND p.contract_expiration_date <= DATEADD(MONTH, 12, @snapshot)
                     THEN 1 ELSE 0 END AS BIT),      -- input to KPI C2
           CAST(CASE WHEN dcl.is_big5_2025_26 = 1
                      AND p.last_season >= 2025      -- retired players keep their last club: exclude them
                     THEN 1 ELSE 0 END AS BIT),
           @run_id
    FROM cln.players p
    LEFT JOIN dw.DimPlayer dp  ON dp.player_id = p.player_id
    LEFT JOIN dw.DimClub   dcl ON dcl.club_id  = p.current_club_id
    LEFT JOIN dw.DimDate   de  ON de.full_date = p.contract_expiration_date
    CROSS APPLY etl.fn_AgeBandKey(p.date_of_birth, @snapshot) ab;

    COMMIT;

    EXEC etl.usp_LogFactLoad @run_id, N'FactContractSnapshot';
END;
GO

CREATE OR ALTER VIEW etl.vw_Src_FactTransfer
AS
SELECT CAST(t.player_id    AS INT)            AS player_id,
       CAST(t.from_club_id AS INT)            AS from_club_id,
       CAST(t.to_club_id   AS INT)            AS to_club_id,
       CAST(t.transfer_subclass AS NVARCHAR(50)) AS transfer_subclass,
       CAST(CASE WHEN t.transfer_date BETWEEN '1990-01-01' AND '2035-12-31'
                 THEN YEAR(t.transfer_date) * 10000 + MONTH(t.transfer_date) * 100 + DAY(t.transfer_date)
                 ELSE -1 END AS INT)          AS transfer_date_key,
       ab.age_band_key,
       t.fee_eur,
       t.market_value_eur,
       CAST(CASE WHEN t.fee_eur > 0 AND t.market_value_eur > 0
                 THEN t.fee_eur / t.market_value_eur END AS DECIMAL(9,4)) AS fee_to_value_ratio,  -- paid moves only
       CAST(COALESCE(t.is_free_departure, 0) AS BIT) AS is_free_departure,
       CAST(COALESCE(t.is_future_dated, 0)   AS BIT) AS is_future_dated
FROM cln.transfers t
LEFT JOIN cln.players p ON p.player_id = t.player_id
CROSS APPLY etl.fn_AgeBandKey(p.date_of_birth, t.transfer_date) ab;
GO

SELECT name, type_desc FROM sys.objects
WHERE schema_id = SCHEMA_ID('etl')
  AND name IN ('fn_AgeBandKey', 'usp_LogFactLoad', 'usp_Load_FactValuation', 'usp_Load_FactAppearance',
               'usp_Load_FactContractSnapshot', 'vw_Src_FactTransfer')
ORDER BY name;

SELECT COUNT(*) AS source_rows_for_FactTransfer FROM etl.vw_Src_FactTransfer;   -- expect 175,165
SELECT TOP 5 * FROM etl.vw_Src_FactTransfer WHERE fee_eur > 50000000 ORDER BY fee_eur DESC;
