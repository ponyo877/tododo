#!/usr/bin/env node
/** 処理済みの最新ビルドをバージョンに添付する。 node scripts/asc-attach-build.mjs [--version 1.0] */
import { readFileSync } from 'node:fs';
import { api, appByBundleId, sleep } from './asc-lib.mjs';
const M = JSON.parse(readFileSync(new URL('../store/metadata.json', import.meta.url), 'utf8'));
const app = await appByBundleId(M.bundleId);
const versions = await api('GET', `/apps/${app.id}/appStoreVersions?filter[platform]=IOS`);
const version = versions.data.find((v) => v.attributes.versionString === M.version);
for (let i = 0; i < 60; i++) {
  const builds = await api('GET', `/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=1`);
  const b = builds.data[0];
  if (b && b.attributes.processingState === 'VALID') {
    await api('PATCH', `/appStoreVersions/${version.id}/relationships/build`, { data: { type: 'builds', id: b.id } });
    console.log(`attached build ${b.attributes.version} (${b.id}) to ${M.version}`);
    process.exit(0);
  }
  console.log(`build state: ${b?.attributes.processingState ?? 'none'} … waiting`);
  await sleep(30000);
}
throw new Error('build did not become VALID in time');
