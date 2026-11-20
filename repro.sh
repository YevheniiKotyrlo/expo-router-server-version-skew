#!/usr/bin/env bash
# Installs the app in ./app twice with npm, each time with its own package.json, and runs
# `npx expo-doctor@latest` and `npx expo export --platform web` in each.
# Exit status: 1 while the expo-router-58.0.25 case installs without a warning, passes expo-doctor
# and fails to export; 0 once it exports or npm reports the mismatch at install;
# 2 when the control fails, expo-doctor reports an issue, or a step ends another way.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="${REPRO_WORK:-$root/.work}"

# The versions expo@58.0.26's bundledNativeModules.json names; each case adds its expo-router.
common_dependencies='"expo": "~58.0.26",
    "expo-constants": "~58.0.16",
    "expo-linking": "~58.0.17",
    "expo-status-bar": "~58.0.5",
    "@expo/metro-runtime": "~58.0.17",
    "react": "19.3.0",
    "react-dom": "19.3.0",
    "react-native": "0.88.1",
    "react-native-web": "~0.21.4",
    "react-native-screens": "~4.30.1",
    "react-native-safe-area-context": "~5.11.1"'

write_case() { # name, expo-router dependency, extra package.json fields
  local dir="$work/$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  cp -R "$root/app" "$root/app.json" "$root/versions.js" "$dir/"
  cat > "$dir/package.json" <<EOF
{
  "name": "$1",
  "private": true,
  "main": "expo-router/entry",$3
  "dependencies": {
    $common_dependencies,
    $2
  }
}
EOF
}

# The verdict of one case from what its steps printed:
# ok, defect, or other (with the reason on the same line).
case_verdict() { # install status, install log, doctor status, export status, export log, dist dir, expected message, mismatched (yes|no)
  local install_status="$1" install_log="$2" doctor_status="$3" export_status="$4" export_log="$5" dist="$6" message="$7" mismatched="$8"
  if [ "$mismatched" = yes ] && grep -Eq 'peer expo-router@[^ ]* from @expo/router-server|While resolving: @expo/router-server' "$install_log"; then
    echo "ok: npm reported the mismatch at install"
    return
  fi
  if [ "$install_status" -ne 0 ]; then
    echo "other: npm install exited $install_status"
    return
  fi
  if [ "$doctor_status" -ne 0 ]; then
    echo "other: expo-doctor exited $doctor_status"
    return
  fi
  if [ "$export_status" -eq 0 ] && [ -f "$dist/index.html" ]; then
    echo "ok: exported dist/index.html"
    return
  fi
  if [ "$export_status" -ne 0 ] && grep -Fq -- "$message" "$export_log"; then
    echo "defect: npm installed it without a warning, expo-doctor passed, and the export failed with \"$message\""
    return
  fi
  echo "other: export exited $export_status without \"$message\""
}

run_case() { # name, expo-router dependency, extra package.json fields, expected message, mismatched (yes|no)
  local dir="$work/$1" install_status doctor_status=127 export_status=127 versions_status=0 verdict
  echo
  echo "== $1"
  write_case "$1" "$2" "$3"
  local fields="${3//$'\n'/}"
  fields="${fields#"${fields%%[! ]*}"}"
  echo "  package.json: $2${fields:+, $fields}"
  echo "\$ npm install"
  (cd "$dir" && npm install --no-audit --no-fund --loglevel warn) >"$dir/install.log" 2>&1
  install_status=$?
  echo "  exit $install_status; lines naming a peer or @expo/router-server:"
  grep -Ei 'peer|router-server' "$dir/install.log" | sed 's/^/    /' || echo "    (none)"
  : >"$dir/doctor.log"
  : >"$dir/export.log"
  if [ "$install_status" -eq 0 ]; then
    (cd "$dir" && node versions.js)
    versions_status=$?
    echo "\$ npx expo-doctor@latest"
    (cd "$dir" && npx --yes expo-doctor@latest) >"$dir/doctor.log" 2>&1
    doctor_status=$?
    echo "  exit $doctor_status; its result lines:"
    grep -E 'checks passed|No issues detected|✖' "$dir/doctor.log" | sed 's/^/    /' || echo "    (none)"
    echo "\$ npx expo export --platform web"
    (cd "$dir" && CI=1 npx expo export --platform web --output-dir dist) >"$dir/export.log" 2>&1
    export_status=$?
    echo "  exit $export_status; its error lines:"
    grep -E '^(Metro error|Error|TypeError)' "$dir/export.log" | sort | uniq -c | sed 's/^ */    /' || echo "    (none)"
  fi
  if [ "$versions_status" -ne 0 ]; then
    verdict="other: printing the versions exited $versions_status"
  else
    verdict="$(case_verdict "$install_status" "$dir/install.log" "$doctor_status" "$export_status" "$dir/export.log" "$dir/dist" "$4" "$5")"
  fi
  verdicts+=("$1: $verdict")
}

main() {
  local -a verdicts=()
  local summary status=0 line system node_version npm_version
  system="$(uname -srm)" || system=unknown
  node_version="$(node --version)" || return 2
  npm_version="$(npm --version)" || return 2
  echo "System: $system, node $node_version, npm $npm_version"
  mkdir -p "$work"

  # expo-router held at the last release before 58.0.26, the way expo-doctor's advice offers.
  run_case expo-router-58.0.25 '"expo-router": "58.0.25"' '
  "expo": { "install": { "exclude": ["expo-router"] } },' \
    'getRouteInfoForMatchedRoute) is not a function' yes
  run_case control '"expo-router": "~58.0.32"' '' \
    'no failure expected' no

  echo
  for line in "${verdicts[@]}"; do
    case "$line" in
      control:\ ok:*) ;;
      control:*) status=2 ;;
      *": other:"*) status=2 ;;
      *": defect:"*) [ "$status" -eq 2 ] || status=1 ;;
    esac
  done
  summary="SUMMARY (exit $status):"
  for line in "${verdicts[@]}"; do summary="$summary [$line]"; done
  echo "$summary"
  return "$status"
}

if [ "${REPRO_SOURCE_ONLY:-}" != 1 ]; then
  main "$@"
fi
