
USE FootballBI;
GO

DROP TABLE IF EXISTS etl.TestTransferLabels;
CREATE TABLE etl.TestTransferLabels (
    player_id INT NOT NULL, transfer_date DATE NOT NULL, from_club_id INT NOT NULL, to_club_id INT NOT NULL,
    player_name NVARCHAR(100), from_club_name NVARCHAR(100), to_club_name NVARCHAR(100),
    expected_subclass NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_TestTransferLabels PRIMARY KEY (player_id, transfer_date, from_club_id, to_club_id)
);
INSERT INTO etl.TestTransferLabels VALUES
    (713644, '2022-07-01', 21550, 16795, N'Bryan Zaragoza', N'Recre Granada', N'Granada CF', N'unknown: fee not disclosed'),
    (713644, '2024-02-01', 16795, 27, N'Bryan Zaragoza', N'Granada CF', N'Bayern Munich', N'loan'),
    (713644, '2024-06-30', 27, 16795, N'Bryan Zaragoza', N'Bayern Munich', N'Granada CF', N'end of loan'),
    (713644, '2024-07-01', 16795, 27, N'Bryan Zaragoza', N'Granada CF', N'Bayern Munich', N'paid'),
    (713644, '2024-08-09', 27, 331, N'Bryan Zaragoza', N'Bayern Munich', N'CA Osasuna', N'loan'),
    (713644, '2025-06-30', 331, 27, N'Bryan Zaragoza', N'CA Osasuna', N'Bayern Munich', N'end of loan'),
    (713644, '2025-07-30', 27, 940, N'Bryan Zaragoza', N'Bayern Munich', N'Celta de Vigo', N'loan'),
    (713644, '2026-02-02', 940, 27, N'Bryan Zaragoza', N'Celta de Vigo', N'Bayern Munich', N'end of loan'),
    (713644, '2026-02-02', 27, 12, N'Bryan Zaragoza', N'Bayern Munich', N'Roma', N'loan'),
    (713644, '2026-06-30', 12, 27, N'Bryan Zaragoza', N'Roma', N'Bayern Munich', N'end of loan'),
    (556385, '2022-07-01', 276, 410, N'Destiny Udogie', N'Hellas Verona', N'Udinese', N'paid'),
    (556385, '2022-08-16', 410, 148, N'Destiny Udogie', N'Udinese', N'Tottenham', N'paid'),
    (556385, '2022-08-16', 148, 410, N'Destiny Udogie', N'Tottenham', N'Udinese', N'loan'),
    (556385, '2023-06-30', 410, 148, N'Destiny Udogie', N'Udinese', N'Tottenham', N'end of loan'),
    (502676, '2024-08-27', 1049, 31, N'Giorgi Mamardashvili', N'Valencia', N'Liverpool', N'paid'),
    (502676, '2024-08-28', 31, 1049, N'Giorgi Mamardashvili', N'Liverpool', N'Valencia', N'loan'),
    (502676, '2025-06-30', 1049, 31, N'Giorgi Mamardashvili', N'Valencia', N'Liverpool', N'end of loan'),
    (533738, '2025-07-04', 1082, 506, N'Jonathan David', N'Lille', N'Juventus', N'free: club to club'),
    (196357, '2025-06-09', 15, 27, N'Jonathan Tah', N'Leverkusen', N'Bayern Munich', N'paid'),
    (88755, '2025-07-01', 281, 6195, N'Kevin De Bruyne', N'Man City', N'Napoli', N'free: club to club'),
    (367284, '2022-07-18', 1237, 6195, N'Leo Østigård', N'Brighton', N'Napoli', N'paid'),
    (367284, '2024-07-30', 6195, 273, N'Leo Østigård', N'Napoli', N'Stade Rennais', N'paid'),
    (367284, '2025-02-03', 273, 533, N'Leo Østigård', N'Stade Rennais', N'Hoffenheim', N'loan'),
    (367284, '2025-06-30', 533, 273, N'Leo Østigård', N'Hoffenheim', N'Stade Rennais', N'end of loan'),
    (367284, '2025-07-29', 273, 252, N'Leo Østigård', N'Stade Rennais', N'Genoa', N'loan'),
    (367284, '2026-01-31', 252, 273, N'Leo Østigård', N'Genoa', N'Stade Rennais', N'end of loan'),
    (367284, '2026-01-31', 273, 252, N'Leo Østigård', N'Stade Rennais', N'Genoa', N'paid'),
    (192565, '2025-07-01', 27, 141, N'Leroy Sané', N'Bayern Munich', N'Galatasaray', N'free: club to club'),
    (368887, '2022-07-06', 2282, 826, N'Loïs Openda', N'Club Brugge', N'Lens', N'paid'),
    (368887, '2023-07-14', 826, 23826, N'Loïs Openda', N'Lens', N'Leipzig', N'paid'),
    (368887, '2025-09-01', 23826, 506, N'Loïs Openda', N'Leipzig', N'Juventus', N'loan'),
    (368887, '2026-06-30', 506, 23826, N'Loïs Openda', N'Juventus', N'Leipzig', N'end of loan'),
    (368887, '2026-07-01', 23826, 506, N'Loïs Openda', N'Leipzig', N'Juventus', N'paid'),
    (938158, '2022-07-01', 14321, 39813, N'Marc Guiu', N'Barça U16', N'Barça U18', N'internal: youth/reserve move'),
    (938158, '2023-01-01', 39813, 2470, N'Marc Guiu', N'Barça U18', N'Barça U19', N'internal: youth/reserve move'),
    (938158, '2024-01-01', 2470, 131, N'Marc Guiu', N'Barça U19', N'Barcelona', N'internal: youth/reserve move'),
    (938158, '2024-07-01', 131, 631, N'Marc Guiu', N'Barcelona', N'Chelsea', N'paid'),
    (938158, '2025-08-06', 631, 289, N'Marc Guiu', N'Chelsea', N'Sunderland', N'loan'),
    (938158, '2025-09-01', 289, 631, N'Marc Guiu', N'Sunderland', N'Chelsea', N'end of loan'),
    (258923, '2025-02-02', 985, 405, N'Marcus Rashford', N'Man Utd', N'Aston Villa', N'loan'),
    (258923, '2025-06-30', 405, 985, N'Marcus Rashford', N'Aston Villa', N'Man Utd', N'end of loan'),
    (258923, '2025-07-23', 985, 131, N'Marcus Rashford', N'Man Utd', N'Barcelona', N'loan'),
    (258923, '2026-06-30', 131, 985, N'Marcus Rashford', N'Barcelona', N'Man Utd', N'end of loan'),
    (776890, '2022-07-01', 11972, 1050, N'Nicolas Jackson', N'Villarreal CF B', N'Villarreal', N'internal: youth/reserve move'),
    (776890, '2023-07-01', 1050, 631, N'Nicolas Jackson', N'Villarreal', N'Chelsea', N'paid'),
    (776890, '2025-09-01', 631, 27, N'Nicolas Jackson', N'Chelsea', N'Bayern Munich', N'loan'),
    (776890, '2026-06-30', 27, 631, N'Nicolas Jackson', N'Bayern Munich', N'Chelsea', N'end of loan'),
    (659813, '2025-09-01', 15, 11, N'Piero Hincapié', N'Leverkusen', N'Arsenal', N'loan'),
    (659813, '2026-06-30', 11, 15, N'Piero Hincapié', N'Arsenal', N'Leverkusen', N'end of loan'),
    (659813, '2026-07-01', 15, 11, N'Piero Hincapié', N'Leverkusen', N'Arsenal', N'paid'),
    (287579, '2023-09-01', 430, 985, N'Sofyan Amrabat', N'Fiorentina', N'Man Utd', N'loan'),
    (287579, '2024-06-30', 985, 430, N'Sofyan Amrabat', N'Man Utd', N'Fiorentina', N'end of loan'),
    (287579, '2024-08-31', 430, 36, N'Sofyan Amrabat', N'Fiorentina', N'Fenerbahçe', N'loan'),
    (287579, '2025-06-30', 36, 430, N'Sofyan Amrabat', N'Fenerbahçe', N'Fiorentina', N'end of loan'),
    (287579, '2025-07-01', 430, 36, N'Sofyan Amrabat', N'Fiorentina', N'Fenerbahçe', N'paid'),
    (287579, '2025-09-01', 36, 150, N'Sofyan Amrabat', N'Fenerbahçe', N'Real Betis', N'loan'),
    (287579, '2026-06-30', 150, 36, N'Sofyan Amrabat', N'Real Betis', N'Fenerbahçe', N'end of loan'),
    (314353, '2025-06-01', 31, 418, N'Trent Alexander-Arnold', N'Liverpool', N'Real Madrid', N'paid'),
    (401923, '2024-09-04', 6195, 141, N'Victor Osimhen', N'Napoli', N'Galatasaray', N'loan'),
    (401923, '2025-06-30', 141, 6195, N'Victor Osimhen', N'Galatasaray', N'Napoli', N'end of loan'),
    (401923, '2025-07-31', 6195, 141, N'Victor Osimhen', N'Napoli', N'Galatasaray', N'paid'),
    (566931, '2022-07-01', 583, 383, N'Xavi Simons', N'PSG', N'PSV', N'free: club to club'),
    (566931, '2023-07-18', 383, 583, N'Xavi Simons', N'PSV', N'PSG', N'paid'),
    (566931, '2023-07-19', 583, 23826, N'Xavi Simons', N'PSG', N'Leipzig', N'loan'),
    (566931, '2025-01-29', 23826, 583, N'Xavi Simons', N'Leipzig', N'PSG', N'end of loan'),
    (566931, '2025-01-30', 583, 23826, N'Xavi Simons', N'PSG', N'Leipzig', N'paid'),
    (566931, '2025-08-29', 23826, 148, N'Xavi Simons', N'Leipzig', N'Tottenham', N'paid');
GO

SELECT table_name, rows_read, rows_loaded, rows_rejected, table_status,
       CASE WHEN table_status = 'Success' THEN 'PASS' ELSE 'FAIL' END AS test
FROM etl.vw_RunSummary
WHERE run_id = (SELECT MAX(run_id) FROM etl.Run WHERE package_name = '02_Clean_Transform')
ORDER BY rows_read;

SELECT x.table_name, x.clean_rows, e.expected,
       CASE WHEN x.clean_rows = e.expected THEN 'PASS' ELSE 'FAIL' END AS test
FROM (
          SELECT 'clubs' AS table_name, COUNT(*) AS clean_rows FROM cln.clubs
    UNION ALL SELECT 'competitions',      COUNT(*) FROM cln.competitions
    UNION ALL SELECT 'players',           COUNT(*) FROM cln.players
    UNION ALL SELECT 'games',             COUNT(*) FROM cln.games
    UNION ALL SELECT 'club_games',        COUNT(*) FROM cln.club_games
    UNION ALL SELECT 'appearances',       COUNT(*) FROM cln.appearances
    UNION ALL SELECT 'game_lineups',      COUNT(*) FROM cln.game_lineups
    UNION ALL SELECT 'player_valuations', COUNT(*) FROM cln.player_valuations
    UNION ALL SELECT 'transfers',         COUNT(*) FROM cln.transfers
) x
JOIN (VALUES ('clubs',796),('competitions',65),('players',50149),('games',88958),
             ('club_games',177916),('appearances',1894350),('game_lineups',3179004),
             ('player_valuations',656301),('transfers',175165)) e(table_name, expected)
  ON e.table_name = x.table_name
ORDER BY e.expected;

SELECT table_name, reason_code, COUNT(*) AS rows_rejected
FROM etl.RejectedRows
WHERE run_id = (SELECT MAX(run_id) FROM etl.Run WHERE package_name = '02_Clean_Transform')
GROUP BY table_name, reason_code;

SELECT e.transfer_subclass, ISNULL(x.n, 0) AS rows_now, e.expected,
       CASE WHEN ISNULL(x.n, 0) = e.expected THEN 'PASS' ELSE 'FAIL' END AS test
FROM (VALUES (N'end of loan',30376),(N'free: club to club',36283),(N'free: free agent signed',2536),
             (N'free: released / contract ended',3846),(N'free: retired',184),
             (N'internal: youth/reserve move',42223),(N'loan',30111),(N'loan with fee',265),
             (N'paid',17289),(N'unknown club',1134),(N'unknown: fee not disclosed',10918)) e(transfer_subclass, expected)
LEFT JOIN (SELECT transfer_subclass, COUNT(*) AS n FROM cln.transfers GROUP BY transfer_subclass) x
  ON x.transfer_subclass = e.transfer_subclass
ORDER BY e.expected DESC;

SELECT COUNT(*) AS legs_tested,
       SUM(CASE WHEN t.transfer_subclass = k.expected_subclass THEN 1 ELSE 0 END) AS legs_matching,
       CASE WHEN SUM(CASE WHEN t.transfer_subclass = k.expected_subclass THEN 1 ELSE 0 END) = 67
            THEN 'PASS' ELSE 'FAIL' END AS test
FROM etl.TestTransferLabels k
LEFT JOIN cln.transfers t
  ON t.player_id = k.player_id AND t.transfer_date = k.transfer_date
 AND t.from_club_id = k.from_club_id AND t.to_club_id = k.to_club_id;

SELECT k.player_name, k.transfer_date, k.from_club_name, k.to_club_name,
       k.expected_subclass, t.transfer_subclass AS subclass_now
FROM etl.TestTransferLabels k
LEFT JOIN cln.transfers t
  ON t.player_id = k.player_id AND t.transfer_date = k.transfer_date
 AND t.from_club_id = k.from_club_id AND t.to_club_id = k.to_club_id
WHERE t.transfer_subclass IS NULL OR t.transfer_subclass <> k.expected_subclass;

SELECT e.season, ISNULL(x.n, 0) AS free_departures_now, e.expected_n,
       ISNULL(x.value_eur, 0) AS value_now, e.expected_value,
       CASE WHEN ISNULL(x.n, 0) = e.expected_n AND ISNULL(x.value_eur, 0) = e.expected_value
            THEN 'PASS' ELSE 'FAIL' END AS test
FROM (VALUES (N'22/23',94,1182000000),(N'23/24',97,1082000000),(N'24/25',84,942000000),
             (N'25/26',66,650500000),(N'26/27',39,431000000)) e(season, expected_n, expected_value)
LEFT JOIN (SELECT transfer_season_label AS season, COUNT(*) AS n, SUM(market_value_eur) AS value_eur
           FROM cln.transfers
           WHERE is_free_departure = 1 AND market_value_eur >= 5000000
           GROUP BY transfer_season_label) x
  ON x.season = e.season
ORDER BY e.season;
