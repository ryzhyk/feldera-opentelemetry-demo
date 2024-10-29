-- The following SQL type declarations match otlp protobuf schema for trace
-- messages.

CREATE TYPE KeyValue AS (
    key VARCHAR,
    value VARIANT
);

CREATE TYPE Event AS (
    timeUnixNano VARCHAR,
    name VARCHAR,
    attributes KeyValue ARRAY
);

CREATE TYPE Span AS (
    traceId VARCHAR,
    spanId VARCHAR,
    traceState VARCHAR,
    parentSpanId VARCHAR,
    flags BIGINT,
    name VARCHAR,
    kind INT,
    startTimeUnixNano VARCHAR,
    endTimeUnixNano VARCHAR,
    attributes KeyValue ARRAY,
    events Event ARRAY
);

CREATE TYPE ScopeSpans AS (
    scope VARIANT,
    spans Span ARRAY
);

CREATE TYPE Resource AS (
    attributes KeyValue ARRAY
);

CREATE TYPE ResourceSpans AS (
    resource Resource,
    scopeSpans ScopeSpans ARRAY
);

-- Input table tahat ingests resource spans from the collector.
CREATE TABLE otel_traces (
    resourceSpans ResourceSpans ARRAY   
) WITH ('append_only' = 'true');

CREATE VIEW resource_spans AS
SELECT
    resourceSpans.*
FROM
    otel_traces, UNNEST(resourceSpans) as resourceSpans;

-- Extract individual scope spans from resource spans.
CREATE VIEW scope_spans AS 
SELECT
    scopeSpan.scope['name'] as scopeName,
    scopeSpan.spans
FROM
    resource_spans, UNNEST(scopeSpans) AS scopeSpan;

-- Extract individual spans, convert timestamps to integers.
CREATE VIEW spans AS
SELECT
    scope_spans.scopeName as scopeName,
    traceId,
    spanId,
    traceState,
    parentSpanId,
    flags,
    name,
    kind,
    CAST(startTimeUnixNano AS BIGINT) AS startTimeUnixNano,
    CAST(endTimeUnixNano AS BIGINT) AS endTimeUnixNano,
    attributes,
    events
FROM
    scope_spans, UNNEST(spans) as span;

-- The following annotation tells Feldera that data in the `spans` view
-- arrives at most 5 minutes (1 minute = 60^E+9 ns) out of order.
LATENESS spans.endTimeUnixNano 60000000000;

-- Compute global statistics for the entire stream.
CREATE MATERIALIZED VIEW span_stat AS
SELECT
    scopeName,
    COUNT(*) numSpans,
    AVG(endTimeUnixNano - startTimeUnixNano) avgTime,
    SUM(endTimeUnixNano - startTimeUnixNano) totalTime,
    SUM(COALESCE(array_length(events), 0)) as numEvents
FROM
    spans
GROUP BY scopeName;

-- Compute statistics for each 1-minute window.
CREATE MATERIALIZED VIEW span_stat_tumbling AS
SELECT
    (endTimeUnixNano / 60000000000) * 60000000000 AS window_end,
    scopeName,
    COUNT(*) numSpans,
    AVG(endTimeUnixNano - startTimeUnixNano) avgTime,
    SUM(endTimeUnixNano - startTimeUnixNano) totalTime,
    SUM(COALESCE(array_length(events), 0)) as numEvents
FROM
    spans
GROUP BY
    scopeName, (endTimeUnixNano / 60000000000) * 60000000000;
