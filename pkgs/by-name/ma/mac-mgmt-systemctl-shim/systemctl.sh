#!@bash@
# Re-routes every `systemctl` invocation to `mac-mgmt systemctl ... @serviceName@`.
#
# Rewrite rules:
#   * Drop scope flags (--user/--system) — mac-mgmt manages the service globally.
#   * Pass through every other flag (-q, --no-pager, --type=service, ...) as-is.
#   * The first positional argument is the verb (start/stop/status/...) and is
#     passed through unchanged.
#   * Every subsequent positional argument is treated as a unit reference and
#     replaced with @serviceName@.

out=()
verb_seen=0
for arg in "$@"; do
  case "$arg" in
    --user|--system)
      ;;
    --*|-*)
      out+=("$arg")
      ;;
    *)
      if [ $verb_seen -eq 0 ]; then
        out+=("$arg")
        verb_seen=1
      else
        out+=("@serviceName@")
      fi
      ;;
  esac
done

exec mac-mgmt systemctl "${out[@]}"
