/// Unit selector for the Erlang `system_time` BIF.
type SystemTimeUnit {
  Second
}

@external(erlang, "erlang", "system_time")
fn erlang_system_time(unit: SystemTimeUnit) -> Int

/// Current Unix time in seconds.
@external(javascript, "./common_ffi.mjs", "now_seconds")
pub fn now_seconds() -> Int {
  erlang_system_time(Second)
}
