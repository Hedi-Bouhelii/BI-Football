USE FootballBI;
GO

SELECT table_name, rows_read, rows_loaded, rows_unknown_key, table_status,
       CASE WHEN table_status = 'Success' AND rows_read = rows_loaded THEN 'PASS' ELSE 'FAIL' END AS test
FROM etl.vw_RunSummary
WHERE run_id = (SELECT MAX(run_id) FROM etl.Run WHERE package_name = '04_Load_Facts')
ORDER BY table_name;

SELECT x.fact, x.fact_rows, x.clean_rows, e.expected,
       CASE WHEN x.fact_rows = x.clean_rows AND x.fact_rows = e.expected THEN 'PASS' ELSE 'FAIL' END AS test
FROM (SELECT 'FactValuation' AS fact, (SELECT COUNT(*) FROM dw.FactValuation) AS fact_rows,
             (SELECT COUNT(*) FROM cln.player_valuations) AS clean_rows
      UNION ALL SELECT 'FactTransfer', (SELECT COUNT(*) FROM dw.FactTransfer), (SELECT COUNT(*) FROM cln.transfers)
      UNION ALL SELECT 'FactAppearance', (SELECT COUNT(*) FROM dw.FactAppearance), (SELECT COUNT(*) FROM cln.appearances)
      UNION ALL SELECT 'FactContractSnapshot', (SELECT COUNT(*) FROM dw.FactContractSnapshot), (SELECT COUNT(*) FROM cln.players)) x
JOIN (VALUES ('FactValuation', 656301), ('FactTransfer', 175165),
             ('FactAppearance', 1894350), ('FactContractSnapshot', 50149)) e(fact, expected)
  ON e.fact = x.fact;

SELECT OBJECT_NAME(parent_object_id) AS fact, name AS foreign_key, is_not_trusted, is_disabled,
       CASE WHEN is_not_trusted = 0 AND is_disabled = 0 THEN 'PASS' ELSE 'FAIL' END AS test
FROM sys.foreign_keys
WHERE OBJECT_SCHEMA_NAME(parent_object_id) = 'dw' AND OBJECT_NAME(parent_object_id) LIKE 'Fact%'
ORDER BY fact, foreign_key;

SELECT fact, key_column, unknown_rows,
       CASE WHEN critical = 0 THEN 'INFO' WHEN unknown_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS test,
       note
FROM (
              SELECT 'FactValuation' AS fact, 'player_key' AS key_column, 1 AS critical,
                     (SELECT COUNT(*) FROM dw.FactValuation WHERE player_key = -1) AS unknown_rows, '' AS note
    UNION ALL SELECT 'FactValuation', 'date_key', 1, (SELECT COUNT(*) FROM dw.FactValuation WHERE date_key = -1), ''
    UNION ALL SELECT 'FactValuation', 'club_key', 1, (SELECT COUNT(*) FROM dw.FactValuation WHERE club_key = -1), ''
    UNION ALL SELECT 'FactValuation', 'competition_key', 0, (SELECT COUNT(*) FROM dw.FactValuation WHERE competition_key = -1),
                     'club outside the covered leagues (expect 92,973)'
    UNION ALL SELECT 'FactValuation', 'age_band_key', 0, (SELECT COUNT(*) FROM dw.FactValuation WHERE age_band_key = -1),
                     'player without birth date (expect 600)'
    UNION ALL SELECT 'FactTransfer', 'player_key', 1, (SELECT COUNT(*) FROM dw.FactTransfer WHERE player_key = -1), ''
    UNION ALL SELECT 'FactTransfer', 'from_club_key', 1, (SELECT COUNT(*) FROM dw.FactTransfer WHERE from_club_key = -1), ''
    UNION ALL SELECT 'FactTransfer', 'to_club_key', 1, (SELECT COUNT(*) FROM dw.FactTransfer WHERE to_club_key = -1), ''
    UNION ALL SELECT 'FactTransfer', 'transfer_type_key', 1, (SELECT COUNT(*) FROM dw.FactTransfer WHERE transfer_type_key = -1), ''
    UNION ALL SELECT 'FactTransfer', 'age_band_key', 0, (SELECT COUNT(*) FROM dw.FactTransfer WHERE age_band_key = -1),
                     'player without birth date (expect 27)'
    UNION ALL SELECT 'FactAppearance', 'player_key', 1, (SELECT COUNT(*) FROM dw.FactAppearance WHERE player_key = -1), ''
    UNION ALL SELECT 'FactAppearance', 'club_key', 1, (SELECT COUNT(*) FROM dw.FactAppearance WHERE club_key = -1), ''
    UNION ALL SELECT 'FactAppearance', 'opponent_club_key', 1, (SELECT COUNT(*) FROM dw.FactAppearance WHERE opponent_club_key = -1), ''
    UNION ALL SELECT 'FactAppearance', 'competition_key', 1, (SELECT COUNT(*) FROM dw.FactAppearance WHERE competition_key = -1), ''
    UNION ALL SELECT 'FactAppearance', 'age_band_key', 0, (SELECT COUNT(*) FROM dw.FactAppearance WHERE age_band_key = -1),
                     'player without birth date (expect 969)'
    UNION ALL SELECT 'FactAppearance', 'is_starter IS NULL', 0, (SELECT COUNT(*) FROM dw.FactAppearance WHERE is_starter IS NULL),
                     'game without a recorded line-up (expect 137,317)'
    UNION ALL SELECT 'FactContractSnapshot', 'club_key', 1, (SELECT COUNT(*) FROM dw.FactContractSnapshot WHERE club_key = -1), ''
    UNION ALL SELECT 'FactContractSnapshot', 'contract_end_date_key', 0,
                     (SELECT COUNT(*) FROM dw.FactContractSnapshot WHERE contract_end_date_key = -1),
                     'contract date unknown (expect 18,569, see D-008)'
) t
ORDER BY fact, critical DESC, key_column;

SELECT check_name, value_now, expected,
       CASE WHEN value_now = expected THEN 'PASS' ELSE 'FAIL' END AS test
FROM (
              SELECT 'total goals in appearances' AS check_name,
                     (SELECT SUM(CAST(goals AS INT)) FROM dw.FactAppearance) AS value_now, 180437 AS expected
    UNION ALL SELECT 'starters (is_starter = 1)',
                     (SELECT COUNT(*) FROM dw.FactAppearance WHERE is_starter = 1), 1331752
    UNION ALL SELECT 'paid transfers with a fee/value ratio',
                     (SELECT COUNT(*) FROM dw.FactTransfer WHERE fee_to_value_ratio IS NOT NULL), 16442
    UNION ALL SELECT 'active big-5 players at the snapshot',
                     (SELECT COUNT(*) FROM dw.FactContractSnapshot WHERE is_active_big5 = 1), 3464
    UNION ALL SELECT 'active big-5 players expiring within 12 months (KPI C2)',
                     (SELECT COUNT(*) FROM dw.FactContractSnapshot WHERE is_active_big5 = 1 AND is_expiring_12m = 1), 818
) t;

SELECT TOP 3 p.player_name, SUM(CAST(f.goals AS INT)) AS goals,
       CASE ROW_NUMBER() OVER (ORDER BY SUM(CAST(f.goals AS INT)) DESC)
            WHEN 1 THEN CASE WHEN SUM(CAST(f.goals AS INT)) = 528 THEN 'PASS' ELSE 'FAIL' END
            WHEN 2 THEN CASE WHEN SUM(CAST(f.goals AS INT)) = 458 THEN 'PASS' ELSE 'FAIL' END
            WHEN 3 THEN CASE WHEN SUM(CAST(f.goals AS INT)) = 434 THEN 'PASS' ELSE 'FAIL' END
       END AS test                       -- Lewandowski 528, Messi 458, Ronaldo 434
FROM dw.FactAppearance f
JOIN dw.DimPlayer p ON p.player_key = f.player_key
GROUP BY p.player_name
ORDER BY goals DESC;

SELECT d.season_label, COUNT(*) AS free_departures,
       CAST(SUM(f.market_value_eur) / 1e6 AS DECIMAL(10,1)) AS value_lost_eur_m,
       e.expected,
       CASE WHEN COUNT(*) = e.expected THEN 'PASS' ELSE 'FAIL' END AS test
FROM dw.FactTransfer f
JOIN dw.DimDate d ON d.date_key = f.transfer_date_key
JOIN (VALUES (N'2022/23', 95), (N'2023/24', 96), (N'2024/25', 86), (N'2025/26', 65), (N'2026/27', 38))
     e(season, expected) ON e.season = d.season_label
WHERE f.is_free_departure = 1 AND f.market_value_eur >= 5000000
GROUP BY d.season_label, e.expected
ORDER BY d.season_label;
