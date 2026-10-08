# Attacker check (follow-up to the dataset feasibility check)

**Data:** `data/raw/transfermarkt-datasets.duckdb`, opened read-only.
**Reference date:** 2026-07-06.
**Queries:** IDs such as `[P12.5]` refer to the "Follow-up 12" section at the end of `reports/queries.sql`. The results are in `reports/evidence/followup12_attackers_results.txt` and the script is `scripts/followup_attackers.py`.

**Definitions used**
- **Last full season:** `games.season = '2025'`, i.e. 2025/26.
- **The 14 leagues with appearance data:** BE1, DK1, ES1, FR1, GB1, GR1, IT1, L1, NL1, PO1, RU1, SC1, TR1 and UKR1 (Phase 5, [P5.19]). Minutes, goals and assists come from domestic league games of these 14 leagues only; cup and European games are not counted. A player who moved between two of these leagues during the season has his minutes added together.
- **Attacker:** `players.position = 'Attack'`. This is the player's *current* position from the players snapshot, not the position played in each game.
- **Watch list:** the 206 players from the main report [P9.2]: market value of at least €5m, contract ending between 2026-07-06 and 2027-07-06, and a current club that played in a big-5 league in 2025/26.

---

## 1. Positions

| position | players |
|---|---|
| Defender | 15,961 |
| Midfield | 14,272 |
| Attack | 13,502 |
| Goalkeeper | 5,828 |
| Missing | 586 |

Source: [P12.1].

| position | sub_position | players |
|---|---|---|
| Attack | Centre-Forward | 6,749 |
| Attack | Left Winger | 3,297 |
| Attack | Right Winger | 3,170 |
| Attack | Second Striker | 286 |
| Defender | Centre-Back | 8,766 |
| Defender | Right-Back | 3,700 |
| Defender | Left-Back | 3,495 |
| Goalkeeper | Goalkeeper | 5,828 |
| Midfield | Central Midfield | 5,498 |
| Midfield | Defensive Midfield | 4,123 |
| Midfield | Attacking Midfield | 3,520 |
| Midfield | Left Midfield | 566 |
| Midfield | Right Midfield | 565 |
| Missing | *(NULL)* | 586 |

Source: [P12.2, P12.3].

- There are 5 position values and 13 sub-position values, plus NULL.
- Every sub-position belongs to exactly one position, so the hierarchy is clean.
- Position `'Missing'` always goes with a NULL sub-position, which makes it a placeholder.

## 2. Attackers with at least 900 minutes in 2025/26

**911 attackers** played at least 900 league minutes in 2025/26 across the 14 leagues, out of 2,026 attackers with any minutes [P12.5].

| By sub-position | Attackers |
|---|---|
| Centre-Forward | 405 |
| Left Winger | 263 |
| Right Winger | 225 |
| Second Striker | 18 |

Source: [P12.6].

By the league where the player played most of his minutes [P12.7]:

| League | Attackers |
|---|---|
| ES1 | 103 |
| GB1 | 87 |
| IT1 | 80 |
| PO1 | 75 |
| NL1 | 73 |
| TR1 | 73 |
| FR1 | 71 |
| L1 | 68 |
| UKR1 | 55 |
| RU1 | 53 |
| BE1 | 50 |
| GR1 | 46 |
| SC1 | 43 |
| DK1 | 34 |

**Scope check.** Every league's 2025/26 season is in the data. Only 2 games are missing appearance rows: one in FR1 and one in UKR1 [P12.4]. Four leagues, however, stop at their regular season:

- **Belgium (BE1):** the play-off rounds are stored under other codes. These are EJPL (Play-off I), POBE (Europe play-offs) and BPO4 (relegation play-offs), with 72 games and 2,232 appearance rows. Adding them raises the count from 911 to **926** (+15) [P12.8, P12.10]. I kept the 14-league definition as the main figure.
- **Denmark (DK1), Greece (GR1), Scotland (SC1):** the championship and relegation rounds after the split **are not in the data**. Only 132 games, 182 games and 198 games respectively are present, which are the regular seasons. After the split, these clubs have only cup and European games [P12.8, P12.9].

As a result, attackers in these four leagues had fewer league minutes available, so the 900-minute threshold is harder to reach there. Their per-90 rates come from the regular season only.

## 3. Goals plus assists per 90 minutes

Distribution for the 911 attackers [P12.11]:

| Measure | G+A per 90 |
|---|---|
| Minimum | 0.000 |
| Median | 0.425 |
| 90th percentile | 0.757 |
| Maximum | 1.549 |
| Mean | 0.454 |

5 attackers with at least 900 minutes had no goal or assist at all, for example Serdar Gürler with 1,290 minutes at Eyüpspor [P12.12].

**The 20 highest** [P12.13]:

| # | Player | Sub-position | Current club | League | Minutes | G | A | G+A per 90 | Value (€m) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Harry Kane | Centre-Forward | Bayern Munich | L1 | 2,382 | 36 | 5 | 1.55 | 60 |
| 2 | Ousmane Dembélé | Centre-Forward | Paris Saint-Germain | FR1 | 1,063 | 10 | 7 | 1.44 | 100 |
| 3 | Aral Şimşir | Left Winger | FC Midtjylland | DK1 | 1,342 | 8 | 13 | 1.41 | 10 |
| 4 | Franculino | Centre-Forward | FC Midtjylland | DK1 | 1,220 | 16 | 3 | 1.40 | 22 |
| 5 | Michael Olise | Right Winger | Bayern Munich | L1 | 2,320 | 15 | 21 | 1.40 | 150 |
| 6 | Luis Díaz | Left Winger | Bayern Munich | L1 | 2,451 | 15 | 17 | 1.18 | 70 |
| 7 | Mehdi Taremi | Centre-Forward | Olympiacos | GR1 | 1,077 | 10 | 4 | 1.17 | 2 |
| 8 | Luis Suárez | Centre-Forward | Sporting CP | PO1 | 2,699 | 28 | 7 | 1.17 | 30 |
| 9 | Lamine Yamal | Right Winger | FC Barcelona | ES1 | 2,270 | 16 | 12 | 1.11 | 200 |
| 10 | Matviy Ponomarenko | Centre-Forward | Dynamo Kyiv | UKR1 | 1,063 | 13 | 0 | 1.10 | 12 |
| 11 | Ricardo Pepi | Centre-Forward | PSV Eindhoven | NL1 | 1,415 | 16 | 1 | 1.08 | 30 |
| 12 | Erling Haaland | Centre-Forward | Manchester City | GB1 | 2,959 | 27 | 8 | 1.06 | 200 |
| 13 | Victor Osimhen | Centre-Forward | Galatasaray | TR1 | 1,713 | 15 | 5 | 1.05 | 75 |
| 14 | Dorgeles Nene | Right Winger | Red Bull Salzburg* | TR1 | 1,466 | 10 | 7 | 1.04 | 20 |
| 15 | Raphinha | Left Winger | FC Barcelona | ES1 | 1,389 | 13 | 3 | 1.04 | 70 |
| 16 | Kylian Mbappé | Centre-Forward | Real Madrid | ES1 | 2,606 | 25 | 5 | 1.04 | 180 |
| 17 | Mauro Icardi | Centre-Forward | Galatasaray | TR1 | 1,313 | 14 | 1 | 1.03 | 4 |
| 18 | Serge Gnabry | Second Striker | Bayern Munich | L1 | 1,228 | 8 | 6 | 1.03 | 18 |
| 19 | Deniz Undav | Centre-Forward | VfB Stuttgart | L1 | 2,249 | 19 | 6 | 1.00 | 22 |
| 20 | Mika Godts | Left Winger | Ajax Amsterdam | NL1 | 2,686 | 17 | 12 | 0.97 | 35 |

\* Nene's minutes were played in TR1. His current club in the players snapshot is Salzburg.

**Reading notes**
- Several entries sit close to the 900-minute minimum: Dembélé and Ponomarenko (1,063 minutes each) and Taremi (1,077). Their rates are based on about 12 full games and are therefore less stable.
- Rates are **not comparable across leagues** without adjusting for league strength. For example, the two Danish players in the top 5 played in a weaker league than the big-5 players around them.
- Goals and assists ignore everything else a forward contributes, and the dataset has no shots or xG to correct for that.

## 4. Attackers on the 206-player watch list

**46 of the 206** watch-list players are attackers, worth €872m in total [P12.14]. The other positions on the watch list are midfield 76 (€999m), defence 70 (€846m) and goalkeeper 14 (€142m) [P12.15].

Of the 46 attackers [P12.16]:
- **34** played at least 900 league minutes in 2025/26.
- 9 played between 1 and 899 minutes: Gabriel Jesus 421, Leon Bailey 634, Joël Piroe 246, Terem Moffi 729, Ethan Mbappé 559, Taiwo Awoniyi 481, Reiss Nelson 118, Romelu Lukaku 40 and Wisdom Mike 27.
- 3 played no league minutes: Joe Gelhardt, Ellis Simms and Benson Manuel.

Every watch-list attacker's contract ends on 2027-06-30 [P12.17]. The full list, sorted by market value:

| Player | Sub-position | Club | Value (€m) | Minutes | G | A | G+A per 90 | ≥ 900 min |
|---|---|---|---|---|---|---|---|---|
| Vinicius Junior | Left Winger | Real Madrid | 140 | 2,825 | 16 | 6 | 0.70 | yes |
| Harry Kane | Centre-Forward | Bayern Munich | 60 | 2,382 | 36 | 5 | 1.55 | yes |
| Ferran Torres | Centre-Forward | FC Barcelona | 50 | 1,975 | 16 | 2 | 0.82 | yes |
| Gabriel Martinelli | Left Winger | Arsenal FC | 45 | 1,073 | 1 | 4 | 0.42 | yes |
| Christian Pulisic | Right Winger | AC Milan | 40 | 1,612 | 8 | 4 | 0.67 | yes |
| Karim Adeyemi | Right Winger | Borussia Dortmund | 40 | 1,196 | 7 | 4 | 0.83 | yes |
| Brahim Díaz | Right Winger | Real Madrid | 35 | 1,252 | 1 | 8 | 0.65 | yes |
| Jean-Philippe Mateta | Centre-Forward | Crystal Palace | 30 | 2,223 | 12 | 0 | 0.49 | yes |
| Richarlison | Centre-Forward | Tottenham Hotspur | 25 | 1,960 | 11 | 4 | 0.69 | yes |
| Kaoru Mitoma | Left Winger | Brighton & Hove Albion | 22 | 1,722 | 3 | 1 | 0.21 | yes |
| Jack Grealish | Left Winger | Everton FC | 20 | 1,632 | 2 | 6 | 0.44 | yes |
| Yann Gboho | Left Winger | FC Toulouse | 18 | 2,610 | 8 | 3 | 0.38 | yes |
| Leandro Trossard | Left Winger | Arsenal FC | 18 | 2,008 | 6 | 6 | 0.54 | yes |
| Beto | Centre-Forward | Everton FC | 18 | 1,565 | 9 | 1 | 0.58 | yes |
| Dwight McNeil | Left Winger | Everton FC | 18 | 1,169 | 0 | 1 | 0.08 | yes |
| Gabriel Jesus | Centre-Forward | Arsenal FC | 17 | 421 | 3 | 0 | 0.64 | no |
| Emiliano Buendía | Left Winger | Aston Villa | 16 | 1,760 | 6 | 2 | 0.41 | yes |
| Viktor Tsygankov | Right Winger | Girona FC | 15 | 2,642 | 6 | 5 | 0.37 | yes |
| Andrea Pinamonti | Centre-Forward | US Sassuolo | 15 | 2,575 | 9 | 4 | 0.45 | yes |
| Sofiane Diop | Left Winger | OGC Nice | 15 | 2,145 | 8 | 2 | 0.42 | yes |
| Riccardo Orsolini | Right Winger | Bologna | 15 | 2,117 | 10 | 1 | 0.47 | yes |
| Pablo Pagis | Left Winger | FC Lorient | 15 | 1,772 | 10 | 5 | 0.76 | yes |
| Leon Bailey | Right Winger | AS Roma | 14 | 634 | 0 | 1 | 0.14 | no |
| Jacob Murphy | Right Winger | Newcastle United | 12 | 1,620 | 3 | 2 | 0.28 | yes |
| Lassine Sinayoko | Centre-Forward | AJ Auxerre | 10 | 2,781 | 12 | 4 | 0.52 | yes |
| Lukas Nmecha | Centre-Forward | Leeds United | 10 | 1,073 | 6 | 1 | 0.59 | yes |
| Takumi Minamino | Left Winger | AS Monaco | 10 | 950 | 3 | 2 | 0.47 | yes |
| Joël Piroe | Centre-Forward | Leeds United | 10 | 246 | 0 | 0 | 0.00 | no |
| Andrej Ilic | Centre-Forward | 1.FC Union Berlin | 9 | 2,257 | 5 | 10 | 0.60 | yes |
| Antoine Griezmann | Second Striker | Atlético de Madrid | 8 | 1,468 | 7 | 4 | 0.67 | yes |
| Terem Moffi | Centre-Forward | OGC Nice | 8 | 729 | 3 | 1 | 0.49 | no |
| Ethan Mbappé | Right Winger | LOSC Lille | 8 | 559 | 3 | 1 | 0.64 | no |
| Taiwo Awoniyi | Centre-Forward | Nottingham Forest | 8 | 481 | 4 | 2 | 1.12 | no |
| Reiss Nelson | Left Winger | Brentford FC | 8 | 118 | 0 | 1 | 0.76 | no |
| Romain Del Castillo | Right Winger | Stade Brestois 29 | 7 | 2,646 | 9 | 3 | 0.41 | yes |
| Matteo Cancellieri | Right Winger | SS Lazio | 7 | 1,731 | 4 | 2 | 0.31 | yes |
| Joe Gelhardt | Centre-Forward | Leeds United | 7 | 0 | 0 | 0 | n/a | no |
| Germán Valera | Left Winger | Elche CF | 6 | 2,871 | 4 | 5 | 0.28 | yes |
| Borja Mayoral | Centre-Forward | Getafe CF | 6 | 1,059 | 4 | 1 | 0.42 | yes |
| Romelu Lukaku | Centre-Forward | SSC Napoli | 6 | 40 | 1 | 0 | 2.25 | no |
| Ellis Simms | Centre-Forward | Everton FC | 6 | 0 | 0 | 0 | n/a | no |
| Ché Adams | Centre-Forward | Torino FC | 5 | 1,897 | 6 | 3 | 0.43 | yes |
| Amine Harit | Left Winger | Olympique Marseille | 5 | 1,566 | 2 | 4 | 0.34 | yes |
| Chris Wood | Centre-Forward | Nottingham Forest | 5 | 907 | 3 | 0 | 0.30 | yes |
| Wisdom Mike | Left Winger | Bayern Munich | 5 | 27 | 0 | 0 | 0.00 | no |
| Benson Manuel | Right Winger | Burnley FC | 5 | 0 | 0 | 0 | n/a | no |

The per-90 figures for players under 900 minutes (for example Lukaku at 2.25 in 40 minutes) are shown for completeness only and should not be read as rates.

## 5. Columns in `appearances`

The table has 13 columns [P12.18]. Besides `goals`, `assists`, `yellow_cards`, `red_cards` and `minutes_played`, it contains:

| Column | Type | What it is |
|---|---|---|
| `appearance_id` | VARCHAR | key, `'<game_id>_<player_id>'` |
| `game_id` | INTEGER | game |
| `player_id` | INTEGER | player |
| `player_club_id` | INTEGER | club the player played for in this game |
| `player_current_club_id` | VARCHAR | the player's *current* club at scrape time (a snapshot, not the club in this game) |
| `date` | DATE | game date |
| `player_name` | VARCHAR | denormalised name |
| `competition_id` | VARCHAR | competition of the game |

**All eight extra columns are identifiers or context; none is a performance measure.** The table has no shots, xG, passes, tackles, saves, starter or substitute flag, or position played. Some of this exists in other tables:
- **Starter vs substitute and position played in the game:** `game_lineups.type` and `game_lineups.position`.
- **Goal minutes and assist providers:** `game_events`.
- **Goals conceded and clean sheets:** `club_games.opponent_goals`.
