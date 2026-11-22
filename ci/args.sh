#!/bin/bash
# Checks that the installers reject wrong arguments before doing anything (download, create a box), that --link
# takes any folder name, and, with Docker, that machine.sh counts the compile jobs within a container's limits.
# A few seconds and no network but the ubuntu image: it runs in the lint job.
# Usage: bash ci/args.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILURES=0
ok()   { echo "  OK    $*"; }
fail() { echo "  FAIL  $*"; FAILURES=$((FAILURES + 1)); }

# curl and distrobox stand-ins: they write each call to $WORK/calls, so a rejected call must leave it empty. The
# distrobox one runs the bash -c command of --link with the home of the box in $WORK/home.
mkdir -p "$WORK/bin" "$WORK/home" "$WORK/alone"
cat >"$WORK/bin/curl" <<EOF
#!/bin/bash
echo "curl \$*" >>"$WORK/calls"
EOF
cat >"$WORK/bin/distrobox" <<EOF
#!/bin/bash
echo "distrobox \$*" >>"$WORK/calls"
if [ "\$1" = enter ] && [ "\$4" = bash ] && [ "\$5" = -c ]; then shift 3; HOME="$WORK/home" exec "\$@"; fi
EOF
chmod +x "$WORK/bin/"*
export PATH="$WORK/bin:$PATH"
# install.sh on its own, as when piped from curl: it would download the release
cp "$ROOT/install.sh" "$WORK/alone/"

# rejected(script, args...): exits with 2 and calls neither curl nor distrobox
rejected() {
  : >"$WORK/calls"
  (cd "$WORK" && bash "$@" >/dev/null 2>&1)
  local rc=$? call="$*"
  call=${call//"$ROOT/"/}
  call=${call//"$WORK/alone/"/}
  if [ $rc -eq 2 ] && [ ! -s "$WORK/calls" ]; then ok "rejected: $call"
  else fail "$call: exit code $rc, calls: $(tr '\n' ';' <"$WORK/calls")"; fi
}

echo "== install.sh"
for args in "bogus noetic" "ubuntu bogus" "user noetic --typo" "ubuntu noetic extra" "root noetic" \
  "root noetic ci Etc/UTC extra" "distrobox noetic --lnk /tmp" "distrobox noetic --link"; do
  # shellcheck disable=SC2086
  rejected "$WORK/alone/install.sh" $args
done

echo "== distrobox/create.sh"
rejected "$ROOT/distrobox/create.sh" noetic --lnk /tmp
rejected "$ROOT/distrobox/create.sh" noetic --link /tmp extra
rejected "$ROOT/distrobox/create.sh" bogus
for name in "it's" "my project" 'a$b' 'q"uote'; do
  mkdir -p "$WORK/projects/$name"
  : >"$WORK/calls"
  # from $WORK: the old quoting bug left a stray link in the current folder
  (cd "$WORK" && USER=ci bash "$ROOT/distrobox/create.sh" noetic --link "$WORK/projects/$name" >/dev/null 2>&1)
  if [ "$(readlink "$WORK/home/projects/$name")" = "$WORK/projects/$name" ]; then ok "--link links \"$name\""
  else fail "--link does not link \"$name\": $(ls -A "$WORK/home/projects" 2>/dev/null | tr '\n' ' ')"; fi
done

echo "== ros/machine.sh"
rejected "$ROOT/ros/machine.sh" --bogus
rejected "$ROOT/ros/machine.sh" --jobs extra
rejected "$ROOT/ros/machine.sh" --save auto extra
rejected "$ROOT/ros/machine.sh" --save --jobs

if command -v docker >/dev/null; then
  echo "== ros/machine.sh --jobs in a container"
  HOST_JOBS=$(bash "$ROOT/ros/machine.sh" --jobs)
  # container_jobs(docker options...): what machine.sh --jobs prints in a container with those limits
  container_jobs() { docker run --rm --network none "$@" -v "$ROOT/ros:/ros:ro" ubuntu:24.04 bash /ros/machine.sh --jobs; }
  docker pull -q ubuntu:24.04 >/dev/null
  [ "$(container_jobs)" = "$HOST_JOBS" ] && ok "no limit: $HOST_JOBS, as on the host" || fail "no limit: $(container_jobs), host $HOST_JOBS"
  [ "$(container_jobs --memory 2g)" = 1 ] && ok "--memory 2g: 1" || fail "--memory 2g: $(container_jobs --memory 2g), expected 1"
  [ "$(container_jobs --cpus 1)" = 1 ] && ok "--cpus 1: 1" || fail "--cpus 1: $(container_jobs --cpus 1), expected 1"
  EXPECTED=$((HOST_JOBS < 2 ? HOST_JOBS : 2))
  [ "$(container_jobs --memory 4g --cpus 2)" = "$EXPECTED" ] && ok "--memory 4g --cpus 2: $EXPECTED" \
    || fail "--memory 4g --cpus 2: $(container_jobs --memory 4g --cpus 2), expected $EXPECTED"
fi

echo
[ $FAILURES -eq 0 ] && echo "ARGUMENT CHECKS OK" || echo "ARGUMENT CHECKS: $FAILURES failure(s)"
exit $FAILURES
