// Prints the version of each package `expo export` loads, resolved the way Node resolves it from the app.
const path = require('path');

const from = (pkg, dir) => {
  try {
    return path.dirname(require.resolve(`${pkg}/package.json`, { paths: [dir] }));
  } catch {
    return null;
  }
};
const manifest = (dir) => (dir ? require(path.join(dir, 'package.json')) : null);
const version = (dir) => manifest(dir)?.version ?? 'missing';

const expo = from('expo', process.cwd());
const cli = expo && from('@expo/cli', expo);
const server = cli && from('@expo/router-server', cli);
const router = server && from('expo-router', server);

console.log(
  `  expo ${version(expo)}, @expo/cli ${version(cli)}, ` +
    `@expo/router-server ${version(server)} (from @expo/cli), ` +
    `expo-router ${version(router)} (from @expo/router-server)`,
);
console.log(
  `  @expo/cli dependencies["@expo/router-server"]: ${JSON.stringify(manifest(cli)?.dependencies?.['@expo/router-server'])}, ` +
    `@expo/router-server peerDependencies["expo-router"]: ${JSON.stringify(manifest(server)?.peerDependencies?.['expo-router'])}`,
);
