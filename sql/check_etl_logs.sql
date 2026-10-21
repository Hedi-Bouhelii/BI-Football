
USE FootballBI;
GO

SELECT TOP 1
       run_id, package_name, status, started_at, ended_at,
       DATEDIFF(SECOND, started_at, ended_at) AS duration_sec,
       run_by, host_name, error_message
FROM etl.Run
ORDER BY run_id DESC;

SELECT table_name, rows_read, rows_loaded,
       rows_read - rows_loaded AS difference,
       table_status
FROM etl.vw_RunSummary
WHERE run_id = (SELECT MAX(run_id) FROM etl.Run)
ORDER BY rows_read;

WITH stamped AS (
    SELECT 'clubs' AS table_name, etl_run_id, COUNT(*) AS n FROM stg.clubs GROUP BY etl_run_id
    UNION ALL SELECT 'competitions',      etl_run_id, COUNT(*) FROM stg.competitions      GROUP BY etl_run_id
    UNION ALL SELECT 'players',           etl_run_id, COUNT(*) FROM stg.players           GROUP BY etl_run_id
    UNION ALL SELECT 'transfers',         etl_run_id, COUNT(*) FROM stg.transfers         GROUP BY etl_run_id
    UNION ALL SELECT 'games',             etl_run_id, COUNT(*) FROM stg.games             GROUP BY etl_run_id
    UNION ALL SELECT 'club_games',        etl_run_id, COUNT(*) FROM stg.club_games        GROUP BY etl_run_id
    UNION ALL SELECT 'player_valuations', etl_run_id, COUNT(*) FROM stg.player_valuations GROUP BY etl_run_id
    UNION ALL SELECT 'appearances',       etl_run_id, COUNT(*) FROM stg.appearances       GROUP BY etl_run_id
    UNION ALL SELECT 'game_lineups',      etl_run_id, COUNT(*) FROM stg.game_lineups      GROUP BY etl_run_id
)
SELECT s.table_name, s.etl_run_id, s.n AS rows_in_staging, e.expected,
       s.n - e.expected AS difference
FROM stamped s
JOIN (VALUES ('clubs',796),('competitions',65),('players',50149),
             ('transfers',175165),('games',88958),('club_games',177916),
             ('player_valuations',656301),('appearances',1894350),
             ('game_lineups',3179016)) e(table_name, expected)
  ON e.table_name = s.table_name
ORDER BY e.expected;

SELECT r.run_id, r.status, r.started_at,
       DATEDIFF(SECOND, r.started_at, r.ended_at) AS duration_sec,
       COUNT(l.run_log_id)                        AS tables_logged,
       SUM(l.rows_loaded)                         AS total_rows_loaded,
       LEFT(r.error_message, 150)                 AS error_start
FROM etl.Run r
LEFT JOIN etl.RunLog l ON l.run_id = r.run_id
GROUP BY r.run_id, r.status, r.started_at, r.ended_at, r.error_message
ORDER BY r.run_id DESC;

SELECT table_name, rows_loaded,
       DATEDIFF(SECOND,
                LAG(logged_at, 1, (SELECT started_at FROM etl.Run WHERE run_id = l.run_id))
                    OVER (ORDER BY logged_at),
                logged_at) AS seconds_taken
FROM etl.RunLog l
WHERE run_id = (SELECT MAX(run_id) FROM etl.Run)
ORDER BY seconds_taken DESC;
