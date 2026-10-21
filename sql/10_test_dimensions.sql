
USE FootballBI;
GO
SELECT table_name, rows_read, rows_inserted, rows_updated, table_status,
       CASE WHEN table_status = 'Success' THEN 'PASS' ELSE 'FAIL' END AS test
FROM etl.vw_RunSummary
WHERE run_id = (SELECT MAX(run_id) FROM etl.Run WHERE package_name = '03_Load_Dimensions');

SELECT x.dim, x.rows_now, e.expected,
       CASE WHEN x.rows_now = e.expected THEN 'PASS' ELSE 'FAIL' END AS test
FROM (SELECT 'DimCompetition' AS dim, COUNT(*) AS rows_now FROM dw.DimCompetition
      UNION ALL SELECT 'DimClub',   COUNT(*) FROM dw.DimClub
      UNION ALL SELECT 'DimPlayer', COUNT(*) FROM dw.DimPlayer) x
JOIN (VALUES ('DimCompetition', 71),      -- 65 + 5 seeded + Unknown
             ('DimClub',        18720),   -- 18,719 club ids + Unknown
             ('DimPlayer',      50151))   -- 50,149 + 1 placeholder + Unknown
     e(dim, expected) ON e.dim = x.dim;

SELECT 'transfers (from)' AS source, COUNT(*) AS missing_clubs,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test
FROM cln.transfers t WHERE NOT EXISTS (SELECT 1 FROM dw.DimClub d WHERE d.club_id = t.from_club_id)
UNION ALL
SELECT 'transfers (to)', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM cln.transfers t WHERE NOT EXISTS (SELECT 1 FROM dw.DimClub d WHERE d.club_id = t.to_club_id)
UNION ALL
SELECT 'valuations', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM cln.player_valuations v WHERE NOT EXISTS (SELECT 1 FROM dw.DimClub d WHERE d.club_id = v.club_id)
UNION ALL
SELECT 'appearances', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM cln.appearances a WHERE NOT EXISTS (SELECT 1 FROM dw.DimClub d WHERE d.club_id = a.player_club_id)
UNION ALL
SELECT 'players (current club)', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM cln.players p WHERE p.current_club_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dw.DimClub d WHERE d.club_id = p.current_club_id);

SELECT check_name, value_now, expected,
       CASE WHEN value_now = expected THEN 'PASS' ELSE 'FAIL' END AS test
FROM (
          SELECT 'clubs with full details (clubs.csv)' AS check_name,
                 (SELECT COUNT(*) FROM dw.DimClub WHERE has_club_details = 1) AS value_now, 796 AS expected
    UNION ALL SELECT 'clubs with no name in any file',
                 (SELECT COUNT(*) FROM dw.DimClub WHERE club_name LIKE N'Club #%'), 185
    UNION ALL SELECT 'big-5 clubs in 2025/26',
                 (SELECT COUNT(*) FROM dw.DimClub WHERE is_big5_2025_26 = 1), 96
    UNION ALL SELECT 'special pseudo-clubs typed',
                 (SELECT COUNT(*) FROM dw.DimClub WHERE club_type <> N'Club' AND club_key <> -1), 5
) t;

SELECT contract_status, COUNT(*) AS players_now, e.expected,
       CASE WHEN COUNT(*) = e.expected THEN 'PASS' ELSE 'FAIL' END AS test
FROM dw.DimPlayer p
JOIN (VALUES (N'Running', 18345), (N'Expired', 13235), (N'Unknown', 18570)) e(status, expected)
  ON e.status = p.contract_status
WHERE p.player_key <> -1
GROUP BY contract_status, e.expected;

SELECT TOP 10 club_key, club_id, club_name, club_type, is_youth_or_reserve,
       domestic_league_name, is_big5_2025_26, has_club_details
FROM dw.DimClub
WHERE club_id IN (11, 131, 418, 27, 515, 123, 12604) OR club_name LIKE N'%U19%'
ORDER BY club_id;

SELECT competition_id, competition_name, competition_type, is_big5, is_seeded
FROM dw.DimCompetition WHERE is_big5 = 1 OR is_seeded = 1 ORDER BY is_seeded, competition_id;
