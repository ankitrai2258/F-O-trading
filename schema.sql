SQL DDL Scripts
CREATE TABLE exchanges (
    id   INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(10) NOT NULL UNIQUE 
        CHECK (name IN ('NSE', 'BSE', 'MCX'))
);

CREATE TABLE instruments (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    symbol      VARCHAR(30) NOT NULL,
    instrument  VARCHAR(10) NOT NULL,
    exchange_id INT NOT NULL FOREIGN KEY REFERENCES exchanges(id),
    CONSTRAINT uq_instrument UNIQUE (symbol, instrument, exchange_id)
);

CREATE TABLE contracts (
    id INT IDENTITY(1,1) PRIMARY KEY,
    instrument_id INT NOT NULL,
    expiry_dt DATE NOT NULL,
    strike_pr DECIMAL(12,2) NOT NULL DEFAULT 0,
    option_typ VARCHAR(5) NOT NULL DEFAULT 'XX',
    CONSTRAINT uq_contract UNIQUE (instrument_id, expiry_dt, strike_pr, option_typ),
    CONSTRAINT fk_contract_instrument FOREIGN KEY (instrument_id)
        REFERENCES instruments(id)
);
CREATE TABLE trades (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    contract_id     INT NOT NULL,
    timestamp       DATE NOT NULL,
    open_price      DECIMAL(12,2) NULL,
    high_price      DECIMAL(12,2) NULL,
    low_price       DECIMAL(12,2) NULL,
    close_price     DECIMAL(12,2) NULL,
    settle_pr       DECIMAL(12,2) NULL,
    val_inlakh      DECIMAL(15,2) NULL,
    open_int        BIGINT NULL,
    chg_in_oi       BIGINT NULL,
    volume          BIGINT NULL,

    CONSTRAINT fk_trade_contract 
        FOREIGN KEY (contract_id) REFERENCES contracts(id),

    CONSTRAINT uq_daily_contract 
        UNIQUE (contract_id, timestamp)
);
-- Indexes
CREATE NONCLUSTERED INDEX idx_trades_timestamp ON trades (timestamp);
CREATE NONCLUSTERED INDEX idx_trades_contract_ts ON trades (contract_id, timestamp);
CREATE NONCLUSTERED INDEX idx_contracts_expiry ON contracts (expiry_dt);

-- Partitioning example (range by year-month on timestamp)
-- Step 1: Partition Function (example: monthly partitions)
CREATE PARTITION FUNCTION pf_trades_monthly (DATE)
AS RANGE RIGHT FOR VALUES 
('2019-01-01', '2019-02-01', '2019-03-01', '2019-04-01', /* add more */ '2026-01-01');

-- Step 2: Partition Scheme (map to filegroups; create filegroups first in prod)
CREATE PARTITION SCHEME ps_trades_monthly
AS PARTITION pf_trades_monthly ALL TO ([PRIMARY]);  -- or dedicated filegroups
