
USE FootballBI;
GO

DROP PROCEDURE IF EXISTS etl.usp_Clean_Competitions;
DROP PROCEDURE IF EXISTS etl.usp_Clean_ClubGames;
DROP PROCEDURE IF EXISTS etl.usp_Clean_Transfers;
GO

ALTER DATABASE FootballBI SET COMPATIBILITY_LEVEL = 170;
GO

IF COL_LENGTH('cln.transfers', 'transfer_season_label') IS NULL
    ALTER TABLE cln.transfers ADD transfer_season_label NVARCHAR(5) NULL;
GO

CREATE OR ALTER PROCEDURE etl.usp_Clean_Clubs @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    TRUNCATE TABLE cln.clubs;

    SELECT v.*, s.club_id AS key_txt,
           CASE WHEN v.club_id IS NULL   THEN N'BAD_KEY'
                WHEN v.club_name IS NULL THEN N'MISSING_VALUE'
                WHEN ROW_NUMBER() OVER (PARTITION BY v.club_id ORDER BY (SELECT NULL)) > 1 THEN N'DUPLICATE'
           END AS reject_code
    INTO #c
    FROM stg.clubs s
    CROSS APPLY (SELECT
        TRY_CONVERT(INT, s.club_id)                    AS club_id,
        NULLIF(TRIM(s.[name]), N'')                     AS club_name,
        NULLIF(TRIM(s.domestic_competition_id), N'')    AS domestic_competition_id,
        TRY_CONVERT(SMALLINT, s.squad_size)             AS squad_size,
        TRY_CONVERT(DECIMAL(4,1), s.average_age)        AS average_age,
        NULLIF(TRIM(s.stadium_name), N'')               AS stadium_name,
        TRY_CONVERT(INT, s.stadium_seats)               AS stadium_seats,
        TRY_CONVERT(SMALLINT, s.last_season)            AS last_season) v;

    INSERT INTO etl.RejectedRows (run_id, table_name, natural_key, reason_code, reason)
    SELECT @run_id, N'clubs', key_txt, reject_code, N'Club row rejected: ' + reject_code
    FROM #c WHERE reject_code IS NOT NULL;

    INSERT INTO cln.clubs WITH (TABLOCK)
          (club_id, club_name, domestic_competition_id, squad_size, average_age,
           stadium_name, stadium_seats, last_season, etl_run_id)
    SELECT club_id, club_name, domestic_competition_id, squad_size, average_age,
           stadium_name, stadium_seats, last_season, @run_id
    FROM #c WHERE reject_code IS NULL;

    EXEC etl.usp_LogCleanTable @run_id, N'clubs';
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Clean_Games @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    TRUNCATE TABLE cln.games;

    SELECT v.*, s.game_id AS key_txt,
           CASE WHEN v.game_id IS NULL THEN N'BAD_KEY'
                WHEN v.game_date IS NULL OR v.season IS NULL OR v.competition_id IS NULL
                  OR v.home_club_id IS NULL OR v.away_club_id IS NULL THEN N'MISSING_VALUE'
                WHEN (s.home_club_goals IS NOT NULL AND v.home_club_goals IS NULL)
                  OR (s.away_club_goals IS NOT NULL AND v.away_club_goals IS NULL) THEN N'CONVERSION_FAILED'
                WHEN ROW_NUMBER() OVER (PARTITION BY v.game_id ORDER BY (SELECT NULL)) > 1 THEN N'DUPLICATE'
           END AS reject_code
    INTO #c
    FROM stg.games s
    CROSS APPLY (SELECT
        TRY_CONVERT(INT, s.game_id)              AS game_id,
        NULLIF(TRIM(s.competition_id), N'')      AS competition_id,
        TRY_CONVERT(SMALLINT, s.season)          AS season,
        TRY_CONVERT(DATE, s.[date])              AS game_date,
        TRY_CONVERT(INT, s.home_club_id)         AS home_club_id,
        TRY_CONVERT(INT, s.away_club_id)         AS away_club_id,
        TRY_CONVERT(TINYINT, s.home_club_goals)  AS home_club_goals,
        TRY_CONVERT(TINYINT, s.away_club_goals)  AS away_club_goals,
        NULLIF(TRIM(s.home_club_name), N'')      AS home_club_name,
        NULLIF(TRIM(s.away_club_name), N'')      AS away_club_name,
        NULLIF(TRIM(s.competition_type), N'')    AS competition_type) v;

    INSERT INTO etl.RejectedRows (run_id, table_name, natural_key, reason_code, reason)
    SELECT @run_id, N'games', key_txt, reject_code, N'Game row rejected: ' + reject_code
    FROM #c WHERE reject_code IS NOT NULL;

    INSERT INTO cln.games WITH (TABLOCK)
          (game_id, competition_id, season, game_date, home_club_id, away_club_id,
           home_club_goals, away_club_goals, home_club_name, away_club_name, competition_type, etl_run_id)
    SELECT game_id, competition_id, season, game_date, home_club_id, away_club_id,
           home_club_goals, away_club_goals, home_club_name, away_club_name, competition_type, @run_id
    FROM #c WHERE reject_code IS NULL;

    EXEC etl.usp_LogCleanTable @run_id, N'games';
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Clean_Appearances @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    TRUNCATE TABLE cln.appearances;

    SELECT v.*, s.appearance_id AS key_txt,
           CASE WHEN v.game_id IS NULL OR v.player_id IS NULL THEN N'BAD_KEY'
                WHEN v.player_club_id IS NULL OR v.game_date IS NULL OR v.competition_id IS NULL THEN N'MISSING_VALUE'
                WHEN v.minutes_played IS NULL OR v.goals IS NULL OR v.assists IS NULL
                  OR v.yellow_cards IS NULL OR v.red_cards IS NULL THEN N'CONVERSION_FAILED'
                WHEN v.minutes_played NOT BETWEEN 0 AND 150 THEN N'OUT_OF_RANGE'
                WHEN ROW_NUMBER() OVER (PARTITION BY v.game_id, v.player_id ORDER BY (SELECT NULL)) > 1 THEN N'DUPLICATE'
           END AS reject_code
    INTO #c
    FROM stg.appearances s
    CROSS APPLY (SELECT
        TRY_CONVERT(INT, s.game_id)            AS game_id,
        TRY_CONVERT(INT, s.player_id)          AS player_id,
        TRY_CONVERT(INT, s.player_club_id)     AS player_club_id,
        TRY_CONVERT(DATE, s.[date])            AS game_date,
        NULLIF(TRIM(s.competition_id), N'')    AS competition_id,
        TRY_CONVERT(SMALLINT, s.minutes_played) AS minutes_played,
        TRY_CONVERT(TINYINT, s.goals)          AS goals,
        TRY_CONVERT(TINYINT, s.assists)        AS assists,
        TRY_CONVERT(TINYINT, s.yellow_cards)   AS yellow_cards,
        TRY_CONVERT(TINYINT, s.red_cards)      AS red_cards) v;

    INSERT INTO etl.RejectedRows (run_id, table_name, natural_key, reason_code, reason)
    SELECT @run_id, N'appearances', key_txt, reject_code, N'Appearance row rejected: ' + reject_code
    FROM #c WHERE reject_code IS NOT NULL;

    INSERT INTO cln.appearances WITH (TABLOCK)
          (game_id, player_id, player_club_id, game_date, competition_id,
           minutes_played, goals, assists, yellow_cards, red_cards, etl_run_id)
    SELECT game_id, player_id, player_club_id, game_date, competition_id,
           minutes_played, goals, assists, yellow_cards, red_cards, @run_id
    FROM #c WHERE reject_code IS NULL;

    EXEC etl.usp_LogCleanTable @run_id, N'appearances';
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Clean_GameLineups @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    TRUNCATE TABLE cln.game_lineups;

    SELECT v.*, CONCAT(s.game_id, N'_', s.player_id) AS key_txt,
           CASE WHEN v.game_id IS NULL OR v.player_id IS NULL THEN N'BAD_KEY'
                WHEN v.club_id IS NULL OR v.is_starter IS NULL THEN N'MISSING_VALUE'
                -- duplicates: keep the starting line-up row if there is one
                WHEN ROW_NUMBER() OVER (PARTITION BY v.game_id, v.player_id ORDER BY v.is_starter DESC) > 1 THEN N'DUPLICATE'
           END AS reject_code
    INTO #c
    FROM stg.game_lineups s
    CROSS APPLY (SELECT
        TRY_CONVERT(INT, s.game_id)    AS game_id,
        TRY_CONVERT(INT, s.player_id)  AS player_id,
        TRY_CONVERT(INT, s.club_id)    AS club_id,
        CASE TRIM(s.[type]) WHEN N'starting_lineup' THEN CAST(1 AS BIT)
                            WHEN N'substitutes'     THEN CAST(0 AS BIT) END AS is_starter,
        CASE WHEN NULLIF(TRIM(s.position), N'') IS NULL THEN NULL
             ELSE UPPER(LEFT(TRIM(s.position), 1)) + SUBSTRING(TRIM(s.position), 2, 50) END AS position,
        CASE WHEN TRIM(s.team_captain) = N'1' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_captain) v;

    INSERT INTO etl.RejectedRows (run_id, table_name, natural_key, reason_code, reason)
    SELECT @run_id, N'game_lineups', key_txt, reject_code, N'Line-up row rejected: ' + reject_code
    FROM #c WHERE reject_code IS NOT NULL;

    INSERT INTO cln.game_lineups WITH (TABLOCK)
          (game_id, player_id, club_id, is_starter, position, is_captain, etl_run_id)
    SELECT game_id, player_id, club_id, is_starter, position, is_captain, @run_id
    FROM #c WHERE reject_code IS NULL;

    EXEC etl.usp_LogCleanTable @run_id, N'game_lineups';
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Clean_PlayerValuations @run_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    TRUNCATE TABLE cln.player_valuations;

    SELECT v.*, CONCAT(s.player_id, N'_', s.[date]) AS key_txt,
           CASE WHEN v.player_id IS NULL OR v.valuation_date IS NULL THEN N'BAD_KEY'
                WHEN v.market_value_eur IS NULL OR v.club_id IS NULL THEN N'MISSING_VALUE'
                WHEN v.market_value_eur < 0 THEN N'OUT_OF_RANGE'
                WHEN ROW_NUMBER() OVER (PARTITION BY v.player_id, v.valuation_date ORDER BY (SELECT NULL)) > 1 THEN N'DUPLICATE'
           END AS reject_code
    INTO #c
    FROM stg.player_valuations s
    CROSS APPLY (SELECT
        TRY_CONVERT(INT, s.player_id)                         AS player_id,
        TRY_CONVERT(DATE, s.[date])                           AS valuation_date,
        TRY_CONVERT(BIGINT, s.market_value_in_eur)            AS market_value_eur,
        TRY_CONVERT(INT, s.current_club_id)                   AS club_id,
        NULLIF(TRIM(s.player_club_domestic_competition_id), N'') AS competition_id) v;

    INSERT INTO etl.RejectedRows (run_id, table_name, natural_key, reason_code, reason)
    SELECT @run_id, N'player_valuations', key_txt, reject_code, N'Valuation row rejected: ' + reject_code
    FROM #c WHERE reject_code IS NOT NULL;

    INSERT INTO cln.player_valuations WITH (TABLOCK)
          (player_id, valuation_date, market_value_eur, club_id, competition_id, etl_run_id)
    SELECT player_id, valuation_date, market_value_eur, club_id, competition_id, @run_id
    FROM #c WHERE reject_code IS NULL;

    EXEC etl.usp_LogCleanTable @run_id, N'player_valuations';
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_ClassifyTransfers
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    -- Special Transfermarkt pseudo-clubs (dataset check P4.8)
    DECLARE @without_club INT = 515, @retired INT = 123, @unknown INT = 75,
            @career_break INT = 2113, @own_youth INT = 12604;
    DECLARE @snapshot DATE = '2026-07-06';
    -- Youth / reserve team names (same regular expression as checklib.YOUTH_REGEX)
    DECLARE @youth NVARCHAR(400) =
        N'(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera'
      + N'|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$'
      + N'|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)';

    WITH o AS (       -- step 1a: same-day ordering hint + youth flags
        SELECT t.player_id, t.transfer_date, t.from_club_id, t.to_club_id, t.fee_eur,
               CASE WHEN t.from_club_id = prev.to_club_id THEN 0 ELSE 1 END                AS same_day_order,
               CASE WHEN REGEXP_LIKE(t.from_club_name, @youth, 'c') THEN 1 ELSE 0 END       AS from_youth,
               CASE WHEN REGEXP_LIKE(t.to_club_name,   @youth, 'c') THEN 1 ELSE 0 END       AS to_youth
        FROM cln.transfers t
        OUTER APPLY (SELECT TOP (1) t2.to_club_id            -- club the player was at before that day
                     FROM cln.transfers t2
                     WHERE t2.player_id = t.player_id AND t2.transfer_date < t.transfer_date
                     ORDER BY t2.transfer_date DESC, t2.to_club_id ASC) prev
    ),
    s AS (            -- step 1b: career order
        SELECT o.*,
               ROW_NUMBER() OVER (PARTITION BY player_id
                                  ORDER BY transfer_date, same_day_order, fee_eur DESC, to_club_id) AS seq
        FROM o
    ),
    l AS (            -- previous move of the same player
        SELECT s.*,
               LAG(from_club_id)  OVER (PARTITION BY player_id ORDER BY seq) AS prev_from,
               LAG(to_club_id)    OVER (PARTITION BY player_id ORDER BY seq) AS prev_to,
               LAG(transfer_date) OVER (PARTITION BY player_id ORDER BY seq) AS prev_date
        FROM s
    ),
    r AS (            -- step 2: does this move reverse the previous one?
        SELECT l.*,
               CASE WHEN prev_from = to_club_id AND prev_to = from_club_id
                     AND DATEDIFF(DAY, prev_date, transfer_date) BETWEEN 14 AND 760
                     AND COALESCE(fee_eur, 0) = 0
                     AND from_club_id NOT IN (@without_club, @retired, @unknown, @career_break, @own_youth)
                     AND to_club_id   NOT IN (@without_club, @retired, @unknown, @career_break, @own_youth)
                    THEN 1 ELSE 0 END AS is_return
        FROM l
    ),
    c AS (            -- step 3a: chain id increases at every move that is not a return
        SELECT r.*,
               SUM(1 - is_return) OVER (PARTITION BY player_id ORDER BY seq ROWS UNBOUNDED PRECEDING) AS chain_id
        FROM r
    ),
    p AS (            -- step 3b: position inside the chain
        SELECT c.*,
               ROW_NUMBER() OVER (PARTITION BY player_id, chain_id ORDER BY seq) AS chain_pos,
               COUNT(*)     OVER (PARTITION BY player_id, chain_id)              AS chain_len
        FROM c
    )
    SELECT player_id, transfer_date, from_club_id, to_club_id, seq,
        CASE
            WHEN chain_len > 1 AND chain_pos % 2 = 0     THEN N'end of loan'
            WHEN chain_len > 1 AND chain_pos < chain_len THEN N'loan'
            WHEN fee_eur > 0                             THEN N'paid'
            WHEN @unknown IN (from_club_id, to_club_id)  THEN N'unknown'
            WHEN to_club_id IN (@retired, @without_club, @career_break) THEN N'free'
            WHEN from_club_id IN (@without_club, @career_break)         THEN N'free'
            WHEN fee_eur = 0                             THEN N'free'
            WHEN from_club_id = @own_youth OR from_youth = 1 OR to_youth = 1 THEN N'internal'
            ELSE N'unknown'
        END AS transfer_class,
        CASE
            WHEN chain_len > 1 AND chain_pos % 2 = 0     THEN N'end of loan'
            WHEN chain_len > 1 AND chain_pos < chain_len THEN CASE WHEN fee_eur > 0 THEN N'loan with fee' ELSE N'loan' END
            WHEN fee_eur > 0                             THEN N'paid'
            WHEN @unknown IN (from_club_id, to_club_id)  THEN N'unknown club'
            WHEN to_club_id = @retired                   THEN N'free: retired'
            WHEN to_club_id IN (@without_club, @career_break) THEN N'free: released / contract ended'
            WHEN from_club_id IN (@without_club, @career_break) THEN N'free: free agent signed'
            WHEN fee_eur = 0                             THEN N'free: club to club'
            WHEN from_club_id = @own_youth OR from_youth = 1 OR to_youth = 1 THEN N'internal: youth/reserve move'
            ELSE N'unknown: fee not disclosed'
        END AS transfer_subclass,
        CASE WHEN (chain_len = 1 OR chain_pos = chain_len) AND chain_pos % 2 = 1
               AND COALESCE(fee_eur, 0) = 0
               AND from_club_id NOT IN (@without_club, @retired, @unknown, @career_break, @own_youth)
               AND from_youth = 0
               AND (fee_eur = 0 OR to_club_id IN (@retired, @without_club, @career_break))
             THEN 1 ELSE 0 END AS is_free_departure,
        CASE WHEN transfer_date > @snapshot THEN 1 ELSE 0 END AS is_future_dated
    INTO #cls
    FROM p;

    UPDATE t
       SET t.seq               = k.seq,
           t.transfer_class    = k.transfer_class,
           t.transfer_subclass = k.transfer_subclass,
           t.is_free_departure = k.is_free_departure,
           t.is_future_dated   = k.is_future_dated
    FROM cln.transfers t
    JOIN #cls k ON  k.player_id = t.player_id AND k.transfer_date = t.transfer_date
               AND k.from_club_id = t.from_club_id AND k.to_club_id = t.to_club_id;
END;
GO

/* ---------- Check: the procedures exist, and regular expressions work ---------- */
SELECT name FROM sys.procedures
WHERE schema_id = SCHEMA_ID('etl') AND (name LIKE 'usp_Clean%' OR name = 'usp_ClassifyTransfers')
ORDER BY name;

SELECT CASE WHEN REGEXP_LIKE(N'Barça U19', N'U1[5-9]', 'c') THEN 'regex works' ELSE 'regex problem' END AS regex_check,
       compatibility_level
FROM sys.databases WHERE name = 'FootballBI';
