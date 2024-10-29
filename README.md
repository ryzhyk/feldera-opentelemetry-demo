# Feldera OpenTelemetry Demo

This is a fork of the [OpenTelemetry demo](https://github.com/open-telemetry/opentelemetry-demo)
that demonstrates the use of Feldera to analyze OpenTelemetry data in real-time
using SQL.

The demo currently implements the following analysis:
* Parse OTel trace stream.
* Flatten ResourceSpans data into individual spans (in SQL).
* Global aggregation: compute totals and average runtimes per scope
  for the entire event history.
* Time-based aggregation: compute the same aggregates per 1-minute
  tumbling window.

## Running the demo

Start the demo using

```bash
make start
```

This will run docker compose to bring up all demo containers, including Feldera.

* Navigate to [localhost:28080](http://localhost:28080) to see the Feldera UI.
  Select the `otel` pipeline (it will be the only pipeline in the list) and
  click on the `Performance` tab to check that resource span records are streaming 
  in from the collector.

* Switch to the `Ad hoc queries` tab and try querying materialized views:
  ```sql
  SELECT * FROM span_stat;
  ```

## Architecture


```
┌─────────────┐ otlp  ┌──────────────┐         ┌──────────┐
│microservices├──────►│OTel Collector├────────►│ Feldera  │
└─────────────┘       └──────────────┘         │(otel.sql)│
                                               └──────────┘
```

## Limitations and future work

This demo is a proof of concept showing how Feldera can process complex
semi-structured OpenTelemetry data in real-time.  It does not yet fully integrate
Feldera in the OpenTelemetry ecosystem.

* Feldera currently only ingests otlp messages in the uncompressed JSON format
  over HTTP.  Going forward, we will add support for ProtoBuf and gzipped JSON formats.

* Feldera's HTTP input connector supports streaming inputs, while oltp is a
  request/response-based protocol.  This mostly works fine, except that Feldera
  does not correctly report HTTP input statistics (number of events received,
  number of errors, etc)

* We do not yet support otlp output.

* It should be straightforward to integrate Feldera as a processor in the OTel
  Collector.   This requires building a go wrapper around the Feldera REST API.
