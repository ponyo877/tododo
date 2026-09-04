// App Store Connect API の最小クライアント（JWT・GET/POST/PATCH・アップロード）
import { createHash, createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { resolve } from 'node:path';

export const ISSUER = process.env.ASC_ISSUER_ID ?? '8e5079df-4827-4f89-b7cd-b77a2b19e16c';
export const KEY_ID = process.env.ASC_KEY_ID ?? 'ZNB52NZ7Q6';
const KEY = readFileSync(resolve(homedir(), '.appstoreconnect/private_keys', `AuthKey_${KEY_ID}.p8`), 'utf8');
const b64url = (b) => Buffer.from(b).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

export function jwt() {
  const now = Math.floor(Date.now() / 1000);
  const h = b64url(JSON.stringify({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' }));
  const p = b64url(JSON.stringify({ iss: ISSUER, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' }));
  const s = createSign('SHA256');
  s.update(`${h}.${p}`);
  return `${h}.${p}.${b64url(s.sign({ key: KEY, dsaEncoding: 'ieee-p1363' }))}`;
}

const API = 'https://api.appstoreconnect.apple.com/v1';
export async function api(method, path, body) {
  const res = await fetch(path.startsWith('http') ? path : `${API}${path}`, {
    method,
    headers: { authorization: `Bearer ${jwt()}`, 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status} ${text.slice(0, 800)}`);
  return text ? JSON.parse(text) : {};
}

export async function appByBundleId(bundleId) {
  const r = await api('GET', `/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
  if (!r.data.length) throw new Error(`App Store Connect にアプリ（${bundleId}）がありません。Web でアプリレコードを作成してください`);
  return r.data[0];
}

/** 予約 → 分割 PUT → コミット（MD5）。appScreenshots / appPreviews 共通 */
export async function uploadAsset(kind, reserveBody, filePath) {
  const data = readFileSync(filePath);
  const reserved = await api('POST', `/${kind}`, reserveBody);
  const ops = reserved.data.attributes.uploadOperations;
  for (const op of ops) {
    const chunk = data.subarray(op.offset, op.offset + op.length);
    const headers = Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value]));
    const r = await fetch(op.url, { method: op.method, headers, body: chunk });
    if (!r.ok) throw new Error(`upload chunk ${op.offset}: ${r.status}`);
  }
  const md5 = createHash('md5').update(data).digest('hex');
  await api('PATCH', `/${kind}/${reserved.data.id}`, {
    data: { type: kind, id: reserved.data.id, attributes: { uploaded: true, sourceFileChecksum: md5 } },
  });
  return reserved.data.id;
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
