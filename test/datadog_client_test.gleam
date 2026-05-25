import datadog_client
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn gauge_encodes_to_json_test() {
  let body =
    datadog_client.gauge("system.load", 0.7)
    |> datadog_client.with_points([#(1_700_000_000, 0.7)])
    |> datadog_client.with_tags(["env:prod", "service:api"])
    |> datadog_client.with_host("web-01")
    |> fn(m) { [m] }
    |> datadog_client.encode_to_json

  assert string.contains(body, "\"metric\":\"system.load\"")
  assert string.contains(body, "\"type\":\"gauge\"")
  assert string.contains(body, "[1700000000,0.7]")
  assert string.contains(body, "\"host\":\"web-01\"")
  assert string.contains(body, "env:prod")
}

pub fn rate_includes_interval_test() {
  let body =
    datadog_client.rate("requests.per_sec", 12.5)
    |> datadog_client.with_points([#(1_700_000_000, 12.5)])
    |> datadog_client.with_interval(10)
    |> fn(m) { [m] }
    |> datadog_client.encode_to_json

  assert string.contains(body, "\"type\":\"rate\"")
  assert string.contains(body, "\"interval\":10")
}

pub fn add_tag_prepends_test() {
  let body =
    datadog_client.count("hits", 1.0)
    |> datadog_client.with_points([#(1_700_000_000, 1.0)])
    |> datadog_client.add_tag("region:us-east-1")
    |> fn(m) { [m] }
    |> datadog_client.encode_to_json

  assert string.contains(body, "region:us-east-1")
}
