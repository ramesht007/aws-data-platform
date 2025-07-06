-- =============================================================================
-- Real-time Analytics SQL for Kinesis Analytics Application
-- Processes streaming data for real-time insights and anomaly detection
-- =============================================================================

-- Create a pump to continuously select from the source stream
CREATE OR REPLACE PUMP "STREAM_PUMP" AS INSERT INTO "DESTINATION_SQL_STREAM"
SELECT 
    user_id,
    event_type,
    timestamp,
    COUNT(*) AS event_count,
    -- Create 5-minute tumbling windows
    ROWTIME_TO_TIMESTAMP(
        ROWTIME - MOD(ROWTIME, INTERVAL '5' MINUTE)
    ) AS window_start
FROM "SOURCE_SQL_STREAM_001"
WHERE 
    -- Filter out invalid events
    user_id IS NOT NULL 
    AND event_type IS NOT NULL
    AND timestamp IS NOT NULL
GROUP BY 
    user_id,
    event_type,
    -- Group by 5-minute tumbling windows
    ROWTIME_TO_TIMESTAMP(
        ROWTIME - MOD(ROWTIME, INTERVAL '5' MINUTE)
    );

-- =============================================================================
-- Anomaly Detection Query
-- Detects unusual patterns in user behavior
-- =============================================================================

CREATE OR REPLACE PUMP "ANOMALY_PUMP" AS INSERT INTO "DESTINATION_SQL_STREAM"
SELECT 
    user_id,
    'ANOMALY_DETECTED' AS event_type,
    CURRENT_TIMESTAMP AS timestamp,
    COUNT(*) AS anomaly_score
FROM "SOURCE_SQL_STREAM_001"
WHERE 
    -- Detect users with unusually high activity in 1-minute windows
    user_id IN (
        SELECT user_id
        FROM "SOURCE_SQL_STREAM_001"
        GROUP BY 
            user_id,
            ROWTIME_TO_TIMESTAMP(
                ROWTIME - MOD(ROWTIME, INTERVAL '1' MINUTE)
            )
        HAVING COUNT(*) > 100  -- Threshold for anomaly detection
    )
GROUP BY 
    user_id,
    ROWTIME_TO_TIMESTAMP(
        ROWTIME - MOD(ROWTIME, INTERVAL '1' MINUTE)
    );

-- =============================================================================
-- Real-time Aggregations
-- Provides real-time metrics and KPIs
-- =============================================================================

CREATE OR REPLACE PUMP "METRICS_PUMP" AS INSERT INTO "DESTINATION_SQL_STREAM"
SELECT 
    'SYSTEM' AS user_id,
    'REAL_TIME_METRICS' AS event_type,
    CURRENT_TIMESTAMP AS timestamp,
    COUNT(*) AS total_events,
    COUNT(DISTINCT user_id) AS unique_users,
    -- Calculate events per second
    COUNT(*) / 60.0 AS events_per_second
FROM "SOURCE_SQL_STREAM_001"
GROUP BY 
    -- 1-minute tumbling windows for real-time metrics
    ROWTIME_TO_TIMESTAMP(
        ROWTIME - MOD(ROWTIME, INTERVAL '1' MINUTE)
    ); 