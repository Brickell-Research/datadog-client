import datadog_client/common

// ==== now_seconds ====
// * ✅ returns a Unix timestamp past 2023
pub fn now_seconds_test() {
  let now = common.now_seconds()
  case now > 1_700_000_000 {
    True -> Nil
    False -> panic as "now_seconds() should be after 2023"
  }
}
