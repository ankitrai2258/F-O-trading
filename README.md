 **Futures & Options (F&O) Database Design – NSE/BSE/MCX Analytics**

 **Objective**
Designed a relational **3NF database** to handle high-volume F&O data (3M+ rows from NSE Kaggle dataset). The schema is also extensible to support other exchanges like BSE and MCX.

The database supports key analytics such as:
* Open Interest (OI) changes
* Volatility analysis
* Option chain summaries
* Cross-exchange comparisons

 **ER Diagram (F&O_ER_Diagram.png)**

Includes:
* Entities and attributes
* Primary & Foreign keys
* 1:M relationships between tables

**Design Rationale**
**Normalization (3NF)**

I used normalization to reduce redundancy and keep the data consistent.
For example:
* Symbol and instrument details are stored once in the `instruments` table
* Contract-level details (expiry, strike, option type) are stored in `contracts`
Without this, the same information would repeat across millions of rows in the `trades` table.

**Why I avoided Star Schema**
Star schema is useful for reporting/OLAP systems, but in this case:
* Data ingestion happens frequently
* Updates should remain simple and consistent
* Avoiding duplication is important
So a normalized relational design felt more practical and efficient for this dataset.

**Scalability (10M+ rows / future HFT use)**
To handle large datasets:

* **Partitioning by date** helps limit data scanned (e.g., last 30 days query only scans relevant partitions)
* **Indexes on timestamp, symbol, and keys** improve query speed
* Design supports **append-only loads**, which is useful for trading data
This makes the system scalable as data grows.

**Files**
* `schema.sql` → Table creation, indexes, partitioning
* `advanced_queries.sql` → SQL queries for analytics
* `F&O_ER_Diagram.png` → ER diagram

