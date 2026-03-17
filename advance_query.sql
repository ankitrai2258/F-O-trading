-- 1. Top 10 symbols by open interest (OI) change across exchanges
-- (latest available date, aggregated across all contracts)
WITH latest_date AS (
    SELECT MAX(CAST(timestamp AS DATE)) AS max_date FROM trades
)
SELECT TOP 10
    i.symbol,
    e.name AS exchange,
    SUM(t.chg_in_oi) AS total_oi_change,
    SUM(t.open_int) AS current_oi
FROM trades t
JOIN contracts c ON t.contract_id = c.id
JOIN instruments i ON c.instrument_id = i.id
JOIN exchanges e ON i.exchange_id = e.id
WHERE CAST(t.timestamp AS DATE) = (SELECT max_date FROM latest_date)
GROUP BY i.symbol, e.name
ORDER BY total_oi_change DESC;


Sample output on your data (BANKNIFTY & NIFTY dominate):
symbol     | exchange | total_oi_change | current_oi
BANKNIFTY  | NSE      | 234640          | 1675780
NIFTY      | NSE      | 1339200         | 19001400


-- 2. Volatility analysis: 7-day rolling std dev of close prices for NIFTY options
 WITH daily_avg AS (
    SELECT 
        CAST(t.timestamp AS DATE) AS trade_date,
        c.option_typ,
        AVG(t.close_price) AS avg_close
    FROM trades t
    JOIN contracts c ON t.contract_id = c.id
    JOIN instruments i ON c.instrument_id = i.id
    WHERE i.symbol = 'NIFTY'
      AND c.option_typ IN ('CE','PE')
      AND i.instrument = 'OPTIDX'
    GROUP BY CAST(t.timestamp AS DATE), c.option_typ
)

SELECT TOP 14
    trade_date,
    option_typ,
    avg_close,

    -- Rolling 7-day volatility on daily avg
    STDEV(avg_close) OVER (
        PARTITION BY option_typ
        ORDER BY trade_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_vol_stddev

FROM daily_avg
ORDER BY trade_date DESC;

-- 3. Cross-exchange comparison: Avg settle_pr for gold futures (MCX) vs. equity index futures (NSE)

SELECT 
    e.name AS exchange,
    i.symbol,
    AVG(t.settle_pr) AS avg_settle_price,
    COUNT(*) AS no_of_days
FROM trades t
JOIN contracts c ON t.contract_id = c.id
JOIN instruments i ON c.instrument_id = i.id
JOIN exchanges e ON i.exchange_id = e.id
WHERE 
    (e.name = 'MCX' AND i.symbol LIKE '%GOLD%' AND c.strike_pr = 0)
    OR
    (e.name = 'NSE' AND i.symbol IN ('NIFTY','BANKNIFTY') AND c.strike_pr = 0)
GROUP BY e.name, i.symbol
ORDER BY e.name, i.symbol;

-- 4. Option chain summary: Grouped by expiry_dt and strike_pr, calculating implied volume
SELECT 
    c.expiry_dt,
    c.strike_pr,
    c.option_typ,
    SUM(t.volume) AS total_implied_volume,
    AVG(t.settle_pr) AS avg_premium,
    SUM(t.open_int) AS total_oi
FROM trades t
JOIN contracts c ON t.contract_id = c.id
JOIN instruments i ON c.instrument_id = i.id
WHERE i.symbol = 'NIFTY'
  AND c.option_typ IN ('CE','PE')
GROUP BY c.expiry_dt, c.strike_pr, c.option_typ
HAVING SUM(t.volume) > 5000
ORDER BY c.expiry_dt, c.strike_pr, total_implied_volume DESC;

-- 5. Performance-optimized query for max volume in last 30 days (using window + indexes)
-- This is the one we will optimize below

WITH ranked_data AS (
    SELECT 
        i.symbol,
        e.name AS exchange,
        t.volume,
        t.timestamp,
        t.settle_pr,
        ROW_NUMBER() OVER (
            PARTITION BY i.symbol 
            ORDER BY t.volume DESC
        ) AS rn
    FROM trades t
    JOIN contracts c ON t.contract_id = c.id
    JOIN instruments i ON c.instrument_id = i.id
    JOIN exchanges e ON i.exchange_id = e.id
    WHERE t.timestamp >= DATEADD(DAY, -30, GETDATE())
)
SELECT 
    symbol,
    exchange,
    volume AS max_volume_30d,
    timestamp AS as_of_date,
    settle_pr
FROM ranked_data
WHERE rn = 1;
-- 6. Bonus advanced query: Daily OI change % vs volume correlation for top symbols

 SELECT 
    i.symbol,
    (
        (COUNT(*) * SUM(CAST(t.volume AS FLOAT) * CAST(t.chg_in_oi AS FLOAT)) 
        - SUM(CAST(t.volume AS FLOAT)) * SUM(CAST(t.chg_in_oi AS FLOAT)))
        /
        (SQRT(
            (COUNT(*) * SUM(POWER(CAST(t.volume AS FLOAT),2)) - POWER(SUM(CAST(t.volume AS FLOAT)),2))
            *
            (COUNT(*) * SUM(POWER(CAST(t.chg_in_oi AS FLOAT),2)) - POWER(SUM(CAST(t.chg_in_oi AS FLOAT)),2))
        ))
    ) AS volume_oi_correlation,
    AVG(t.volume) AS avg_daily_volume
FROM trades t
JOIN contracts c ON t.contract_id = c.id
JOIN instruments i ON c.instrument_id = i.id
WHERE i.symbol IN ('NIFTY','BANKNIFTY')
GROUP BY i.symbol
HAVING COUNT(*) > 30
ORDER BY volume_oi_correlation DESC;
