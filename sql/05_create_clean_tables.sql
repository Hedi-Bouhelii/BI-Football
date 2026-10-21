
USE FootballBI;
GO
IF SCHEMA_ID('cln') IS NULL EXEC('CREATE SCHEMA cln');
GO

DROP TABLE IF EXISTS cln.transfers;
DROP TABLE IF EXISTS cln.player_valuations;
DROP TABLE IF EXISTS cln.game_lineups;
DROP TABLE IF EXISTS cln.appearances;
DROP TABLE IF EXISTS cln.club_games;
DROP TABLE IF EXISTS cln.games;
DROP TABLE IF EXISTS cln.players;
DROP TABLE IF EXISTS cln.competitions;
DROP TABLE IF EXISTS cln.clubs;
GO

CREATE TABLE cln.clubs (
    club_id                  INT           NOT NULL CONSTRAINT PK_cln_clubs PRIMARY KEY,
    club_name                NVARCHAR(100) NOT NULL,
    domestic_competition_id  NVARCHAR(10)  NULL,
    squad_size               SMALLINT      NULL,
    average_age              DECIMAL(4,1)  NULL,
    stadium_name             NVARCHAR(100) NULL,
    stadium_seats            INT           NULL,
    last_season              SMALLINT      NULL,
    etl_run_id               INT           NULL
);

CREATE TABLE cln.competitions (
    competition_id        NVARCHAR(10)  NOT NULL CONSTRAINT PK_cln_competitions PRIMARY KEY,
    competition_code      NVARCHAR(100) NOT NULL,   -- URL slug, e.g. 'premier-league'
    competition_name      NVARCHAR(100) NOT NULL,   -- readable name built from the slug
    competition_type      NVARCHAR(50)  NOT NULL,
    sub_type              NVARCHAR(50)  NULL,
    country_name          NVARCHAR(50)  NULL,       -- NULL when country_id = -1 (international)
    confederation         NVARCHAR(20)  NULL,
    etl_run_id            INT           NULL
);

CREATE TABLE cln.players (
    player_id                  INT           NOT NULL CONSTRAINT PK_cln_players PRIMARY KEY,
    player_name                NVARCHAR(100) NOT NULL,
    first_name                 NVARCHAR(50)  NULL,
    last_name                  NVARCHAR(50)  NULL,
    date_of_birth              DATE          NULL,
    country_of_birth           NVARCHAR(50)  NULL,
    city_of_birth              NVARCHAR(100) NULL,    -- non-breaking spaces removed
    country_of_citizenship     NVARCHAR(50)  NULL,
    position_group             NVARCHAR(20)  NOT NULL, -- 'Missing' -> 'Unknown'
    sub_position               NVARCHAR(50)  NOT NULL, -- NULL -> 'Unknown'
    foot                       NVARCHAR(10)  NULL,
    height_cm                  SMALLINT      NULL,
    contract_expiration_date   DATE          NULL,
    agent_name                 NVARCHAR(50)  NULL,
    image_url                  NVARCHAR(150) NULL,
    last_season                SMALLINT      NULL,
    current_club_id            INT           NULL,
    current_club_name          NVARCHAR(100) NULL,
    market_value_eur           BIGINT        NULL,
    highest_market_value_eur   BIGINT        NULL,
    etl_run_id                 INT           NULL
);

CREATE TABLE cln.games (
    game_id            INT          NOT NULL CONSTRAINT PK_cln_games PRIMARY KEY,
    competition_id     NVARCHAR(10) NOT NULL,
    season             SMALLINT     NOT NULL,     -- start year: 2025 = 2025/26
    game_date          DATE         NOT NULL,
    home_club_id       INT          NOT NULL,
    away_club_id       INT          NOT NULL,
    home_club_goals    TINYINT      NULL,
    away_club_goals    TINYINT      NULL,
    home_club_name     NVARCHAR(100) NULL,
    away_club_name     NVARCHAR(100) NULL,
    competition_type   NVARCHAR(50) NULL,
    etl_run_id         INT          NULL
);

CREATE TABLE cln.club_games (
    game_id         INT     NOT NULL,
    club_id         INT     NOT NULL,
    opponent_id     INT     NOT NULL,
    own_goals       TINYINT NULL,
    opponent_goals  TINYINT NULL,
    is_home         BIT     NOT NULL,
    etl_run_id      INT     NULL,
    CONSTRAINT PK_cln_club_games PRIMARY KEY (game_id, club_id)
);

-- appearances.csv
CREATE TABLE cln.appearances (
    game_id          INT          NOT NULL,
    player_id        INT          NOT NULL,
    player_club_id   INT          NOT NULL,
    game_date        DATE         NOT NULL,
    competition_id   NVARCHAR(10) NOT NULL,
    minutes_played   SMALLINT     NOT NULL,
    goals            TINYINT      NOT NULL,
    assists          TINYINT      NOT NULL,
    yellow_cards     TINYINT      NOT NULL,
    red_cards        TINYINT      NOT NULL,
    etl_run_id       INT          NULL,
    CONSTRAINT PK_cln_appearances PRIMARY KEY (game_id, player_id)
);

CREATE TABLE cln.game_lineups (
    game_id        INT          NOT NULL,
    player_id      INT          NOT NULL,
    club_id        INT          NOT NULL,
    is_starter     BIT          NOT NULL,   -- 'starting_lineup' -> 1, 'substitutes' -> 0
    position       NVARCHAR(50) NULL,       -- case variants normalised
    is_captain     BIT          NOT NULL,
    etl_run_id     INT          NULL,
    CONSTRAINT PK_cln_game_lineups PRIMARY KEY (game_id, player_id)
);

CREATE TABLE cln.player_valuations (
    player_id         INT          NOT NULL,
    valuation_date    DATE         NOT NULL,
    market_value_eur  BIGINT       NOT NULL,
    club_id           INT          NOT NULL,   -- club AT the valuation date
    competition_id    NVARCHAR(10) NULL,
    etl_run_id        INT          NULL,
    CONSTRAINT PK_cln_player_valuations PRIMARY KEY (player_id, valuation_date)
);

CREATE TABLE cln.transfers (
    player_id           INT           NOT NULL,
    transfer_date       DATE          NOT NULL,
    from_club_id        INT           NOT NULL,
    to_club_id          INT           NOT NULL,
    from_club_name      NVARCHAR(100) NOT NULL,
    to_club_name        NVARCHAR(100) NOT NULL,
    player_name         NVARCHAR(100) NULL,
    fee_eur             DECIMAL(18,2) NULL,
    market_value_eur    BIGINT        NULL,
    transfer_season_label NVARCHAR(5) NULL,     -- source label '25/26', kept to compare with the dataset check
    -- enrichment, filled by etl.usp_ClassifyTransfers
    seq                 INT           NULL,     -- order of the move in the player's career
    transfer_class      NVARCHAR(20)  NULL,     -- paid | free | loan | end of loan | internal | unknown
    transfer_subclass   NVARCHAR(50)  NULL,     -- must match dw.DimTransferType.transfer_subclass
    is_free_departure   BIT           NULL,
    is_future_dated     BIT           NULL,     -- after the 2026-07-06 snapshot
    etl_run_id          INT           NULL,
    CONSTRAINT PK_cln_transfers PRIMARY KEY (player_id, transfer_date, from_club_id, to_club_id)
);
GO

SELECT t.name AS table_name,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS columns
FROM sys.tables t
WHERE SCHEMA_NAME(t.schema_id) = 'cln'
ORDER BY t.name;
