# @expo/router-server accepts any expo-router

`@expo/router-server` 58.0.17 and later call `getRouteInfoForMatchedRoute` from `expo-router/internal/static` while rendering a route, and expo-router exports it from 58.0.26.
Its `peerDependencies` still accept `"expo-router": "*"`, so npm installs it beside an older expo-router without a warning.

`./app` is a one-route Expo Router app with `web.output: "static"`. `./repro.sh` installs it with npm twice, beside `expo@~58.0.26` and the versions that release's `bundledNativeModules.json` names, then runs `npx expo-doctor@latest` and `npx expo export --platform web` in each:

| Case | expo-router | package.json |
| --- | --- | --- |
| `expo-router-58.0.25` | `58.0.25` | `"expo": { "install": { "exclude": ["expo-router"] } }`, as expo-doctor's advice offers for a package held back |
| `control` | `~58.0.32` | |

```sh
./repro.sh
```

It prints each case's install warnings, the versions the export loads, expo-doctor's result and the export's error lines, then one `SUMMARY` line.
It exits 1 while the `expo-router-58.0.25` case installs without a warning, passes expo-doctor and fails to export; 0 once it exports or npm reports the mismatch at install; and 2 when the control fails, expo-doctor reports an issue, or a step ends another way.
