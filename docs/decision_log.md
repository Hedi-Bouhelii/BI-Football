# Decision log

One entry per decision, newest at the bottom. Each entry records the decision, why it was made, and what follows from it.

---

## D-001 · 2026-10-08 · Use SQL Server Developer Edition instead of LocalDB

- **Decision:** Use SQL Server Developer Edition instead of LocalDB.
- **Reason:** LocalDB has no SQL Server Agent and no SSIS catalog.
- **Consequences:**
  - The ETL can be deployed to the SSIS catalog (SSISDB) and scheduled with SQL Server Agent jobs, which the brief's automated, reusable ETL needs.
  - The installed instance is SQL Server 2025 Standard Developer Edition (17.0.1000.7), default instance `localhost`. The SQL Server, SQL Server Agent and Integration Services services are running (checked 2026-10-08).
  - The SSIS catalog does not exist yet. It still has to be created (SSMS: Integration Services Catalogs → Create Catalog).
  - The staging load test from the feasibility check ran on LocalDB (database `BI_DatasetCheck_Staging`; see `reports/dataset_check_report.md`, Appendix A). It needs to be re-run on the Developer Edition instance.
- **Status:** Accepted
