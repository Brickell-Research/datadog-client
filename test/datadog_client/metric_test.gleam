import datadog_client/metric
import gleam/json
import gleam/string
import test_helpers

const ts = 1_700_000_000

/// Pins the metric to a known point and renders it to a JSON string.
fn render(m: metric.Metric, value: Float) -> String {
  m
  |> metric.with_points(with: [metric.Point(timestamp: ts, value: value)])
  |> metric.to_json
  |> json.to_string
}

// ==== gauge ====
// * ✅ encodes "gauge" type
// * ✅ preserves metric name
pub fn gauge_test() {
  let body = render(metric.gauge("system.load", 0.7), 0.7)
  test_helpers.assert_contains(body, "\"type\":\"gauge\"")
  test_helpers.assert_contains(body, "\"metric\":\"system.load\"")
  test_helpers.assert_contains(body, "[1700000000,0.7]")
}

// ==== count ====
// * ✅ encodes "count" type
pub fn count_test() {
  let body = render(metric.count("hits", 3.0), 3.0)
  test_helpers.assert_contains(body, "\"type\":\"count\"")
}

// ==== rate ====
// * ✅ encodes "rate" type
pub fn rate_test() {
  let body = render(metric.rate("requests.per_sec", 12.5), 12.5)
  test_helpers.assert_contains(body, "\"type\":\"rate\"")
}

// ==== with_tags ====
// * ✅ replaces existing tag list
pub fn with_tags_test() {
  let body =
    metric.gauge("x", 1.0)
    |> metric.with_tags(with: ["env:prod", "service:api"])
    |> render(1.0)
  test_helpers.assert_contains(body, "\"tags\":[\"env:prod\",\"service:api\"]")
}

// ==== add_tag ====
// * ✅ prepends tag to the existing list
pub fn add_tag_test() {
  let body =
    metric.gauge("x", 1.0)
    |> metric.with_tags(with: ["env:prod"])
    |> metric.add_tag(with: "region:us-east-1")
    |> render(1.0)
  test_helpers.assert_contains(
    body,
    "\"tags\":[\"region:us-east-1\",\"env:prod\"]",
  )
}

// ==== with_host ====
// * ✅ includes host field
pub fn with_host_test() {
  let body =
    metric.gauge("x", 1.0)
    |> metric.with_host(to: "web-01")
    |> render(1.0)
  test_helpers.assert_contains(body, "\"host\":\"web-01\"")
}

// ==== with_type ====
// * ✅ overrides constructor's type
pub fn with_type_test() {
  let body =
    metric.gauge("x", 1.0)
    |> metric.with_type(to: metric.Count)
    |> render(1.0)
  test_helpers.assert_contains(body, "\"type\":\"count\"")
}

// ==== with_interval ====
// * ✅ includes interval field
pub fn with_interval_test() {
  let body =
    metric.rate("requests.per_sec", 12.5)
    |> metric.with_interval(of: 10)
    |> render(12.5)
  test_helpers.assert_contains(body, "\"interval\":10")
}

// ==== with_points ====
// * ✅ replaces all points
pub fn with_points_test() {
  let body =
    metric.gauge("x", 1.0)
    |> metric.with_points(with: [
      metric.Point(timestamp: ts, value: 9.5),
      metric.Point(timestamp: ts + 1, value: 8.25),
    ])
    |> metric.to_json
    |> json.to_string
  test_helpers.assert_contains(body, "[1700000000,9.5]")
  test_helpers.assert_contains(body, "[1700000001,8.25]")
}

// ==== add_point ====
// * ✅ prepends a new point
pub fn add_point_test() {
  let body =
    metric.gauge("x", 1.0)
    |> metric.with_points(with: [metric.Point(timestamp: ts, value: 1.5)])
    |> metric.add_point(at: ts + 5, of: 2.25)
    |> metric.to_json
    |> json.to_string
  test_helpers.assert_contains(body, "[1700000005,2.25]")
  test_helpers.assert_contains(body, "[1700000000,1.5]")
}

// ==== to_json ====
// * ✅ omits host when None
// * ✅ omits interval when None
pub fn to_json_omits_optionals_test() {
  let body = render(metric.gauge("x", 1.0), 1.0)
  case
    string.contains(body, "\"host\":"),
    string.contains(body, "\"interval\":")
  {
    False, False -> Nil
    _, _ -> panic as "expected host and interval to be omitted"
  }
}
