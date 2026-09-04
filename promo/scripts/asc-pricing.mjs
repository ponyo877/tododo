#!/usr/bin/env node
/** 価格を無料（基準国 日本）、配信地域を全世界に設定する。 node scripts/asc-pricing.mjs */
import { readFileSync } from 'node:fs';
import { api, appByBundleId } from './asc-lib.mjs';
const M = JSON.parse(readFileSync(new URL('../store/metadata.json', import.meta.url), 'utf8'));
const app = await appByBundleId(M.bundleId);

// 価格: 日本の無料プライスポイント
const pts = await api('GET', `/apps/${app.id}/appPricePoints?filter[territory]=JPN&limit=5`);
const free = pts.data.find((p) => Number(p.attributes.customerPrice) === 0) ?? pts.data[0];
console.log('free price point:', free.id, free.attributes.customerPrice);
const existing = await api('GET', `/apps/${app.id}/appPriceSchedule`).catch(() => null);
if (existing?.data) {
  console.log('price schedule already exists');
} else {
  await api('POST', '/appPriceSchedules', {
    data: {
      type: 'appPriceSchedules',
      relationships: {
        app: { data: { type: 'apps', id: app.id } },
        baseTerritory: { data: { type: 'territories', id: 'JPN' } },
        manualPrices: { data: [{ type: 'appPrices', id: '${price1}' }] },
      },
    },
    included: [{ type: 'appPrices', id: '${price1}', attributes: { startDate: null }, relationships: { appPricePoint: { data: { type: 'appPricePoints', id: free.id } } } }],
  });
  console.log('price schedule created (free)');
}

// 配信地域: 全テリトリー
const terr = await api('GET', '/territories?limit=200');
const ids = terr.data.map((t) => t.id);
const av = await api('GET', `/apps/${app.id}/appAvailabilityV2`).catch(() => null);
if (av?.data) {
  console.log('availability already set');
} else {
  await api('POST', 'https://api.appstoreconnect.apple.com/v2/appAvailabilities', {
    data: {
      type: 'appAvailabilities',
      attributes: { availableInNewTerritories: true },
      relationships: { app: { data: { type: 'apps', id: app.id } }, territoryAvailabilities: { data: ids.map((_, i) => ({ type: 'territoryAvailabilities', id: `\${t${i}}` })) } },
    },
    included: ids.map((id, i) => ({ type: 'territoryAvailabilities', id: `\${t${i}}`, attributes: { available: true }, relationships: { territory: { data: { type: 'territories', id } } } })),
  });
  console.log(`availability created for ${ids.length} territories`);
}
