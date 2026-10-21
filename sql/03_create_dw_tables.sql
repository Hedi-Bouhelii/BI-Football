USE FootballBI;
GO

DROP TABLE IF EXISTS dw.FactContractSnapshot;
DROP TABLE IF EXISTS dw.FactAppearance;
DROP TABLE IF EXISTS dw.FactTransfer;
DROP TABLE IF EXISTS dw.FactValuation;
DROP TABLE IF EXISTS dw.DimTransferType;
DROP TABLE IF EXISTS dw.DimAgeBand;
DROP TABLE IF EXISTS dw.DimCompetition;
DROP TABLE IF EXISTS dw.DimClub;
DROP TABLE IF EXISTS dw.DimPlayer;
DROP TABLE IF EXISTS dw.DimDate;
GO

CREATE TABLE dw.DimDate (
    date_key            INT          NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,  -- 20260706
    full_date           DATE         NOT NULL CONSTRAINT UQ_DimDate_full_date UNIQUE,
    [year]              SMALLINT     NOT NULL,
    [quarter]           TINYINT      NOT NULL,
    [month]             TINYINT      NOT NULL,
    month_name          NVARCHAR(10) NOT NULL,
    day_of_month        TINYINT      NOT NULL,
    day_of_week         TINYINT      NOT NULL,  
    day_name            NVARCHAR(10) NOT NULL,
    is_weekend          BIT          NOT NULL,
    season_start_year   SMALLINT     NOT NULL,   
    season_label        NVARCHAR(7)  NOT NULL,
    season_month_no     TINYINT      NOT NULL,
    transfer_window     NVARCHAR(10) NOT NULL,
    is_transfer_window  BIT          NOT NULL
);

CREATE TABLE dw.DimPlayer (
    player_key                INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimPlayer PRIMARY KEY,
    player_id                 INT           NOT NULL CONSTRAINT UQ_DimPlayer_player_id UNIQUE,  -- Transfermarkt id
    player_name               NVARCHAR(100) NOT NULL,
    first_name                NVARCHAR(50)  NULL,
    last_name                 NVARCHAR(50)  NULL,
    date_of_birth             DATE          NULL,
    country_of_birth          NVARCHAR(50)  NULL,
    country_of_citizenship    NVARCHAR(50)  NULL,
    position_group            NVARCHAR(20)  NOT NULL,  -- Attack | Midfield | Defender | Goalkeeper | Unknown
    sub_position              NVARCHAR(50)  NOT NULL,  -- Centre-Forward, Left-Back, ... | Unknown
    foot                      NVARCHAR(10)  NULL,      -- left | right | both
    height_cm                 SMALLINT      NULL,
    contract_end_date         DATE          NULL,      -- snapshot only (DQ2): valid as of 2026-07-06
    contract_status           NVARCHAR(20)  NOT NULL,  -- Running | Expired | Unknown (at the snapshot date)
    last_season               SMALLINT      NULL,      -- last season the player appears in a covered squad
    highest_market_value_eur  BIGINT        NULL,
    agent_name                NVARCHAR(50)  NULL,
    image_url                 NVARCHAR(150) NULL,
    etl_run_id                INT           NULL,
    updated_at                DATETIME2(0)  NOT NULL CONSTRAINT DF_DimPlayer_updated DEFAULT SYSDATETIME()
);

CREATE TABLE dw.DimClub (
    club_key                 INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimClub PRIMARY KEY,
    club_id                  INT           NOT NULL CONSTRAINT UQ_DimClub_club_id UNIQUE,
    club_name                NVARCHAR(100) NOT NULL,
    club_type                NVARCHAR(20)  NOT NULL,  -- Club | Without club | Retired | Unknown | Career break | Own youth
    is_youth_or_reserve      BIT           NOT NULL,  -- U19, B team, Primavera, Castilla...
    domestic_competition_id  NVARCHAR(10)  NULL,      -- LAST covered league of the club (not always current)
    domestic_league_name     NVARCHAR(100) NULL,      -- copied from DimCompetition (flat = no snowflake)
    is_big5_2025_26          BIT           NOT NULL,  -- played a big-5 league game in 2025/26 (from games)
    has_club_details         BIT           NOT NULL,  -- 1 = the club has a row in clubs.csv
    stadium_name             NVARCHAR(100) NULL,
    stadium_seats            INT           NULL,
    etl_run_id               INT           NULL,
    updated_at               DATETIME2(0)  NOT NULL CONSTRAINT DF_DimClub_updated DEFAULT SYSDATETIME()
);

CREATE TABLE dw.DimCompetition (
    competition_key    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCompetition PRIMARY KEY,
    competition_id     NVARCHAR(10)  NOT NULL CONSTRAINT UQ_DimCompetition_id UNIQUE,  -- GB1, ES1, CL...
    competition_name   NVARCHAR(100) NOT NULL,   -- readable name, not the URL slug
    competition_type   NVARCHAR(50)  NOT NULL,   -- domestic_league | domestic_cup | international_cup | other ...
    sub_type           NVARCHAR(50)  NULL,
    country_name       NVARCHAR(50)  NULL,
    confederation      NVARCHAR(20)  NULL,
    is_big5            BIT           NOT NULL,   -- GB1, ES1, IT1, L1, FR1
    is_seeded          BIT           NOT NULL,   -- 1 = added by us (missing from competitions.csv)
    etl_run_id         INT           NULL
);

CREATE TABLE dw.DimAgeBand (
    age_band_key  SMALLINT     NOT NULL CONSTRAINT PK_DimAgeBand PRIMARY KEY,  -- fixed keys, no IDENTITY
    age_band      NVARCHAR(10) NOT NULL,   -- 'U21', '21-24', '25-28', '29+', 'Unknown'
    min_age       TINYINT      NULL,
    max_age       TINYINT      NULL,
    sort_order    TINYINT      NOT NULL
);

CREATE TABLE dw.DimTransferType (
    transfer_type_key  SMALLINT     NOT NULL CONSTRAINT PK_DimTransferType PRIMARY KEY,  -- fixed keys
    transfer_class     NVARCHAR(20) NOT NULL,   -- paid | free | loan | end of loan | internal | unknown
    transfer_subclass  NVARCHAR(50) NOT NULL CONSTRAINT UQ_DimTransferType_sub UNIQUE,
    is_permanent       BIT          NOT NULL,   -- 1 = the player changes club for good
    sort_order         TINYINT      NOT NULL
);
GO

CREATE TABLE dw.FactValuation (
    date_key          INT      NOT NULL CONSTRAINT FK_FV_Date        REFERENCES dw.DimDate(date_key),
    player_key        INT      NOT NULL CONSTRAINT FK_FV_Player      REFERENCES dw.DimPlayer(player_key),
    club_key          INT      NOT NULL CONSTRAINT FK_FV_Club        REFERENCES dw.DimClub(club_key),         -- club AT that date
    competition_key   INT      NOT NULL CONSTRAINT FK_FV_Competition REFERENCES dw.DimCompetition(competition_key),
    age_band_key      SMALLINT NOT NULL CONSTRAINT FK_FV_AgeBand     REFERENCES dw.DimAgeBand(age_band_key),
    market_value_eur  BIGINT   NOT NULL,
    etl_run_id        INT      NULL,
    CONSTRAINT UQ_FactValuation_grain UNIQUE (player_key, date_key)
);

CREATE TABLE dw.FactTransfer (
    transfer_date_key   INT           NOT NULL CONSTRAINT FK_FT_Date     REFERENCES dw.DimDate(date_key),
    player_key          INT           NOT NULL CONSTRAINT FK_FT_Player   REFERENCES dw.DimPlayer(player_key),
    from_club_key       INT           NOT NULL CONSTRAINT FK_FT_FromClub REFERENCES dw.DimClub(club_key),
    to_club_key         INT           NOT NULL CONSTRAINT FK_FT_ToClub   REFERENCES dw.DimClub(club_key),
    transfer_type_key   SMALLINT      NOT NULL CONSTRAINT FK_FT_Type     REFERENCES dw.DimTransferType(transfer_type_key),
    age_band_key        SMALLINT      NOT NULL CONSTRAINT FK_FT_AgeBand  REFERENCES dw.DimAgeBand(age_band_key),
    fee_eur             DECIMAL(18,2) NULL,      -- NULL = not disclosed / not applicable
    market_value_eur    BIGINT        NULL,      -- value at transfer (= latest valuation before it, P8.10)
    fee_to_value_ratio  DECIMAL(9,4)  NULL,      -- NON-additive: average or recompute, never sum
    is_free_departure   BIT           NOT NULL,  -- a senior club lost the player without a fee (KPI C3)
    is_future_dated     BIT           NOT NULL,  -- dated after the 2026-07-06 snapshot (announced moves)
    etl_run_id          INT           NULL,
    CONSTRAINT UQ_FactTransfer_grain UNIQUE (player_key, transfer_date_key, from_club_key, to_club_key)
);

CREATE TABLE dw.FactAppearance (
    date_key            INT      NOT NULL CONSTRAINT FK_FA_Date        REFERENCES dw.DimDate(date_key),
    game_id             INT      NOT NULL,   -- "degenerate dimension": an id with no table of its own
    player_key          INT      NOT NULL CONSTRAINT FK_FA_Player      REFERENCES dw.DimPlayer(player_key),
    club_key            INT      NOT NULL CONSTRAINT FK_FA_Club        REFERENCES dw.DimClub(club_key),
    opponent_club_key   INT      NOT NULL CONSTRAINT FK_FA_Opponent    REFERENCES dw.DimClub(club_key),
    competition_key     INT      NOT NULL CONSTRAINT FK_FA_Competition REFERENCES dw.DimCompetition(competition_key),
    age_band_key        SMALLINT NOT NULL CONSTRAINT FK_FA_AgeBand     REFERENCES dw.DimAgeBand(age_band_key),
    minutes_played      SMALLINT NOT NULL,
    goals               TINYINT  NOT NULL,
    assists             TINYINT  NOT NULL,
    yellow_cards        TINYINT  NOT NULL,
    red_cards           TINYINT  NOT NULL,
    is_starter          BIT      NULL,       -- from game_lineups (NULL if no line-up recorded)
    is_home             BIT      NULL,
    team_goals_for      TINYINT  NULL,       -- for team results and clean sheets (defenders, goalkeepers)
    team_goals_against  TINYINT  NULL,
    etl_run_id          INT      NULL,
    CONSTRAINT UQ_FactAppearance_grain UNIQUE (game_id, player_key)
);

CREATE TABLE dw.FactContractSnapshot (
    snapshot_date_key      INT      NOT NULL CONSTRAINT FK_FC_Snapshot    REFERENCES dw.DimDate(date_key),
    player_key             INT      NOT NULL CONSTRAINT FK_FC_Player      REFERENCES dw.DimPlayer(player_key),
    club_key               INT      NOT NULL CONSTRAINT FK_FC_Club        REFERENCES dw.DimClub(club_key),
    contract_end_date_key  INT      NOT NULL CONSTRAINT FK_FC_ContractEnd REFERENCES dw.DimDate(date_key),  -- -1 = unknown
    age_band_key           SMALLINT NOT NULL CONSTRAINT FK_FC_AgeBand     REFERENCES dw.DimAgeBand(age_band_key),
    market_value_eur       BIGINT   NULL,
    months_to_expiry       SMALLINT NULL,     -- KPI C1 (negative = already expired)
    is_expiring_12m        BIT      NOT NULL, -- 0 <= months_to_expiry <= 12 (input to KPI C2)
    is_active_big5         BIT      NOT NULL, -- current club played big-5 football in 2025/26
    etl_run_id             INT      NULL,
    CONSTRAINT UQ_FactContract_grain UNIQUE (snapshot_date_key, player_key)
);
GO

CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactAppearance ON dw.FactAppearance;
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactValuation  ON dw.FactValuation;
GO

SELECT t.name AS table_name,
       CASE WHEN t.name LIKE 'Fact%' THEN 'Fact' ELSE 'Dimension' END AS table_type,
       (SELECT COUNT(*) FROM sys.columns c      WHERE c.object_id = t.object_id)          AS columns,
       (SELECT COUNT(*) FROM sys.foreign_keys f WHERE f.parent_object_id = t.object_id)   AS foreign_keys
FROM sys.tables t
WHERE SCHEMA_NAME(t.schema_id) = 'dw'
ORDER BY table_type, t.name;
