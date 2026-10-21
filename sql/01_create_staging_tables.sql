USE FootballBI;
SELECT COUNT(*) AS rows_loaded FROM stg.clubs;
SELECT TOP 10 name, coach_name, stadium_name
FROM stg.clubs
WHERE name LIKE N'%[éüöóñ]%';