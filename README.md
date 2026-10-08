# BI Football: player valuation and contract risk

This is a Business Intelligence project built on Transfermarkt data. It follows these stages:

1. Data sources
2. ETL with SSIS
3. Data warehouse (star schema) in SQL Server
4. KPIs
5. Power BI dashboard
6. Analysis and recommendations

The business question is which players are worth more or less than their price, which valuable players may leave for free, and how much value clubs give away through free departures.

## Structure

```
BI_Football/
├── data/        raw/ (not in Git), inbox/, archive/  (see data/README.md)
├── sql/         DDL, stored procedures, test scripts
├── ssis/        Visual Studio SSIS solution
├── python/      AI layer
├── powerbi/     Power BI report (.pbix)
├── reports/     dataset feasibility check (report, column dictionary, quality issues, queries)
└── docs/        decision log, screenshots
```

## Start here

- `reports/dataset_check_report.md`: the dataset feasibility check (verdict, coverage, data gaps)
- `docs/decision_log.md`: the project's decisions

## Data source and license

"Football Data from Transfermarkt" (Kaggle `davidcariboo/player-scores`), built by https://github.com/dcaribou/transfermarkt-datasets and released under CC0 (public domain). The original data comes from transfermarkt.co.uk.
