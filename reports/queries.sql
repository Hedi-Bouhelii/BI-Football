-- Dataset feasibility check: Transfermarkt 'player-scores' (Kaggle davidcariboo/player-scores)
-- Every query run during the check, in order, grouped by phase. Engine: DuckDB 1.5.6 on
-- data/raw/transfermarkt-datasets.duckdb (read-only). Reference date: 2026-07-06.
-- Query ids [Pn.m] match the result blocks in reports/evidence/phaseNN_results.txt.
-- Phase 4/8/9 create a TEMP table transfers_classified (the transfer classification rule).

-- =====================================================
-- Phase 0: Inventory
-- =====================================================

-- [P0.1] List tables
SHOW TABLES;

-- [P0.2] Row count of appearances
SELECT COUNT(*) AS n FROM appearances;

-- [P0.3] Schema of appearances
DESCRIBE appearances;

-- [P0.4] Row count of club_games
SELECT COUNT(*) AS n FROM club_games;

-- [P0.5] Schema of club_games
DESCRIBE club_games;

-- [P0.6] Row count of clubs
SELECT COUNT(*) AS n FROM clubs;

-- [P0.7] Schema of clubs
DESCRIBE clubs;

-- [P0.8] Row count of competitions
SELECT COUNT(*) AS n FROM competitions;

-- [P0.9] Schema of competitions
DESCRIBE competitions;

-- [P0.10] Row count of countries
SELECT COUNT(*) AS n FROM countries;

-- [P0.11] Schema of countries
DESCRIBE countries;

-- [P0.12] Row count of game_events
SELECT COUNT(*) AS n FROM game_events;

-- [P0.13] Schema of game_events
DESCRIBE game_events;

-- [P0.14] Row count of game_lineups
SELECT COUNT(*) AS n FROM game_lineups;

-- [P0.15] Schema of game_lineups
DESCRIBE game_lineups;

-- [P0.16] Row count of games
SELECT COUNT(*) AS n FROM games;

-- [P0.17] Schema of games
DESCRIBE games;

-- [P0.18] Row count of national_teams
SELECT COUNT(*) AS n FROM national_teams;

-- [P0.19] Schema of national_teams
DESCRIBE national_teams;

-- [P0.20] Row count of player_valuations
SELECT COUNT(*) AS n FROM player_valuations;

-- [P0.21] Schema of player_valuations
DESCRIBE player_valuations;

-- [P0.22] Row count of players
SELECT COUNT(*) AS n FROM players;

-- [P0.23] Schema of players
DESCRIBE players;

-- [P0.24] Row count of transfers
SELECT COUNT(*) AS n FROM transfers;

-- [P0.25] Schema of transfers
DESCRIBE transfers;

-- [P0.26] Row count of version
SELECT COUNT(*) AS n FROM version;

-- [P0.27] Schema of version
DESCRIBE version;

-- NOTE: Column profile per table/column used:
-- NOTE: SELECT COUNT(*) FILTER (WHERE "<col>" IS NULL), COUNT(DISTINCT "<col>") FROM <table>;
-- NOTE: SELECT DISTINCT CAST("<col>" AS VARCHAR) FROM (SELECT "<col>" FROM <table> WHERE "<col>" IS NOT NULL LIMIT 2000) LIMIT 3;


-- =====================================================
-- Phase 1: Time coverage and cut-offs
-- =====================================================

-- [P1.1] games date range
SELECT MIN(date) AS min_date, MAX(date) AS max_date, COUNT(*) AS n FROM games;

-- [P1.2] appearances date range
SELECT MIN(date) AS min_date, MAX(date) AS max_date, COUNT(*) AS n FROM appearances;

-- [P1.3] player_valuations date range
SELECT MIN(date) AS min_date, MAX(date) AS max_date, COUNT(*) AS n FROM player_valuations;

-- [P1.4] transfers date range
SELECT MIN(transfer_date) AS min_date, MAX(transfer_date) AS max_date, COUNT(*) AS n FROM transfers;

-- [P1.5] game_events / game_lineups date range
SELECT 'game_events' AS t, MIN(date) AS min_date, MAX(date) AS max_date, COUNT(*) AS n FROM game_events
UNION ALL
SELECT 'game_lineups', MIN(date), MAX(date), COUNT(*) FROM game_lineups;

-- [P1.6] Rows after the notice cut-offs (should all be 0)
SELECT (SELECT COUNT(*) FROM games WHERE date > DATE '2026-07-06') AS games_after_0706,
       (SELECT COUNT(*) FROM appearances WHERE date > DATE '2026-06-28') AS appearances_after_0628,
       (SELECT COUNT(*) FROM player_valuations WHERE date > DATE '2026-06-12') AS valuations_after_0612,
       (SELECT COUNT(*) FROM transfers WHERE transfer_date > DATE '2026-07-06') AS transfers_after_0706;

-- [P1.7] Transfers dated after the cut-off, by season label
SELECT transfer_season, COUNT(*) AS n, MIN(transfer_date) AS min_d, MAX(transfer_date) AS max_d
FROM transfers WHERE transfer_date > DATE '2026-07-06' GROUP BY 1 ORDER BY 1;

-- [P1.8] Monthly row counts in the last 6 months before the cut-off
SELECT strftime(d, '%Y-%m') AS month,
       SUM(CASE WHEN src='games' THEN 1 ELSE 0 END) AS games,
       SUM(CASE WHEN src='appearances' THEN 1 ELSE 0 END) AS appearances,
       SUM(CASE WHEN src='valuations' THEN 1 ELSE 0 END) AS valuations,
       SUM(CASE WHEN src='transfers' THEN 1 ELSE 0 END) AS transfers
FROM (
  SELECT date AS d, 'games' AS src FROM games WHERE date >= DATE '2026-01-01'
  UNION ALL SELECT date, 'appearances' FROM appearances WHERE date >= DATE '2026-01-01'
  UNION ALL SELECT date, 'valuations' FROM player_valuations WHERE date >= DATE '2026-01-01'
  UNION ALL SELECT transfer_date, 'transfers' FROM transfers WHERE transfer_date >= DATE '2026-01-01'
) GROUP BY 1 ORDER BY 1;

-- [P1.9] Confirm major league codes in competitions
SELECT competition_id, name, country_name, type, sub_type
FROM competitions WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') ORDER BY 1;

-- [P1.10] All domestic first-tier leagues in the dataset
SELECT competition_id, name, country_name FROM competitions
WHERE sub_type = 'first_tier' ORDER BY country_name;

-- [P1.11] Season label format and range in games
SELECT season, COUNT(*) AS games, MIN(date) AS min_d, MAX(date) AS max_d FROM games GROUP BY 1 ORDER BY 1;

-- [P1.12] Games per season, five major leagues (wide)
PIVOT (SELECT competition_id, season, COUNT(*) AS games FROM games
       WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') GROUP BY 1, 2)
ON competition_id USING SUM(games) ORDER BY season;

-- [P1.13] Completeness: games vs expected (n_clubs * (n_clubs - 1)) per league-season
WITH g AS (
  SELECT competition_id, season, COUNT(*) AS games,
         COUNT(DISTINCT home_club_id) AS clubs
  FROM games WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') GROUP BY 1, 2)
SELECT competition_id, season, games, clubs, clubs * (clubs - 1) AS expected,
       ROUND(100.0 * games / (clubs * (clubs - 1)), 1) AS pct_complete
FROM g ORDER BY competition_id, season;

-- [P1.14] Appearances per game, major leagues by season (games with >= 1 appearance row)
WITH g AS (SELECT game_id, competition_id, season FROM games
           WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1')),
     a AS (SELECT game_id, COUNT(*) AS n FROM appearances GROUP BY 1)
SELECT g.season,
       COUNT(*) AS games,
       COUNT(a.game_id) AS games_with_appearances,
       ROUND(100.0 * COUNT(a.game_id) / COUNT(*), 1) AS pct_games_with_app,
       ROUND(AVG(a.n), 1) AS avg_app_rows_per_game
FROM g LEFT JOIN a ON CAST(g.game_id AS INTEGER) = a.game_id
GROUP BY 1 ORDER BY 1;

-- [P1.15] Season-level completeness summary per league (seasons with >=95% games and >=95% games having appearances)
WITH g AS (
  SELECT competition_id, season, game_id, home_club_id FROM games
  WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1')),
 a AS (SELECT DISTINCT game_id FROM appearances),
 s AS (
  SELECT competition_id, season, COUNT(*) AS games,
         COUNT(DISTINCT home_club_id) AS clubs,
         COUNT(a.game_id) AS with_app
  FROM g LEFT JOIN a ON CAST(g.game_id AS INTEGER) = a.game_id GROUP BY 1, 2)
SELECT competition_id,
       COUNT(*) AS seasons_present,
       MIN(season) AS first_season, MAX(season) AS last_season,
       COUNT(*) FILTER (WHERE games >= 0.95 * clubs * (clubs - 1) AND with_app >= 0.95 * games) AS complete_seasons,
       STRING_AGG(season, ',' ORDER BY season) FILTER (WHERE NOT (games >= 0.95 * clubs * (clubs - 1) AND with_app >= 0.95 * games)) AS incomplete_seasons
FROM s GROUP BY 1 ORDER BY 1;

-- [P1.16] Gap years: seasons missing per major league between first and last season
WITH s AS (SELECT DISTINCT competition_id, CAST(season AS INTEGER) AS season FROM games
           WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1')),
     r AS (SELECT competition_id, MIN(season) AS lo, MAX(season) AS hi FROM s GROUP BY 1)
SELECT r.competition_id, y.season AS missing_season
FROM r, range(r.lo, r.hi + 1) AS y(season)
WHERE NOT EXISTS (SELECT 1 FROM s WHERE s.competition_id = r.competition_id AND s.season = y.season)
ORDER BY 1, 2;

-- [P1.17] Season 2025 (= 2025/26) progress per major league: last game date and games played
SELECT competition_id, COUNT(*) AS games, MAX(date) AS last_game, MIN(date) AS first_game
FROM games WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025'
GROUP BY 1 ORDER BY 1;

-- [P1.18] Valuations per year (history depth)
SELECT year(date) AS yr, COUNT(*) AS n FROM player_valuations GROUP BY 1 ORDER BY 1;

-- [P1.19] Transfers per year
SELECT year(transfer_date) AS yr, COUNT(*) AS n FROM transfers GROUP BY 1 ORDER BY 1;


-- =====================================================
-- Phase 2: Contract data
-- =====================================================

-- [P2.1] Meaning of players.last_season: distribution (VARCHAR, cast to INT)
SELECT last_season, COUNT(*) AS players,
       COUNT(contract_expiration_date) AS with_contract,
       ROUND(100.0 * COUNT(contract_expiration_date) / COUNT(*), 1) AS pct_with_contract,
       COUNT(market_value_in_eur) AS with_value
FROM players GROUP BY 1 ORDER BY 1;

-- [P2.2] last_season vs the player's last appearance season (sample check of the meaning)
WITH la AS (SELECT a.player_id, MAX(CAST(g.season AS INTEGER)) AS last_app_season
            FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id GROUP BY 1)
SELECT CAST(p.last_season AS INTEGER) = la.last_app_season AS matches_last_app_season, COUNT(*) AS players
FROM players p JOIN la USING (player_id) GROUP BY 1;

-- [P2.3] Overall contract completeness
SELECT COUNT(*) AS players,
       COUNT(contract_expiration_date) AS with_contract,
       ROUND(100.0 * COUNT(contract_expiration_date) / COUNT(*), 1) AS pct
FROM players;

-- [P2.4] Recently active players (last_season >= 2025) by current competition
SELECT current_club_domestic_competition_id AS comp, COUNT(*) AS n,
       ROUND(100.0 * COUNT(contract_expiration_date) / COUNT(*), 1) AS pct_with_contract,
       ROUND(100.0 * COUNT(*) FILTER (WHERE contract_expiration_date >= DATE '2026-07-06') / COUNT(*), 1) AS pct_contract_running_at_cutoff
FROM players
WHERE CAST(last_season AS INTEGER) >= 2025
GROUP BY 1 ORDER BY n DESC LIMIT 15;

-- [P2.5] DECISION METRIC: recently active players at big-5 clubs with a valid contract date
SELECT COUNT(*) AS n,
       COUNT(contract_expiration_date) AS with_contract,
       ROUND(100.0 * COUNT(contract_expiration_date) / COUNT(*), 1) AS pct_with_contract,
       COUNT(*) FILTER (WHERE contract_expiration_date BETWEEN TIMESTAMP '2000-01-01' AND TIMESTAMP '2035-12-31') AS valid_range,
       ROUND(100.0 * COUNT(*) FILTER (WHERE contract_expiration_date BETWEEN TIMESTAMP '2000-01-01' AND TIMESTAMP '2035-12-31') / COUNT(*), 1) AS pct_valid_range,
       COUNT(*) FILTER (WHERE contract_expiration_date >= TIMESTAMP '2026-07-06') AS running_at_cutoff,
       ROUND(100.0 * COUNT(*) FILTER (WHERE contract_expiration_date >= TIMESTAMP '2026-07-06') / COUNT(*), 1) AS pct_running_at_cutoff
FROM players
WHERE CAST(last_season AS INTEGER) >= 2025
  AND current_club_domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1');

-- [P2.6] Same, restricted to players with market value >= 1m EUR
SELECT COUNT(*) AS n,
       ROUND(100.0 * COUNT(contract_expiration_date) / COUNT(*), 1) AS pct_with_contract,
       ROUND(100.0 * COUNT(*) FILTER (WHERE contract_expiration_date >= TIMESTAMP '2026-07-06') / COUNT(*), 1) AS pct_running_at_cutoff
FROM players
WHERE CAST(last_season AS INTEGER) >= 2025 AND market_value_in_eur >= 1000000
  AND current_club_domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1');

-- [P2.7] Distribution of expiry years (all players)
SELECT EXTRACT(year FROM contract_expiration_date) AS expiry_year, COUNT(*) AS n
FROM players GROUP BY 1 ORDER BY 1;

-- [P2.8] Distribution of expiry month-day (are dates mostly 30 June?)
SELECT strftime(contract_expiration_date, '%m-%d') AS mmdd, COUNT(*) AS n
FROM players WHERE contract_expiration_date IS NOT NULL GROUP BY 1 ORDER BY n DESC LIMIT 10;

-- [P2.9] Expiry year by last_season (shows that the date is frozen at the player's last scrape)
SELECT last_season,
       MIN(contract_expiration_date)::DATE AS min_exp, MEDIAN(contract_expiration_date)::DATE AS median_exp,
       MAX(contract_expiration_date)::DATE AS max_exp, COUNT(contract_expiration_date) AS n
FROM players GROUP BY 1 ORDER BY 1;

-- [P2.10] At-risk cohort: value >= 5m, contract ends 2026-07-06..2027-07-06 (top 50)
SELECT name, current_club_name, current_club_domestic_competition_id AS comp, last_season,
       market_value_in_eur, contract_expiration_date::DATE AS contract_end
FROM players
WHERE contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
  AND market_value_in_eur >= 5000000
ORDER BY market_value_in_eur DESC LIMIT 50;

-- [P2.11] At-risk cohort size, total and big-5
SELECT COUNT(*) AS at_risk_total,
       COUNT(*) FILTER (WHERE current_club_domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1')) AS at_risk_big5,
       COUNT(*) FILTER (WHERE CAST(last_season AS INTEGER) >= 2025) AS at_risk_active
FROM players
WHERE contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
  AND market_value_in_eur >= 5000000;

-- [P2.12] Any other table carrying a contract date? (column search)
SELECT table_name, column_name FROM information_schema.columns
WHERE column_name ILIKE '%contract%' OR column_name ILIKE '%expir%';

-- [P2.13] Snapshot test 1: players whose latest transfer (<= cut-off) was in 2025 to their current club - contract end vs transfer date
WITH last_t AS (
  SELECT * FROM (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY transfer_date DESC) AS rn
    FROM transfers t WHERE transfer_date <= DATE '2026-07-06') WHERE rn = 1)
SELECT COUNT(*) AS players_moved_2025,
       COUNT(p.contract_expiration_date) AS with_contract,
       COUNT(*) FILTER (WHERE p.contract_expiration_date > lt.transfer_date) AS contract_after_move,
       COUNT(*) FILTER (WHERE p.contract_expiration_date <= lt.transfer_date) AS contract_before_or_at_move,
       ROUND(100.0 * COUNT(*) FILTER (WHERE p.contract_expiration_date > lt.transfer_date) / COUNT(p.contract_expiration_date), 1) AS pct_consistent
FROM last_t lt JOIN players p USING (player_id)
WHERE year(lt.transfer_date) = 2025
  AND CAST(lt.to_club_id AS VARCHAR) = p.current_club_id;

-- [P2.14] Snapshot test 1b: sample of 2025 movers with their current contract
WITH last_t AS (
  SELECT * FROM (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY transfer_date DESC) AS rn
    FROM transfers t WHERE transfer_date <= DATE '2026-07-06') WHERE rn = 1)
SELECT p.name, lt.transfer_date, lt.from_club_name, lt.to_club_name, lt.transfer_fee,
       p.current_club_name, p.contract_expiration_date::DATE AS contract_end, p.market_value_in_eur
FROM last_t lt JOIN players p USING (player_id)
WHERE year(lt.transfer_date) = 2025 AND CAST(lt.to_club_id AS VARCHAR) = p.current_club_id
  AND p.market_value_in_eur >= 20000000
ORDER BY p.market_value_in_eur DESC LIMIT 15;

-- [P2.15] Snapshot test 2: one row per player in players (no history possible)
SELECT COUNT(*) AS rows, COUNT(DISTINCT player_id) AS players FROM players;

-- [P2.16] Snapshot test 3: does current_club_id agree with the latest transfer destination (<= cut-off)?
WITH last_t AS (
  SELECT * FROM (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY transfer_date DESC) AS rn
    FROM transfers t WHERE transfer_date <= DATE '2026-07-06') WHERE rn = 1)
SELECT CAST(lt.to_club_id AS VARCHAR) = p.current_club_id AS agrees,
       COUNT(*) AS players
FROM last_t lt JOIN players p USING (player_id)
WHERE CAST(p.last_season AS INTEGER) >= 2025
GROUP BY 1;

-- [P2.17] Contract dates in the past (< 2026-07-06) for players with a current club, by last_season
SELECT last_season, COUNT(*) AS n_past_contract,
       MIN(contract_expiration_date)::DATE AS min_exp, MAX(contract_expiration_date)::DATE AS max_exp
FROM players
WHERE contract_expiration_date < TIMESTAMP '2026-07-06'
  AND current_club_id IS NOT NULL AND current_club_name IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- [P2.18] Recently active (last_season >= 2025) with contract already expired at cut-off, by expiry date
SELECT contract_expiration_date::DATE AS contract_end, COUNT(*) AS n
FROM players
WHERE CAST(last_season AS INTEGER) >= 2025 AND contract_expiration_date < TIMESTAMP '2026-07-06'
GROUP BY 1 ORDER BY n DESC LIMIT 10;

-- [P2.19] Sample: active big-5 players whose contract ended before the cut-off
SELECT name, current_club_name, contract_expiration_date::DATE AS contract_end, market_value_in_eur, last_season
FROM players
WHERE CAST(last_season AS INTEGER) >= 2025 AND current_club_domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1')
  AND contract_expiration_date < TIMESTAMP '2026-07-06'
ORDER BY market_value_in_eur DESC NULLS LAST LIMIT 15;

-- [P2.20] Implausible contract dates (before 2000 or after 2035)
SELECT COUNT(*) FILTER (WHERE contract_expiration_date < TIMESTAMP '2000-01-01') AS before_2000,
       COUNT(*) FILTER (WHERE contract_expiration_date > TIMESTAMP '2035-12-31') AS after_2035,
       MIN(contract_expiration_date) AS min_exp, MAX(contract_expiration_date) AS max_exp
FROM players;

-- [P2.21] Players whose current club looks like a placeholder (no club name)
SELECT current_club_id, COUNT(*) AS n, COUNT(contract_expiration_date) AS with_contract
FROM players WHERE current_club_name IS NULL GROUP BY 1 ORDER BY n DESC LIMIT 10;

-- [P2.22] clubs tagged with a big-5 domestic_competition_id, by clubs.last_season
SELECT domestic_competition_id, last_season, COUNT(*) AS clubs
FROM clubs WHERE domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1') GROUP BY 1, 2 ORDER BY 1, 2;

-- [P2.23] Example: big-5-tagged clubs that did not play in the big-5 in 2025/26
SELECT club_id, name, domestic_competition_id, last_season FROM clubs
WHERE domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1') AND last_season <> '2025' ORDER BY last_season DESC LIMIT 10;

-- [P2.24] Number of clubs that actually played in a big-5 league in 2025/26
SELECT COUNT(*) AS clubs FROM (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
               WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025');

-- [P2.25] DECISION METRIC (corrected): recently active players at clubs that played big-5 2025/26
SELECT COUNT(*) AS n,
       COUNT(contract_expiration_date) AS with_contract,
       ROUND(100.0 * COUNT(contract_expiration_date) / COUNT(*), 1) AS pct_with_contract,
       COUNT(*) FILTER (WHERE contract_expiration_date >= TIMESTAMP '2026-07-06') AS running_at_cutoff,
       ROUND(100.0 * COUNT(*) FILTER (WHERE contract_expiration_date >= TIMESTAMP '2026-07-06') / COUNT(*), 1) AS pct_running_at_cutoff
FROM players
WHERE CAST(last_season AS INTEGER) >= 2025 AND current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
               WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025');

-- [P2.26] Same, value >= 1m EUR
SELECT COUNT(*) AS n,
       ROUND(100.0 * COUNT(contract_expiration_date) / COUNT(*), 1) AS pct_with_contract,
       ROUND(100.0 * COUNT(*) FILTER (WHERE contract_expiration_date >= TIMESTAMP '2026-07-06') / COUNT(*), 1) AS pct_running_at_cutoff
FROM players
WHERE CAST(last_season AS INTEGER) >= 2025 AND current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
               WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025') AND market_value_in_eur >= 1000000;

-- [P2.27] At-risk cohort (value >= 5m, ends 2026-07-06..2027-07-06) at clubs that played big-5 2025/26
SELECT COUNT(*) AS at_risk_big5_current,
       SUM(market_value_in_eur) AS total_value_eur
FROM players
WHERE contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
  AND market_value_in_eur >= 5000000 AND current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
               WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025');

-- [P2.28] Missing contract dates among active big-5 players: who are they? (value bands)
SELECT CASE WHEN market_value_in_eur IS NULL THEN 'no value'
            WHEN market_value_in_eur < 1000000 THEN '<1m'
            WHEN market_value_in_eur < 5000000 THEN '1-5m' ELSE '5m+' END AS value_band,
       COUNT(*) AS missing_contract
FROM players
WHERE CAST(last_season AS INTEGER) >= 2025 AND current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
               WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025')
  AND contract_expiration_date IS NULL
GROUP BY 1 ORDER BY 2 DESC;

-- [P2.29] Players with current_club_id 515 (placeholder with no club row)
SELECT name, last_season, market_value_in_eur, contract_expiration_date FROM players
WHERE current_club_id = '515' LIMIT 5;


-- =====================================================
-- Phase 3: Valuation history
-- =====================================================

-- [P3.1] Overall size and range
SELECT COUNT(*) AS rows, COUNT(DISTINCT player_id) AS players,
       MIN(date) AS first_date, MAX(date) AS last_date
FROM player_valuations;

-- [P3.2] Valuation points per player (buckets)
SELECT CASE WHEN n = 1 THEN '1' WHEN n BETWEEN 2 AND 4 THEN '2-4'
            WHEN n BETWEEN 5 AND 9 THEN '5-9' ELSE '10+' END AS bucket,
       COUNT(*) AS players
FROM (SELECT player_id, COUNT(*) AS n FROM player_valuations GROUP BY 1)
GROUP BY 1 ORDER BY 1;

-- [P3.3] Players whose history spans >= 365 days
SELECT COUNT(*) AS players_span_12m FROM (
  SELECT player_id FROM player_valuations
  GROUP BY 1 HAVING date_diff('day', MIN(date), MAX(date)) >= 365);

-- [P3.4] Null or zero values
SELECT COUNT(*) FILTER (WHERE market_value_in_eur IS NULL) AS nulls,
       COUNT(*) FILTER (WHERE market_value_in_eur = 0) AS zeros,
       COUNT(*) FILTER (WHERE market_value_in_eur < 0) AS negatives,
       COUNT(*) AS total,
       MIN(market_value_in_eur) AS min_v, MAX(market_value_in_eur) AS max_v
FROM player_valuations;

-- [P3.5] Duplicate (player_id, date) pairs
SELECT COUNT(*) AS dup_pairs, SUM(n - 1) AS extra_rows FROM (
  SELECT player_id, date, COUNT(*) AS n FROM player_valuations GROUP BY 1, 2 HAVING COUNT(*) > 1);

-- [P3.6] DECISION METRIC: players with current value >= 1m having >= 3 points spanning >= 12 months
WITH v AS (SELECT player_id, COUNT(*) AS n, MIN(date) AS d0, MAX(date) AS d1
           FROM player_valuations GROUP BY 1)
SELECT COUNT(*) AS players_1m_plus,
       COUNT(v.player_id) AS with_any_valuation,
       COUNT(*) FILTER (WHERE v.n >= 3 AND date_diff('day', v.d0, v.d1) >= 365) AS with_3pts_12m,
       ROUND(100.0 * COUNT(*) FILTER (WHERE v.n >= 3 AND date_diff('day', v.d0, v.d1) >= 365) / COUNT(*), 1) AS pct
FROM players p LEFT JOIN v USING (player_id)
WHERE p.market_value_in_eur >= 1000000;

-- [P3.7] Same, recently active players only (last_season >= 2025)
WITH v AS (SELECT player_id, COUNT(*) AS n, MIN(date) AS d0, MAX(date) AS d1
           FROM player_valuations GROUP BY 1)
SELECT COUNT(*) AS players_1m_plus,
       COUNT(v.player_id) AS with_any_valuation,
       COUNT(*) FILTER (WHERE v.n >= 3 AND date_diff('day', v.d0, v.d1) >= 365) AS with_3pts_12m,
       ROUND(100.0 * COUNT(*) FILTER (WHERE v.n >= 3 AND date_diff('day', v.d0, v.d1) >= 365) / COUNT(*), 1) AS pct
FROM players p LEFT JOIN v USING (player_id)
WHERE p.market_value_in_eur >= 1000000 AND CAST(p.last_season AS INTEGER) >= 2025;

-- [P3.8] Update frequency: points per player per year of history (players with span >= 1 year)
WITH v AS (SELECT player_id, COUNT(*) AS n, date_diff('day', MIN(date), MAX(date)) / 365.25 AS yrs
           FROM player_valuations GROUP BY 1 HAVING date_diff('day', MIN(date), MAX(date)) >= 365)
SELECT ROUND(AVG(n / yrs), 2) AS avg_pts_per_year, ROUND(MEDIAN(n / yrs), 2) AS median_pts_per_year,
       ROUND(QUANTILE_CONT(n / yrs, 0.1), 2) AS p10, ROUND(QUANTILE_CONT(n / yrs, 0.9), 2) AS p90
FROM v;

-- [P3.9] Gap between consecutive valuations (days)
WITH g AS (SELECT date_diff('day', LAG(date) OVER (PARTITION BY player_id ORDER BY date), date) AS gap
           FROM player_valuations)
SELECT ROUND(AVG(gap), 0) AS avg_gap, MEDIAN(gap) AS median_gap,
       QUANTILE_CONT(gap, 0.9) AS p90_gap, MAX(gap) AS max_gap
FROM g WHERE gap IS NOT NULL;

-- [P3.10] Gap between consecutive valuations, recent years only (2022+)
WITH g AS (SELECT date, date_diff('day', LAG(date) OVER (PARTITION BY player_id ORDER BY date), date) AS gap
           FROM player_valuations)
SELECT year(date) AS yr, ROUND(AVG(gap), 0) AS avg_gap, MEDIAN(gap) AS median_gap
FROM g WHERE gap IS NOT NULL AND date >= DATE '2022-01-01' GROUP BY 1 ORDER BY 1;

-- [P3.11] Valuation dates cluster on a few update days per year? (top dates)
SELECT date, COUNT(*) AS n FROM player_valuations WHERE date >= DATE '2025-01-01'
GROUP BY 1 ORDER BY n DESC LIMIT 12;

-- [P3.12] Does players.market_value_in_eur equal the latest valuation?
WITH last_v AS (SELECT player_id, arg_max(market_value_in_eur, date) AS last_value, MAX(date) AS last_date
                FROM player_valuations GROUP BY 1)
SELECT COUNT(*) AS players_with_both,
       COUNT(*) FILTER (WHERE p.market_value_in_eur = l.last_value) AS equal,
       ROUND(100.0 * COUNT(*) FILTER (WHERE p.market_value_in_eur = l.last_value) / COUNT(*), 1) AS pct_equal
FROM players p JOIN last_v l USING (player_id)
WHERE p.market_value_in_eur IS NOT NULL;

-- [P3.13] Players with a value in players but no row in player_valuations, and vice versa
SELECT (SELECT COUNT(*) FROM players p WHERE market_value_in_eur IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM player_valuations v WHERE v.player_id = p.player_id)) AS value_but_no_history,
       (SELECT COUNT(*) FROM players p WHERE market_value_in_eur IS NULL
          AND EXISTS (SELECT 1 FROM player_valuations v WHERE v.player_id = p.player_id)) AS history_but_no_value;

-- [P3.14] 12-month value change feasibility as of 2026-07-06 (active players, value >= 1m)
WITH base AS (SELECT player_id FROM players
              WHERE CAST(last_season AS INTEGER) >= 2025 AND market_value_in_eur >= 1000000),
     now_v AS (SELECT player_id, arg_max(market_value_in_eur, date) AS v_now, MAX(date) AS d_now
               FROM player_valuations WHERE date <= DATE '2026-07-06' GROUP BY 1),
     ago_v AS (SELECT player_id, arg_max(market_value_in_eur, date) AS v_ago, MAX(date) AS d_ago
               FROM player_valuations WHERE date <= DATE '2025-07-06' GROUP BY 1)
SELECT COUNT(*) AS base_players,
       COUNT(n.player_id) AS with_value_now,
       COUNT(a.player_id) AS with_value_12m_ago,
       ROUND(100.0 * COUNT(a.player_id) / COUNT(*), 1) AS pct_both,
       COUNT(*) FILTER (WHERE n.d_now >= DATE '2026-01-01') AS now_value_dated_2026
FROM base b LEFT JOIN now_v n USING (player_id) LEFT JOIN ago_v a USING (player_id);

-- [P3.15] Value distribution of latest valuation per player (as of cut-off)
WITH l AS (SELECT player_id, arg_max(market_value_in_eur, date) AS v FROM player_valuations GROUP BY 1)
SELECT CASE WHEN v < 100000 THEN 'a <100k' WHEN v < 1000000 THEN 'b 100k-1m'
            WHEN v < 5000000 THEN 'c 1-5m' WHEN v < 20000000 THEN 'd 5-20m'
            WHEN v < 50000000 THEN 'e 20-50m' ELSE 'f 50m+' END AS band, COUNT(*) AS players
FROM l GROUP BY 1 ORDER BY 1;

-- [P3.16] Extreme valuation values (top 5)
SELECT v.player_id, p.name, v.date, v.market_value_in_eur
FROM player_valuations v LEFT JOIN players p USING (player_id)
ORDER BY v.market_value_in_eur DESC LIMIT 5;

-- [P3.17] Valuation rows: club columns completeness
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE current_club_id IS NULL) / COUNT(*), 2) AS pct_club_id_null,
       ROUND(100.0 * COUNT(*) FILTER (WHERE player_club_domestic_competition_id IS NULL) / COUNT(*), 2) AS pct_comp_null
FROM player_valuations;

-- [P3.18] Is player_valuations.current_club_id the club AT valuation date or the CURRENT club? (players with >1 club in history)
SELECT COUNT(*) AS players, COUNT(*) FILTER (WHERE n_clubs > 1) AS players_with_multiple_clubs
FROM (SELECT player_id, COUNT(DISTINCT current_club_id) AS n_clubs FROM player_valuations GROUP BY 1);

-- [P3.19] Sample: one well-known player's valuation history with club
SELECT v.date, v.market_value_in_eur, v.current_club_name, v.player_club_domestic_competition_id
FROM player_valuations v JOIN players p USING (player_id)
WHERE p.name = 'Florian Wirtz' ORDER BY v.date DESC LIMIT 12;


-- =====================================================
-- Phase 4: Transfers
-- =====================================================

-- [P4.1] Schema
DESCRIBE transfers;

-- [P4.2] Rows per transfer_season (latest 15)
SELECT transfer_season, COUNT(*) AS n, MIN(transfer_date) AS min_d, MAX(transfer_date) AS max_d
FROM transfers GROUP BY 1 ORDER BY 1 DESC LIMIT 15;

-- [P4.3] All transfer_season labels (format check)
SELECT transfer_season, COUNT(*) AS n FROM transfers GROUP BY 1 ORDER BY 1;

-- [P4.4] Fee null / zero / positive
SELECT COUNT(*) FILTER (WHERE transfer_fee IS NULL) AS fee_null,
       COUNT(*) FILTER (WHERE transfer_fee = 0) AS fee_zero,
       COUNT(*) FILTER (WHERE transfer_fee > 0) AS fee_positive,
       COUNT(*) FILTER (WHERE transfer_fee < 0) AS fee_negative,
       COUNT(*) AS total
FROM transfers;

-- [P4.5] market_value_in_eur (value at transfer) null / zero / positive
SELECT COUNT(*) FILTER (WHERE market_value_in_eur IS NULL) AS mv_null,
       COUNT(*) FILTER (WHERE market_value_in_eur = 0) AS mv_zero,
       COUNT(*) FILTER (WHERE market_value_in_eur > 0) AS mv_positive
FROM transfers;

-- [P4.6] Top from_club_name
SELECT from_club_name, from_club_id, COUNT(*) AS n FROM transfers GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 25;

-- [P4.7] Top to_club_name
SELECT to_club_name, to_club_id, COUNT(*) AS n FROM transfers GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 25;

-- [P4.8] Special club names (Without Club, Retired, Unknown, Career break, U-teams, ...)
SELECT name, id, SUM(n) AS n FROM (
  SELECT from_club_name AS name, from_club_id AS id, COUNT(*) AS n FROM transfers GROUP BY 1, 2
  UNION ALL SELECT to_club_name, to_club_id, COUNT(*) FROM transfers GROUP BY 1, 2)
WHERE regexp_matches(lower(name), 'without|retired|unknown|career|break|banned|own youth|free agent|vereinslos|pause')
GROUP BY 1, 2 ORDER BY 3 DESC;

-- [P4.9] Any column carrying loan information? (text search in club names)
SELECT COUNT(*) FILTER (WHERE from_club_name ILIKE '%loan%' OR to_club_name ILIKE '%loan%') AS loan_in_names
FROM transfers;

-- [P4.10] Sample rows, fee NULL
SELECT * FROM transfers WHERE transfer_fee IS NULL ORDER BY transfer_date DESC LIMIT 20;

-- [P4.11] Sample rows, fee = 0
SELECT * FROM transfers WHERE transfer_fee = 0 ORDER BY transfer_date DESC LIMIT 20;

-- [P4.12] Sample rows, fee > 0 (largest)
SELECT * FROM transfers WHERE transfer_fee > 0 ORDER BY transfer_fee DESC LIMIT 20;

-- [P4.13] Round trips: A->B followed by B->A for the same player (loan + end-of-loan signature)
WITH t AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY transfer_date, transfer_fee NULLS FIRST) AS seq
           FROM transfers),
     pair AS (SELECT a.player_id, a.transfer_date AS out_date, b.transfer_date AS back_date,
                     a.transfer_fee AS out_fee, b.transfer_fee AS back_fee,
                     date_diff('day', a.transfer_date, b.transfer_date) AS days
              FROM t a JOIN t b ON a.player_id = b.player_id AND b.seq = a.seq + 1
               AND a.from_club_id = b.to_club_id AND a.to_club_id = b.from_club_id)
SELECT COUNT(*) AS round_trips,
       COUNT(*) FILTER (WHERE days <= 730) AS within_2y,
       COUNT(*) FILTER (WHERE out_fee IS NULL) AS out_fee_null,
       COUNT(*) FILTER (WHERE out_fee = 0) AS out_fee_zero,
       COUNT(*) FILTER (WHERE out_fee > 0) AS out_fee_pos,
       COUNT(*) FILTER (WHERE back_fee IS NULL) AS back_fee_null,
       COUNT(*) FILTER (WHERE back_fee = 0) AS back_fee_zero,
       COUNT(*) FILTER (WHERE back_fee > 0) AS back_fee_pos
FROM pair;

-- [P4.14] Round trip examples with dates (loan-like)
WITH t AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY transfer_date, transfer_fee NULLS FIRST) AS seq
           FROM transfers)
SELECT a.player_name, a.transfer_date AS out_date, a.from_club_name, a.to_club_name, a.transfer_fee AS out_fee,
       b.transfer_date AS back_date, b.transfer_fee AS back_fee, a.market_value_in_eur AS mv
FROM t a JOIN t b ON a.player_id = b.player_id AND b.seq = a.seq + 1
 AND a.from_club_id = b.to_club_id AND a.to_club_id = b.from_club_id
WHERE a.transfer_date >= DATE '2024-07-01' ORDER BY a.market_value_in_eur DESC NULLS LAST LIMIT 20;

-- [P4.15] Return dates: share of 'back' legs dated 30 June / 31 Dec / 1 July etc.
WITH t AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY transfer_date, transfer_fee NULLS FIRST) AS seq
           FROM transfers)
SELECT strftime(b.transfer_date, '%m-%d') AS back_mmdd, COUNT(*) AS n
FROM t a JOIN t b ON a.player_id = b.player_id AND b.seq = a.seq + 1
 AND a.from_club_id = b.to_club_id AND a.to_club_id = b.from_club_id
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

-- [P4.16] Check against the raw CSV: does transfers.csv carry the original fee text (e.g. 'loan', 'free transfer')?
SELECT * FROM read_csv_auto('../data/raw/transfers.csv.gz') LIMIT 3;

-- [P4.17] Round-trip gap distribution (days between out leg and return leg)
WITH t AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY transfer_date, transfer_fee NULLS FIRST) AS seq
           FROM transfers)
SELECT CASE WHEN d < 7 THEN 'a <7d' WHEN d < 60 THEN 'b 7-59d' WHEN d < 150 THEN 'c 60-149d'
            WHEN d < 400 THEN 'd 150-399d' WHEN d < 760 THEN 'e 400-759d' ELSE 'f 760d+' END AS gap, COUNT(*) AS n
FROM (SELECT date_diff('day', a.transfer_date, b.transfer_date) AS d
      FROM t a JOIN t b ON a.player_id = b.player_id AND b.seq = a.seq + 1
       AND a.from_club_id = b.to_club_id AND a.to_club_id = b.from_club_id)
GROUP BY 1 ORDER BY 1;

-- [P4.18] Fee NULL rows: breakdown by special clubs
SELECT CASE WHEN to_club_id = 123 THEN 'to Retired' WHEN to_club_id = 515 THEN 'to Without Club'
            WHEN from_club_id = 515 THEN 'from Without Club' WHEN 75 IN (from_club_id, to_club_id) THEN 'Unknown club'
            ELSE 'club to club' END AS kind, COUNT(*) AS n
FROM transfers WHERE transfer_fee IS NULL GROUP BY 1 ORDER BY 2 DESC;

-- [P4.19] Fee 0 rows: breakdown by special clubs
SELECT CASE WHEN to_club_id = 123 THEN 'to Retired' WHEN to_club_id = 515 THEN 'to Without Club'
            WHEN from_club_id = 515 THEN 'from Without Club' WHEN 75 IN (from_club_id, to_club_id) THEN 'Unknown club'
            ELSE 'club to club' END AS kind, COUNT(*) AS n
FROM transfers WHERE transfer_fee = 0 GROUP BY 1 ORDER BY 2 DESC;

-- [P4.20] Youth / reserve team name patterns among NULL-fee club-to-club rows
SELECT from_club_name, to_club_name, COUNT(*) AS n FROM transfers
WHERE transfer_fee IS NULL AND from_club_id NOT IN (75, 515) AND to_club_id NOT IN (75, 123, 515)
GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 25;

-- [P4.21] Rows where one side is a youth/reserve team (name regex)
SELECT COUNT(*) AS n,
       COUNT(*) FILTER (WHERE transfer_fee IS NULL) AS fee_null,
       COUNT(*) FILTER (WHERE transfer_fee = 0) AS fee_zero,
       COUNT(*) FILTER (WHERE transfer_fee > 0) AS fee_pos
FROM transfers
WHERE regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|II|B| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.)')
   OR regexp_matches(to_club_name,   '(U1[5-9]|U2[0-3]|II|B| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.)');

-- [P4.22] Season label vs date-derived season (July-June) mismatch
WITH t AS (SELECT transfer_season,
                  CASE WHEN month(transfer_date) >= 7 THEN year(transfer_date) ELSE year(transfer_date) - 1 END AS y
           FROM transfers)
SELECT transfer_season = lpad(CAST(y % 100 AS VARCHAR), 2, '0') || '/' || lpad(CAST((y + 1) % 100 AS VARCHAR), 2, '0') AS label_matches_date,
       COUNT(*) AS n
FROM t GROUP BY 1;

-- [P4.23] Season label mismatch examples
SELECT transfer_season, transfer_date, from_club_name, to_club_name, transfer_fee, player_name
FROM transfers WHERE transfer_season = '25/26' AND transfer_date < DATE '2025-05-01' ORDER BY transfer_date LIMIT 10;

-- [P4.24] Free-agent signings and releases dated 30 June vs 1 July (when do contract-end exits get dated?)
SELECT strftime(transfer_date, '%m-%d') AS mmdd, COUNT(*) AS n
FROM transfers WHERE transfer_fee = 0 OR transfer_fee IS NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

-- [P4.25] Create transfers_classified (classification rule, see checklib.TRANSFER_CLASS_SQL)
CREATE OR REPLACE TEMP TABLE transfers_classified AS
WITH o AS (
  SELECT t.*,
         CASE WHEN t.from_club_id = (SELECT arg_max(t2.to_club_id, t2.transfer_date) FROM transfers t2
                                     WHERE t2.player_id = t.player_id AND t2.transfer_date < t.transfer_date)
              THEN 0 ELSE 1 END AS same_day_order
  FROM transfers t),
s AS (
  SELECT o.* EXCLUDE (same_day_order),
         ROW_NUMBER() OVER (PARTITION BY player_id
                            ORDER BY transfer_date, same_day_order, transfer_fee DESC NULLS LAST, to_club_id) AS seq
  FROM o),
l AS (
  SELECT s.*,
         LAG(from_club_id) OVER w AS prev_from, LAG(to_club_id) OVER w AS prev_to, LAG(transfer_date) OVER w AS prev_date
  FROM s WINDOW w AS (PARTITION BY player_id ORDER BY seq)),
r AS (
  SELECT l.*,
         CASE WHEN prev_from = to_club_id AND prev_to = from_club_id
               AND date_diff('day', prev_date, transfer_date) BETWEEN 14 AND 760
               AND COALESCE(transfer_fee, 0) = 0
               AND from_club_id NOT IN (515, 123, 75, 2113, 12604) AND to_club_id NOT IN (515, 123, 75, 2113, 12604)
              THEN 1 ELSE 0 END AS is_return
  FROM l),
c AS (  -- chain id: increments at every leg that is not a return
  SELECT r.*, SUM(1 - is_return) OVER (PARTITION BY player_id ORDER BY seq ROWS UNBOUNDED PRECEDING) AS chain_id
  FROM r),
p AS (
  SELECT c.*,
         ROW_NUMBER() OVER (PARTITION BY player_id, chain_id ORDER BY seq) AS chain_pos,
         COUNT(*) OVER (PARTITION BY player_id, chain_id) AS chain_len
  FROM c)
SELECT p.* EXCLUDE (prev_from, prev_to, prev_date),
  CASE
    WHEN chain_len > 1 AND chain_pos % 2 = 0 THEN 'end of loan'
    WHEN chain_len > 1 AND chain_pos < chain_len THEN 'loan'
    WHEN transfer_fee > 0 THEN 'paid'
    WHEN 75 IN (from_club_id, to_club_id) THEN 'unknown'
    WHEN to_club_id IN (123, 515, 2113) THEN 'free'
    WHEN from_club_id IN (515, 2113) THEN 'free'
    WHEN transfer_fee = 0 THEN 'free'
    WHEN from_club_id = 12604 OR regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
         OR regexp_matches(to_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)') THEN 'internal'
    ELSE 'unknown'
  END AS transfer_class,
  CASE
    WHEN chain_len > 1 AND chain_pos % 2 = 0 THEN 'end of loan'
    WHEN chain_len > 1 AND chain_pos < chain_len THEN CASE WHEN transfer_fee > 0 THEN 'loan with fee' ELSE 'loan' END
    WHEN transfer_fee > 0 THEN 'paid'
    WHEN 75 IN (from_club_id, to_club_id) THEN 'unknown club'
    WHEN to_club_id = 123 THEN 'free: retired'
    WHEN to_club_id IN (515, 2113) THEN 'free: released / contract ended'
    WHEN from_club_id IN (515, 2113) THEN 'free: free agent signed'
    WHEN transfer_fee = 0 THEN 'free: club to club'
    WHEN from_club_id = 12604 OR regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
         OR regexp_matches(to_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)') THEN 'internal: youth/reserve move'
    ELSE 'unknown: fee not disclosed'
  END AS transfer_subclass,
  -- a club lost a player without a fee (excludes loans, loan returns, youth moves, special 'from' clubs)
  CASE WHEN (chain_len = 1 OR chain_pos = chain_len) AND chain_pos % 2 = 1
            AND COALESCE(transfer_fee, 0) = 0
            AND from_club_id NOT IN (515, 123, 75, 2113, 12604)
            AND NOT regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
            AND (transfer_fee = 0 OR to_club_id IN (123, 515, 2113))
       THEN 1 ELSE 0 END AS is_free_departure
FROM p;

-- [P4.26] CLASSIFICATION RESULT: rows per class
SELECT transfer_class, COUNT(*) AS n, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM transfers_classified GROUP BY 1 ORDER BY 2 DESC;

-- [P4.27] CLASSIFICATION RESULT: rows per subclass
SELECT transfer_class, transfer_subclass, COUNT(*) AS n, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM transfers_classified GROUP BY 1, 2 ORDER BY 1, 3 DESC;

-- [P4.28] DECISION METRIC: share classified as paid/free/loan/end of loan (strict) and incl. internal youth moves
SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE transfer_class IN ('paid','free','loan','end of loan')) AS classified_strict,
       ROUND(100.0 * COUNT(*) FILTER (WHERE transfer_class IN ('paid','free','loan','end of loan')) / COUNT(*), 1) AS pct_strict,
       COUNT(*) FILTER (WHERE transfer_class <> 'unknown') AS classified_incl_internal,
       ROUND(100.0 * COUNT(*) FILTER (WHERE transfer_class <> 'unknown') / COUNT(*), 1) AS pct_incl_internal,
       COUNT(*) FILTER (WHERE transfer_class = 'unknown') AS unknown
FROM transfers_classified;

-- [P4.29] Same metric, senior moves only (neither side a youth/reserve team)
SELECT COUNT(*) AS total,
       ROUND(100.0 * COUNT(*) FILTER (WHERE transfer_class IN ('paid','free','loan','end of loan')) / COUNT(*), 1) AS pct_classified,
       COUNT(*) FILTER (WHERE transfer_class = 'unknown') AS unknown
FROM transfers_classified
WHERE NOT regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
  AND NOT regexp_matches(to_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)');

-- [P4.30] Same metric, senior moves in the last three seasons (23/24-25/26), value >= 1m
SELECT COUNT(*) AS total,
       ROUND(100.0 * COUNT(*) FILTER (WHERE transfer_class IN ('paid','free','loan','end of loan')) / COUNT(*), 1) AS pct_classified,
       COUNT(*) FILTER (WHERE transfer_class = 'unknown') AS unknown
FROM transfers_classified
WHERE transfer_season IN ('23/24','24/25','25/26') AND market_value_in_eur >= 1000000;

-- [P4.31] Validation sample: known 2022-2026 moves (loans, loan-backs, same-day legs, free transfers)
SELECT player_name, transfer_date, from_club_name, to_club_name, transfer_fee, market_value_in_eur, transfer_subclass
FROM transfers_classified
WHERE player_name IN ('Marcus Rashford','Nicolas Jackson','Piero Hincapié','Loïs Openda','Kevin De Bruyne',
                      'Leroy Sané','Jonathan Tah','Jonathan David','Trent Alexander-Arnold','Victor Osimhen',
                      'Giorgi Mamardashvili','Xavi Simons','Leo Østigård','Bryan Zaragoza','Sofyan Amrabat',
                      'Marc Guiu','Destiny Udogie')
  AND transfer_date >= DATE '2022-07-01' AND transfer_date <= DATE '2026-07-06'
ORDER BY player_name, transfer_date;

-- [P4.32] Unknown rows: what remains (by subclass and top club pairs)
SELECT from_club_name, to_club_name, transfer_fee, COUNT(*) AS n FROM transfers_classified
WHERE transfer_class = 'unknown' GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 15;

-- [P4.33] Unknown rows by season (are they concentrated in old data?)
SELECT transfer_season, COUNT(*) FILTER (WHERE transfer_class = 'unknown') AS unknown, COUNT(*) AS total,
       ROUND(100.0 * COUNT(*) FILTER (WHERE transfer_class = 'unknown') / COUNT(*), 1) AS pct_unknown
FROM transfers_classified WHERE transfer_season >= '15/16' AND transfer_season < '90/91'
GROUP BY 1 ORDER BY 1;

-- [P4.34] Possible misclassification check: 'free: club to club' legs whose player later goes back to the from-club (any gap)
SELECT COUNT(*) AS free_legs,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM transfers t2 WHERE t2.player_id = tc.player_id
                         AND t2.transfer_date > tc.transfer_date AND t2.from_club_id = tc.to_club_id
                         AND t2.to_club_id = tc.from_club_id)) AS later_returned
FROM transfers_classified tc WHERE transfer_subclass = 'free: club to club';

-- [P4.35] Free departures with value at transfer >= 5m, per season (label-based, loans excluded)
SELECT transfer_season, COUNT(*) AS free_departures_5m_plus, SUM(market_value_in_eur) AS value_given_away
FROM transfers_classified
WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000
  AND transfer_season IN ('22/23','23/24','24/25','25/26','26/27')
GROUP BY 1 ORDER BY 1;

-- [P4.36] Instruction template version (fee 0 or NULL, value >= 5m, season 25/26) WITHOUT loan exclusion, for comparison
SELECT COUNT(*) AS naive_count FROM transfers
WHERE transfer_season = '25/26' AND COALESCE(transfer_fee, 0) = 0 AND market_value_in_eur >= 5000000;

-- [P4.37] Summer windows only (transfer_date June-September) - free departures >= 5m
SELECT year(transfer_date) AS summer, COUNT(*) AS n, SUM(market_value_in_eur) AS value
FROM transfers_classified
WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000 AND month(transfer_date) BETWEEN 6 AND 9
  AND year(transfer_date) BETWEEN 2023 AND 2026 GROUP BY 1 ORDER BY 1;

-- [P4.38] Top 10 free departures by value, last three complete seasons (23/24-25/26)
SELECT transfer_season, transfer_date, player_name, from_club_name, to_club_name, transfer_subclass, market_value_in_eur
FROM transfers_classified
WHERE is_free_departure = 1 AND transfer_season IN ('23/24','24/25','25/26')
ORDER BY market_value_in_eur DESC NULLS LAST LIMIT 10;

-- [P4.39] Top 10 free departures, partial season 26/27 (data up to cut-off)
SELECT transfer_date, player_name, from_club_name, to_club_name, transfer_subclass, market_value_in_eur
FROM transfers_classified
WHERE is_free_departure = 1 AND transfer_season = '26/27'
ORDER BY market_value_in_eur DESC NULLS LAST LIMIT 10;


-- =====================================================
-- Phase 5: Appearances
-- =====================================================

-- [P5.1] Size and range
SELECT COUNT(*) AS rows, COUNT(DISTINCT player_id) AS players,
       COUNT(DISTINCT game_id) AS games, MIN(date) AS min_d, MAX(date) AS max_d
FROM appearances;

-- [P5.2] Appearances by competition (top 15) with competition type
SELECT a.competition_id, c.name, c.type, COUNT(*) AS n
FROM appearances a LEFT JOIN competitions c USING (competition_id)
GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 15;

-- [P5.3] Appearances by competition type
SELECT c.type, COUNT(*) AS n, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM appearances a LEFT JOIN competitions c USING (competition_id) GROUP BY 1 ORDER BY 2 DESC;

-- [P5.4] Nulls, zeros and maxima
SELECT COUNT(*) FILTER (WHERE minutes_played IS NULL) AS minutes_null,
       COUNT(*) FILTER (WHERE minutes_played = 0) AS minutes_zero,
       COUNT(*) FILTER (WHERE minutes_played < 0) AS minutes_neg,
       COUNT(*) FILTER (WHERE minutes_played > 120) AS minutes_over_120,
       MAX(minutes_played) AS max_minutes,
       COUNT(*) FILTER (WHERE goals IS NULL) AS goals_null, MAX(goals) AS max_goals,
       COUNT(*) FILTER (WHERE assists IS NULL) AS assists_null, MAX(assists) AS max_assists,
       COUNT(*) FILTER (WHERE yellow_cards > 2 OR red_cards > 1) AS card_anomalies,
       COUNT(*) AS total
FROM appearances;

-- [P5.5] Minutes distribution
SELECT CASE WHEN minutes_played <= 0 THEN 'a 0' WHEN minutes_played < 15 THEN 'b 1-14'
            WHEN minutes_played < 45 THEN 'c 15-44' WHEN minutes_played < 90 THEN 'd 45-89'
            WHEN minutes_played = 90 THEN 'e 90' ELSE 'f >90' END AS band, COUNT(*) AS n
FROM appearances GROUP BY 1 ORDER BY 1;

-- [P5.6] Rows with minutes > 90: are they extra-time games?
SELECT minutes_played, COUNT(*) AS n FROM appearances WHERE minutes_played > 90
GROUP BY 1 ORDER BY 1;

-- [P5.7] Players with 4+ goals in one game (plausibility spot check)
SELECT a.date, a.player_name, a.goals, a.assists, a.minutes_played, a.competition_id
FROM appearances a WHERE goals >= 4 ORDER BY goals DESC, date DESC LIMIT 10;

-- [P5.8] DECISION METRIC: share of appearances with goals, assists, minutes present and plausible
SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE goals IS NOT NULL AND assists IS NOT NULL AND minutes_played IS NOT NULL
                          AND minutes_played BETWEEN 1 AND 125 AND goals BETWEEN 0 AND 6 AND assists BETWEEN 0 AND 6) AS plausible,
       ROUND(100.0 * COUNT(*) FILTER (WHERE goals IS NOT NULL AND assists IS NOT NULL AND minutes_played IS NOT NULL
                          AND minutes_played BETWEEN 1 AND 125 AND goals BETWEEN 0 AND 6 AND assists BETWEEN 0 AND 6) / COUNT(*), 2) AS pct
FROM appearances;

-- [P5.9] Consistency: sum of appearance goals vs final score, big-5 league games 2012-2025
WITH g AS (SELECT CAST(game_id AS INTEGER) AS game_id, home_club_goals + away_club_goals AS score_goals
           FROM games WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1')),
     a AS (SELECT game_id, SUM(goals) AS app_goals, SUM(assists) AS app_assists, SUM(minutes_played) AS mins,
                  COUNT(*) AS n FROM appearances GROUP BY 1)
SELECT COUNT(*) AS games,
       COUNT(*) FILTER (WHERE a.app_goals = g.score_goals) AS equal,
       COUNT(*) FILTER (WHERE a.app_goals < g.score_goals) AS app_less,
       COUNT(*) FILTER (WHERE a.app_goals > g.score_goals) AS app_more,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.app_goals = g.score_goals) / COUNT(*), 1) AS pct_equal,
       SUM(g.score_goals) AS score_goals, SUM(a.app_goals) AS app_goals,
       ROUND(AVG(a.mins), 0) AS avg_total_minutes_per_game, ROUND(AVG(a.n), 1) AS avg_rows_per_game
FROM g JOIN a USING (game_id);

-- [P5.10] Own goals explain the gap? (game_events goal descriptions mentioning own goal, big-5)
SELECT COUNT(*) AS own_goal_events FROM game_events e
JOIN games g ON g.game_id = e.game_id
WHERE e.type = 'Goals' AND e.description ILIKE '%own-goal%'
  AND g.competition_id IN ('GB1','ES1','IT1','L1','FR1');

-- [P5.11] Do appearances include unused substitutes? (lineup rows vs appearance rows, big-5 2024)
WITH g AS (SELECT CAST(game_id AS INTEGER) AS game_id FROM games
           WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2024')
SELECT (SELECT COUNT(*) FROM game_lineups l JOIN g USING (game_id)) AS lineup_rows,
       (SELECT COUNT(*) FROM game_lineups l JOIN g USING (game_id) WHERE l.type = 'starting_lineup') AS starters,
       (SELECT COUNT(*) FROM appearances a JOIN g USING (game_id)) AS appearance_rows;

-- [P5.12] TASK: value >= 5m players with >= 10 appearances in seasons 2024/25 + 2025/26
WITH base AS (SELECT player_id, current_club_domestic_competition_id AS comp FROM players WHERE market_value_in_eur >= 5000000),
     a AS (SELECT a.player_id, COUNT(*) AS apps, SUM(minutes_played) AS mins
           FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
           WHERE g.season IN ('2024', '2025') GROUP BY 1)
SELECT COUNT(*) AS players_5m,
       COUNT(*) FILTER (WHERE a.apps >= 10) AS with_10_apps,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.apps >= 10) / COUNT(*), 1) AS pct,
       COUNT(*) FILTER (WHERE a.player_id IS NULL) AS with_no_apps
FROM base b LEFT JOIN a USING (player_id);

-- [P5.13] Same, by date window (2024-07-06..2026-07-06) and split by whether the club plays in a covered league
WITH base AS (
  SELECT p.player_id, p.current_club_domestic_competition_id IS NOT NULL AS covered_club
  FROM players p WHERE market_value_in_eur >= 5000000),
     a AS (SELECT player_id, COUNT(*) AS apps FROM appearances
           WHERE date BETWEEN DATE '2024-07-06' AND DATE '2026-07-06' GROUP BY 1)
SELECT covered_club, COUNT(*) AS players_5m,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.apps >= 10) / COUNT(*), 1) AS pct_10_apps
FROM base b LEFT JOIN a USING (player_id) GROUP BY 1;

-- [P5.14] Value >= 5m players without 10 apps: who are they? (sample)
WITH a AS (SELECT player_id, COUNT(*) AS apps FROM appearances
           WHERE date BETWEEN DATE '2024-07-06' AND DATE '2026-07-06' GROUP BY 1)
SELECT p.name, p.current_club_name, p.current_club_domestic_competition_id AS comp, p.last_season,
       p.market_value_in_eur, COALESCE(a.apps, 0) AS apps
FROM players p LEFT JOIN a USING (player_id)
WHERE p.market_value_in_eur >= 5000000 AND COALESCE(a.apps, 0) < 10
ORDER BY p.market_value_in_eur DESC LIMIT 15;

-- [P5.15] game_events types and description examples
SELECT type, COUNT(*) AS n, ANY_VALUE(description) AS example FROM game_events GROUP BY 1 ORDER BY 2 DESC;

-- [P5.16] game_lineups positions (per-game position)
SELECT position, COUNT(*) AS n FROM game_lineups GROUP BY 1 ORDER BY 2 DESC;

-- [P5.17] players.position / sub_position
SELECT position, sub_position, COUNT(*) AS n FROM players GROUP BY 1, 2 ORDER BY 1, 3 DESC;

-- [P5.18] club_games columns usable for defenders/GK (goals conceded, clean sheets): sample
SELECT * FROM club_games LIMIT 3;

-- [P5.19] Appearance coverage per first-tier league: seasons with games vs seasons with appearances
WITH g AS (SELECT competition_id, season, COUNT(*) AS games FROM games GROUP BY 1, 2),
     a AS (SELECT g.competition_id, g.season, COUNT(DISTINCT a.game_id) AS games_with_app
           FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id GROUP BY 1, 2)
SELECT c.competition_id, c.country_name,
       MIN(g.season) AS first_season_games, MAX(g.season) AS last_season_games,
       MIN(a.season) FILTER (WHERE a.games_with_app > 0) AS first_season_app,
       SUM(g.games) FILTER (WHERE g.season = '2025') AS games_2025,
       SUM(a.games_with_app) FILTER (WHERE g.season = '2025') AS games_with_app_2025
FROM competitions c LEFT JOIN g USING (competition_id) LEFT JOIN a USING (competition_id, season)
WHERE c.sub_type = 'first_tier' GROUP BY 1, 2 ORDER BY first_season_app NULLS LAST, 1;

-- [P5.20] Games with no appearance rows at all, by competition (all seasons)
SELECT g.competition_id, COUNT(*) AS games_without_app
FROM games g LEFT JOIN (SELECT DISTINCT game_id FROM appearances) a ON CAST(g.game_id AS INTEGER) = a.game_id
WHERE a.game_id IS NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 15;


-- =====================================================
-- Phase 6: Keys and referential integrity
-- =====================================================

-- [P6.1] Key type mismatches (from DESCRIBE)
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE column_name IN ('player_id','game_id','club_id','current_club_id','player_club_id','player_current_club_id',
                      'home_club_id','away_club_id','from_club_id','to_club_id','competition_id','country_id',
                      'opponent_id','domestic_competition_id','current_national_team_id','national_team_id')
ORDER BY column_name, table_name;

-- [P6.2] Orphans: appearances -> players
SELECT COUNT(*) AS orphans, ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM appearances), 3) AS pct
FROM appearances a LEFT JOIN players p USING (player_id) WHERE p.player_id IS NULL;

-- [P6.3] Orphans: appearances -> games (cast games.game_id VARCHAR -> INT)
SELECT COUNT(*) AS orphans, ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM appearances), 3) AS pct
FROM appearances a LEFT JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id WHERE g.game_id IS NULL;

-- [P6.4] Can games.game_id always be cast to INTEGER?
SELECT COUNT(*) FILTER (WHERE TRY_CAST(game_id AS INTEGER) IS NULL) AS not_castable FROM games;

-- [P6.5] Orphans: player_valuations -> players
SELECT COUNT(*) AS orphans, ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM player_valuations), 3) AS pct
FROM player_valuations v LEFT JOIN players p USING (player_id) WHERE p.player_id IS NULL;

-- [P6.6] Orphans: transfers -> players
SELECT COUNT(*) AS orphans, ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transfers), 3) AS pct
FROM transfers t LEFT JOIN players p USING (player_id) WHERE p.player_id IS NULL;

-- [P6.7] Players' current club not in clubs (current_club_id VARCHAR vs clubs.club_id VARCHAR)
SELECT COUNT(*) AS players_without_club,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM players), 2) AS pct
FROM players p LEFT JOIN clubs c ON p.current_club_id = c.club_id
WHERE p.current_club_id IS NOT NULL AND c.club_id IS NULL;

-- [P6.8] ...and those players: do they have a current_club_name / competition? (explains the orphan)
SELECT p.current_club_name IS NULL AS no_club_name, p.current_club_domestic_competition_id IS NULL AS no_comp,
       COUNT(*) AS n
FROM players p LEFT JOIN clubs c ON p.current_club_id = c.club_id
WHERE c.club_id IS NULL GROUP BY 1, 2;

-- [P6.9] Orphans: appearances.player_club_id -> clubs
SELECT COUNT(*) AS orphans, ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM appearances), 2) AS pct
FROM appearances a LEFT JOIN clubs c ON CAST(a.player_club_id AS VARCHAR) = c.club_id WHERE c.club_id IS NULL;

-- [P6.10] Orphan appearance clubs by competition type (expected: cup / European opponents outside covered leagues)
SELECT co.type, COUNT(*) AS n
FROM appearances a LEFT JOIN clubs c ON CAST(a.player_club_id AS VARCHAR) = c.club_id
LEFT JOIN competitions co ON co.competition_id = a.competition_id
WHERE c.club_id IS NULL GROUP BY 1 ORDER BY 2 DESC;

-- [P6.11] Orphans: games home/away club -> clubs
SELECT COUNT(*) FILTER (WHERE ch.club_id IS NULL) AS home_orphans,
       COUNT(*) FILTER (WHERE ca.club_id IS NULL) AS away_orphans,
       COUNT(*) AS games
FROM games g
LEFT JOIN clubs ch ON CAST(g.home_club_id AS VARCHAR) = ch.club_id
LEFT JOIN clubs ca ON CAST(g.away_club_id AS VARCHAR) = ca.club_id;

-- [P6.12] Orphans: games home/away club -> clubs, domestic league games only
SELECT COUNT(*) FILTER (WHERE ch.club_id IS NULL OR ca.club_id IS NULL) AS games_with_orphan_club, COUNT(*) AS league_games
FROM games g
LEFT JOIN clubs ch ON CAST(g.home_club_id AS VARCHAR) = ch.club_id
LEFT JOIN clubs ca ON CAST(g.away_club_id AS VARCHAR) = ca.club_id
WHERE g.competition_type = 'domestic_league';

-- [P6.13] games with null home/away club id or name
SELECT COUNT(*) FILTER (WHERE home_club_id IS NULL OR away_club_id IS NULL) AS null_ids,
       COUNT(*) FILTER (WHERE home_club_name IS NULL OR away_club_name IS NULL) AS null_names
FROM games;

-- [P6.14] Orphans: transfers from/to club -> clubs (expected high: clubs outside covered leagues)
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE cf.club_id IS NULL) / COUNT(*), 1) AS pct_from_orphan,
       ROUND(100.0 * COUNT(*) FILTER (WHERE ct.club_id IS NULL) / COUNT(*), 1) AS pct_to_orphan,
       COUNT(DISTINCT t.from_club_id) FILTER (WHERE cf.club_id IS NULL) AS distinct_from_clubs_missing
FROM transfers t
LEFT JOIN clubs cf ON CAST(t.from_club_id AS VARCHAR) = cf.club_id
LEFT JOIN clubs ct ON CAST(t.to_club_id AS VARCHAR) = ct.club_id;

-- [P6.15] Orphans: player_valuations.current_club_id -> clubs
SELECT COUNT(*) AS orphans, ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM player_valuations), 1) AS pct
FROM player_valuations v LEFT JOIN clubs c ON CAST(v.current_club_id AS VARCHAR) = c.club_id WHERE c.club_id IS NULL;

-- [P6.16] Orphans: competition ids (games, appearances, clubs, players) -> competitions
SELECT 'games' AS src, COUNT(*) AS orphans, STRING_AGG(DISTINCT g.competition_id, ',') AS ids
FROM games g LEFT JOIN competitions c USING (competition_id) WHERE c.competition_id IS NULL
UNION ALL
SELECT 'appearances', COUNT(*), STRING_AGG(DISTINCT a.competition_id, ',')
FROM appearances a LEFT JOIN competitions c USING (competition_id) WHERE c.competition_id IS NULL
UNION ALL
SELECT 'clubs', COUNT(*), STRING_AGG(DISTINCT cl.domestic_competition_id, ',')
FROM clubs cl LEFT JOIN competitions c ON c.competition_id = cl.domestic_competition_id WHERE c.competition_id IS NULL
UNION ALL
SELECT 'players', COUNT(*), STRING_AGG(DISTINCT p.current_club_domestic_competition_id, ',')
FROM players p LEFT JOIN competitions c ON c.competition_id = p.current_club_domestic_competition_id
WHERE p.current_club_domestic_competition_id IS NOT NULL AND c.competition_id IS NULL;

-- [P6.17] game_lineups / game_events -> players and games
SELECT (SELECT COUNT(*) FROM game_lineups l LEFT JOIN players p USING (player_id) WHERE p.player_id IS NULL) AS lineup_player_orphans,
       (SELECT COUNT(*) FROM game_lineups) AS lineup_rows,
       (SELECT COUNT(*) FROM game_lineups l LEFT JOIN games g ON CAST(g.game_id AS INTEGER) = l.game_id WHERE g.game_id IS NULL) AS lineup_game_orphans,
       (SELECT COUNT(*) FROM game_events e LEFT JOIN players p USING (player_id) WHERE p.player_id IS NULL) AS event_player_orphans,
       (SELECT COUNT(*) FROM game_events) AS event_rows,
       (SELECT COUNT(*) FROM game_events e LEFT JOIN games g USING (game_id) WHERE g.game_id IS NULL) AS event_game_orphans;

-- [P6.18] Duplicate keys in every table
SELECT 'players.player_id' AS key, COUNT(*) AS dup_keys FROM (SELECT player_id FROM players GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL SELECT 'games.game_id', COUNT(*) FROM (SELECT game_id FROM games GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL SELECT 'appearances.appearance_id', COUNT(*) FROM (SELECT appearance_id FROM appearances GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL SELECT 'appearances.(game_id,player_id)', COUNT(*) FROM (SELECT game_id, player_id FROM appearances GROUP BY 1, 2 HAVING COUNT(*) > 1)
UNION ALL SELECT 'clubs.club_id', COUNT(*) FROM (SELECT club_id FROM clubs GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL SELECT 'competitions.competition_id', COUNT(*) FROM (SELECT competition_id FROM competitions GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL SELECT 'player_valuations.(player_id,date)', COUNT(*) FROM (SELECT player_id, date FROM player_valuations GROUP BY 1, 2 HAVING COUNT(*) > 1)
UNION ALL SELECT 'transfers.(player_id,date,from,to)', COUNT(*) FROM (SELECT player_id, transfer_date, from_club_id, to_club_id FROM transfers GROUP BY ALL HAVING COUNT(*) > 1)
UNION ALL SELECT 'club_games.(game_id,club_id)', COUNT(*) FROM (SELECT game_id, club_id FROM club_games GROUP BY 1, 2 HAVING COUNT(*) > 1)
UNION ALL SELECT 'game_lineups.game_lineups_id', COUNT(*) FROM (SELECT game_lineups_id FROM game_lineups GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL SELECT 'game_lineups.(game_id,player_id)', COUNT(*) FROM (SELECT game_id, player_id FROM game_lineups GROUP BY 1, 2 HAVING COUNT(*) > 1)
UNION ALL SELECT 'game_events.game_event_id', COUNT(*) FROM (SELECT game_event_id FROM game_events GROUP BY 1 HAVING COUNT(*) > 1);

-- [P6.19] Exact duplicate transfer rows (all columns)
SELECT (SELECT COUNT(*) FROM transfers) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM transfers)) AS exact_duplicate_rows;

-- [P6.20] Duplicate transfer keys: sample
SELECT t.* FROM transfers t JOIN (SELECT player_id, transfer_date, from_club_id, to_club_id FROM transfers GROUP BY ALL HAVING COUNT(*) > 1) d
USING (player_id, transfer_date, from_club_id, to_club_id) ORDER BY player_id, transfer_date LIMIT 10;

-- [P6.21] Duplicate lineup (game_id, player_id): sample
SELECT l.* FROM game_lineups l JOIN (SELECT game_id, player_id FROM game_lineups GROUP BY 1, 2 HAVING COUNT(*) > 1) d
USING (game_id, player_id) ORDER BY game_id, player_id LIMIT 6;

-- [P6.22] appearance_id format = '<game_id>_<player_id>'?
SELECT COUNT(*) FILTER (WHERE appearance_id <> CAST(game_id AS VARCHAR) || '_' || CAST(player_id AS VARCHAR)) AS mismatches
FROM appearances;

-- [P6.23] appearances: player_club_id is one of the two clubs in the game; dates agree with games
SELECT COUNT(*) FILTER (WHERE a.player_club_id NOT IN (g.home_club_id, g.away_club_id)) AS club_not_in_game,
       COUNT(*) FILTER (WHERE a.date <> g.date) AS date_mismatch,
       COUNT(*) FILTER (WHERE a.competition_id <> g.competition_id) AS comp_mismatch,
       COUNT(*) AS total
FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id;

-- [P6.24] club_games: exactly two rows per game?
SELECT n_rows, COUNT(*) AS games FROM (SELECT game_id, COUNT(*) AS n_rows FROM club_games GROUP BY 1) GROUP BY 1 ORDER BY 1;

-- [P6.25] Clubs table coverage: clubs per domestic competition
SELECT domestic_competition_id, COUNT(*) AS clubs FROM clubs GROUP BY 1 ORDER BY 2 DESC;

-- [P6.26] Missing competitions: what are they? (games referencing codes absent from competitions)
SELECT g.competition_id, g.competition_type, COUNT(*) AS games, MIN(g.season) AS first_season, MAX(g.season) AS last_season
FROM games g LEFT JOIN competitions c USING (competition_id) WHERE c.competition_id IS NULL GROUP BY 1, 2 ORDER BY 3 DESC;

-- [P6.27] Players in lineups but not in players: which clubs/competitions? (top)
SELECT g.competition_id, COUNT(*) AS n FROM game_lineups l
LEFT JOIN players p USING (player_id) JOIN games g ON CAST(g.game_id AS INTEGER) = l.game_id
WHERE p.player_id IS NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 10;


-- =====================================================
-- Phase 7: Data quality log
-- =====================================================

-- [P7.1] Null % per column: appearances
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "appearance_id" IS NULL)/COUNT(*),2) AS "appearance_id", ROUND(100.0*COUNT(*) FILTER (WHERE "game_id" IS NULL)/COUNT(*),2) AS "game_id", ROUND(100.0*COUNT(*) FILTER (WHERE "player_id" IS NULL)/COUNT(*),2) AS "player_id", ROUND(100.0*COUNT(*) FILTER (WHERE "player_club_id" IS NULL)/COUNT(*),2) AS "player_club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "player_current_club_id" IS NULL)/COUNT(*),2) AS "player_current_club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "date" IS NULL)/COUNT(*),2) AS "date", ROUND(100.0*COUNT(*) FILTER (WHERE "player_name" IS NULL)/COUNT(*),2) AS "player_name", ROUND(100.0*COUNT(*) FILTER (WHERE "competition_id" IS NULL)/COUNT(*),2) AS "competition_id", ROUND(100.0*COUNT(*) FILTER (WHERE "yellow_cards" IS NULL)/COUNT(*),2) AS "yellow_cards", ROUND(100.0*COUNT(*) FILTER (WHERE "red_cards" IS NULL)/COUNT(*),2) AS "red_cards", ROUND(100.0*COUNT(*) FILTER (WHERE "goals" IS NULL)/COUNT(*),2) AS "goals", ROUND(100.0*COUNT(*) FILTER (WHERE "assists" IS NULL)/COUNT(*),2) AS "assists", ROUND(100.0*COUNT(*) FILTER (WHERE "minutes_played" IS NULL)/COUNT(*),2) AS "minutes_played" FROM appearances) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.2] Null % per column: club_games
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "game_id" IS NULL)/COUNT(*),2) AS "game_id", ROUND(100.0*COUNT(*) FILTER (WHERE "club_id" IS NULL)/COUNT(*),2) AS "club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "own_goals" IS NULL)/COUNT(*),2) AS "own_goals", ROUND(100.0*COUNT(*) FILTER (WHERE "own_position" IS NULL)/COUNT(*),2) AS "own_position", ROUND(100.0*COUNT(*) FILTER (WHERE "own_manager_name" IS NULL)/COUNT(*),2) AS "own_manager_name", ROUND(100.0*COUNT(*) FILTER (WHERE "opponent_id" IS NULL)/COUNT(*),2) AS "opponent_id", ROUND(100.0*COUNT(*) FILTER (WHERE "opponent_goals" IS NULL)/COUNT(*),2) AS "opponent_goals", ROUND(100.0*COUNT(*) FILTER (WHERE "opponent_position" IS NULL)/COUNT(*),2) AS "opponent_position", ROUND(100.0*COUNT(*) FILTER (WHERE "opponent_manager_name" IS NULL)/COUNT(*),2) AS "opponent_manager_name", ROUND(100.0*COUNT(*) FILTER (WHERE "hosting" IS NULL)/COUNT(*),2) AS "hosting", ROUND(100.0*COUNT(*) FILTER (WHERE "is_win" IS NULL)/COUNT(*),2) AS "is_win" FROM club_games) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.3] Null % per column: clubs
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "club_id" IS NULL)/COUNT(*),2) AS "club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "club_code" IS NULL)/COUNT(*),2) AS "club_code", ROUND(100.0*COUNT(*) FILTER (WHERE "name" IS NULL)/COUNT(*),2) AS "name", ROUND(100.0*COUNT(*) FILTER (WHERE "domestic_competition_id" IS NULL)/COUNT(*),2) AS "domestic_competition_id", ROUND(100.0*COUNT(*) FILTER (WHERE "total_market_value" IS NULL)/COUNT(*),2) AS "total_market_value", ROUND(100.0*COUNT(*) FILTER (WHERE "squad_size" IS NULL)/COUNT(*),2) AS "squad_size", ROUND(100.0*COUNT(*) FILTER (WHERE "average_age" IS NULL)/COUNT(*),2) AS "average_age", ROUND(100.0*COUNT(*) FILTER (WHERE "foreigners_number" IS NULL)/COUNT(*),2) AS "foreigners_number", ROUND(100.0*COUNT(*) FILTER (WHERE "foreigners_percentage" IS NULL)/COUNT(*),2) AS "foreigners_percentage", ROUND(100.0*COUNT(*) FILTER (WHERE "national_team_players" IS NULL)/COUNT(*),2) AS "national_team_players", ROUND(100.0*COUNT(*) FILTER (WHERE "stadium_name" IS NULL)/COUNT(*),2) AS "stadium_name", ROUND(100.0*COUNT(*) FILTER (WHERE "stadium_seats" IS NULL)/COUNT(*),2) AS "stadium_seats", ROUND(100.0*COUNT(*) FILTER (WHERE "net_transfer_record" IS NULL)/COUNT(*),2) AS "net_transfer_record", ROUND(100.0*COUNT(*) FILTER (WHERE "coach_name" IS NULL)/COUNT(*),2) AS "coach_name", ROUND(100.0*COUNT(*) FILTER (WHERE "last_season" IS NULL)/COUNT(*),2) AS "last_season", ROUND(100.0*COUNT(*) FILTER (WHERE "filename" IS NULL)/COUNT(*),2) AS "filename", ROUND(100.0*COUNT(*) FILTER (WHERE "url" IS NULL)/COUNT(*),2) AS "url" FROM clubs) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.4] Null % per column: competitions
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "competition_id" IS NULL)/COUNT(*),2) AS "competition_id", ROUND(100.0*COUNT(*) FILTER (WHERE "competition_code" IS NULL)/COUNT(*),2) AS "competition_code", ROUND(100.0*COUNT(*) FILTER (WHERE "name" IS NULL)/COUNT(*),2) AS "name", ROUND(100.0*COUNT(*) FILTER (WHERE "sub_type" IS NULL)/COUNT(*),2) AS "sub_type", ROUND(100.0*COUNT(*) FILTER (WHERE "type" IS NULL)/COUNT(*),2) AS "type", ROUND(100.0*COUNT(*) FILTER (WHERE "country_id" IS NULL)/COUNT(*),2) AS "country_id", ROUND(100.0*COUNT(*) FILTER (WHERE "country_name" IS NULL)/COUNT(*),2) AS "country_name", ROUND(100.0*COUNT(*) FILTER (WHERE "domestic_league_code" IS NULL)/COUNT(*),2) AS "domestic_league_code", ROUND(100.0*COUNT(*) FILTER (WHERE "confederation" IS NULL)/COUNT(*),2) AS "confederation", ROUND(100.0*COUNT(*) FILTER (WHERE "total_clubs" IS NULL)/COUNT(*),2) AS "total_clubs", ROUND(100.0*COUNT(*) FILTER (WHERE "url" IS NULL)/COUNT(*),2) AS "url" FROM competitions) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.5] Null % per column: countries
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "country_id" IS NULL)/COUNT(*),2) AS "country_id", ROUND(100.0*COUNT(*) FILTER (WHERE "country_name" IS NULL)/COUNT(*),2) AS "country_name", ROUND(100.0*COUNT(*) FILTER (WHERE "country_code" IS NULL)/COUNT(*),2) AS "country_code", ROUND(100.0*COUNT(*) FILTER (WHERE "confederation" IS NULL)/COUNT(*),2) AS "confederation", ROUND(100.0*COUNT(*) FILTER (WHERE "total_clubs" IS NULL)/COUNT(*),2) AS "total_clubs", ROUND(100.0*COUNT(*) FILTER (WHERE "total_players" IS NULL)/COUNT(*),2) AS "total_players", ROUND(100.0*COUNT(*) FILTER (WHERE "average_age" IS NULL)/COUNT(*),2) AS "average_age", ROUND(100.0*COUNT(*) FILTER (WHERE "url" IS NULL)/COUNT(*),2) AS "url" FROM countries) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.6] Null % per column: game_events
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "game_event_id" IS NULL)/COUNT(*),2) AS "game_event_id", ROUND(100.0*COUNT(*) FILTER (WHERE "date" IS NULL)/COUNT(*),2) AS "date", ROUND(100.0*COUNT(*) FILTER (WHERE "game_id" IS NULL)/COUNT(*),2) AS "game_id", ROUND(100.0*COUNT(*) FILTER (WHERE "minute" IS NULL)/COUNT(*),2) AS "minute", ROUND(100.0*COUNT(*) FILTER (WHERE "type" IS NULL)/COUNT(*),2) AS "type", ROUND(100.0*COUNT(*) FILTER (WHERE "club_id" IS NULL)/COUNT(*),2) AS "club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "club_name" IS NULL)/COUNT(*),2) AS "club_name", ROUND(100.0*COUNT(*) FILTER (WHERE "player_id" IS NULL)/COUNT(*),2) AS "player_id", ROUND(100.0*COUNT(*) FILTER (WHERE "description" IS NULL)/COUNT(*),2) AS "description", ROUND(100.0*COUNT(*) FILTER (WHERE "player_in_id" IS NULL)/COUNT(*),2) AS "player_in_id", ROUND(100.0*COUNT(*) FILTER (WHERE "player_assist_id" IS NULL)/COUNT(*),2) AS "player_assist_id" FROM game_events) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.7] Null % per column: game_lineups
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "game_lineups_id" IS NULL)/COUNT(*),2) AS "game_lineups_id", ROUND(100.0*COUNT(*) FILTER (WHERE "date" IS NULL)/COUNT(*),2) AS "date", ROUND(100.0*COUNT(*) FILTER (WHERE "game_id" IS NULL)/COUNT(*),2) AS "game_id", ROUND(100.0*COUNT(*) FILTER (WHERE "player_id" IS NULL)/COUNT(*),2) AS "player_id", ROUND(100.0*COUNT(*) FILTER (WHERE "club_id" IS NULL)/COUNT(*),2) AS "club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "player_name" IS NULL)/COUNT(*),2) AS "player_name", ROUND(100.0*COUNT(*) FILTER (WHERE "type" IS NULL)/COUNT(*),2) AS "type", ROUND(100.0*COUNT(*) FILTER (WHERE "position" IS NULL)/COUNT(*),2) AS "position", ROUND(100.0*COUNT(*) FILTER (WHERE "number" IS NULL)/COUNT(*),2) AS "number", ROUND(100.0*COUNT(*) FILTER (WHERE "team_captain" IS NULL)/COUNT(*),2) AS "team_captain" FROM game_lineups) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.8] Null % per column: games
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "game_id" IS NULL)/COUNT(*),2) AS "game_id", ROUND(100.0*COUNT(*) FILTER (WHERE "competition_id" IS NULL)/COUNT(*),2) AS "competition_id", ROUND(100.0*COUNT(*) FILTER (WHERE "season" IS NULL)/COUNT(*),2) AS "season", ROUND(100.0*COUNT(*) FILTER (WHERE "round" IS NULL)/COUNT(*),2) AS "round", ROUND(100.0*COUNT(*) FILTER (WHERE "date" IS NULL)/COUNT(*),2) AS "date", ROUND(100.0*COUNT(*) FILTER (WHERE "home_club_id" IS NULL)/COUNT(*),2) AS "home_club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "away_club_id" IS NULL)/COUNT(*),2) AS "away_club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "home_club_goals" IS NULL)/COUNT(*),2) AS "home_club_goals", ROUND(100.0*COUNT(*) FILTER (WHERE "away_club_goals" IS NULL)/COUNT(*),2) AS "away_club_goals", ROUND(100.0*COUNT(*) FILTER (WHERE "home_club_position" IS NULL)/COUNT(*),2) AS "home_club_position", ROUND(100.0*COUNT(*) FILTER (WHERE "away_club_position" IS NULL)/COUNT(*),2) AS "away_club_position", ROUND(100.0*COUNT(*) FILTER (WHERE "home_club_manager_name" IS NULL)/COUNT(*),2) AS "home_club_manager_name", ROUND(100.0*COUNT(*) FILTER (WHERE "away_club_manager_name" IS NULL)/COUNT(*),2) AS "away_club_manager_name", ROUND(100.0*COUNT(*) FILTER (WHERE "stadium" IS NULL)/COUNT(*),2) AS "stadium", ROUND(100.0*COUNT(*) FILTER (WHERE "attendance" IS NULL)/COUNT(*),2) AS "attendance", ROUND(100.0*COUNT(*) FILTER (WHERE "referee" IS NULL)/COUNT(*),2) AS "referee", ROUND(100.0*COUNT(*) FILTER (WHERE "url" IS NULL)/COUNT(*),2) AS "url", ROUND(100.0*COUNT(*) FILTER (WHERE "home_club_formation" IS NULL)/COUNT(*),2) AS "home_club_formation", ROUND(100.0*COUNT(*) FILTER (WHERE "away_club_formation" IS NULL)/COUNT(*),2) AS "away_club_formation", ROUND(100.0*COUNT(*) FILTER (WHERE "home_club_name" IS NULL)/COUNT(*),2) AS "home_club_name", ROUND(100.0*COUNT(*) FILTER (WHERE "away_club_name" IS NULL)/COUNT(*),2) AS "away_club_name", ROUND(100.0*COUNT(*) FILTER (WHERE "aggregate" IS NULL)/COUNT(*),2) AS "aggregate", ROUND(100.0*COUNT(*) FILTER (WHERE "competition_type" IS NULL)/COUNT(*),2) AS "competition_type" FROM games) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.9] Null % per column: national_teams
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "national_team_id" IS NULL)/COUNT(*),2) AS "national_team_id", ROUND(100.0*COUNT(*) FILTER (WHERE "name" IS NULL)/COUNT(*),2) AS "name", ROUND(100.0*COUNT(*) FILTER (WHERE "team_code" IS NULL)/COUNT(*),2) AS "team_code", ROUND(100.0*COUNT(*) FILTER (WHERE "country_id" IS NULL)/COUNT(*),2) AS "country_id", ROUND(100.0*COUNT(*) FILTER (WHERE "country_name" IS NULL)/COUNT(*),2) AS "country_name", ROUND(100.0*COUNT(*) FILTER (WHERE "country_code" IS NULL)/COUNT(*),2) AS "country_code", ROUND(100.0*COUNT(*) FILTER (WHERE "confederation" IS NULL)/COUNT(*),2) AS "confederation", ROUND(100.0*COUNT(*) FILTER (WHERE "team_image_url" IS NULL)/COUNT(*),2) AS "team_image_url", ROUND(100.0*COUNT(*) FILTER (WHERE "squad_size" IS NULL)/COUNT(*),2) AS "squad_size", ROUND(100.0*COUNT(*) FILTER (WHERE "average_age" IS NULL)/COUNT(*),2) AS "average_age", ROUND(100.0*COUNT(*) FILTER (WHERE "foreigners_number" IS NULL)/COUNT(*),2) AS "foreigners_number", ROUND(100.0*COUNT(*) FILTER (WHERE "foreigners_percentage" IS NULL)/COUNT(*),2) AS "foreigners_percentage", ROUND(100.0*COUNT(*) FILTER (WHERE "total_market_value" IS NULL)/COUNT(*),2) AS "total_market_value", ROUND(100.0*COUNT(*) FILTER (WHERE "coach_name" IS NULL)/COUNT(*),2) AS "coach_name", ROUND(100.0*COUNT(*) FILTER (WHERE "fifa_ranking" IS NULL)/COUNT(*),2) AS "fifa_ranking", ROUND(100.0*COUNT(*) FILTER (WHERE "last_season" IS NULL)/COUNT(*),2) AS "last_season", ROUND(100.0*COUNT(*) FILTER (WHERE "url" IS NULL)/COUNT(*),2) AS "url" FROM national_teams) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.10] Null % per column: player_valuations
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "player_id" IS NULL)/COUNT(*),2) AS "player_id", ROUND(100.0*COUNT(*) FILTER (WHERE "date" IS NULL)/COUNT(*),2) AS "date", ROUND(100.0*COUNT(*) FILTER (WHERE "market_value_in_eur" IS NULL)/COUNT(*),2) AS "market_value_in_eur", ROUND(100.0*COUNT(*) FILTER (WHERE "current_club_name" IS NULL)/COUNT(*),2) AS "current_club_name", ROUND(100.0*COUNT(*) FILTER (WHERE "current_club_id" IS NULL)/COUNT(*),2) AS "current_club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "player_club_domestic_competition_id" IS NULL)/COUNT(*),2) AS "player_club_domestic_competition_id" FROM player_valuations) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.11] Null % per column: players
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "player_id" IS NULL)/COUNT(*),2) AS "player_id", ROUND(100.0*COUNT(*) FILTER (WHERE "first_name" IS NULL)/COUNT(*),2) AS "first_name", ROUND(100.0*COUNT(*) FILTER (WHERE "last_name" IS NULL)/COUNT(*),2) AS "last_name", ROUND(100.0*COUNT(*) FILTER (WHERE "name" IS NULL)/COUNT(*),2) AS "name", ROUND(100.0*COUNT(*) FILTER (WHERE "last_season" IS NULL)/COUNT(*),2) AS "last_season", ROUND(100.0*COUNT(*) FILTER (WHERE "current_club_id" IS NULL)/COUNT(*),2) AS "current_club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "player_code" IS NULL)/COUNT(*),2) AS "player_code", ROUND(100.0*COUNT(*) FILTER (WHERE "country_of_birth" IS NULL)/COUNT(*),2) AS "country_of_birth", ROUND(100.0*COUNT(*) FILTER (WHERE "city_of_birth" IS NULL)/COUNT(*),2) AS "city_of_birth", ROUND(100.0*COUNT(*) FILTER (WHERE "country_of_citizenship" IS NULL)/COUNT(*),2) AS "country_of_citizenship", ROUND(100.0*COUNT(*) FILTER (WHERE "date_of_birth" IS NULL)/COUNT(*),2) AS "date_of_birth", ROUND(100.0*COUNT(*) FILTER (WHERE "sub_position" IS NULL)/COUNT(*),2) AS "sub_position", ROUND(100.0*COUNT(*) FILTER (WHERE "position" IS NULL)/COUNT(*),2) AS "position", ROUND(100.0*COUNT(*) FILTER (WHERE "foot" IS NULL)/COUNT(*),2) AS "foot", ROUND(100.0*COUNT(*) FILTER (WHERE "height_in_cm" IS NULL)/COUNT(*),2) AS "height_in_cm", ROUND(100.0*COUNT(*) FILTER (WHERE "contract_expiration_date" IS NULL)/COUNT(*),2) AS "contract_expiration_date", ROUND(100.0*COUNT(*) FILTER (WHERE "agent_name" IS NULL)/COUNT(*),2) AS "agent_name", ROUND(100.0*COUNT(*) FILTER (WHERE "image_url" IS NULL)/COUNT(*),2) AS "image_url", ROUND(100.0*COUNT(*) FILTER (WHERE "international_caps" IS NULL)/COUNT(*),2) AS "international_caps", ROUND(100.0*COUNT(*) FILTER (WHERE "international_goals" IS NULL)/COUNT(*),2) AS "international_goals", ROUND(100.0*COUNT(*) FILTER (WHERE "current_national_team_id" IS NULL)/COUNT(*),2) AS "current_national_team_id", ROUND(100.0*COUNT(*) FILTER (WHERE "url" IS NULL)/COUNT(*),2) AS "url", ROUND(100.0*COUNT(*) FILTER (WHERE "current_club_domestic_competition_id" IS NULL)/COUNT(*),2) AS "current_club_domestic_competition_id", ROUND(100.0*COUNT(*) FILTER (WHERE "current_club_name" IS NULL)/COUNT(*),2) AS "current_club_name", ROUND(100.0*COUNT(*) FILTER (WHERE "market_value_in_eur" IS NULL)/COUNT(*),2) AS "market_value_in_eur", ROUND(100.0*COUNT(*) FILTER (WHERE "highest_market_value_in_eur" IS NULL)/COUNT(*),2) AS "highest_market_value_in_eur" FROM players) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.12] Null % per column: transfers
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "player_id" IS NULL)/COUNT(*),2) AS "player_id", ROUND(100.0*COUNT(*) FILTER (WHERE "transfer_date" IS NULL)/COUNT(*),2) AS "transfer_date", ROUND(100.0*COUNT(*) FILTER (WHERE "transfer_season" IS NULL)/COUNT(*),2) AS "transfer_season", ROUND(100.0*COUNT(*) FILTER (WHERE "from_club_id" IS NULL)/COUNT(*),2) AS "from_club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "to_club_id" IS NULL)/COUNT(*),2) AS "to_club_id", ROUND(100.0*COUNT(*) FILTER (WHERE "from_club_name" IS NULL)/COUNT(*),2) AS "from_club_name", ROUND(100.0*COUNT(*) FILTER (WHERE "to_club_name" IS NULL)/COUNT(*),2) AS "to_club_name", ROUND(100.0*COUNT(*) FILTER (WHERE "transfer_fee" IS NULL)/COUNT(*),2) AS "transfer_fee", ROUND(100.0*COUNT(*) FILTER (WHERE "market_value_in_eur" IS NULL)/COUNT(*),2) AS "market_value_in_eur", ROUND(100.0*COUNT(*) FILTER (WHERE "player_name" IS NULL)/COUNT(*),2) AS "player_name" FROM transfers) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.13] Null % per column: version
UNPIVOT (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE "commit_hash" IS NULL)/COUNT(*),2) AS "commit_hash" FROM version) ON COLUMNS(*) INTO NAME col VALUE null_pct;

-- [P7.14] Birth dates: future, before 1950, implausibly young (< 14 at cut-off)
SELECT COUNT(*) FILTER (WHERE date_of_birth > TIMESTAMP '2026-07-06') AS future,
       COUNT(*) FILTER (WHERE date_of_birth < TIMESTAMP '1950-01-01') AS before_1950,
       COUNT(*) FILTER (WHERE date_of_birth > TIMESTAMP '2012-07-06') AS under_14,
       MIN(date_of_birth) AS min_dob, MAX(date_of_birth) AS max_dob, COUNT(*) FILTER (WHERE date_of_birth IS NULL) AS nulls
FROM players;

-- [P7.15] Contract dates before 2000 / after 2035
SELECT COUNT(*) FILTER (WHERE contract_expiration_date < TIMESTAMP '2000-01-01') AS before_2000,
       COUNT(*) FILTER (WHERE contract_expiration_date > TIMESTAMP '2035-12-31') AS after_2035,
       COUNT(*) FILTER (WHERE contract_expiration_date < TIMESTAMP '2023-01-01') AS before_2023
FROM players;

-- [P7.16] The single pre-2023 contract date
SELECT name, last_season, current_club_name, contract_expiration_date FROM players
WHERE contract_expiration_date < TIMESTAMP '2023-01-01';

-- [P7.17] Games: season label vs date (dates outside the season label's plausible window)
SELECT season, competition_id, COUNT(*) AS n, MIN(date) AS min_d, MAX(date) AS max_d FROM games
WHERE date < make_date(CAST(season AS INTEGER), 1, 1) OR date > make_date(CAST(season AS INTEGER) + 2, 1, 1)
GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 10;

-- [P7.18] Transfers dated in the future relative to the cut-off
SELECT COUNT(*) AS n FROM transfers WHERE transfer_date > DATE '2026-07-06';

-- [P7.19] Money columns: negatives, zeros, extremes
SELECT 'players.market_value_in_eur' AS col, COUNT(*) FILTER (WHERE market_value_in_eur < 0) AS neg,
       COUNT(*) FILTER (WHERE market_value_in_eur = 0) AS zero, MIN(market_value_in_eur) AS min_v, MAX(market_value_in_eur) AS max_v FROM players
UNION ALL SELECT 'players.highest_market_value_in_eur', COUNT(*) FILTER (WHERE highest_market_value_in_eur < 0),
       COUNT(*) FILTER (WHERE highest_market_value_in_eur = 0), MIN(highest_market_value_in_eur), MAX(highest_market_value_in_eur) FROM players
UNION ALL SELECT 'player_valuations.market_value_in_eur', COUNT(*) FILTER (WHERE market_value_in_eur < 0),
       COUNT(*) FILTER (WHERE market_value_in_eur = 0), MIN(market_value_in_eur), MAX(market_value_in_eur) FROM player_valuations
UNION ALL SELECT 'transfers.transfer_fee', COUNT(*) FILTER (WHERE transfer_fee < 0),
       COUNT(*) FILTER (WHERE transfer_fee = 0), MIN(transfer_fee), MAX(transfer_fee) FROM transfers
UNION ALL SELECT 'transfers.market_value_in_eur', COUNT(*) FILTER (WHERE market_value_in_eur < 0),
       COUNT(*) FILTER (WHERE market_value_in_eur = 0), MIN(market_value_in_eur), MAX(market_value_in_eur) FROM transfers
UNION ALL SELECT 'national_teams.total_market_value', COUNT(*) FILTER (WHERE total_market_value < 0),
       COUNT(*) FILTER (WHERE total_market_value = 0), MIN(total_market_value), MAX(total_market_value) FROM national_teams;

-- [P7.20] highest_market_value < current market value (impossible)
SELECT COUNT(*) AS n FROM players WHERE highest_market_value_in_eur < market_value_in_eur;

-- [P7.21] Valuation zero row
SELECT v.*, p.name FROM player_valuations v JOIN players p USING (player_id) WHERE v.market_value_in_eur = 0;

-- [P7.22] Transfer fee outliers: fee > 5x value at transfer (value >= 1m)
SELECT COUNT(*) AS n FROM transfers WHERE transfer_fee > 5 * market_value_in_eur AND market_value_in_eur >= 1000000;

-- [P7.23] Transfer fee outliers: examples
SELECT player_name, transfer_date, from_club_name, to_club_name, transfer_fee, market_value_in_eur
FROM transfers WHERE transfer_fee > 5 * market_value_in_eur AND market_value_in_eur >= 1000000
ORDER BY transfer_fee / market_value_in_eur DESC LIMIT 8;

-- [P7.24] clubs.net_transfer_record is text with currency symbol (examples and formats)
SELECT regexp_replace(net_transfer_record, '[0-9]', '9', 'g') AS pattern, COUNT(*) AS n, ANY_VALUE(net_transfer_record) AS example
FROM clubs GROUP BY 1 ORDER BY 2 DESC;

-- [P7.25] clubs.total_market_value and national_teams.coach_name entirely null
SELECT (SELECT COUNT(total_market_value) FROM clubs) AS clubs_tmv_non_null,
       (SELECT COUNT(coach_name) FROM national_teams) AS nt_coach_non_null;

-- [P7.26] Height outliers
SELECT COUNT(*) FILTER (WHERE height_in_cm < 150) AS under_150, COUNT(*) FILTER (WHERE height_in_cm > 210) AS over_210,
       COUNT(*) FILTER (WHERE height_in_cm = 0) AS zero, MIN(height_in_cm) AS min_h, MAX(height_in_cm) AS max_h FROM players;

-- [P7.27] Height outliers: examples
SELECT name, height_in_cm, position FROM players WHERE height_in_cm < 150 OR height_in_cm > 210 ORDER BY height_in_cm LIMIT 10;

-- [P7.28] players.position values
SELECT position, COUNT(*) AS n FROM players GROUP BY 1 ORDER BY 2 DESC;

-- [P7.29] players.sub_position values
SELECT sub_position, COUNT(*) AS n FROM players GROUP BY 1 ORDER BY 2 DESC;

-- [P7.30] players.foot values
SELECT foot, COUNT(*) AS n FROM players GROUP BY 1 ORDER BY 2 DESC;

-- [P7.31] game_lineups.position: case variants and blanks
SELECT position, COUNT(*) AS n FROM game_lineups
WHERE position IN ('Attack','midfield','Midfield','Defender','Sweeper','') OR position IS NULL OR TRIM(position) = ''
GROUP BY 1 ORDER BY 2 DESC;

-- [P7.32] game_lineups.type and number values (non-numeric shirt numbers)
SELECT type, COUNT(*) AS n, COUNT(*) FILTER (WHERE TRY_CAST(number AS INTEGER) IS NULL) AS non_numeric_number,
       ANY_VALUE(number) FILTER (WHERE TRY_CAST(number AS INTEGER) IS NULL) AS example
FROM game_lineups GROUP BY 1;

-- [P7.33] games.competition_type values (incl. NULL)
SELECT competition_type, COUNT(*) AS n FROM games GROUP BY 1 ORDER BY 2 DESC;

-- [P7.34] games formation variants (non-standard labels)
SELECT home_club_formation AS formation, COUNT(*) AS n FROM games
WHERE NOT regexp_matches(home_club_formation, '^[0-9](-[0-9]){2,4}$') GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

-- [P7.35] Country names: variants and historical states (country_of_birth vs country_of_citizenship)
SELECT country_of_birth AS country, COUNT(*) AS n FROM players
WHERE country_of_birth NOT IN (SELECT DISTINCT country_of_citizenship FROM players WHERE country_of_citizenship IS NOT NULL)
GROUP BY 1 ORDER BY 2 DESC LIMIT 15;

-- [P7.36] Competition names are slugs (lowercase-with-dashes), not display names
SELECT competition_id, name, competition_code FROM competitions WHERE name = competition_code LIMIT 5;

-- [P7.37] competitions.name = competition_code count; duplicate names
SELECT COUNT(*) FILTER (WHERE name = competition_code) AS name_is_slug, COUNT(*) AS total,
       COUNT(*) - COUNT(DISTINCT name) AS duplicate_names FROM competitions;

-- [P7.38] Duplicate competition names
SELECT name, STRING_AGG(competition_id || ' (' || COALESCE(country_name, '-') || ')', ', ') AS ids
FROM competitions GROUP BY 1 HAVING COUNT(*) > 1;

-- [P7.39] Confederation labels differ between tables (competitions/countries vs national_teams)
SELECT 'competitions' AS src, confederation, COUNT(*) AS n FROM competitions GROUP BY 1, 2
UNION ALL SELECT 'national_teams', confederation, COUNT(*) FROM national_teams GROUP BY 1, 2 ORDER BY 1, 2;

-- [P7.40] Club names: short in transfers vs official in clubs (same id, different name)
SELECT c.club_id, c.name AS clubs_name, t.to_club_name AS transfers_name, COUNT(*) AS n
FROM transfers t JOIN clubs c ON CAST(t.to_club_id AS VARCHAR) = c.club_id
WHERE c.name <> t.to_club_name GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 8;

-- [P7.41] Same club id with several names in player_valuations (name history / variants)
SELECT COUNT(*) AS club_ids_with_multiple_names FROM (
  SELECT current_club_id FROM player_valuations GROUP BY 1 HAVING COUNT(DISTINCT current_club_name) > 1);

-- [P7.42] Leading/trailing whitespace (incl. non-breaking spaces) in text columns
SELECT 'players.name' AS col, COUNT(*) FILTER (WHERE regexp_matches(name, '^[\s\x{00A0}]|[\s\x{00A0}]$')) AS n FROM players
UNION ALL SELECT 'players.first_name', COUNT(*) FILTER (WHERE regexp_matches(first_name, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM players
UNION ALL SELECT 'players.last_name', COUNT(*) FILTER (WHERE regexp_matches(last_name, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM players
UNION ALL SELECT 'players.city_of_birth', COUNT(*) FILTER (WHERE regexp_matches(city_of_birth, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM players
UNION ALL SELECT 'players.agent_name', COUNT(*) FILTER (WHERE regexp_matches(agent_name, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM players
UNION ALL SELECT 'clubs.name', COUNT(*) FILTER (WHERE regexp_matches(name, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM clubs
UNION ALL SELECT 'clubs.stadium_name', COUNT(*) FILTER (WHERE regexp_matches(stadium_name, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM clubs
UNION ALL SELECT 'transfers.player_name', COUNT(*) FILTER (WHERE regexp_matches(player_name, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM transfers
UNION ALL SELECT 'games.stadium', COUNT(*) FILTER (WHERE regexp_matches(stadium, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM games
UNION ALL SELECT 'game_events.description', COUNT(*) FILTER (WHERE regexp_matches(description, '^[\s\x{00A0}]|[\s\x{00A0}]$')) FROM game_events;

-- [P7.43] city_of_birth trailing NBSP example
SELECT city_of_birth, length(city_of_birth) AS len FROM players WHERE regexp_matches(city_of_birth, '\x{00A0}$') LIMIT 3;

-- [P7.44] Non-ASCII characters in names (accents etc.) - share of players
SELECT COUNT(*) FILTER (WHERE regexp_matches(name, '[^\x00-\x7F]')) AS non_ascii_names, COUNT(*) AS total FROM players;

-- [P7.45] Unusual characters in names (control chars, replacement char, digits, symbols)
SELECT name FROM players WHERE regexp_matches(name, '[\x00-\x1F\x{FFFD}0-9@#$%^*_=<>|]') LIMIT 10;

-- [P7.46] Embedded line breaks, quotes, commas or semicolons in text (CSV risk)
SELECT 'players.name' AS col, COUNT(*) FILTER (WHERE regexp_matches(name, '[\r\n]')) AS linebreaks,
       COUNT(*) FILTER (WHERE name LIKE '%"%') AS dquotes, COUNT(*) FILTER (WHERE name LIKE '%,%') AS commas FROM players
UNION ALL SELECT 'players.agent_name', COUNT(*) FILTER (WHERE regexp_matches(agent_name, '[\r\n]')),
       COUNT(*) FILTER (WHERE agent_name LIKE '%"%'), COUNT(*) FILTER (WHERE agent_name LIKE '%,%') FROM players
UNION ALL SELECT 'clubs.name', COUNT(*) FILTER (WHERE regexp_matches(name, '[\r\n]')),
       COUNT(*) FILTER (WHERE name LIKE '%"%'), COUNT(*) FILTER (WHERE name LIKE '%,%') FROM clubs
UNION ALL SELECT 'clubs.stadium_name', COUNT(*) FILTER (WHERE regexp_matches(stadium_name, '[\r\n]')),
       COUNT(*) FILTER (WHERE stadium_name LIKE '%"%'), COUNT(*) FILTER (WHERE stadium_name LIKE '%,%') FROM clubs
UNION ALL SELECT 'games.stadium', COUNT(*) FILTER (WHERE regexp_matches(stadium, '[\r\n]')),
       COUNT(*) FILTER (WHERE stadium LIKE '%"%'), COUNT(*) FILTER (WHERE stadium LIKE '%,%') FROM games
UNION ALL SELECT 'games.round', COUNT(*) FILTER (WHERE regexp_matches(round, '[\r\n]')),
       COUNT(*) FILTER (WHERE round LIKE '%"%'), COUNT(*) FILTER (WHERE round LIKE '%,%') FROM games
UNION ALL SELECT 'game_events.description', COUNT(*) FILTER (WHERE regexp_matches(description, '[\r\n]')),
       COUNT(*) FILTER (WHERE description LIKE '%"%'), COUNT(*) FILTER (WHERE description LIKE '%,%') FROM game_events
UNION ALL SELECT 'transfers.from_club_name', COUNT(*) FILTER (WHERE regexp_matches(from_club_name, '[\r\n]')),
       COUNT(*) FILTER (WHERE from_club_name LIKE '%"%'), COUNT(*) FILTER (WHERE from_club_name LIKE '%,%') FROM transfers;

-- [P7.47] Same player, different name spelling across tables (players.name vs transfers.player_name)
SELECT COUNT(DISTINCT t.player_id) AS players_with_name_mismatch FROM transfers t JOIN players p USING (player_id)
WHERE t.player_name <> p.name;

-- [P7.48] Name mismatch examples
SELECT DISTINCT p.name, t.player_name FROM transfers t JOIN players p USING (player_id) WHERE t.player_name <> p.name LIMIT 8;

-- [P7.49] Players with the same name but different ids
SELECT COUNT(*) AS names_shared, SUM(n) AS players_involved FROM (SELECT name, COUNT(*) AS n FROM players GROUP BY 1 HAVING COUNT(*) > 1);

-- [P7.50] Same name AND same birth date (possible true duplicates)
SELECT name, date_of_birth::DATE AS dob, COUNT(*) AS n, STRING_AGG(CAST(player_id AS VARCHAR), ',') AS ids
FROM players WHERE date_of_birth IS NOT NULL GROUP BY 1, 2 HAVING COUNT(*) > 1 ORDER BY 3 DESC LIMIT 10;

-- [P7.51] Same name examples (different people)
SELECT name, COUNT(*) AS n FROM players GROUP BY 1 HAVING COUNT(*) > 1 ORDER BY 2 DESC LIMIT 8;

-- [P7.52] Players with position = 'Missing'
SELECT COUNT(*) AS n, COUNT(*) FILTER (WHERE CAST(last_season AS INTEGER) >= 2025) AS active,
       COUNT(market_value_in_eur) AS with_value FROM players WHERE position = 'Missing';

-- [P7.53] Players with no market value: profile
SELECT last_season, COUNT(*) AS no_value FROM players WHERE market_value_in_eur IS NULL GROUP BY 1 ORDER BY 1;

-- [P7.54] Appearances with minutes 0 or > 125
SELECT a.date, a.player_name, a.minutes_played, a.competition_id FROM appearances a
WHERE minutes_played = 0 OR minutes_played > 125;

-- [P7.55] Games: implausible scores or attendance
SELECT COUNT(*) FILTER (WHERE home_club_goals > 10 OR away_club_goals > 10) AS score_over_10,
       COUNT(*) FILTER (WHERE attendance > 120000) AS attendance_over_120k,
       COUNT(*) FILTER (WHERE attendance = 0) AS attendance_zero,
       MAX(attendance) AS max_att FROM games;

-- [P7.56] clubs.filename column holds build paths (not data)
SELECT DISTINCT filename FROM clubs LIMIT 3;

-- [P7.57] Season columns stored as text (players/clubs last_season, games.season)
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE column_name IN ('season','last_season','transfer_season') ORDER BY 1;

-- [P7.58] player_valuations.player_club_domestic_competition_id null share (clubs outside covered leagues)
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE player_club_domestic_competition_id IS NULL) / COUNT(*), 1) AS pct_null
FROM player_valuations;


-- =====================================================
-- Phase 8: Star schema feasibility
-- =====================================================

-- [P8.1] Create transfers_classified (classification rule, see checklib.TRANSFER_CLASS_SQL)
CREATE OR REPLACE TEMP TABLE transfers_classified AS
WITH o AS (
  SELECT t.*,
         CASE WHEN t.from_club_id = (SELECT arg_max(t2.to_club_id, t2.transfer_date) FROM transfers t2
                                     WHERE t2.player_id = t.player_id AND t2.transfer_date < t.transfer_date)
              THEN 0 ELSE 1 END AS same_day_order
  FROM transfers t),
s AS (
  SELECT o.* EXCLUDE (same_day_order),
         ROW_NUMBER() OVER (PARTITION BY player_id
                            ORDER BY transfer_date, same_day_order, transfer_fee DESC NULLS LAST, to_club_id) AS seq
  FROM o),
l AS (
  SELECT s.*,
         LAG(from_club_id) OVER w AS prev_from, LAG(to_club_id) OVER w AS prev_to, LAG(transfer_date) OVER w AS prev_date
  FROM s WINDOW w AS (PARTITION BY player_id ORDER BY seq)),
r AS (
  SELECT l.*,
         CASE WHEN prev_from = to_club_id AND prev_to = from_club_id
               AND date_diff('day', prev_date, transfer_date) BETWEEN 14 AND 760
               AND COALESCE(transfer_fee, 0) = 0
               AND from_club_id NOT IN (515, 123, 75, 2113, 12604) AND to_club_id NOT IN (515, 123, 75, 2113, 12604)
              THEN 1 ELSE 0 END AS is_return
  FROM l),
c AS (  -- chain id: increments at every leg that is not a return
  SELECT r.*, SUM(1 - is_return) OVER (PARTITION BY player_id ORDER BY seq ROWS UNBOUNDED PRECEDING) AS chain_id
  FROM r),
p AS (
  SELECT c.*,
         ROW_NUMBER() OVER (PARTITION BY player_id, chain_id ORDER BY seq) AS chain_pos,
         COUNT(*) OVER (PARTITION BY player_id, chain_id) AS chain_len
  FROM c)
SELECT p.* EXCLUDE (prev_from, prev_to, prev_date),
  CASE
    WHEN chain_len > 1 AND chain_pos % 2 = 0 THEN 'end of loan'
    WHEN chain_len > 1 AND chain_pos < chain_len THEN 'loan'
    WHEN transfer_fee > 0 THEN 'paid'
    WHEN 75 IN (from_club_id, to_club_id) THEN 'unknown'
    WHEN to_club_id IN (123, 515, 2113) THEN 'free'
    WHEN from_club_id IN (515, 2113) THEN 'free'
    WHEN transfer_fee = 0 THEN 'free'
    WHEN from_club_id = 12604 OR regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
         OR regexp_matches(to_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)') THEN 'internal'
    ELSE 'unknown'
  END AS transfer_class,
  CASE
    WHEN chain_len > 1 AND chain_pos % 2 = 0 THEN 'end of loan'
    WHEN chain_len > 1 AND chain_pos < chain_len THEN CASE WHEN transfer_fee > 0 THEN 'loan with fee' ELSE 'loan' END
    WHEN transfer_fee > 0 THEN 'paid'
    WHEN 75 IN (from_club_id, to_club_id) THEN 'unknown club'
    WHEN to_club_id = 123 THEN 'free: retired'
    WHEN to_club_id IN (515, 2113) THEN 'free: released / contract ended'
    WHEN from_club_id IN (515, 2113) THEN 'free: free agent signed'
    WHEN transfer_fee = 0 THEN 'free: club to club'
    WHEN from_club_id = 12604 OR regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
         OR regexp_matches(to_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)') THEN 'internal: youth/reserve move'
    ELSE 'unknown: fee not disclosed'
  END AS transfer_subclass,
  -- a club lost a player without a fee (excludes loans, loan returns, youth moves, special 'from' clubs)
  CASE WHEN (chain_len = 1 OR chain_pos = chain_len) AND chain_pos % 2 = 1
            AND COALESCE(transfer_fee, 0) = 0
            AND from_club_id NOT IN (515, 123, 75, 2113, 12604)
            AND NOT regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
            AND (transfer_fee = 0 OR to_club_id IN (123, 515, 2113))
       THEN 1 ELSE 0 END AS is_free_departure
FROM p;

-- [P8.2] Grain: FactValuation (player_id, date) unique; club id present
SELECT COUNT(*) AS rows, COUNT(DISTINCT (player_id, date)) AS distinct_grain,
       COUNT(current_club_id) AS with_club_id FROM player_valuations;

-- [P8.3] Grain: FactAppearance (player_id, game_id) unique; measures present
SELECT COUNT(*) AS rows, COUNT(DISTINCT (player_id, game_id)) AS distinct_grain,
       COUNT(goals) AS goals, COUNT(assists) AS assists, COUNT(minutes_played) AS minutes FROM appearances;

-- [P8.4] Grain: FactTransfer (player_id, transfer_date, from, to) unique; fee and value coverage
SELECT COUNT(*) AS rows, COUNT(DISTINCT (player_id, transfer_date, from_club_id, to_club_id)) AS distinct_grain,
       COUNT(transfer_fee) AS with_fee, COUNT(market_value_in_eur) AS with_value_at_transfer FROM transfers;

-- [P8.5] DimClub: distinct club ids referenced anywhere vs rows in clubs
WITH ids AS (
  SELECT from_club_id AS id FROM transfers UNION SELECT to_club_id FROM transfers
  UNION SELECT current_club_id FROM player_valuations
  UNION SELECT home_club_id FROM games UNION SELECT away_club_id FROM games
  UNION SELECT player_club_id FROM appearances)
SELECT (SELECT COUNT(*) FROM ids) AS distinct_club_ids_referenced, (SELECT COUNT(*) FROM clubs) AS clubs_rows,
       (SELECT COUNT(*) FROM ids WHERE CAST(id AS VARCHAR) NOT IN (SELECT club_id FROM clubs)) AS ids_without_club_row;

-- [P8.6] DimClub fallback: every referenced club id has at least a name somewhere?
WITH names AS (
  SELECT from_club_id AS id, from_club_name AS name FROM transfers UNION ALL SELECT to_club_id, to_club_name FROM transfers
  UNION ALL SELECT current_club_id, current_club_name FROM player_valuations
  UNION ALL SELECT home_club_id, home_club_name FROM games UNION ALL SELECT away_club_id, away_club_name FROM games
  UNION ALL SELECT CAST(club_id AS INTEGER), name FROM clubs),
ids AS (SELECT id, COUNT(name) AS n_names FROM names GROUP BY 1)
SELECT COUNT(*) AS ids, COUNT(*) FILTER (WHERE n_names = 0) AS ids_without_any_name FROM ids;

-- [P8.7] DimCompetition: competitions rows vs codes referenced
WITH ids AS (SELECT competition_id FROM games UNION SELECT competition_id FROM appearances
             UNION SELECT domestic_competition_id FROM clubs UNION SELECT player_club_domestic_competition_id FROM player_valuations)
SELECT (SELECT COUNT(*) FROM ids WHERE competition_id IS NOT NULL) AS referenced,
       (SELECT COUNT(*) FROM competitions) AS rows,
       (SELECT COUNT(*) FROM ids WHERE competition_id NOT IN (SELECT competition_id FROM competitions)) AS missing;

-- [P8.8] DimPosition: values available (players.position x sub_position) and lineups per-game position
SELECT 'players' AS src, COUNT(DISTINCT (position, sub_position)) AS combos FROM players
UNION ALL SELECT 'game_lineups', COUNT(DISTINCT position) FROM game_lineups;

-- [P8.9] Club history for SCD2 / bridge: club per player per date available from valuations and transfers
SELECT COUNT(DISTINCT player_id) AS players_with_club_history FROM (
  SELECT player_id FROM player_valuations GROUP BY 1 HAVING COUNT(DISTINCT current_club_id) > 1
  UNION SELECT player_id FROM transfers);

-- [P8.10] Value at transfer: does transfers.market_value_in_eur equal the latest valuation on or before the transfer date?
WITH t AS (SELECT player_id, transfer_date, market_value_in_eur AS mv_t FROM transfers
           WHERE market_value_in_eur IS NOT NULL AND transfer_date <= DATE '2026-07-06'),
     m AS (SELECT t.player_id, t.transfer_date, t.mv_t,
                  (SELECT arg_max(v.market_value_in_eur, v.date) FROM player_valuations v
                   WHERE v.player_id = t.player_id AND v.date <= t.transfer_date) AS mv_v
           FROM t)
SELECT COUNT(*) AS rows, COUNT(mv_v) AS with_prior_valuation,
       COUNT(*) FILTER (WHERE mv_t = mv_v) AS equal,
       ROUND(100.0 * COUNT(*) FILTER (WHERE mv_t = mv_v) / COUNT(mv_v), 1) AS pct_equal
FROM m;

-- [P8.11] KPI 1 sample: market value change over 12 months as of 2026-07-06 (top risers, big-5)
WITH now_v AS (SELECT player_id, arg_max(market_value_in_eur, date) AS v_now FROM player_valuations
               WHERE date <= DATE '2026-07-06' GROUP BY 1),
     ago_v AS (SELECT player_id, arg_max(market_value_in_eur, date) AS v_ago FROM player_valuations
               WHERE date <= DATE '2025-07-06' GROUP BY 1)
SELECT p.name, p.current_club_name, a.v_ago, n.v_now, n.v_now - a.v_ago AS change_eur,
       ROUND(100.0 * (n.v_now - a.v_ago) / a.v_ago, 1) AS change_pct
FROM players p JOIN now_v n USING (player_id) JOIN ago_v a USING (player_id)
WHERE p.current_club_domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1') AND CAST(p.last_season AS INTEGER) >= 2025
ORDER BY change_eur DESC LIMIT 10;

-- [P8.12] KPI 1 sample: biggest fallers
WITH now_v AS (SELECT player_id, arg_max(market_value_in_eur, date) AS v_now FROM player_valuations
               WHERE date <= DATE '2026-07-06' GROUP BY 1),
     ago_v AS (SELECT player_id, arg_max(market_value_in_eur, date) AS v_ago FROM player_valuations
               WHERE date <= DATE '2025-07-06' GROUP BY 1)
SELECT p.name, p.current_club_name, a.v_ago, n.v_now, n.v_now - a.v_ago AS change_eur
FROM players p JOIN now_v n USING (player_id) JOIN ago_v a USING (player_id)
WHERE p.current_club_domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1') AND CAST(p.last_season AS INTEGER) >= 2025
ORDER BY change_eur ASC LIMIT 5;

-- [P8.13] KPI 2 sample: goal contributions per 90, big-5 league games 2025/26, >= 900 minutes (top 10)
SELECT p.name, p.sub_position, SUM(a.minutes_played) AS mins, SUM(a.goals) AS g, SUM(a.assists) AS a,
       ROUND(90.0 * (SUM(a.goals) + SUM(a.assists)) / SUM(a.minutes_played), 2) AS ga_per90
FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id JOIN players p USING (player_id)
WHERE g.competition_id IN ('GB1','ES1','IT1','L1','FR1') AND g.season = '2025'
GROUP BY 1, 2 HAVING SUM(a.minutes_played) >= 900 ORDER BY ga_per90 DESC LIMIT 10;

-- [P8.14] KPI 3 sample: value per goal contribution, big-5 2025/26 (cheapest output among >= 900 min, >= 5 G+A)
WITH perf AS (
  SELECT a.player_id, SUM(a.goals) + SUM(a.assists) AS ga, SUM(a.minutes_played) AS mins
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.competition_id IN ('GB1','ES1','IT1','L1','FR1') AND g.season = '2025' GROUP BY 1)
SELECT p.name, p.current_club_name, p.market_value_in_eur, perf.ga,
       ROUND(p.market_value_in_eur / perf.ga) AS eur_per_ga
FROM perf JOIN players p USING (player_id)
WHERE perf.mins >= 900 AND perf.ga >= 5 AND p.market_value_in_eur IS NOT NULL
ORDER BY eur_per_ga ASC LIMIT 10;

-- [P8.15] KPI 4 sample: fee vs market value at transfer (paid transfers 2023-2026), ratio distribution
SELECT COUNT(*) AS paid_with_value,
       ROUND(MEDIAN(transfer_fee / market_value_in_eur), 2) AS median_ratio,
       ROUND(QUANTILE_CONT(transfer_fee / market_value_in_eur, 0.1), 2) AS p10,
       ROUND(QUANTILE_CONT(transfer_fee / market_value_in_eur, 0.9), 2) AS p90,
       COUNT(*) FILTER (WHERE transfer_fee > market_value_in_eur) AS fee_above_value
FROM transfers_classified
WHERE transfer_class = 'paid' AND market_value_in_eur > 0 AND transfer_date BETWEEN DATE '2023-07-01' AND DATE '2026-07-06';

-- [P8.16] KPI 4 sample: largest overpayments in euros (paid transfers since 2023-07)
SELECT player_name, transfer_date, from_club_name, to_club_name, transfer_fee, market_value_in_eur,
       transfer_fee - market_value_in_eur AS premium_eur, ROUND(transfer_fee / market_value_in_eur, 2) AS ratio
FROM transfers_classified
WHERE transfer_class = 'paid' AND market_value_in_eur > 0 AND transfer_date BETWEEN DATE '2023-07-01' AND DATE '2026-07-06'
ORDER BY premium_eur DESC LIMIT 8;

-- [P8.17] KPI 5 sample: months until contract end as of 2026-07-06 (distribution, active big-5 players)
SELECT CASE WHEN m < 0 THEN 'a expired' WHEN m <= 6 THEN 'b 0-6' WHEN m <= 12 THEN 'c 7-12'
            WHEN m <= 24 THEN 'd 13-24' WHEN m <= 36 THEN 'e 25-36' ELSE 'f 37+' END AS months_left, COUNT(*) AS players
FROM (SELECT date_diff('month', DATE '2026-07-06', CAST(contract_expiration_date AS DATE)) AS m FROM players
      WHERE CAST(last_season AS INTEGER) >= 2025 AND current_club_domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1')
        AND contract_expiration_date IS NOT NULL)
GROUP BY 1 ORDER BY 1;

-- [P8.18] KPI 5 sample rows: months until contract end
SELECT name, current_club_name, contract_expiration_date::DATE AS contract_end,
       date_diff('month', DATE '2026-07-06', CAST(contract_expiration_date AS DATE)) AS months_left, market_value_in_eur
FROM players WHERE name IN ('Vinicius Junior','Phil Foden','Harry Kane','Florian Wirtz','Lamine Yamal');

-- [P8.19] KPI 6 sample: value-gap score = performance rank - value rank within sub_position (big-5 2025/26, >= 900 min, outfield)
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins,
         90.0 * (SUM(a.goals) + SUM(a.assists)) / SUM(a.minutes_played) AS ga90
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.competition_id IN ('GB1','ES1','IT1','L1','FR1') AND g.season = '2025' GROUP BY 1 HAVING SUM(a.minutes_played) >= 900),
r AS (
  SELECT p.name, p.sub_position, p.market_value_in_eur, ROUND(perf.ga90, 2) AS ga90,
         RANK() OVER (PARTITION BY p.sub_position ORDER BY perf.ga90 DESC) AS perf_rank,
         RANK() OVER (PARTITION BY p.sub_position ORDER BY p.market_value_in_eur DESC) AS value_rank
  FROM perf JOIN players p USING (player_id)
  WHERE p.position NOT IN ('Goalkeeper', 'Missing') AND p.market_value_in_eur IS NOT NULL)
SELECT *, value_rank - perf_rank AS value_gap FROM r
WHERE sub_position = 'Centre-Forward' ORDER BY value_gap DESC LIMIT 10;

-- [P8.20] KPI 7 sample: free departures above 5m per season - see Phase 4 (P4.35); club totals here
SELECT from_club_name, COUNT(*) AS n, SUM(market_value_in_eur) AS value_lost
FROM transfers_classified WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000
  AND transfer_season IN ('23/24','24/25','25/26')
GROUP BY 1 ORDER BY value_lost DESC LIMIT 10;

-- [P8.21] KPI 8 sample: squad value at risk (contracts ending 2026-07-06..2027-07-06) per big-5 club
WITH cur AS (SELECT DISTINCT CAST(home_club_id AS VARCHAR) AS club_id FROM games
             WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025')
SELECT p.current_club_name,
       SUM(p.market_value_in_eur) FILTER (WHERE p.contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06') AS value_at_risk,
       SUM(p.market_value_in_eur) AS squad_value,
       ROUND(100.0 * SUM(p.market_value_in_eur) FILTER (WHERE p.contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06')
             / SUM(p.market_value_in_eur), 1) AS pct_at_risk
FROM players p JOIN cur ON p.current_club_id = cur.club_id
WHERE CAST(p.last_season AS INTEGER) >= 2025
GROUP BY 1 ORDER BY value_at_risk DESC NULLS LAST LIMIT 10;


-- =====================================================
-- Phase 9: Business questions
-- =====================================================

-- [P9.1] Create transfers_classified (classification rule, see checklib.TRANSFER_CLASS_SQL)
CREATE OR REPLACE TEMP TABLE transfers_classified AS
WITH o AS (
  SELECT t.*,
         CASE WHEN t.from_club_id = (SELECT arg_max(t2.to_club_id, t2.transfer_date) FROM transfers t2
                                     WHERE t2.player_id = t.player_id AND t2.transfer_date < t.transfer_date)
              THEN 0 ELSE 1 END AS same_day_order
  FROM transfers t),
s AS (
  SELECT o.* EXCLUDE (same_day_order),
         ROW_NUMBER() OVER (PARTITION BY player_id
                            ORDER BY transfer_date, same_day_order, transfer_fee DESC NULLS LAST, to_club_id) AS seq
  FROM o),
l AS (
  SELECT s.*,
         LAG(from_club_id) OVER w AS prev_from, LAG(to_club_id) OVER w AS prev_to, LAG(transfer_date) OVER w AS prev_date
  FROM s WINDOW w AS (PARTITION BY player_id ORDER BY seq)),
r AS (
  SELECT l.*,
         CASE WHEN prev_from = to_club_id AND prev_to = from_club_id
               AND date_diff('day', prev_date, transfer_date) BETWEEN 14 AND 760
               AND COALESCE(transfer_fee, 0) = 0
               AND from_club_id NOT IN (515, 123, 75, 2113, 12604) AND to_club_id NOT IN (515, 123, 75, 2113, 12604)
              THEN 1 ELSE 0 END AS is_return
  FROM l),
c AS (  -- chain id: increments at every leg that is not a return
  SELECT r.*, SUM(1 - is_return) OVER (PARTITION BY player_id ORDER BY seq ROWS UNBOUNDED PRECEDING) AS chain_id
  FROM r),
p AS (
  SELECT c.*,
         ROW_NUMBER() OVER (PARTITION BY player_id, chain_id ORDER BY seq) AS chain_pos,
         COUNT(*) OVER (PARTITION BY player_id, chain_id) AS chain_len
  FROM c)
SELECT p.* EXCLUDE (prev_from, prev_to, prev_date),
  CASE
    WHEN chain_len > 1 AND chain_pos % 2 = 0 THEN 'end of loan'
    WHEN chain_len > 1 AND chain_pos < chain_len THEN 'loan'
    WHEN transfer_fee > 0 THEN 'paid'
    WHEN 75 IN (from_club_id, to_club_id) THEN 'unknown'
    WHEN to_club_id IN (123, 515, 2113) THEN 'free'
    WHEN from_club_id IN (515, 2113) THEN 'free'
    WHEN transfer_fee = 0 THEN 'free'
    WHEN from_club_id = 12604 OR regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
         OR regexp_matches(to_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)') THEN 'internal'
    ELSE 'unknown'
  END AS transfer_class,
  CASE
    WHEN chain_len > 1 AND chain_pos % 2 = 0 THEN 'end of loan'
    WHEN chain_len > 1 AND chain_pos < chain_len THEN CASE WHEN transfer_fee > 0 THEN 'loan with fee' ELSE 'loan' END
    WHEN transfer_fee > 0 THEN 'paid'
    WHEN 75 IN (from_club_id, to_club_id) THEN 'unknown club'
    WHEN to_club_id = 123 THEN 'free: retired'
    WHEN to_club_id IN (515, 2113) THEN 'free: released / contract ended'
    WHEN from_club_id IN (515, 2113) THEN 'free: free agent signed'
    WHEN transfer_fee = 0 THEN 'free: club to club'
    WHEN from_club_id = 12604 OR regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
         OR regexp_matches(to_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)') THEN 'internal: youth/reserve move'
    ELSE 'unknown: fee not disclosed'
  END AS transfer_subclass,
  -- a club lost a player without a fee (excludes loans, loan returns, youth moves, special 'from' clubs)
  CASE WHEN (chain_len = 1 OR chain_pos = chain_len) AND chain_pos % 2 = 1
            AND COALESCE(transfer_fee, 0) = 0
            AND from_club_id NOT IN (515, 123, 75, 2113, 12604)
            AND NOT regexp_matches(from_club_name, '(U1[5-9]|U2[0-3]|Sub-1[5-9]|Sub-2[0-3]|Y1[5-9]|\bII\b|\bB\b| Yth\.| Youth|Jgd|Primavera|Reserves| Res\.|Castilla| Atl\.$| 2$|^Jong |Academy|Akademi|Academia|NXT$|Liefering|Young Violets|Basconia|Bilbao Athletic|Betis Deportivo)')
            AND (transfer_fee = 0 OR to_club_id IN (123, 515, 2113))
       THEN 1 ELSE 0 END AS is_free_departure
FROM p;

-- [P9.2] Q1: value >= 5m, contract ends 2026-07-06..2027-07-06 - totals
SELECT COUNT(*) AS players, SUM(market_value_in_eur) AS total_value,
       COUNT(*) FILTER (WHERE current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
               WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025')) AS at_big5_clubs_2025_26,
       SUM(market_value_in_eur) FILTER (WHERE current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
               WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025')) AS value_at_big5_clubs,
       COUNT(*) FILTER (WHERE current_club_domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1')) AS tagged_big5_competition_id
FROM players
WHERE contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
  AND market_value_in_eur >= 5000000;

-- [P9.3] Q1: by league (clubs that played big-5 in 2025/26)
SELECT current_club_domestic_competition_id AS league, COUNT(*) AS players, SUM(market_value_in_eur) AS value
FROM players
WHERE contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
  AND market_value_in_eur >= 5000000 AND current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
               WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025')
GROUP BY 1 ORDER BY 2 DESC;

-- [P9.4] Q1: did any of them already move after the cut-off? (transfers dated > 2026-07-06 or on 2026-07-01..06)
SELECT COUNT(DISTINCT p.player_id) AS at_risk_with_recorded_move_since_2026_06_01
FROM players p JOIN transfers t USING (player_id)
WHERE p.contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
  AND p.market_value_in_eur >= 5000000 AND t.transfer_date >= DATE '2026-06-01';

-- [P9.5] Q2: rows available (outfield, big-5 2025/26, >= 900 min, with value and birth date)
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS g, SUM(a.assists) AS a,
         90.0 * (SUM(a.goals) + SUM(a.assists)) / SUM(a.minutes_played) AS ga90
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.competition_id IN ('GB1','ES1','IT1','L1','FR1') AND g.season = '2025' GROUP BY 1 HAVING SUM(a.minutes_played) >= 900),
base AS (
  SELECT p.player_id, p.name, p.current_club_name, p.position, p.sub_position, p.market_value_in_eur,
         date_diff('year', CAST(p.date_of_birth AS DATE), DATE '2026-07-06') AS age, perf.mins, perf.g, perf.a, perf.ga90
  FROM perf JOIN players p USING (player_id)
  WHERE p.position NOT IN ('Goalkeeper', 'Missing') AND p.market_value_in_eur IS NOT NULL AND p.date_of_birth IS NOT NULL),
ranked AS (
  SELECT *, CASE WHEN age <= 21 THEN 'U22' WHEN age <= 25 THEN '22-25' WHEN age <= 29 THEN '26-29' ELSE '30+' END AS age_band,
         PERCENT_RANK() OVER (PARTITION BY position ORDER BY ga90) AS perf_pct
  FROM base),
ranked2 AS (
  SELECT *, PERCENT_RANK() OVER (PARTITION BY position, age_band ORDER BY market_value_in_eur) AS value_pct FROM ranked)

SELECT position, COUNT(*) AS players FROM ranked2 GROUP BY 1 ORDER BY 1;

-- [P9.6] Q2: undervalued = top 20% output for position, bottom 30% value for position x age band
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS g, SUM(a.assists) AS a,
         90.0 * (SUM(a.goals) + SUM(a.assists)) / SUM(a.minutes_played) AS ga90
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.competition_id IN ('GB1','ES1','IT1','L1','FR1') AND g.season = '2025' GROUP BY 1 HAVING SUM(a.minutes_played) >= 900),
base AS (
  SELECT p.player_id, p.name, p.current_club_name, p.position, p.sub_position, p.market_value_in_eur,
         date_diff('year', CAST(p.date_of_birth AS DATE), DATE '2026-07-06') AS age, perf.mins, perf.g, perf.a, perf.ga90
  FROM perf JOIN players p USING (player_id)
  WHERE p.position NOT IN ('Goalkeeper', 'Missing') AND p.market_value_in_eur IS NOT NULL AND p.date_of_birth IS NOT NULL),
ranked AS (
  SELECT *, CASE WHEN age <= 21 THEN 'U22' WHEN age <= 25 THEN '22-25' WHEN age <= 29 THEN '26-29' ELSE '30+' END AS age_band,
         PERCENT_RANK() OVER (PARTITION BY position ORDER BY ga90) AS perf_pct
  FROM base),
ranked2 AS (
  SELECT *, PERCENT_RANK() OVER (PARTITION BY position, age_band ORDER BY market_value_in_eur) AS value_pct FROM ranked)

SELECT COUNT(*) AS undervalued, COUNT(*) FILTER (WHERE age <= 25) AS aged_25_or_less FROM ranked2
WHERE perf_pct >= 0.8 AND value_pct <= 0.3;

-- [P9.7] Q2: list (sorted by output)
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS g, SUM(a.assists) AS a,
         90.0 * (SUM(a.goals) + SUM(a.assists)) / SUM(a.minutes_played) AS ga90
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.competition_id IN ('GB1','ES1','IT1','L1','FR1') AND g.season = '2025' GROUP BY 1 HAVING SUM(a.minutes_played) >= 900),
base AS (
  SELECT p.player_id, p.name, p.current_club_name, p.position, p.sub_position, p.market_value_in_eur,
         date_diff('year', CAST(p.date_of_birth AS DATE), DATE '2026-07-06') AS age, perf.mins, perf.g, perf.a, perf.ga90
  FROM perf JOIN players p USING (player_id)
  WHERE p.position NOT IN ('Goalkeeper', 'Missing') AND p.market_value_in_eur IS NOT NULL AND p.date_of_birth IS NOT NULL),
ranked AS (
  SELECT *, CASE WHEN age <= 21 THEN 'U22' WHEN age <= 25 THEN '22-25' WHEN age <= 29 THEN '26-29' ELSE '30+' END AS age_band,
         PERCENT_RANK() OVER (PARTITION BY position ORDER BY ga90) AS perf_pct
  FROM base),
ranked2 AS (
  SELECT *, PERCENT_RANK() OVER (PARTITION BY position, age_band ORDER BY market_value_in_eur) AS value_pct FROM ranked)

SELECT name, current_club_name, position, age, mins, g, a, ROUND(ga90, 2) AS ga90, market_value_in_eur,
       ROUND(perf_pct, 2) AS perf_pct, ROUND(value_pct, 2) AS value_pct
FROM ranked2 WHERE perf_pct >= 0.8 AND value_pct <= 0.3 ORDER BY ga90 DESC LIMIT 20;

-- [P9.8] Q3: paid transfers with both fee and value at transfer
SELECT COUNT(*) AS paid, COUNT(market_value_in_eur) AS with_value,
       ROUND(100.0 * COUNT(market_value_in_eur) / COUNT(*), 1) AS pct_with_value
FROM transfers_classified WHERE transfer_class = 'paid';

-- [P9.9] Q3: fee / value ratio by season (paid, value > 0)
SELECT transfer_season, COUNT(*) AS n, ROUND(MEDIAN(transfer_fee / market_value_in_eur), 2) AS median_ratio,
       ROUND(SUM(transfer_fee) / SUM(market_value_in_eur), 2) AS aggregate_ratio
FROM transfers_classified WHERE transfer_class = 'paid' AND market_value_in_eur > 0
  AND transfer_season BETWEEN '18/19' AND '26/27' GROUP BY 1 ORDER BY 1;

-- [P9.10] Q3: fee / value ratio by destination league (big-5 buyers, 2023/24-2025/26)
SELECT c.domestic_competition_id AS buyer_league, COUNT(*) AS n,
       ROUND(MEDIAN(t.transfer_fee / t.market_value_in_eur), 2) AS median_ratio,
       ROUND(SUM(t.transfer_fee) / SUM(t.market_value_in_eur), 2) AS aggregate_ratio
FROM transfers_classified t JOIN clubs c ON CAST(t.to_club_id AS VARCHAR) = c.club_id
WHERE t.transfer_class = 'paid' AND t.market_value_in_eur > 0
  AND t.transfer_season IN ('23/24','24/25','25/26') AND c.domestic_competition_id IN ('GB1','ES1','IT1','L1','FR1')
GROUP BY 1 ORDER BY 1;

-- [P9.11] Q4: free departures >= 5m per window (season label) and value
SELECT transfer_season, COUNT(*) AS players, SUM(market_value_in_eur) AS value_given_away,
       COUNT(*) FILTER (WHERE transfer_subclass = 'free: released / contract ended') AS to_without_club,
       COUNT(*) FILTER (WHERE transfer_subclass = 'free: club to club') AS club_to_club
FROM transfers_classified WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000
  AND transfer_season IN ('23/24','24/25','25/26','26/27') GROUP BY 1 ORDER BY 1;

-- [P9.12] Q4: clubs that lost the most value on free departures, 23/24
SELECT from_club_name, COUNT(*) AS players, SUM(market_value_in_eur) AS value_lost,
       STRING_AGG(player_name, ', ' ORDER BY market_value_in_eur DESC) AS who
FROM transfers_classified WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000
  AND transfer_season = '23/24' GROUP BY 1 ORDER BY value_lost DESC LIMIT 5;

-- [P9.13] Q4: clubs that lost the most value on free departures, 24/25
SELECT from_club_name, COUNT(*) AS players, SUM(market_value_in_eur) AS value_lost,
       STRING_AGG(player_name, ', ' ORDER BY market_value_in_eur DESC) AS who
FROM transfers_classified WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000
  AND transfer_season = '24/25' GROUP BY 1 ORDER BY value_lost DESC LIMIT 5;

-- [P9.14] Q4: clubs that lost the most value on free departures, 25/26
SELECT from_club_name, COUNT(*) AS players, SUM(market_value_in_eur) AS value_lost,
       STRING_AGG(player_name, ', ' ORDER BY market_value_in_eur DESC) AS who
FROM transfers_classified WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000
  AND transfer_season = '25/26' GROUP BY 1 ORDER BY value_lost DESC LIMIT 5;

-- [P9.15] Q4: clubs that lost the most value, three windows combined (all free departures, any value)
SELECT from_club_name, COUNT(*) AS players, SUM(market_value_in_eur) AS value_lost
FROM transfers_classified WHERE is_free_departure = 1 AND transfer_season IN ('23/24','24/25','25/26')
GROUP BY 1 ORDER BY value_lost DESC NULLS LAST LIMIT 10;

-- [P9.16] Q5: value trend in the 12 months before a free departure (>= 5m, 23/24-25/26)
WITH fd AS (
  SELECT player_id, player_name, transfer_date, transfer_season, from_club_name, market_value_in_eur AS v_exit
  FROM transfers_classified WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000
    AND transfer_season IN ('23/24','24/25','25/26')),
j AS (
  SELECT fd.*,
         (SELECT arg_max(v.market_value_in_eur, v.date) FROM player_valuations v
          WHERE v.player_id = fd.player_id AND v.date <= fd.transfer_date - INTERVAL 12 MONTH) AS v_12m_before,
         (SELECT MAX(v.market_value_in_eur) FROM player_valuations v
          WHERE v.player_id = fd.player_id AND v.date BETWEEN fd.transfer_date - INTERVAL 12 MONTH AND fd.transfer_date) AS v_peak_12m,
         (SELECT COUNT(*) FROM player_valuations v
          WHERE v.player_id = fd.player_id AND v.date BETWEEN fd.transfer_date - INTERVAL 12 MONTH AND fd.transfer_date) AS points_12m
  FROM fd)

SELECT COUNT(*) AS departures, COUNT(v_12m_before) AS with_value_12m_before,
       COUNT(*) FILTER (WHERE v_exit < v_12m_before) AS fell,
       COUNT(*) FILTER (WHERE v_exit = v_12m_before) AS flat,
       COUNT(*) FILTER (WHERE v_exit > v_12m_before) AS rose,
       ROUND(MEDIAN(100.0 * (v_exit - v_12m_before) / v_12m_before), 1) AS median_change_pct,
       ROUND(AVG(points_12m), 1) AS avg_valuation_points_in_window
FROM j;

-- [P9.17] Q5: examples
WITH fd AS (
  SELECT player_id, player_name, transfer_date, transfer_season, from_club_name, market_value_in_eur AS v_exit
  FROM transfers_classified WHERE is_free_departure = 1 AND market_value_in_eur >= 5000000
    AND transfer_season IN ('23/24','24/25','25/26')),
j AS (
  SELECT fd.*,
         (SELECT arg_max(v.market_value_in_eur, v.date) FROM player_valuations v
          WHERE v.player_id = fd.player_id AND v.date <= fd.transfer_date - INTERVAL 12 MONTH) AS v_12m_before,
         (SELECT MAX(v.market_value_in_eur) FROM player_valuations v
          WHERE v.player_id = fd.player_id AND v.date BETWEEN fd.transfer_date - INTERVAL 12 MONTH AND fd.transfer_date) AS v_peak_12m,
         (SELECT COUNT(*) FROM player_valuations v
          WHERE v.player_id = fd.player_id AND v.date BETWEEN fd.transfer_date - INTERVAL 12 MONTH AND fd.transfer_date) AS points_12m
  FROM fd)

SELECT player_name, transfer_date, from_club_name, v_12m_before, v_peak_12m, v_exit,
       ROUND(100.0 * (v_exit - v_12m_before) / v_12m_before, 1) AS change_pct
FROM j ORDER BY v_exit DESC LIMIT 10;

-- [P9.18] Q5 comparison: players worth >= 5m who STAYED or were SOLD - 12-month change before their mid-2025 valuation
WITH sold AS (SELECT DISTINCT player_id FROM transfers_classified WHERE transfer_class = 'paid' AND transfer_season = '25/26'),
v AS (SELECT p.player_id,
             (SELECT arg_max(market_value_in_eur, date) FROM player_valuations x WHERE x.player_id = p.player_id AND x.date <= DATE '2025-07-01') AS v_now,
             (SELECT arg_max(market_value_in_eur, date) FROM player_valuations x WHERE x.player_id = p.player_id AND x.date <= DATE '2024-07-01') AS v_ago
      FROM players p)
SELECT CASE WHEN s.player_id IS NOT NULL THEN 'sold in 25/26' ELSE 'other' END AS grp, COUNT(*) AS n,
       ROUND(MEDIAN(100.0 * (v_now - v_ago) / v_ago), 1) AS median_change_pct
FROM v LEFT JOIN sold s USING (player_id) WHERE v_now >= 5000000 AND v_ago > 0 GROUP BY 1;

-- [P9.19] Backtest feasibility: contracts as of a past date are not stored (only one snapshot column)
SELECT COUNT(*) AS contract_columns FROM information_schema.columns WHERE column_name ILIKE '%contract%';

-- [P9.20] Backtest proxy (look-ahead): of players who left free in 25/26 with value >= 5m, how many still show a contract date?
SELECT COUNT(*) AS free_departures_5m, COUNT(p.contract_expiration_date) AS with_contract_now,
       COUNT(*) FILTER (WHERE p.contract_expiration_date > TIMESTAMP '2026-07-06') AS new_contract_after_cutoff
FROM transfers_classified t JOIN players p USING (player_id)
WHERE t.is_free_departure = 1 AND t.market_value_in_eur >= 5000000 AND t.transfer_season = '25/26';


-- =====================================================
-- Phase 10: SQL Server and SSIS readiness
-- =====================================================
-- 10a: CSV profile done in Python (scripts/phase10_csv_profile.py): csv module over each .csv.gz;
--      results in reports/evidence/phase10a_csv_profile.txt.
-- 10b: SQL Server 2025 LocalDB, database BI_DatasetCheck_Staging; run with sqlcmd -f 65001.
--      Staging DDL: scripts/staging_tables.sql (included below). Results: reports/evidence/phase10b_load_test.txt.

-- ---- [P10b] 00_setup.sql ----
IF DB_ID('BI_DatasetCheck_Staging') IS NULL CREATE DATABASE [BI_DatasetCheck_Staging];


-- ---- [P10b] 01_ddl.sql ----
IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
GO
-- Proposed SQL Server staging tables (schema stg), generated from the CSV profile.
-- NVARCHAR sizes = max observed length x 1.5, rounded up to [10, 20, 50, 100, 150, 200, 255, 500].
-- Nullable when the column has empty values in the file.

IF OBJECT_ID('stg.appearances') IS NOT NULL DROP TABLE stg.appearances;
CREATE TABLE stg.appearances (
    [appearance_id] NVARCHAR(50) NOT NULL,
    [game_id] INT NOT NULL,
    [player_id] INT NOT NULL,
    [player_club_id] INT NOT NULL,
    [player_current_club_id] INT NOT NULL,
    [date] DATE NOT NULL,
    [player_name] NVARCHAR(100) NULL,
    [competition_id] NVARCHAR(10) NOT NULL,
    [yellow_cards] INT NOT NULL,
    [red_cards] INT NOT NULL,
    [goals] INT NOT NULL,
    [assists] INT NOT NULL,
    [minutes_played] INT NOT NULL
);

IF OBJECT_ID('stg.club_games') IS NOT NULL DROP TABLE stg.club_games;
CREATE TABLE stg.club_games (
    [game_id] INT NOT NULL,
    [club_id] INT NOT NULL,
    [own_goals] INT NOT NULL,
    [own_position] INT NULL,
    [own_manager_name] NVARCHAR(50) NULL,
    [opponent_id] INT NOT NULL,
    [opponent_goals] INT NOT NULL,
    [opponent_position] INT NULL,
    [opponent_manager_name] NVARCHAR(50) NULL,
    [hosting] NVARCHAR(10) NOT NULL,
    [is_win] INT NOT NULL
);

IF OBJECT_ID('stg.clubs') IS NOT NULL DROP TABLE stg.clubs;
CREATE TABLE stg.clubs (
    [club_id] INT NOT NULL,
    [club_code] NVARCHAR(100) NOT NULL,
    [name] NVARCHAR(100) NOT NULL,
    [domestic_competition_id] NVARCHAR(10) NOT NULL,
    [total_market_value] NVARCHAR(50) NULL,
    [squad_size] INT NOT NULL,
    [average_age] DECIMAL(6,2) NULL,
    [foreigners_number] INT NOT NULL,
    [foreigners_percentage] DECIMAL(6,2) NULL,
    [national_team_players] INT NOT NULL,
    [stadium_name] NVARCHAR(100) NOT NULL,
    [stadium_seats] INT NOT NULL,
    [net_transfer_record] NVARCHAR(20) NOT NULL,
    [coach_name] NVARCHAR(50) NULL,
    [last_season] SMALLINT NOT NULL,
    [filename] NVARCHAR(100) NOT NULL,
    [url] NVARCHAR(150) NOT NULL
);

IF OBJECT_ID('stg.competitions') IS NOT NULL DROP TABLE stg.competitions;
CREATE TABLE stg.competitions (
    [competition_id] NVARCHAR(10) NOT NULL,
    [competition_code] NVARCHAR(100) NOT NULL,
    [name] NVARCHAR(100) NOT NULL,
    [sub_type] NVARCHAR(50) NOT NULL,
    [type] NVARCHAR(50) NOT NULL,
    [country_id] INT NOT NULL,
    [country_name] NVARCHAR(50) NULL,
    [domestic_league_code] NVARCHAR(10) NULL,
    [confederation] NVARCHAR(20) NOT NULL,
    [total_clubs] INT NULL,
    [url] NVARCHAR(150) NOT NULL
);

IF OBJECT_ID('stg.countries') IS NOT NULL DROP TABLE stg.countries;
CREATE TABLE stg.countries (
    [country_id] INT NOT NULL,
    [country_name] NVARCHAR(50) NOT NULL,
    [country_code] NVARCHAR(10) NOT NULL,
    [confederation] NVARCHAR(20) NOT NULL,
    [total_clubs] INT NOT NULL,
    [total_players] INT NOT NULL,
    [average_age] DECIMAL(6,2) NOT NULL,
    [url] NVARCHAR(150) NOT NULL
);

IF OBJECT_ID('stg.game_events') IS NOT NULL DROP TABLE stg.game_events;
CREATE TABLE stg.game_events (
    [game_event_id] NVARCHAR(50) NOT NULL,
    [date] DATE NOT NULL,
    [game_id] INT NOT NULL,
    [minute] INT NOT NULL,
    [type] NVARCHAR(20) NOT NULL,
    [club_id] INT NOT NULL,
    [club_name] NVARCHAR(100) NOT NULL,
    [player_id] INT NOT NULL,
    [description] NVARCHAR(150) NULL,
    [player_in_id] INT NULL,
    [player_assist_id] INT NULL
);

IF OBJECT_ID('stg.game_lineups') IS NOT NULL DROP TABLE stg.game_lineups;
CREATE TABLE stg.game_lineups (
    [game_lineups_id] NVARCHAR(50) NOT NULL,
    [date] DATE NOT NULL,
    [game_id] INT NOT NULL,
    [player_id] INT NOT NULL,
    [club_id] INT NOT NULL,
    [player_name] NVARCHAR(100) NOT NULL,
    [type] NVARCHAR(50) NOT NULL,
    [position] NVARCHAR(50) NULL,
    [number] NVARCHAR(10) NOT NULL,
    [team_captain] INT NOT NULL
);

IF OBJECT_ID('stg.games') IS NOT NULL DROP TABLE stg.games;
CREATE TABLE stg.games (
    [game_id] INT NOT NULL,
    [competition_id] NVARCHAR(10) NOT NULL,
    [season] SMALLINT NOT NULL,
    [round] NVARCHAR(50) NOT NULL,
    [date] DATE NOT NULL,
    [home_club_id] INT NOT NULL,
    [away_club_id] INT NOT NULL,
    [home_club_goals] INT NOT NULL,
    [away_club_goals] INT NOT NULL,
    [home_club_position] INT NULL,
    [away_club_position] INT NULL,
    [home_club_manager_name] NVARCHAR(50) NULL,
    [away_club_manager_name] NVARCHAR(50) NULL,
    [stadium] NVARCHAR(100) NULL,
    [attendance] INT NULL,
    [referee] NVARCHAR(100) NULL,
    [url] NVARCHAR(200) NOT NULL,
    [home_club_formation] NVARCHAR(50) NULL,
    [away_club_formation] NVARCHAR(50) NULL,
    [home_club_name] NVARCHAR(100) NULL,
    [away_club_name] NVARCHAR(100) NULL,
    [aggregate] NVARCHAR(10) NOT NULL,
    [competition_type] NVARCHAR(50) NULL
);

IF OBJECT_ID('stg.national_teams') IS NOT NULL DROP TABLE stg.national_teams;
CREATE TABLE stg.national_teams (
    [national_team_id] INT NOT NULL,
    [name] NVARCHAR(50) NOT NULL,
    [team_code] NVARCHAR(50) NOT NULL,
    [country_id] INT NOT NULL,
    [country_name] NVARCHAR(50) NOT NULL,
    [country_code] NVARCHAR(10) NOT NULL,
    [confederation] NVARCHAR(20) NULL,
    [team_image_url] NVARCHAR(150) NOT NULL,
    [squad_size] INT NOT NULL,
    [average_age] DECIMAL(6,2) NOT NULL,
    [foreigners_number] INT NOT NULL,
    [foreigners_percentage] DECIMAL(6,2) NULL,
    [total_market_value] BIGINT NULL,
    [coach_name] NVARCHAR(50) NULL,
    [fifa_ranking] INT NOT NULL,
    [last_season] SMALLINT NOT NULL,
    [url] NVARCHAR(150) NOT NULL
);

IF OBJECT_ID('stg.player_valuations') IS NOT NULL DROP TABLE stg.player_valuations;
CREATE TABLE stg.player_valuations (
    [player_id] INT NOT NULL,
    [date] DATE NOT NULL,
    [market_value_in_eur] BIGINT NOT NULL,
    [current_club_name] NVARCHAR(100) NOT NULL,
    [current_club_id] INT NOT NULL,
    [player_club_domestic_competition_id] NVARCHAR(10) NULL
);

IF OBJECT_ID('stg.players') IS NOT NULL DROP TABLE stg.players;
CREATE TABLE stg.players (
    [player_id] INT NOT NULL,
    [first_name] NVARCHAR(50) NULL,
    [last_name] NVARCHAR(50) NOT NULL,
    [name] NVARCHAR(100) NOT NULL,
    [last_season] SMALLINT NOT NULL,
    [current_club_id] INT NOT NULL,
    [player_code] NVARCHAR(100) NOT NULL,
    [country_of_birth] NVARCHAR(50) NULL,
    [city_of_birth] NVARCHAR(100) NULL,
    [country_of_citizenship] NVARCHAR(50) NULL,
    [date_of_birth] DATETIME2(0) NULL,
    [sub_position] NVARCHAR(50) NULL,
    [position] NVARCHAR(20) NOT NULL,
    [foot] NVARCHAR(10) NULL,
    [height_in_cm] INT NULL,
    [contract_expiration_date] DATETIME2(0) NULL,
    [agent_name] NVARCHAR(50) NULL,
    [image_url] NVARCHAR(150) NOT NULL,
    [international_caps] INT NULL,
    [international_goals] INT NULL,
    [current_national_team_id] INT NULL,
    [url] NVARCHAR(150) NOT NULL,
    [current_club_domestic_competition_id] NVARCHAR(10) NULL,
    [current_club_name] NVARCHAR(100) NULL,
    [market_value_in_eur] BIGINT NULL,
    [highest_market_value_in_eur] BIGINT NULL
);

IF OBJECT_ID('stg.transfers') IS NOT NULL DROP TABLE stg.transfers;
CREATE TABLE stg.transfers (
    [player_id] INT NOT NULL,
    [transfer_date] DATE NOT NULL,
    [transfer_season] NVARCHAR(10) NOT NULL,
    [from_club_id] INT NOT NULL,
    [to_club_id] INT NOT NULL,
    [from_club_name] NVARCHAR(100) NOT NULL,
    [to_club_name] NVARCHAR(100) NOT NULL,
    [transfer_fee] DECIMAL(18,3) NULL,
    [market_value_in_eur] DECIMAL(18,3) NULL,
    [player_name] NVARCHAR(100) NOT NULL
);


-- ---- [P10b] 02_load.sql ----
SET NOCOUNT ON;

BEGIN TRY
  BULK INSERT stg.appearances FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\appearances_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|appearances|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.appearances;
END TRY
BEGIN CATCH
  SELECT 'FAILED|appearances|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.club_games FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\club_games_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|club_games|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.club_games;
END TRY
BEGIN CATCH
  SELECT 'FAILED|club_games|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.clubs FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\clubs_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|clubs|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.clubs;
END TRY
BEGIN CATCH
  SELECT 'FAILED|clubs|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.competitions FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\competitions_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|competitions|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.competitions;
END TRY
BEGIN CATCH
  SELECT 'FAILED|competitions|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.countries FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\countries_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|countries|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.countries;
END TRY
BEGIN CATCH
  SELECT 'FAILED|countries|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.game_events FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\game_events_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|game_events|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.game_events;
END TRY
BEGIN CATCH
  SELECT 'FAILED|game_events|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.game_lineups FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\game_lineups_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|game_lineups|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.game_lineups;
END TRY
BEGIN CATCH
  SELECT 'FAILED|game_lineups|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.games FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\games_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|games|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.games;
END TRY
BEGIN CATCH
  SELECT 'FAILED|games|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.national_teams FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\national_teams_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|national_teams|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.national_teams;
END TRY
BEGIN CATCH
  SELECT 'FAILED|national_teams|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.player_valuations FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\player_valuations_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|player_valuations|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.player_valuations;
END TRY
BEGIN CATCH
  SELECT 'FAILED|player_valuations|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.players FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\players_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|players|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.players;
END TRY
BEGIN CATCH
  SELECT 'FAILED|players|' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
  BULK INSERT stg.transfers FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\transfers_sample.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a',
        CODEPAGE = '65001', FIRSTROW = 2, KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'LOADED|transfers|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.transfers;
END TRY
BEGIN CATCH
  SELECT 'FAILED|transfers|' + ERROR_MESSAGE();
END CATCH;

-- ---- [P10b] 03_checks.sql ----
SET NOCOUNT ON;
SELECT 'accent|players.name with non-ASCII (binary collation)|' + CAST(COUNT(*) AS VARCHAR) FROM stg.players WHERE name COLLATE Latin1_General_BIN2 LIKE N'%[^ -~]%';
SELECT 'accent|exact match Aurélien Joachim in appearances|' + CAST(COUNT(*) AS VARCHAR) FROM stg.appearances WHERE player_name = N'Aurélien Joachim';
SELECT 'quote|games.stadium containing a double quote|' + CAST(COUNT(*) AS VARCHAR) FROM stg.games WHERE stadium LIKE '%"%';
SELECT 'quote|example|' + MAX(stadium) FROM stg.games WHERE stadium LIKE '%"%';
SELECT 'null|game_events.description NULL vs empty string|' + CAST(SUM(CASE WHEN description IS NULL THEN 1 ELSE 0 END) AS VARCHAR) + ' NULL / ' + CAST(SUM(CASE WHEN description = '' THEN 1 ELSE 0 END) AS VARCHAR) + ' empty' FROM stg.game_events;
SELECT 'null|players.contract_expiration_date NULL|' + CAST(SUM(CASE WHEN contract_expiration_date IS NULL THEN 1 ELSE 0 END) AS VARCHAR) FROM stg.players;
SELECT 'nbsp|players.city_of_birth ending in NCHAR(160)|' + CAST(COUNT(*) AS VARCHAR) FROM stg.players WHERE RIGHT(city_of_birth, 1) = NCHAR(160);
SELECT 'decimal|transfers max fee|' + CAST(MAX(transfer_fee) AS VARCHAR) FROM stg.transfers;
SELECT 'datetime|players min/max date_of_birth|' + CONVERT(VARCHAR, MIN(date_of_birth), 120) + ' / ' + CONVERT(VARCHAR, MAX(date_of_birth), 120) FROM stg.players;
SELECT 'text|game_lineups.number non-numeric|' + CAST(COUNT(*) AS VARCHAR) FROM stg.game_lineups WHERE TRY_CAST(number AS INT) IS NULL;


-- ---- [P10b] 04_full_load.sql ----
SET NOCOUNT ON;

TRUNCATE TABLE stg.players;
BEGIN TRY
  BULK INSERT stg.players FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\players_full.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', FIRSTROW = 2,
        KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'FULL LOADED|players|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.players;
END TRY
BEGIN CATCH
  SELECT 'FULL FAILED|players|' + ERROR_MESSAGE();
END CATCH;

TRUNCATE TABLE stg.transfers;
BEGIN TRY
  BULK INSERT stg.transfers FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\transfers_full.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', FIRSTROW = 2,
        KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'FULL LOADED|transfers|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.transfers;
END TRY
BEGIN CATCH
  SELECT 'FULL FAILED|transfers|' + ERROR_MESSAGE();
END CATCH;

TRUNCATE TABLE stg.player_valuations;
BEGIN TRY
  BULK INSERT stg.player_valuations FROM 'C:\Users\Hedi\AppData\Local\Temp\claude\c--Users-Hedi-Desktop-projects-BI\0065ffd1-3b38-4e22-96ad-7d1d4e9bef38\scratchpad\samples\player_valuations_full.csv'
  WITH (FORMAT = 'CSV', FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', FIRSTROW = 2,
        KEEPNULLS, TABLOCK, MAXERRORS = 0);
  SELECT 'FULL LOADED|player_valuations|' + CAST(COUNT(*) AS VARCHAR(10)) FROM stg.player_valuations;
END TRY
BEGIN CATCH
  SELECT 'FULL FAILED|player_valuations|' + ERROR_MESSAGE();
END CATCH;

-- =====================================================
-- Phase 11: not run (no SoFIFA file supplied)
-- =====================================================

-- =====================================================
-- Follow-up 12: Attacker check
-- =====================================================

-- [P12.1] 1a. Distinct players.position with counts
SELECT position, COUNT(*) AS players FROM players GROUP BY 1 ORDER BY 2 DESC;

-- [P12.2] 1b. Distinct players.sub_position with counts (NULL included)
SELECT sub_position, COUNT(*) AS players FROM players GROUP BY 1 ORDER BY 2 DESC;

-- [P12.3] 1c. position x sub_position combinations
SELECT position, sub_position, COUNT(*) AS players FROM players GROUP BY 1, 2 ORDER BY 1, 3 DESC;

-- [P12.4] 2a. Scope check: 2025/26 league games per league (all 14 leagues complete?)
SELECT g.competition_id, COUNT(*) AS games, MIN(g.date) AS first_game, MAX(g.date) AS last_game,
       COUNT(*) FILTER (WHERE a.game_id IS NULL) AS games_without_appearances
FROM games g LEFT JOIN (SELECT DISTINCT game_id FROM appearances) a ON CAST(g.game_id AS INTEGER) = a.game_id
WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1')
GROUP BY 1 ORDER BY 1;

-- [P12.5] 2b. Attackers (position = 'Attack') with >= 900 league minutes in 2025/26, 14 leagues
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS goals, SUM(a.assists) AS assists,
         COUNT(*) AS apps, STRING_AGG(DISTINCT a.competition_id, ',') AS leagues
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1')
  GROUP BY 1)

SELECT COUNT(*) FILTER (WHERE perf.mins >= 900) AS attackers_900_plus,
       COUNT(*) AS attackers_with_any_minutes
FROM perf JOIN players p USING (player_id) WHERE p.position = 'Attack';

-- [P12.6] 2c. Same, by sub_position
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS goals, SUM(a.assists) AS assists,
         COUNT(*) AS apps, STRING_AGG(DISTINCT a.competition_id, ',') AS leagues
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1')
  GROUP BY 1)

SELECT p.sub_position, COUNT(*) AS attackers_900_plus
FROM perf JOIN players p USING (player_id)
WHERE p.position = 'Attack' AND perf.mins >= 900 GROUP BY 1 ORDER BY 2 DESC;

-- [P12.7] 2d. Attackers >= 900 min by main league (league with most minutes)
WITH m AS (
  SELECT a.player_id, g.competition_id, SUM(a.minutes_played) AS mins
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1') GROUP BY 1, 2),
t AS (SELECT player_id, SUM(mins) AS total, arg_max(competition_id, mins) AS main_league FROM m GROUP BY 1)
SELECT main_league, COUNT(*) AS attackers_900_plus
FROM t JOIN players p USING (player_id)
WHERE p.position = 'Attack' AND t.total >= 900 GROUP BY 1 ORDER BY 2 DESC;

-- [P12.8] 2e. Do BE1/DK1/GR1/SC1 have games after their last 2025/26 league game (split-season play-off rounds)?
WITH lg AS (SELECT competition_id, MAX(date) AS last_league_game FROM games
            WHERE season = '2025' AND competition_id IN ('BE1','DK1','GR1','SC1') GROUP BY 1),
     cl AS (SELECT DISTINCT g.competition_id AS league, x.club_id
            FROM games g, (SELECT g.home_club_id AS club_id UNION SELECT g.away_club_id) x
            WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','GR1','SC1'))
SELECT lg.competition_id AS league, lg.last_league_game,
       COUNT(DISTINCT g.game_id) FILTER (WHERE g.competition_id = lg.competition_id) AS later_games_same_code,
       COUNT(DISTINCT g.game_id) FILTER (WHERE g.competition_id <> lg.competition_id) AS later_games_other_codes,
       STRING_AGG(DISTINCT g.competition_id, ',') FILTER (WHERE g.competition_id <> lg.competition_id) AS other_codes
FROM lg JOIN cl ON cl.league = lg.competition_id
LEFT JOIN games g ON g.date > lg.last_league_game AND g.date <= DATE '2026-07-06'
                 AND cl.club_id IN (g.home_club_id, g.away_club_id)
GROUP BY 1, 2 ORDER BY 1;

-- [P12.9] 2f. Expected regular-season size vs games present (BE1 16 clubs, DK1 12, GR1 14, SC1 12)
SELECT competition_id, COUNT(*) AS games, COUNT(DISTINCT home_club_id) AS clubs
FROM games WHERE season = '2025' AND competition_id IN ('BE1','DK1','GR1','SC1') GROUP BY 1 ORDER BY 1;

-- [P12.10] 2g. Sensitivity: Belgian play-off codes (EJPL, POBE, BPO4) - in competitions? appearances? effect on the 900-min count
WITH pl AS (SELECT CAST(game_id AS INTEGER) AS game_id, competition_id FROM games
            WHERE season = '2025' AND competition_id IN ('EJPL','POBE','BPO4')),
     base AS (SELECT a.player_id, SUM(a.minutes_played) AS mins FROM appearances a
              JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
              WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1') GROUP BY 1),
     plm AS (SELECT a.player_id, SUM(a.minutes_played) AS mins FROM appearances a JOIN pl USING (game_id) GROUP BY 1),
     comb AS (SELECT player_id, COALESCE(b.mins, 0) + COALESCE(x.mins, 0) AS mins
              FROM base b FULL JOIN plm x USING (player_id))
SELECT (SELECT STRING_AGG(competition_id || ':' || name, ', ') FROM competitions WHERE competition_id IN ('EJPL','POBE','BPO4')) AS in_competitions,
       (SELECT COUNT(*) FROM pl) AS playoff_games,
       (SELECT COUNT(*) FROM appearances a JOIN pl USING (game_id)) AS playoff_appearance_rows,
       (SELECT COUNT(*) FROM comb JOIN players p USING (player_id) WHERE p.position = 'Attack' AND comb.mins >= 900) AS attackers_900_incl_playoffs;

-- [P12.11] 3a. Distribution of (goals + assists) per 90, attackers >= 900 min
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS goals, SUM(a.assists) AS assists,
         COUNT(*) AS apps, STRING_AGG(DISTINCT a.competition_id, ',') AS leagues
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1')
  GROUP BY 1)

, x AS (SELECT 90.0 * (goals + assists) / mins AS ga90 FROM perf JOIN players p USING (player_id)
        WHERE p.position = 'Attack' AND perf.mins >= 900)
SELECT COUNT(*) AS players, ROUND(MIN(ga90), 3) AS min_ga90, ROUND(MEDIAN(ga90), 3) AS median_ga90,
       ROUND(QUANTILE_CONT(ga90, 0.9), 3) AS p90_ga90, ROUND(MAX(ga90), 3) AS max_ga90,
       ROUND(AVG(ga90), 3) AS mean_ga90
FROM x;

-- [P12.12] 3b. Attackers >= 900 min with zero goal contributions
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS goals, SUM(a.assists) AS assists,
         COUNT(*) AS apps, STRING_AGG(DISTINCT a.competition_id, ',') AS leagues
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1')
  GROUP BY 1)

SELECT p.name, p.sub_position, p.current_club_name, perf.mins, perf.apps
FROM perf JOIN players p USING (player_id)
WHERE p.position = 'Attack' AND perf.mins >= 900 AND perf.goals + perf.assists = 0 ORDER BY perf.mins DESC;

-- [P12.13] 3c. Top 20 attackers by (goals + assists) per 90 (>= 900 min)
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS goals, SUM(a.assists) AS assists,
         COUNT(*) AS apps, STRING_AGG(DISTINCT a.competition_id, ',') AS leagues
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1')
  GROUP BY 1)

SELECT p.name, p.sub_position, p.current_club_name, perf.leagues, perf.apps, perf.mins, perf.goals, perf.assists,
       ROUND(90.0 * (perf.goals + perf.assists) / perf.mins, 2) AS ga90, p.market_value_in_eur
FROM perf JOIN players p USING (player_id)
WHERE p.position = 'Attack' AND perf.mins >= 900
ORDER BY 90.0 * (perf.goals + perf.assists) / perf.mins DESC, perf.mins DESC LIMIT 20;

-- [P12.14] 4a. Watch list size (should be 206) and attackers in it
WITH watch AS (
  SELECT p.* FROM players p
  WHERE p.contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
    AND p.market_value_in_eur >= 5000000
    AND p.current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
                              WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025'))
SELECT COUNT(*) AS watch_list, COUNT(*) FILTER (WHERE position = 'Attack') AS attackers,
       SUM(market_value_in_eur) FILTER (WHERE position = 'Attack') AS attackers_value
FROM watch;

-- [P12.15] 4b. Watch list by position
WITH watch AS (
  SELECT p.* FROM players p
  WHERE p.contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
    AND p.market_value_in_eur >= 5000000
    AND p.current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
                              WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025'))
SELECT position, COUNT(*) AS players, SUM(market_value_in_eur) AS value FROM watch GROUP BY 1 ORDER BY 2 DESC;

-- [P12.16] 4c. Watch-list attackers with >= 900 league minutes in 2025/26 (14 leagues)
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS goals, SUM(a.assists) AS assists,
         COUNT(*) AS apps, STRING_AGG(DISTINCT a.competition_id, ',') AS leagues
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1')
  GROUP BY 1)
,
watch AS (
  SELECT p.* FROM players p
  WHERE p.contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
    AND p.market_value_in_eur >= 5000000
    AND p.current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
                              WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025'))

SELECT COUNT(*) AS watch_attackers,
       COUNT(*) FILTER (WHERE perf.mins >= 900) AS with_900_plus,
       COUNT(*) FILTER (WHERE perf.mins < 900) AS under_900,
       COUNT(*) FILTER (WHERE perf.player_id IS NULL) AS no_league_minutes
FROM watch w LEFT JOIN perf USING (player_id) WHERE w.position = 'Attack';

-- [P12.17] 4d. Watch-list attackers: detail
WITH perf AS (
  SELECT a.player_id, SUM(a.minutes_played) AS mins, SUM(a.goals) AS goals, SUM(a.assists) AS assists,
         COUNT(*) AS apps, STRING_AGG(DISTINCT a.competition_id, ',') AS leagues
  FROM appearances a JOIN games g ON CAST(g.game_id AS INTEGER) = a.game_id
  WHERE g.season = '2025' AND g.competition_id IN ('BE1','DK1','ES1','FR1','GB1','GR1','IT1','L1','NL1','PO1','RU1','SC1','TR1','UKR1')
  GROUP BY 1)
,
watch AS (
  SELECT p.* FROM players p
  WHERE p.contract_expiration_date BETWEEN TIMESTAMP '2026-07-06' AND TIMESTAMP '2027-07-06'
    AND p.market_value_in_eur >= 5000000
    AND p.current_club_id IN (SELECT DISTINCT CAST(home_club_id AS VARCHAR) FROM games
                              WHERE competition_id IN ('GB1','ES1','IT1','L1','FR1') AND season = '2025'))

SELECT w.name, w.sub_position, w.current_club_name, w.market_value_in_eur, w.contract_expiration_date::DATE AS contract_end,
       COALESCE(perf.mins, 0) AS mins, COALESCE(perf.goals, 0) AS goals, COALESCE(perf.assists, 0) AS assists,
       CASE WHEN perf.mins > 0 THEN ROUND(90.0 * (perf.goals + perf.assists) / perf.mins, 2) END AS ga90,
       COALESCE(perf.mins, 0) >= 900 AS min_900
FROM watch w LEFT JOIN perf USING (player_id) WHERE w.position = 'Attack'
ORDER BY w.market_value_in_eur DESC, mins DESC;

-- [P12.18] 5. All columns in appearances (with type)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'appearances' ORDER BY ordinal_position;

