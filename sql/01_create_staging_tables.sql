USE FootballBI;
SELECT COUNT(*) AS rows_loaded FROM stg.clubs;            -- expect 796
SELECT TOP 10 name, coach_name, stadium_name
FROM stg.clubs
WHERE name LIKE N'%[éüöóñ]%';                             -- accents must look right