#!/usr/bin/env bats

load setup

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "remote-hook uses mounted UNIX socket when available" {
  export PEON_RELAY_SOCKET="$TEST_DIR/.peon-relay.sock"
  export PEON_RELAY_URL="http://fallback.example:19998"
  start_mock_unix_socket "$PEON_RELAY_SOCKET"
  touch "$TEST_DIR/.relay_socket_available"

  run_remote_hook '{"hook_event_name":"Stop"}'
  [ "$REMOTE_HOOK_EXIT" -eq 0 ]
  relay_was_called
  [ "$(relay_call_count)" -eq 1 ]
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"--unix-socket $PEON_RELAY_SOCKET"* ]]
  [[ "$cmdline" != *"fallback.example"* ]]
}

@test "remote-hook falls back to RELAY_URL when socket request fails" {
  export PEON_RELAY_SOCKET="$TEST_DIR/.peon-relay.sock"
  export PEON_RELAY_URL="http://fallback.example:19998"
  start_mock_unix_socket "$PEON_RELAY_SOCKET"
  rm -f "$TEST_DIR/.relay_socket_available"
  touch "$TEST_DIR/.relay_available"

  run_remote_hook '{"hook_event_name":"Stop"}'
  [ "$REMOTE_HOOK_EXIT" -eq 0 ]
  relay_was_called
  [ "$(relay_call_count)" -eq 2 ]
  first_cmd=$(head -n 1 "$TEST_DIR/relay_curl.log")
  last_cmd=$(tail -n 1 "$TEST_DIR/relay_curl.log")
  [[ "$first_cmd" == *"--unix-socket $PEON_RELAY_SOCKET"* ]]
  [[ "$last_cmd" == *"fallback.example:19998"* ]]
}

@test "remote-hook uses RELAY_URL when no socket is mounted" {
  export PEON_RELAY_SOCKET="$TEST_DIR/.missing.sock"
  export PEON_RELAY_URL="http://fallback.example:19998"
  touch "$TEST_DIR/.relay_available"

  run_remote_hook '{"hook_event_name":"PermissionRequest"}'
  [ "$REMOTE_HOOK_EXIT" -eq 0 ]
  relay_was_called
  [ "$(relay_call_count)" -eq 1 ]
  cmdline=$(relay_cmdline)
  [[ "$cmdline" != *"--unix-socket"* ]]
  [[ "$cmdline" == *"fallback.example:19998/play?category=input.required"* ]]
}
