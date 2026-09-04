#!/usr/bin/env node
/**
 * App Store Connect API で App プレビュー動画をアップロードする（ブラウザ不要）。
 *   使い方: node scripts/asc-upload-preview.mjs --issuer <ISSUER_ID> [--version 1.0.4] [--file out/deliver/appstore-886x1920-upload.mp4]
 *           [--poster 00:00:15:13] [--type IPHONE_65|IPHONE_67] [--locale ja] [--dry-run]
 * 認証: ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8（既定 KEY_ID=ZNB52NZ7Q6）。Issuer ID は
 * ASC → ユーザとアクセス → 統合 → App Store Connect API の先頭に表示される。
 * 手順: 編集可能なバージョンを探す（無ければ --version で作る）→ ja のローカリゼーション → プレビューセット（スクリーンショットと同じ枠。6.5 インチ = IPHONE_65、6.9/6.7 インチ = IPHONE_67）
 *       → 予約 → 分割 PUT → コミット（MD5）→ 処理完了までポーリング。既存のプレビューがあれば置き換えず追加（最大 3 本）。
 */
import { createHash, createSign } from 'node:crypto';
import { readFileSync, statSync } from 'node:fs';
import { basename, resolve } from 'node:path';
import { homedir } from 'node:os';

const args = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : dflt;
};
const ISSUER = opt('--issuer', process.env.ASC_ISSUER_ID);
const KEY_ID = opt('--key', 'ZNB52NZ7Q6');
const APP_ID = opt('--app', process.env.ASC_APP_ID);
const VERSION = opt('--version', '1.0');
const FILE = resolve(opt('--file', 'out/deliver/tododo-appstore-preview-886x1920.mp4'));
const POSTER = opt('--poster', '00:00:24:12');
const TYPE = opt('--type', 'IPHONE_67');
const LOCALE = opt('--locale', 'ja');
const DRY = args.includes('--dry-run');
if (!ISSUER || !APP_ID) {
  console.error('--issuer <ISSUER_ID>（または ASC_ISSUER_ID）と --app <APP_ID>（または ASC_APP_ID）が必要です');
  process.exit(1);
}

const KEY = readFileSync(resolve(homedir(), '.appstoreconnect/private_keys', `AuthKey_${KEY_ID}.p8`), 'utf8');
const b64url = (b) => Buffer.from(b).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
function jwt() {
  const now = Math.floor(Date.now() / 1000);
  const h = b64url(JSON.stringify({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' }));
  const p = b64url(JSON.stringify({ iss: ISSUER, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' }));
  const s = createSign('SHA256');
  s.update(`${h}.${p}`);
  return `${h}.${p}.${b64url(s.sign({ key: KEY, dsaEncoding: 'ieee-p1363' }))}`;
}
const API = 'https://api.appstoreconnect.apple.com/v1';
async function api(method, path, body) {
  const res = await fetch(path.startsWith('http') ? path : `${API}${path}`, {
    method,
    headers: { authorization: `Bearer ${jwt()}`, 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status} ${text.slice(0, 800)}`);
  return text ? JSON.parse(text) : {};
}

const EDITABLE = new Set(['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'INVALID_BINARY', 'WAITING_FOR_REVIEW']);

// 1) バージョン
const versions = await api('GET', `/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=10`);
for (const v of versions.data) console.log(`version ${v.attributes.versionString}: ${v.attributes.appStoreState}`);
let version = versions.data.find((v) => v.attributes.versionString === VERSION) ?? versions.data.find((v) => EDITABLE.has(v.attributes.appStoreState));
if (version && !EDITABLE.has(version.attributes.appStoreState)) {
  throw new Error(`version ${version.attributes.versionString} は ${version.attributes.appStoreState} で編集不可。--version で新しい番号を指定してください`);
}
if (!version) {
  if (DRY) {
    console.log(`dry-run: version ${VERSION} を作成する必要があります`);
    process.exit(0);
  }
  version = (
    await api('POST', '/appStoreVersions', {
      data: { type: 'appStoreVersions', attributes: { platform: 'IOS', versionString: VERSION }, relationships: { app: { data: { type: 'apps', id: APP_ID } } } },
    })
  ).data;
  console.log(`created version ${VERSION} (${version.id})`);
} else {
  console.log(`using version ${version.attributes.versionString} (${version.id}, ${version.attributes.appStoreState})`);
}

// 2) ローカリゼーション
const locs = await api('GET', `/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
const loc = locs.data.find((l) => l.attributes.locale === LOCALE) ?? locs.data[0];
if (!loc) throw new Error('ローカリゼーションがありません');
console.log(`localization ${loc.attributes.locale} (${loc.id})`);

// 3) プレビューセット
const sets = await api('GET', `/appStoreVersionLocalizations/${loc.id}/appPreviewSets`);
for (const s of sets.data) console.log(`  preview set ${s.attributes.previewType} (${s.id})`);
let set = sets.data.find((s) => s.attributes.previewType === TYPE);
if (DRY) {
  if (set) {
    const previews = await api('GET', `/appPreviewSets/${set.id}/appPreviews`);
    for (const p of previews.data) console.log(`    preview ${p.attributes.fileName} ${p.attributes.assetDeliveryState?.state}`);
  }
  console.log('dry-run: ここまで。アップロードは行いません');
  process.exit(0);
}
if (!set) {
  set = (
    await api('POST', '/appPreviewSets', {
      data: { type: 'appPreviewSets', attributes: { previewType: TYPE }, relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: loc.id } } } },
    })
  ).data;
  console.log(`created preview set ${TYPE} (${set.id})`);
}

// 4) 予約 → 分割 PUT → コミット
const size = statSync(FILE).size;
const bytes = readFileSync(FILE);
const reserve = (
  await api('POST', '/appPreviews', {
    data: { type: 'appPreviews', attributes: { fileName: basename(FILE), fileSize: size, mimeType: 'video/mp4' }, relationships: { appPreviewSet: { data: { type: 'appPreviewSets', id: set.id } } } },
  })
).data;
console.log(`reserved preview ${reserve.id} (${size} bytes, ${reserve.attributes.uploadOperations.length} parts)`);
for (const op of reserve.attributes.uploadOperations) {
  const chunk = bytes.subarray(op.offset, op.offset + op.length);
  const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]));
  const res = await fetch(op.url, { method: op.method, headers, body: chunk });
  if (!res.ok) throw new Error(`upload part failed: ${res.status} ${await res.text()}`);
  process.stdout.write('.');
}
console.log(' uploaded');
const md5 = createHash('md5').update(bytes).digest('hex');
await api('PATCH', `/appPreviews/${reserve.id}`, {
  data: { type: 'appPreviews', id: reserve.id, attributes: { uploaded: true, sourceFileChecksum: md5, previewFrameTimeCode: POSTER } },
});
console.log(`committed (md5 ${md5}, poster ${POSTER})`);

// 5) 処理待ち
for (let i = 0; i < 60; i++) {
  const p = (await api('GET', `/appPreviews/${reserve.id}`)).data;
  const st = p.attributes.assetDeliveryState;
  console.log(`  state: ${st?.state}${st?.errors?.length ? ' ' + JSON.stringify(st.errors) : ''}`);
  if (st?.state === 'COMPLETE') break;
  if (st?.state === 'FAILED') process.exit(1);
  await new Promise((r) => setTimeout(r, 10000));
}
console.log('done: ASC の「プレビューとスクリーンショット」に反映されました（提出は次回のビルドと一緒に）');
