# Dataset feasibility check: Transfermarkt "player-scores"

**Project:** BI project on football player valuation and contract risk (SSIS, then a star schema, KPIs and a dashboard)
**Dataset:** "Football Data from Transfermarkt", Kaggle `davidcariboo/player-scores` (version 679, last updated 2026-09-05), built by the open-source project https://github.com/dcaribou/transfermarkt-datasets (commit `e44f186d6f06dd8452aaf54c7921ba66c961f637`, from the `version` table). The underlying data comes from transfermarkt.co.uk.
**License:** CC0 public domain. Kaggle's API reports `licenseName = "CC0: Public Domain"` and the GitHub repository is CC0-1.0. Credit: David Cariboo / transfermarkt-datasets, with data from Transfermarkt.
**Files used:** the DuckDB file (option A) for all analysis, plus the 12 `*.csv.gz` files from the project's public mirror (option C) for the SQL Server load test. All files were downloaded on 2026-10-06 and have server timestamps of 2026-09-05. The Kaggle zip (option B) was not downloaded because the Kaggle CLI is not installed. The mirror CSVs are the same build, but see section 7.
**Reference date:** 2026-07-06 (the data cut-off) is used as "today" in every calculation.
**Evidence:** query IDs such as `[P2.25]` refer to `reports/queries.sql` (the SQL) and `reports/evidence/phaseNN_results.txt` (the output). All scripts are in `scripts/`.

---

## 1. Summary

### Verdict: **GO**

The decision rules in section 6 give **GO**. Every criterion is PASS except transfer classification, which is PARTIAL, and there is no FAIL. Contract completeness passes (84.2%), so the GO WITH CHANGES rule does not apply. The project still needs **three scope changes**, described in section 5:
1. The contract end date is a **single snapshot**. Contract risk can only be measured as of 2026-07-06, and a backtest is not possible with this dataset alone.
2. Loan and free transfers are **not labelled**. The ETL must derive the transfer type with the rule given in Phase 4.
3. Performance data (appearances) exists only for the **14 original European leagues**. Value-vs-output KPIs must be limited to those leagues.

### The five most important numbers

| # | Number | Evidence |
|---|---|---|
| 1 | **14 seasons** (2012/13 to 2025/26) of games and appearances in each big-5 league, with no gap years. 13 to 14 seasons per league are complete; the exception is Ligue 1 2019/20, which was cut short by COVID. | [P1.12-P1.16] |
| 2 | **84.2%** of recently active players at the 96 clubs that played big-5 football in 2025/26 have a contract end date. It is a current snapshot only, with no history. | [P2.25], [P2.13] |
| 3 | **96.1%** of players worth at least €1m have 3 or more valuations spanning at least 12 months (8,300 of 8,635). | [P3.6] |
| 4 | **93.1%** of the 175,165 transfers are classified by the derived rule, but only 69.0% fall strictly into paid, free, loan or end of loan. For senior moves worth at least €1m in the last 3 seasons, the figure is 95.7%. | [P4.28-P4.30] |
| 5 | **206 players** worth at least €5m at big-5 clubs (€2.86bn in total) have contracts ending within 12 months of 2026-07-06. Separately, **247** players worth at least €5m left on free transfers in 2023/24 to 2025/26 (€2.67bn). | [P9.2], [P9.11] |

### The three biggest risks

1. **No contract history.** `players.contract_expiration_date` is overwritten with the player's current contract. For example, 58 of the 66 players worth at least €5m who left for free in 2025/26 now show their *new* club's contract [P9.20]. In addition, 1,134 recently active players have a contract that ended on 2026-06-30, so their real status at the cut-off is unknown [P2.18].
2. **Transfer type must be inferred.** Fee 0 can mean a free move, a loan or the end of a loan. A naive "fee 0 or NULL" filter counts **725** free departures worth at least €5m in 2025/26, while the classification rule counts **66** [P4.36 vs P4.35]. Every free-departure KPI depends on the rule.
3. **Coverage is uneven.** The 17 leagues added in 2024 (Brazil, MLS, Saudi Arabia, Austria and others) have games but **no appearances** [P5.19]. The `clubs` table holds only 796 of the 18,636 club IDs referenced elsewhere [P8.5], 5 competition codes are missing [P6.16], and a club's "competition" field shows its *last covered* league, not its current one [P2.22-P2.23]. Output data is limited to goals, assists, minutes and cards; there is no xG and there are no defensive actions.

---

## 2. Results against the decision criteria

| Criterion | Measured value | Result |
|---|---|---|
| Coverage (Phase 1) | Each big-5 league has 14 seasons (2012 to 2025) with games and appearances and no gaps. Complete seasons: ES1 14, GB1 14, IT1 14, L1 14, FR1 13 (2019/20 had 279 of 380 games). 99.9 to 100% of big-5 games have appearance rows. [P1.13-P1.16, P1.14] | **PASS** |
| Contract completeness (Phase 2) | 84.2% (2,918 of 3,464) of recently active players (`last_season >= 2025`) at clubs that played big-5 in 2025/26 have a contract date, all between 2000 and 2035. 83.1% are still running at 2026-07-06. Among players worth at least €1m: 91.2%. [P2.25, P2.26] | **PASS** (snapshot only, see risk 1) |
| Valuation history (Phase 3) | 96.1% (8,300 of 8,635) of players with a current value of at least €1m have 3 or more points spanning at least 365 days. For recently active players: 95.8%. [P3.6, P3.7] | **PASS** |
| Transfer classification (Phase 4) | 93.1% classified (163,113 of 175,165) if youth and reserve moves count as a known "internal" class. 69.0% fit strictly into paid, free, loan or end of loan. Senior moves only: 89.1%. Senior moves worth at least €1m in 2023/24 to 2025/26: 95.7%. [P4.28-P4.30] | **PARTIAL** |
| Referential integrity (Phase 6) | Appearances to players: 2 orphans out of 1,894,350 (0.0001%). Appearances to games: 0. Valuations to players: 0. Transfers to players: 0. [P6.2-P6.6] | **PASS** |
| Output data (Phase 5) | 100.0% (1,894,344 of 1,894,350) of appearances have goals, assists and minutes present and plausible (minutes 1 to 125, goals and assists 0 to 6). [P5.8] | **PASS** (14 leagues only) |
| Volume | Appearances: 1,894,350. Valuations: 656,301. [P0.2, P0.20] | **PASS** |
| Loadability (Phase 10) | All 12 CSVs are valid UTF-8 with no BOM, LF line endings, every value quoted and NULL written as an empty field. 1,000-row samples (the full file for the 3 small tables) of all 12 tables loaded into typed SQL Server staging tables with zero errors. Full files of players, transfers and valuations loaded with exact row counts. Documented fixes: decompress the `.gz` files, use code page 65001 and a `"` text qualifier. [P10a, P10b] | **PASS** (the SSIS package itself is NOT VERIFIED) |

**Verdict logic:** there is no FAIL on coverage, valuation history, transfers or integrity, and every criterion is PASS or PARTIAL, so the verdict is **GO**.

---

## 3. Findings by phase

### Phase 0: Inventory

The DuckDB file holds **13 tables**: the 12 dataset tables plus `version`. The full column list, types, null percentages, distinct counts, examples and descriptions are in `column_dictionary.csv` (164 columns). The table row counts come from [P0.2-P0.26].

| Table | Rows | Grain (one row = …) |
|---|---|---|
| appearances | 1,894,350 | one player in one game they played in (unused substitutes are not included) |
| club_games | 177,916 | one club in one game (always 2 rows per game [P6.24]) |
| clubs | 796 | one club in a covered domestic league |
| competitions | 65 | one competition |
| countries | 124 | one country |
| game_events | 1,274,469 | one goal, card, substitution or shoot-out kick |
| game_lineups | 3,179,016 | one player named in a match squad (starter or substitute) |
| games | 88,958 | one game |
| national_teams | 124 | one national team |
| player_valuations | 656,301 | one player on one Transfermarkt valuation date |
| players | 50,149 | one player (current snapshot) |
| transfers | 175,165 | one transfer leg between two clubs, including loans and loan returns |
| version | 1 | build commit hash |

**Comparison with the published figures:**
- games: 88,958 vs 88,000+ (+1.1%)
- players: 50,149 vs 50,000+ (+0.3%)
- appearances: 1,894,350 vs 1,890,000+ (+0.2%)
- valuations: 656,301 vs 650,000+ (+1.0%)
- transfers: 175,165 vs 175,000+ (+0.1%)

All differences are under 5%.

**Schema differences from the hints in section 9:**
- **Key types differ between tables.** `clubs.club_id`, `games.game_id`, `club_games.game_id`, `game_events.game_id` and `players.current_club_id` are VARCHAR, while the matching columns elsewhere are INTEGER. Every join must cast; all values are castable [P6.4].
- **Extra columns:**
  - `players`: `player_code`, `image_url`, `international_caps`, `international_goals`, `current_national_team_id`, `url`.
  - `appearances`: `player_current_club_id` and `player_name`.
  - `player_valuations`: `current_club_name`, `current_club_id`, `player_club_domestic_competition_id`. Despite the name, this is the club *at the valuation date* [P3.19].
- **Type differences:** `players.last_season` and `games.season` are text, and `players.date_of_birth` and `contract_expiration_date` are TIMESTAMP.

### Phase 1: Time coverage and cut-offs

| Table | Min date | Max date | Rows | Rows after the notice cut-off |
|---|---|---|---|---|
| games | 2006-06-09 | 2026-07-06 | 88,958 | 0 after 2026-07-06 |
| appearances | 2012-07-03 | 2026-06-28 | 1,894,350 | 0 after 2026-06-28 |
| player_valuations | 2000-01-20 | 2026-06-12 | 656,301 | 0 after 2026-06-12 |
| transfers | 1993-07-01 | **2030-06-30** | 175,165 | **520** after 2026-07-06 |

Source: [P1.1-P1.7].

- **The cut-offs match the notice exactly.** The 520 future-dated transfers (15 labelled 25/26, 492 labelled 26/27 and 13 labelled 27/28) are scheduled loan returns and agreed moves [P1.7, P4.10-P4.11]. They must be kept, because they are needed to pair loans, but they should be excluded from "as of cut-off" facts.
- **Big-5 codes are confirmed:** GB1, ES1, IT1, L1 and FR1 [P1.9]. Each league has 2012 to 2025 data (14 seasons) with **no gap years** [P1.16].
  - Games per season: 380, or 306 for L1 in every season and for FR1 from 2023, when Ligue 1 shrank to 18 clubs.
  - All seasons are 100% complete against n×(n-1) fixtures, except **FR1 2019/20 (279 of 380)**. That reflects the real COVID curtailment, not a data gap [P1.13].
- Appearance rows exist for 99.9 to 100% of big-5 games in every season, at 27.6 to 31.0 rows per game [P1.14]. The 2025/26 season is complete, with the last games played between 2026-05-16 and 2026-05-24 [P1.17].
- **Before 2012, games only cover four tournaments:** the 2006 and 2010 World Cups and Euro 2008 and Euro 2012, with seasons labelled 2005, 2007, 2009 and 2011 [P1.11].
- **Season label convention:** the season is labelled by its start year, so 2025 means 2025/26. Calendar-year leagues use the calendar year. Seasons 2024 and 2025 contain about 4,000 extra games because 17 leagues were added in 2024 [P1.11, P5.19].
- **Valuation volume:** about 45,000 to 60,000 valuation rows per year from 2019 onward [P1.18].

### Phase 2: Contract data

- **Overall coverage:** 31,580 of 50,149 players (63.0%) have a contract date [P2.3]. Among recently active players (`last_season = 2025`, 22,292 players) the figure is 77.2% [P2.1].
- **`last_season` means** the last season in which the player appears in a covered squad. It matches the season of the player's last appearance for 24,977 of 29,530 players [P2.2].
- **Decision metric:** I counted players at the **96 clubs that actually played big-5 football in 2025/26**, using the `games` table [P2.24]. That gives 3,464 recently active players, of whom 84.2% have a date and 83.1% have a contract still running at the cut-off [P2.25]. The template query that uses `current_club_domestic_competition_id` gives 84.8% of 3,627 players [P2.5], but it wrongly includes 163 players at relegated clubs such as Hull City, Watford and QPR, which are still tagged GB1 [P2.19, P2.22-P2.23].
- **By league** (recently active players, % with a contract date): ES1 91.7, GB1 84.7, IT1 84.0, FR1 82.3, ARG1 98.4, MLS1 99.8, BRA1 98.3, TR1 76.0, MEX1 45.4 [P2.4].
- **Expiry dates:** 73.6% fall on 30 June (23,252 of 31,580) [P2.8]. Expiry years range from 2000 to 2035; one date (2000-05-31) is an error [P2.7, P7.16]. No dates fall before 2000 or after 2035 [P2.20].
- **The contract date is a snapshot of the current contract. This is confirmed by four tests:**
  1. There is one row per player [P2.15], and no other column anywhere stores a contract date [P2.12].
  2. Of the players whose latest move in 2025 took them to their current club, 98.8% (5,210 of 5,272) show a contract ending *after* the move, i.e. the new contract. Examples: Wirtz, Liverpool, 2030-06-30; Isak, Liverpool, 2031-06-30 [P2.13-P2.14].
  3. Of the 66 players worth at least €5m who left for free in 2025/26, 58 now show a contract ending after 2026-07-06, which is the new club's contract [P9.20].
  4. Players whose last covered season was 2012 to 2022 still show expiry dates of 2023 or later [P2.9]. Their profiles were therefore scraped long after they left the covered leagues, so the date is "as of the last profile scrape", not "as of the player's last season".
- **Implication for a backtest:** the question "what was this player's contract in 2023?" cannot be answered. A backtest of "a contract ending soon predicts a free departure" is **not possible with this dataset alone** (see Phase 9).
- **Contract dates in the past:**
  - **12,561 players** with a club show a contract that ended before 2026-07-06 [P2.17].
  - Among recently active players, **1,134 contracts ended on 2026-06-30**, 6 days before the reference date [P2.18]. Examples at big-5 clubs: Ansu Fati, Wout Faes, Krépin Diatta (all Monaco) [P2.19]. These players either renewed or left, but the 2026/27 squads are not covered.
- **Players at the current club:** for 3,208 of 19,031 active players (16.9%), the current club differs from the destination of their latest transfer [P2.16]. Most of these are players on loan or loan returns.
- **At-risk cohort:** 348 players worth at least €5m have a contract ending between 2026-07-06 and 2027-07-06 [P2.11]. 206 of them are at big-5 clubs from 2025/26 [P2.27]. Almost all expire on 2027-06-30 [P2.10].

### Phase 3: Valuation history

- **Size:** 656,301 rows for 41,528 players, from 2000-01-20 to 2026-06-12 [P3.1]. No NULL values, 1 zero (Samardzic, 2008) and no duplicate (player, date) pairs [P3.4, P3.5].
- **Points per player:** 1 point: 1,063 players; 2 to 4: 4,576; 5 to 9: 7,211; 10 or more: 28,678 [P3.2]. 37,844 players have a history spanning at least 12 months [P3.3].
- **Decision metric:** 96.1% [P3.6]. Recently active players only: 95.8% [P3.7].
- **Update frequency:** median 2.21 points per player per year (p10 1.44, p90 2.97) [P3.8]. The median gap between valuations is 168 days, or about 156 days in 2026 [P3.9-P3.10]. Updates cluster on Transfermarkt's big update days in December and late May/June [P3.11].
- **`players.market_value_in_eur` equals the latest valuation for 100%** of players [P3.12].
- **12-month change KPI:** feasible for 96.9% (6,833 of 7,055) of active players worth at least €1m [P3.14].
- **Club at valuation date:** the valuation row carries the club at that date. For example, Wirtz shows Leverkusen until 2025-06 and Liverpool after [P3.19]. 18,821 players have more than one club in their valuation history [P3.18]. This makes valuations usable for club-history slowly changing dimensions.

### Phase 4: Transfers

- **Fees:** NULL for 61,526 rows (35.1%), 0 for 96,085 (54.9%) and above 0 for 17,554 (10.0%). No fee is negative [P4.4].
- **Value at transfer:** NULL for 68,160 rows (38.9%) [P4.5]. Where present, it equals the player's latest valuation on or before the transfer date in 99.97% of rows (106,345 of 106,381) [P8.10].
- **Season labels** have the format `YY/YY` and match the July-to-June season of the date in 99.0% of rows (173,465). The 1,700 mismatches are calendar-year leagues and back-dated rows [P4.22-P4.23], so the ETL should derive the season from the date.
- **Special pseudo-clubs** [P4.8]:
  - 515 "Without Club": 6,275 references
  - 75 "Unknown": 1,145
  - 123 "Retired": 185
  - 2113 "Career break": 125
  - 12604 "Own Youth": 35
- **No loan information exists in any column.** Club names never contain "loan" [P4.9], and the CSV carries the same numeric fee with no fee text [P4.16].
- **How loans appear:** a loan shows up as a leg `A→B` with fee 0, followed by a reverse leg `B→A`, usually with fee 0 and dated 30 June or 31 December [P4.13, P4.15]. There are 37,208 such round trips [P4.13].
- **What NULL fees are:** mostly youth and reserve moves, such as Benfica U17 → Benfica U19 [P4.20], plus undisclosed fees.

**Classification rule** (in `scripts/checklib.py`, `TRANSFER_CLASS_SQL`). It uses window functions only, so it ports to T-SQL.

1. Order each player's legs by date. When a player has several legs on the same day, first take the leg that starts at the club the player was at before that day, then sort by fee in descending order. This handles both "loan return, then purchase" and "purchase, then loan back".
2. A leg is a **return** when it reverses the previous leg, comes 14 to 760 days later, has fee 0 or NULL, and does not involve a pseudo-club.
3. Consecutive returns form chains. Odd positions in a chain are **loans** and even positions are **ends of loan**.
4. All other legs:
   - fee above 0 → **paid**
   - Unknown club → **unknown**
   - to Retired, Without Club or Career break → **free** (retired / released)
   - from Without Club → **free** (free agent signed)
   - fee 0 → **free**
   - fee NULL and either side is a youth or reserve team → **internal**
   - otherwise → **unknown** (fee not disclosed)
5. `is_free_departure` marks legs where a real, senior club lost the player without a fee. It excludes loans, loan returns and youth moves.

| Class | Rows | % |
|---|---|---|
| free | 42,849 | 24.46 |
| internal (youth/reserve) | 42,223 | 24.10 |
| loan | 30,376 | 17.34 |
| end of loan | 30,376 | 17.34 |
| paid | 17,289 | 9.87 |
| unknown | 12,052 | 6.88 |

Source: [P4.26]. Subclasses are in [P4.27].

- **Validation:** 66 of the 67 legs for 17 well-known players (2022 to 2026) are classified correctly [P4.31]. The one miss is Recre Granada → Granada CF, a reserve-team promotion left as "unknown", which is the feeder-club gap described under residual error. The correct cases include:
  - Rashford's two loans
  - Hincapié's loan followed by a purchase
  - Mamardashvili's purchase and loan back
  - Simons' end of loan followed by a purchase
  - Østigård's loan, end of loan and purchase on the same day
  - Zaragoza's loan ending and a new loan starting on the same day
  - Udogie's and Amrabat's purchase and loan back
  - Guiu's 26-day loan that was recalled
  - De Bruyne, Sané and David leaving for free
- **Fixes after a first run:** the first version of the rule mis-ordered same-day legs and dropped short loans. These are the Zaragoza, Amrabat, Udogie and Guiu cases, and all of them were fixed before the final run.
- **Residual error:**
  - 655 "free" legs are later followed by a reverse move, so they may be loans whose return was not recorded (0.4%) [P4.34].
  - 12,052 rows stay unknown, mostly B-team to first-team moves at named feeder clubs such as Atl. Madrileño and Tapatío [P4.32]. The unknown share is stable at 6 to 8% per season [P4.33].
- **Free-departure test** (value at transfer of at least €5m, loans excluded) [P4.35]:

| Season | Free departures ≥ €5m | Value |
|---|---|---|
| 22/23 | 94 | €1.182bn |
| 23/24 | 97 | €1.082bn |
| 24/25 | 84 | €942m |
| 25/26 | 66 | €650.5m |
| 26/27 (partial, data to the cut-off) | 39 | €431m |

  - Summer windows only (June to September): 88 in 2023, 81 in 2024, 53 in 2025 [P4.37].
  - The instructions' template query (fee 0 or NULL, without excluding loans) returns **725** for 25/26 [P4.36], about 11 times too many.
  - The 10 most valuable free departures in 2023/24 to 2025/26 [P4.38] were Mbappé (€180m), Škriniar (€50m), J. David (€45m), Messi (€35m), Rabiot (€35m), Thuram (€32m), Sané (€32m), Laimer (€28m), Ndicka (€28m) and Kamada (€27m).
  - In the partial 26/27 window, the largest are Konaté (€45m), Vlahović (€35m), Salah (€22m) and Bernardo Silva (€22m). All are recorded as going to "Without Club" on 2026-07-01 because their next club is not covered [P4.39].

### Phase 5: Appearances

- **Size:** 1,894,350 rows covering 29,531 players and 73,426 games, from 2012-07-03 to 2026-06-28 [P5.1]. By competition type: domestic league 84.8%, domestic cup 6.3%, international cup 3.2%, other (UEFA club competitions) 4.8%, and missing competition 0.7% [P5.3].
- **Measures:** goals, assists and minutes have no NULLs. Minutes equal 0 in 3 rows and exceed 120 in 3 rows (135, 135, 148); 9,262 rows are at exactly 120 (extra time). The maximum is 6 goals or 6 assists in a game. Cards are always valid [P5.4-P5.7].
- **Plausibility:** 100.0% plausible [P5.8].
- **Consistency with scores:** in big-5 league games, appearance goals equal the final score in 91.1% of games. The gap of 2,451 goals is largely own goals (2,066 own-goal events), which are not credited to a player [P5.9-P5.10]. Appearances do not include unused substitutes [P5.11].
- **Task: players worth at least €5m with at least 10 appearances in 2024/25 plus 2025/26:** **80.6%** (2,029 of 2,518) [P5.12]. Of the rest, 291 have no appearances at all. They are mostly players in leagues without appearance data, such as Kaio Jorge (Cruzeiro), Ivan Toney (Al-Ahli) and Kurt Zouma (CFR Cluj), plus injured players [P5.14].
- **Coverage:** appearances exist only for the **14 original leagues**: BE1, DK1, ES1, FR1, GB1, GR1, IT1, L1, NL1, PO1, RU1, SC1, TR1 and UKR1. The 17 leagues added in 2024 (A1, ARG1, AUS1, BRA1, C1, JAP1, KR1, MEX1, MLS1, NO1, PL1, RO1, RSK1, SA1, SE1, SER1 and TS1) have games but **no appearances** [P5.19-P5.20].
- **Defenders and goalkeepers:** goals and assists understate them. Position-specific measures that can be built from the available columns:
  - **Clean sheets and goals conceded** per game and per 90 minutes, from `club_games.opponent_goals` [P5.18].
  - **Goals conceded while on the pitch**, from goal minutes in `game_events` combined with substitution minutes.
  - **Starts and minutes share**, from `game_lineups.type` and minutes.
  - **Team points per game when playing**, from `club_games.is_win` and the score.
  - **Cards per 90 minutes**.
  - **Per-game position**, from `game_lineups.position` (19 values) [P5.16].
- **Not available:** shots, xG, tackles, saves and passing.

### Phase 6: Keys and referential integrity

| Join | Orphans | Explanation |
|---|---|---|
| appearances → players | 2 (0.0001%) | negligible |
| appearances → games (cast) | 0 | safe |
| player_valuations → players | 0 | safe |
| transfers → players | 0 | safe |
| players.current_club_id → clubs | 2,986 (5.95%) | club outside the covered leagues; these players also have no club name or competition [P6.7-P6.8] |
| appearances.player_club_id → clubs | 11,062 (0.58%) | opponents in cups and European games [P6.9-P6.10] |
| games home/away → clubs | 12,818 home / 11,242 away | all in cup, European and international games; **0 in domestic league games** [P6.11-P6.12] |
| transfers from/to → clubs | 62.6% / 52.9% | clubs outside the covered leagues (16,612 distinct missing from-IDs) [P6.14] |
| player_valuations club → clubs | 92,973 (14.2%) | clubs outside the covered leagues [P6.15] |
| competition codes → competitions | games 1,214; appearances 14,200 | codes POCP, CGB, COL1, KLUB and UKRS are missing from `competitions` [P6.16, P6.26] |
| game_lineups → players | 315,555 (9.9%) | opponents from uncovered clubs in qualifiers and cups [P6.17, P6.27] |
| game_events → players | 128,274 (10.1%) | same reason |

**Duplicate keys** [P6.18-P6.21]: none in players, games, appearances (by ID and by game plus player), clubs, competitions, valuations (player plus date), transfers (player, date, from and to; also no exact duplicate rows), club_games or game_events. **game_lineups has 12 duplicated (game, player) pairs.**

**Other checks:** `appearance_id` is always `<game_id>_<player_id>` [P6.22]. In every appearance, the player's club is one of the two clubs in the game and the date and competition match the game [P6.23].

**Safe joins:** appearances to players, appearances to games, valuations to players, transfers to players, and games to clubs for league games. **Joins that need a fallback dimension:** any club join outside league games, and any competition join.

### Phase 7: Data quality log

All 61 issues are listed in `quality_issues.csv`, with the rows affected, the percentage, an example and the fix. Null percentages per column for every table are in [P7.1-P7.13] and `column_dictionary.csv`. Section 6 below summarises the ETL tasks.

- **Dates:**
  - No birth dates fall in the future, before 1950 or less than 14 years before the cut-off; the range is 1968 to 2011 [P7.14].
  - One contract date is impossible [P7.16].
  - 39 games are dated far outside their season label [P7.17].
- **Money:**
  - No values are negative [P7.19], and `highest_market_value` is never below the current value [P7.20].
  - 111 fees are more than 5 times the value at transfer; these are genuine, e.g. Bastoni [P7.22-P7.23].
  - `clubs.net_transfer_record` is text such as `+€5.90m` [P7.24].
  - `clubs.total_market_value` and `national_teams.coach_name` are 100% NULL [P7.25].
- **Physical:** 13 heights are below 150 cm (17 and 18 cm) [P7.26-P7.27].
- **Categories:**
  - `position` has a `'Missing'` value for 586 players [P7.28, P7.52].
  - `game_lineups.position` has case variants and blanks [P7.31].
  - Non-numeric shirt numbers occur 25,698 times [P7.32].
  - 1,214 games have a NULL `competition_type` [P7.33].
  - Formation labels include non-standard variants [P7.34].
  - At least 2,534 players have a defunct birth country, such as UdSSR or Jugoslawien [P7.35].
  - Competition names are URL slugs, and 3 names are duplicated (premier-liga, superliga, bundesliga) [P7.36-P7.38].
  - Confederation labels differ between tables (europa vs UEFA) [P7.39].
  - Transfers use short club names (`Inter` vs `Inter Milan`) [P7.40].
- **Text:**
  - 44,493 values of `city_of_birth` end with two non-breaking spaces [P7.42-P7.43].
  - No control characters or replacement characters appear in names [P7.45].
  - 8,545 names contain accented characters, which are stored correctly as UTF-8 [P7.44].
  - Transfer and player names are consistent across tables [P7.47].
- **Same name, different IDs:** 937 names are shared by 2,261 players, e.g. "Paulinho" ×14 [P7.49, P7.51]. Only one pair also shares a birth date and may be the same person (João Ricciulli) [P7.50].

### Phase 8: Star schema feasibility

| Planned object | Source table(s) | Grain (confirmed) | Needed columns | Result |
|---|---|---|---|---|
| FactValuation | player_valuations | player + date (656,301 rows, all distinct) [P8.2] | player_id, date, market_value_in_eur, current_club_id (club at that date, 100% present) | **PASS** |
| FactAppearance | appearances (+ games) | player + game (1,894,350 rows, all distinct) [P8.3] | player_id, game_id, goals, assists, minutes (all 100% present) | **PASS**: limited to 14 leagues |
| FactTransfer | transfers | one transfer leg (175,165 rows, all distinct) [P8.4] | player_id, date, from and to club, fee (64.9% non-null), value at transfer (61.1%) | **PARTIAL**: the transfer type is not in the data and must be derived (93.1% classified); most clubs are not in `clubs` |
| DimPlayer | players | player (50,149) [P6.18] | id, name, birth date, position, nationality, contract end | **PARTIAL**: the contract end is a snapshot only, so use SCD type 1 with a snapshot date; `position = 'Missing'` for 586; defunct country names |
| DimClub | clubs, plus club IDs and names from transfers, valuations and games | club | id, name, competition | **PARTIAL**: `clubs` has 796 rows but 18,636 club IDs are referenced (17,840 have no `clubs` row; 100 have no name anywhere) [P8.5-P8.6]; `domestic_competition_id` is the last covered league |
| DimCompetition | competitions | competition (65) | id, name, country, type | **PARTIAL**: 5 referenced codes are missing [P8.7]; names are slugs |
| DimDate | generated | day | not in the data | **PASS**: generate in the ETL, with a July-to-June football season and transfer-window flags |
| DimPosition | players.position and sub_position (14 combinations), game_lineups.position (19 values) [P8.8] | position | position group, detailed position | **PASS** after normalisation |

**KPI computability** (reference date 2026-07-06):

| KPI (section 1) | Computable? | Columns used | Missing / caveat | Sample |
|---|---|---|---|---|
| Market value change over 12 months | **Yes** (96.9% of active players worth at least €1m [P3.14]) | player_valuations (value as of 2026-07-06 vs as of 2025-07-06) | none | Yan Diomande €1.5m → €90m; J. Neves and Vitinha +€60m; Rodri −€60m; Bellingham −€50m [P8.11-P8.12] |
| Value per goal contribution | **Yes**, 14 leagues only | players.market_value_in_eur, appearances goals and assists | no xG; favours forwards | Kike García €78k per G+A; Kramarić €125k [P8.14] |
| Goal contributions per 90 | **Yes**, 14 leagues only | appearances | none | Kane 1.55, Dembélé 1.44, Olise 1.40 (big-5 2025/26, at least 900 minutes) [P8.13] |
| Fee paid vs market value at transfer | **Yes** (93.6% of paid transfers have a value [P9.8]) | transfers.transfer_fee, transfers.market_value_in_eur (equal to the as-of valuation in 99.97% of rows [P8.10]) | the paid class comes from the derived rule | 2023 to 2026: median ratio 0.86 (p10 0.26, p90 2.24); Woltemade 2.50×, N. González 3.33× [P8.15-P8.16] |
| Months until contract end (as of 2026-07-06) | **Yes, snapshot only** | players.contract_expiration_date | no history; 16% of active big-5 players have no date | Kane, Vinicius Junior and Foden: 11 months; Wirtz: 47; Yamal: 59. Distribution: 852 players at 7 to 12 months, 66 expired [P8.17-P8.18] |
| "Value gap" score (performance rank minus value rank) | **Yes**, but must be ranked within position **and age band** | appearances, players | the raw rank is dominated by veterans (Gregoritsch 32, Aubameyang 37) | [P8.19], age-adjusted version in [P9.7] |
| Free departures above a threshold | **Yes**, with the derived class | transfers (classified) | depends on the rule | Phase 4, [P8.20] |
| Squad value at risk | **Yes**, snapshot only | players (contract end, value, current club) | as of the cut-off only | Real Madrid €231.5m (18.3% of squad value), Man City €145.3m, Fulham 30.2% [P8.21] |

**Data the KPIs cannot use:** wages, contract start dates and contract history, release clauses, agent fees, xG and defensive event data.

---

## 4. Answers to the business questions (Phase 9)

| # | Question | Answerable | Supporting rows | Answer | Weaknesses |
|---|---|---|---|---|---|
| 1 | **Contract risk:** players worth at least €5m with a contract ending within 12 months of 2026-07-06, and how many are in the big 5 | **Yes** (as of the cut-off) | 348 players (€3.95bn); **206 at big-5 clubs** (€2.86bn) [P9.2] | By league: GB1 64 (€1.05bn), IT1 43 (€534m), FR1 40 (€393m), ES1 30 (€501m), L1 29 (€384m) [P9.3]. Largest: Vinicius Junior €140m, Foden €70m, Kane €60m, Dimarco, Rodri and Ferran Torres €50m each [P2.10]. Using the raw competition column instead gives 214, which includes relegated clubs. | Snapshot only; 47 of the 348 have a move recorded since 2026-06-01, mostly loan returns [P9.4]; 2026/27 squads are not covered |
| 2 | **Value vs output:** high G+A per 90 but low value for position and age, last full season (2025/26) | **Partly** | 1,483 outfield players at big-5 clubs with at least 900 minutes (408 Attack, 601 Defender, 474 Midfield) [P9.5] | **42 players** are in the top 20% for output within their position and the bottom 30% for value within position × age band; 16 of them are aged 25 or under [P9.6]. Examples: Santiago Hidalgo (21, Toulouse, €6m, 0.69 per 90), Javi Rueda (24, Celta, €6m), Martim Neto (23, Elche, €4m), Pablo Torre (23, Mallorca, €5m), Kamory Doumbia (23, Brest, €9m) [P9.7]. | G+A only, with no xG or defensive actions, so defenders are under-rated (use clean sheets); 14 leagues only; value at the cut-off vs output over the whole season |
| 3 | **Fee vs value at transfer** | **Yes** | 17,289 paid transfers, of which **16,188 (93.6%)** have both numbers [P9.8] | Median fee/value ratio of 0.83 to 0.86 since 2021/22. The aggregate ratio (total fees ÷ total values) was 0.94 to 1.00 in 2021/22 and 2022/23, and 1.04 to 1.06 from 2023/24 to 2025/26 [P9.9]. Buyers in the big 5 (2023/24 to 2025/26): Premier League median **1.25×**, Ligue 1 1.11×, Serie A 1.00×, Bundesliga 0.87×, LaLiga 0.83× [P9.10]. | The paid class comes from the derived rule; fees are Transfermarkt-reported (add-ons unclear); 0.15% are loans with a fee |
| 4 | **Value given away** through free departures of players worth at least €5m, over the last three windows | **Yes** (with the derived rule) | 247 departures [P9.11] | 23/24: **97** (€1.08bn); 24/25: **84** (€942m); 25/26: **66** (€650.5m). Biggest club losses: 23/24 Leicester €58m (Tielemans and others) and Frankfurt €55m; 24/25 **PSG €187.5m** (Mbappé) and Juventus €41m; 25/26 Lille €65m (J. David) and Arsenal €47m. Over all three windows: PSG €230.9m, Lille €108.8m, Leicester €83.2m [P9.12-P9.15]. | Depends on the classification (655 possible unpaired loans); "Without Club" exits on 2026-07-01 may hide later club-to-club moves |
| 5 | **Value trajectory** in the 12 months before a free departure | **Yes** | 247 departures, all with a valuation 12 months earlier (on average 2.8 valuation points in the window) [P9.16] | **162 values fell, 25 stayed flat and 60 rose; the median change was −25%** over the final year. Examples: Sané −54%, Messi −30%, Škriniar −23%, Thuram +60% [P9.17]. For comparison, players sold for a fee in 25/26 gained a median **+25%** in the year before their sale, against 0% for all other players worth at least €5m [P9.18]. | Valuations are updated about every 5 to 6 months, so the trend is coarse |

**Backtest note:** a backtest of "a contract ending soon predicts a free departure" is **not possible with this dataset alone**. There is only one contract column [P9.19], and it holds the current contract (Phase 2 tests). Possible alternatives:
- (a) **Phase 11:** a SoFIFA / EA FC snapshot with contract end dates, matched on name plus birth year. This was not run because no file was supplied.
- (b) **Older versions of this same Kaggle dataset** (CC0, 679 versions). An old version's `players` table should hold the contract dates *as of that build*, for example a July 2024 build checked against free departures in summer 2025. This is NOT VERIFIED, because no downloads beyond section 3 were allowed.
- (c) **An outcome-only analysis**, such as Q5, which needs no contract history.

---

## 5. Recommended changes to the star schema and KPI list

**Star schema**
- **DimClub:** build it from the union of `clubs` and every club ID and name in transfers, valuations and games (18,636 IDs).
  - Prefer `clubs.name`, otherwise use the most recent short name.
  - Add the attributes `club_type` (real / Without Club / Retired / Unknown / Career break / Own Youth), `is_youth_or_reserve`, `parent_club_id` (from a maintained feeder-club lookup table) and `is_big5_2025_26` (from games, *not* from `domestic_competition_id`).
- **DimCompetition:** seed the 5 missing codes (POCP, CGB, COL1, KLUB, UKRS) and a display name.
  - Add `has_appearance_data`, true only for the 14 original leagues.
  - Map `country_id = -1` to "International".
- **DimPlayer:** use SCD type 1 for descriptive attributes and for `contract_end_date`, together with `contract_snapshot_date = 2026-07-06` and `contract_status` (running / expired before the reference date / unknown).
  - Track club history either as SCD type 2 on club, or (recommended) as a **FactPlayerClubSpell** bridge with player, club, start, end and spell type (permanent / loan). Build it from the classified transfers, cross-checked with the club on each valuation.
- **FactTransfer:** add the derived `transfer_class`, `transfer_subclass`, `is_free_departure`, `is_future_dated` and `season_from_date` (via **DimTransferType**).
  - Keep the raw fee and value. Add a `fee_to_value_ratio` measure.
- **FactValuation:** keep `club_id` at the valuation date. This is the only reliable dated club link.
- **FactAppearance:** add `position_played` from game_lineups, and the team result and goals conceded from club_games, so defensive KPIs can be built.
- **FactPlayerSnapshot (optional):** one row per player per month-end with value, club and 12-month value change. Contract months-left can only be filled for the 2026-07-06 snapshot.
- **DimDate:** add a football season (July to June), a calendar season for calendar-year leagues, and summer and winter window flags.
- **DimPosition:** normalise player positions (14 combinations, `Missing` → Unknown) and lineup positions (19 values, case variants).
- **DimAgeBand** (or an age attribute on the fact): needed for the value-gap KPI.

**KPI list**
- **Keep:** 12-month value change; fee vs value at transfer; free departures above a threshold; squad value at risk; months until contract end.
  - Label the last two clearly as "as of 2026-07-06".
- **Change:**
  - Rank the value-gap score **within position × age band**.
  - Use **clean sheets and goals conceded per 90** for defenders and goalkeepers instead of G+A.
  - Report "value per goal contribution" for attackers and midfielders only.
  - Restrict output KPIs to the 14 leagues with appearance data.
- **Add:**
  - **Value decay before a free exit** (Q5: median −25%).
  - **Fee premium by buying league** (Q3).
  - **Loan share of moves**, which needs the derived class.
  - **Data coverage KPIs:** the share of players with a contract date, and the share of transfers with type unknown.
- **Drop or rescope:** any predictive or backtested contract-risk claim. Present contract risk as a forward-looking watch list as of the cut-off.
- **ETL automation, as planned:** split the source into season or month batch files, use a watermark and load-log table, and load only unprocessed files. State in the report that new data is simulated, because the source is frozen.

---

## 6. Cleaning tasks the ETL must handle

This is a summary of `quality_issues.csv`, which has 61 issues with fixes.

1. **Decompress** the `.gz` files before the Data Flow, because the SSIS Flat File source cannot read gzip. Read them as UTF-8 (code page 65001) with the `"` text qualifier and a header row. Treat empty fields as NULL, and convert `""` to NULL in `game_events.description`.
2. **Cast all key columns to INT.** The club and game ID types differ between tables, and all values are castable. Cast `season` and `last_season` to SMALLINT and the TIMESTAMP columns to DATE.
3. **Derive the transfer type** with the rule. Keep the 520 future-dated rows for loan pairing but flag them. Derive the season from the date (1,700 labels disagree).
4. **Build DimClub and DimCompetition from all sources**, with seeded pseudo-clubs, the 5 missing competitions, display names and a "current big-5 club" flag derived from games.
5. **Contract fields:** add a snapshot date and status. Mark the 12,561 past-dated contracts (including 1,134 that ended on 2026-06-30 for active players) as expired or unknown, and set the one impossible date to NULL.
6. **Text:** remove the non-breaking spaces from `city_of_birth` (44,493 values) and trim names. Normalise the `game_lineups.position` case variants (13,325 rows) and map `'Missing'` positions (586) to Unknown.
7. **Invalid values:** set heights below 150 cm (13) to NULL, set the zero valuation (1) to NULL, cap minutes at 120 and set 0 minutes to NULL (6 rows), and convert non-numeric shirt numbers to NULL (25,698).
8. **Parse** `clubs.net_transfer_record` (text such as `+€5.90m`) into a number. Drop the all-NULL columns `clubs.total_market_value` and `national_teams.coach_name`, and the build artefact `clubs.filename`.
9. **Map defunct countries** (UdSSR, Jugoslawien and others; at least 2,534 players) and conform confederation labels.
10. **De-duplicate game_lineups** on (game, player) (12 pairs). Map orphan players in lineups and events to an "Unknown player" member.
11. **Never join on player name** (937 names are shared). Review the one possible duplicate person (João Ricciulli).

---

## 7. NOT VERIFIED

- **The SSIS package.** The load was tested with `BULK INSERT (FORMAT='CSV')` into SQL Server 2025 LocalDB, not through an SSIS Flat File source. The SSIS 2016 runtime (`dtexec`) is installed, but no .dtsx package was built. Two SSIS-specific behaviours are untested: embedded `""` qualifiers and the "retain null values" setting.
- **Full-file loads for 9 of the 12 tables.** players, transfers and player_valuations were loaded in full, and the other tables were tested with samples that include their hardest rows. The DDL sizes come from a scan of every row, so overflows are not expected.
- **Kaggle zip (option B).** It was not downloaded because the Kaggle CLI is not installed. The mirror CSVs share Kaggle's last-update date (2026-09-05), but byte-level identity with the Kaggle files was not checked.
- **The Kaggle web page license text.** The page needs JavaScript to render. The license was confirmed through Kaggle's API metadata and the GitHub repository instead.
- **The meaning of transfer fee 0 vs NULL.** It was inferred from patterns; no source documentation states it.
- **Accuracy of the transfer classification beyond the validation sample.** There is no ground truth; 67 legs of 17 known players were checked by hand (66 correct).
- **Free departures in 2026/27.** Whether players recorded as going to "Without Club" on 2026-07-01 later joined clubs cannot be known, because 2026/27 is not covered.
- **Real-world accuracy of Transfermarkt market values and fees.** These are crowd-sourced estimates and reported fees.
- **The cause of the 17 to 18 cm heights.** They are presumed to be scraping or parsing errors.
- **Historical contract dates in older Kaggle versions** (backtest alternative b). Not checked, because no downloads beyond section 3 were allowed.
- **Phase 11 (SoFIFA matching).** Skipped because no SoFIFA file was supplied.

---

## Appendix A: Phase 10 SQL Server and SSIS readiness

**File facts** (from `reports/evidence/phase10a_csv_profile.txt`):

| File | gz size | Uncompressed | Data rows | Columns | Notes |
|---|---|---|---|---|---|
| appearances.csv.gz | 45.3 MB | 198.4 MB | 1,894,350 | 13 | 2 empty `player_name` values |
| club_games.csv.gz | 2.1 MB | 14.7 MB | 177,916 | 11 | |
| clubs.csv.gz | 51 KB | 0.2 MB | 796 | 17 | embedded quotes and commas in names; `€` in `net_transfer_record` |
| competitions.csv.gz | 2 KB | 12 KB | 65 | 11 | `country_id = -1` sentinel |
| countries.csv.gz | 3 KB | 15 KB | 124 | 8 | |
| game_events.csv.gz | 45.5 MB | 179.1 MB | 1,274,469 | 11 | 93,157 quoted empty strings `""`; 1,080,685 descriptions contain commas |
| game_lineups.csv.gz | 125.8 MB | 416.0 MB | 3,179,016 | 10 | `number` has `-`; 4 names with leading or trailing spaces |
| games.csv.gz | 5.0 MB | 29.0 MB | 88,958 | 23 | 1,828 stadium values contain `"` (escaped as `""`) |
| national_teams.csv.gz | 7 KB | 33 KB | 124 | 17 | |
| player_valuations.csv.gz | 7.2 MB | 39.6 MB | 656,301 | 6 | |
| players.csv.gz | 4.4 MB | 19.6 MB | 50,149 | 26 | dates written as `YYYY-MM-DD 00:00:00`; non-breaking spaces in `city_of_birth` |
| transfers.csv.gz | 5.8 MB | 18.1 MB | 175,165 | 10 | money written with 3 decimals (`0.000`) |

**Format of all files:**
- Delimiter `,` and quote `"`; every non-empty value is quoted, and embedded quotes are doubled.
- **No BOM**, LF line endings, valid UTF-8.
- **No embedded line breaks:** the number of physical lines equals the number of rows plus 1 in every file.
- No rows with the wrong number of fields.
- NULL is written as an **empty unquoted field**. The literal strings `NULL`, `nan` and `None` never appear.
- Dates are ISO `YYYY-MM-DD`, except the `players` TIMESTAMP columns, which add ` 00:00:00`. Decimals use `.` and there are no thousands separators.
- Every row count matches the DuckDB row count.

**Load test** (`reports/evidence/phase10b_load_test.txt`):
- **Setup:** database `BI_DatasetCheck_Staging` on `(localdb)\MSSQLLocalDB` (SQL Server 2025 Express 17.0.4025.3), with the typed staging tables below in schema `stg`.
- **Command:** `BULK INSERT ... WITH (FORMAT='CSV', FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', FIRSTROW=2, KEEPNULLS, MAXERRORS=0)`.
- **Sample loads:** each sample held 1,000 rows (or the whole file for clubs, competitions, countries and national_teams), chosen to include the longest value in every column and the first rows with quotes, commas, non-ASCII characters and empty fields. **All 12 loaded with 0 errors.**
- **Full-file loads:** players 50,149, transfers 175,165 and player_valuations 656,301. **All exact.**
- **Round-trip checks passed:**
  - accents (`Aurélien Joachim` matched exactly)
  - embedded quotes (`Stadion "Galgenwaard"`)
  - DECIMAL(18,3) fees
  - DATETIME2 dates
  - non-breaking spaces preserved (and therefore needing cleaning)
- **Behaviour to know:** `BULK INSERT` turns the quoted `""` in `game_events.description` into NULL.

**Staging definitions:** the tables to load (players, player_valuations, transfers, appearances, games, club_games, clubs, competitions and game_lineups) are below. The full DDL for all 12 tables is in `scripts/staging_tables.sql`.
- NVARCHAR sizes are the maximum observed length × 1.5, rounded up.
- Columns are NOT NULL when the file has no empty values. For batch loads of future files, consider making every non-key column nullable.
- The test database can be removed with `DROP DATABASE BI_DatasetCheck_Staging;`.

<details><summary><code>stg.players</code></summary>

```sql
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
```

</details>

<details><summary><code>stg.player_valuations</code></summary>

```sql
IF OBJECT_ID('stg.player_valuations') IS NOT NULL DROP TABLE stg.player_valuations;
CREATE TABLE stg.player_valuations (
    [player_id] INT NOT NULL,
    [date] DATE NOT NULL,
    [market_value_in_eur] BIGINT NOT NULL,
    [current_club_name] NVARCHAR(100) NOT NULL,
    [current_club_id] INT NOT NULL,
    [player_club_domestic_competition_id] NVARCHAR(10) NULL
);
```

</details>

<details><summary><code>stg.transfers</code></summary>

```sql
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
```

</details>

<details><summary><code>stg.appearances</code></summary>

```sql
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
```

</details>

<details><summary><code>stg.games</code></summary>

```sql
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
```

</details>

<details><summary><code>stg.club_games</code></summary>

```sql
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
```

</details>

<details><summary><code>stg.clubs</code></summary>

```sql
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
```

</details>

<details><summary><code>stg.competitions</code></summary>

```sql
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
```

</details>

<details><summary><code>stg.game_lineups</code></summary>

```sql
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
```

</details>
