import datadog_client
import datadog_client/metric
import gleeunit
import test_helpers

pub fn main() -> Nil {
  gleeunit.main()
}

const ts = 1_700_000_000

// ==== new ====
// * ✅ defaults to datadoghq.com
// * ✅ stores the supplied api key
pub fn new_test() {
  let client = datadog_client.new("secret")
  case client.api_key == "secret" && client.site == "datadoghq.com" {
    True -> Nil
    False -> panic as "client defaults mismatch"
  }
}

// ==== with_site ====
// * ✅ overrides default site
pub fn with_site_test() {
  let client =
    datadog_client.new("secret")
    |> datadog_client.with_site(to: "datadoghq.eu")
  case client.site == "datadoghq.eu" {
    True -> Nil
    False -> panic as "with_site did not override site"
  }
}

// ==== encode_to_json ====
// * ✅ wraps metrics in a "series" envelope
// * ✅ embeds each metric's encoded body
pub fn encode_to_json_test() {
  let body =
    metric.gauge("system.load", 0.7)
    |> metric.with_points(with: [metric.Point(timestamp: ts, value: 0.7)])
    |> fn(m) { [m] }
    |> datadog_client.encode_to_json
  test_helpers.assert_contains(body, "\"series\":[")
  test_helpers.assert_contains(body, "\"metric\":\"system.load\"")
}
