
USE FootballBI;
GO

IF COL_LENGTH('etl.RunLog', 'rows_inserted') IS NULL ALTER TABLE etl.RunLog ADD rows_inserted INT NULL;
IF COL_LENGTH('etl.RunLog', 'rows_updated')  IS NULL ALTER TABLE etl.RunLog ADD rows_updated  INT NULL;
GO

CREATE OR ALTER VIEW etl.vw_RunSummary
AS
SELECT r.run_id, r.package_name, r.status AS run_status, r.started_at, r.ended_at,
       DATEDIFF(SECOND, r.started_at, r.ended_at) AS duration_sec,
       l.table_name, l.rows_read, l.rows_loaded, l.rows_rejected,
       l.rows_inserted, l.rows_updated,
       l.status AS table_status, r.error_message
FROM etl.Run r
LEFT JOIN etl.RunLog l ON l.run_id = r.run_id;
GO

CREATE OR ALTER PROCEDURE etl.usp_LogDimLoad
    @run_id INT, @table_name SYSNAME,
    @rows_read INT, @rows_inserted INT, @rows_updated INT, @keys_missing INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @status NVARCHAR(20) = CASE WHEN @keys_missing = 0 THEN N'Success' ELSE N'Mismatch' END;

    INSERT INTO etl.RunLog (run_id, table_name, rows_read, rows_loaded, rows_rejected,
                            rows_inserted, rows_updated, status)
    VALUES (@run_id, @table_name, @rows_read, @rows_inserted + @rows_updated, 0,
            @rows_inserted, @rows_updated, @status);

    IF @status = N'Mismatch'
    BEGIN
        DECLARE @msg NVARCHAR(400) = CONCAT(@table_name, N': ', @keys_missing,
                                            N' source keys are missing from the dimension after the load.');
        THROW 50005, @msg, 1;
    END;
END;
GO

CREATE OR ALTER FUNCTION etl.fn_IsYouthTeam (@club_name NVARCHAR(200))
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN REGEXP_LIKE(@club_name,
        N'(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera'
      + N'|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$'
      + N'|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)', 'c')
        THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_DimCompetition @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    -- the complete list of codes, with the best available description
    SELECT c.competition_id, c.competition_name, c.competition_type, c.sub_type,
           c.country_name, c.confederation, CAST(0 AS BIT) AS is_seeded
    INTO #src
    FROM cln.competitions c;

    INSERT INTO #src
    SELECT x.code, x.code + N' (not in competitions file)', N'unknown', NULL, NULL, NULL, CAST(1 AS BIT)
    FROM (SELECT competition_id AS code FROM cln.games
          UNION SELECT competition_id FROM cln.appearances
          UNION SELECT competition_id FROM cln.player_valuations
          UNION SELECT domestic_competition_id FROM cln.clubs) x
    WHERE x.code IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM cln.competitions c WHERE c.competition_id = x.code);

    DECLARE @actions TABLE (act NVARCHAR(10));

    MERGE dw.DimCompetition AS t
    USING (SELECT *, CASE WHEN competition_id IN (N'GB1', N'ES1', N'IT1', N'L1', N'FR1')
                          THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_big5
           FROM #src) AS s
       ON t.competition_id = s.competition_id
    WHEN MATCHED AND EXISTS (   -- update only if something really changed (NULL-safe comparison)
            SELECT s.competition_name, s.competition_type, s.sub_type, s.country_name, s.confederation, s.is_big5, s.is_seeded
            EXCEPT
            SELECT t.competition_name, t.competition_type, t.sub_type, t.country_name, t.confederation, t.is_big5, t.is_seeded)
        THEN UPDATE SET competition_name = s.competition_name, competition_type = s.competition_type,
                        sub_type = s.sub_type, country_name = s.country_name, confederation = s.confederation,
                        is_big5 = s.is_big5, is_seeded = s.is_seeded, etl_run_id = @run_id
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (competition_id, competition_name, competition_type, sub_type, country_name,
                     confederation, is_big5, is_seeded, etl_run_id)
             VALUES (s.competition_id, s.competition_name, s.competition_type, s.sub_type, s.country_name,
                     s.confederation, s.is_big5, s.is_seeded, @run_id)
    OUTPUT $action INTO @actions;

    DECLARE @read INT = (SELECT COUNT(*) FROM #src),
            @ins  INT = (SELECT COUNT(*) FROM @actions WHERE act = 'INSERT'),
            @upd  INT = (SELECT COUNT(*) FROM @actions WHERE act = 'UPDATE'),
            @miss INT = (SELECT COUNT(*) FROM #src s WHERE NOT EXISTS
                            (SELECT 1 FROM dw.DimCompetition d WHERE d.competition_id = s.competition_id));
    EXEC etl.usp_LogDimLoad @run_id, N'DimCompetition', @read, @ins, @upd, @miss;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_DimClub @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT club_id INTO #ids FROM cln.clubs
    UNION SELECT from_club_id   FROM cln.transfers
    UNION SELECT to_club_id     FROM cln.transfers
    UNION SELECT club_id        FROM cln.player_valuations
    UNION SELECT home_club_id   FROM cln.games
    UNION SELECT away_club_id   FROM cln.games
    UNION SELECT player_club_id FROM cln.appearances
    UNION SELECT club_id        FROM cln.club_games
    UNION SELECT opponent_id    FROM cln.club_games
    UNION SELECT current_club_id FROM cln.players WHERE current_club_id IS NOT NULL;

    SELECT club_id, nm, prio INTO #names FROM (
              SELECT club_id,        club_name         AS nm, 1 AS prio FROM cln.clubs
    UNION ALL SELECT home_club_id,   home_club_name,          2         FROM cln.games
    UNION ALL SELECT away_club_id,   away_club_name,          2         FROM cln.games
    UNION ALL SELECT from_club_id,   from_club_name,          3         FROM cln.transfers
    UNION ALL SELECT to_club_id,     to_club_name,            3         FROM cln.transfers
    UNION ALL SELECT current_club_id, current_club_name,      4         FROM cln.players
    ) n
    WHERE nm IS NOT NULL AND nm <> N'';

    WITH ranked AS (
        SELECT club_id, nm,
               ROW_NUMBER() OVER (PARTITION BY club_id ORDER BY MIN(prio), COUNT(*) DESC, nm) AS rn
        FROM #names GROUP BY club_id, nm
    ),
    youth AS (   -- youth / reserve if ANY of its names says so (e.g. 'Barça U19' in transfers)
        SELECT club_id, MAX(CAST(etl.fn_IsYouthTeam(nm) AS INT)) AS is_youth
        FROM (SELECT DISTINCT club_id, nm FROM #names) d GROUP BY club_id
    ),
    big5 AS (    -- clubs that played a big-5 league game in season 2025/26
        SELECT home_club_id AS club_id FROM cln.games WHERE season = 2025 AND competition_id IN (N'GB1',N'ES1',N'IT1',N'L1',N'FR1')
        UNION
        SELECT away_club_id FROM cln.games WHERE season = 2025 AND competition_id IN (N'GB1',N'ES1',N'IT1',N'L1',N'FR1')
    )
    SELECT i.club_id,
           COALESCE(r.nm, N'Club #' + CAST(i.club_id AS NVARCHAR(10)))           AS club_name,
           CASE i.club_id WHEN 515 THEN N'Without club' WHEN 123 THEN N'Retired'
                          WHEN 75  THEN N'Unknown'      WHEN 2113 THEN N'Career break'
                          WHEN 12604 THEN N'Own youth'  ELSE N'Club' END         AS club_type,
           CAST(CASE WHEN i.club_id = 12604 OR y.is_youth = 1 THEN 1 ELSE 0 END AS BIT) AS is_youth_or_reserve,
           c.domestic_competition_id,
           dc.competition_name                                                  AS domestic_league_name,
           CAST(CASE WHEN b.club_id IS NOT NULL THEN 1 ELSE 0 END AS BIT)        AS is_big5_2025_26,
           CAST(CASE WHEN c.club_id IS NOT NULL THEN 1 ELSE 0 END AS BIT)        AS has_club_details,
           c.stadium_name, c.stadium_seats
    INTO #src
    FROM #ids i
    LEFT JOIN ranked r ON r.club_id = i.club_id AND r.rn = 1
    LEFT JOIN youth  y ON y.club_id = i.club_id
    LEFT JOIN big5   b ON b.club_id = i.club_id
    LEFT JOIN cln.clubs c ON c.club_id = i.club_id
    LEFT JOIN dw.DimCompetition dc ON dc.competition_id = c.domestic_competition_id;

    DECLARE @actions TABLE (act NVARCHAR(10));

    MERGE dw.DimClub AS t
    USING #src AS s
       ON t.club_id = s.club_id
    WHEN MATCHED AND EXISTS (
            SELECT s.club_name, s.club_type, s.is_youth_or_reserve, s.domestic_competition_id, s.domestic_league_name,
                   s.is_big5_2025_26, s.has_club_details, s.stadium_name, s.stadium_seats
            EXCEPT
            SELECT t.club_name, t.club_type, t.is_youth_or_reserve, t.domestic_competition_id, t.domestic_league_name,
                   t.is_big5_2025_26, t.has_club_details, t.stadium_name, t.stadium_seats)
        THEN UPDATE SET club_name = s.club_name, club_type = s.club_type, is_youth_or_reserve = s.is_youth_or_reserve,
                        domestic_competition_id = s.domestic_competition_id, domestic_league_name = s.domestic_league_name,
                        is_big5_2025_26 = s.is_big5_2025_26, has_club_details = s.has_club_details,
                        stadium_name = s.stadium_name, stadium_seats = s.stadium_seats,
                        etl_run_id = @run_id, updated_at = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (club_id, club_name, club_type, is_youth_or_reserve, domestic_competition_id, domestic_league_name,
                     is_big5_2025_26, has_club_details, stadium_name, stadium_seats, etl_run_id)
             VALUES (s.club_id, s.club_name, s.club_type, s.is_youth_or_reserve, s.domestic_competition_id, s.domestic_league_name,
                     s.is_big5_2025_26, s.has_club_details, s.stadium_name, s.stadium_seats, @run_id)
    OUTPUT $action INTO @actions;

    DECLARE @read INT = (SELECT COUNT(*) FROM #src),
            @ins  INT = (SELECT COUNT(*) FROM @actions WHERE act = 'INSERT'),
            @upd  INT = (SELECT COUNT(*) FROM @actions WHERE act = 'UPDATE'),
            @miss INT = (SELECT COUNT(*) FROM #src s WHERE NOT EXISTS
                            (SELECT 1 FROM dw.DimClub d WHERE d.club_id = s.club_id));
    EXEC etl.usp_LogDimLoad @run_id, N'DimClub', @read, @ins, @upd, @miss;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Load_DimPlayer @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @snapshot DATE = '2026-07-06';

    SELECT p.player_id, p.player_name, p.first_name, p.last_name, p.date_of_birth,
           p.country_of_birth, p.country_of_citizenship, p.position_group, p.sub_position,
           p.foot, p.height_cm, p.contract_expiration_date AS contract_end_date,
           CASE WHEN p.contract_expiration_date IS NULL       THEN N'Unknown'
                WHEN p.contract_expiration_date >= @snapshot  THEN N'Running'
                ELSE N'Expired' END                            AS contract_status,
           p.last_season, p.highest_market_value_eur, p.agent_name, p.image_url
    INTO #src
    FROM cln.players p;

    INSERT INTO #src (player_id, player_name, position_group, sub_position, contract_status)
    SELECT x.player_id,
           COALESCE((SELECT TOP (1) t.player_name FROM cln.transfers t
                     WHERE t.player_id = x.player_id AND t.player_name IS NOT NULL),
                    N'Player #' + CAST(x.player_id AS NVARCHAR(10))),
           N'Unknown', N'Unknown', N'Unknown'
    FROM (SELECT player_id FROM cln.appearances
          UNION SELECT player_id FROM cln.transfers
          UNION SELECT player_id FROM cln.player_valuations) x
    WHERE NOT EXISTS (SELECT 1 FROM cln.players p WHERE p.player_id = x.player_id);

    DECLARE @actions TABLE (act NVARCHAR(10));

    MERGE dw.DimPlayer AS t
    USING #src AS s
       ON t.player_id = s.player_id
    WHEN MATCHED AND EXISTS (
            SELECT s.player_name, s.first_name, s.last_name, s.date_of_birth, s.country_of_birth,
                   s.country_of_citizenship, s.position_group, s.sub_position, s.foot, s.height_cm,
                   s.contract_end_date, s.contract_status, s.last_season, s.highest_market_value_eur,
                   s.agent_name, s.image_url
            EXCEPT
            SELECT t.player_name, t.first_name, t.last_name, t.date_of_birth, t.country_of_birth,
                   t.country_of_citizenship, t.position_group, t.sub_position, t.foot, t.height_cm,
                   t.contract_end_date, t.contract_status, t.last_season, t.highest_market_value_eur,
                   t.agent_name, t.image_url)
        THEN UPDATE SET player_name = s.player_name, first_name = s.first_name, last_name = s.last_name,
                        date_of_birth = s.date_of_birth, country_of_birth = s.country_of_birth,
                        country_of_citizenship = s.country_of_citizenship, position_group = s.position_group,
                        sub_position = s.sub_position, foot = s.foot, height_cm = s.height_cm,
                        contract_end_date = s.contract_end_date, contract_status = s.contract_status,
                        last_season = s.last_season, highest_market_value_eur = s.highest_market_value_eur,
                        agent_name = s.agent_name, image_url = s.image_url,
                        etl_run_id = @run_id, updated_at = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (player_id, player_name, first_name, last_name, date_of_birth, country_of_birth,
                     country_of_citizenship, position_group, sub_position, foot, height_cm,
                     contract_end_date, contract_status, last_season, highest_market_value_eur,
                     agent_name, image_url, etl_run_id)
             VALUES (s.player_id, s.player_name, s.first_name, s.last_name, s.date_of_birth, s.country_of_birth,
                     s.country_of_citizenship, s.position_group, s.sub_position, s.foot, s.height_cm,
                     s.contract_end_date, s.contract_status, s.last_season, s.highest_market_value_eur,
                     s.agent_name, s.image_url, @run_id)
    OUTPUT $action INTO @actions;

    DECLARE @read INT = (SELECT COUNT(*) FROM #src),
            @ins  INT = (SELECT COUNT(*) FROM @actions WHERE act = 'INSERT'),
            @upd  INT = (SELECT COUNT(*) FROM @actions WHERE act = 'UPDATE'),
            @miss INT = (SELECT COUNT(*) FROM #src s WHERE NOT EXISTS
                            (SELECT 1 FROM dw.DimPlayer d WHERE d.player_id = s.player_id));
    EXEC etl.usp_LogDimLoad @run_id, N'DimPlayer', @read, @ins, @upd, @miss;
END;
GO

SELECT name, type_desc FROM sys.objects
WHERE schema_id = SCHEMA_ID('etl')
  AND name IN ('usp_LogDimLoad', 'fn_IsYouthTeam', 'usp_Load_DimCompetition', 'usp_Load_DimClub', 'usp_Load_DimPlayer')
ORDER BY name;
