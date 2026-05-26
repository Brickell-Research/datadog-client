# Datadog Client

[![Package Version](https://img.shields.io/hexpm/v/datadog_client)](https://hex.pm/packages/datadog_client)
[![Tests](https://github.com/Brickell-Research/datadog-client/actions/workflows/test.yml/badge.svg)](https://github.com/Brickell-Research/datadog-client/actions/workflows/test.yml)

A minimal HTTP client for Datadog. Intentionally dual target-able (JS & Erlang) ✅

```sh
gleam add datadog_client
```

```gleam
import datadog_client
import datadog_client/metric

pub fn main() {
  let client = datadog_client.new("YOUR_DD_API_KEY")

  let m =
    metric.gauge("system.load", 0.7)
    |> metric.with_tags(with: ["env:prod", "service:api"])
    |> metric.with_host(to: "web-01")

  datadog_client.send_one(client, m)
}
```
