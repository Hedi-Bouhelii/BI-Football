# Data folders

| Folder | Contents | In Git? |
|---|---|---|
| `raw/` | The source dataset as downloaded. It is read-only, so never edit these files. | No (1.1 GB) |
| `inbox/` | Batch files waiting to be loaded by the SSIS package | Folder only |
| `archive/` | Batch files already loaded (moved here by the ETL) | Folder only |

## Getting the raw data

The source is "Football Data from Transfermarkt" (Kaggle `davidcariboo/player-scores`, CC0), built by https://github.com/dcaribou/transfermarkt-datasets. The data is a frozen snapshot that runs up to 2026-07-06.

Use either option to download it into `data/raw/`:

- **Kaggle** (needs a Kaggle API token):
  `kaggle datasets download -d davidcariboo/player-scores -p data/raw --unzip`
- **Project mirror** (no login): one file per table. The file name pattern is
  `https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data/<table>.csv.gz`
  and the DuckDB file is at
  `https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data/transfermarkt-datasets.duckdb`.
  Decompress the `.gz` files after downloading.

The 12 tables are: appearances, club_games, clubs, competitions, countries, game_events, game_lineups, games, national_teams, player_valuations, players, transfers.
