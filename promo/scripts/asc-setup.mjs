#!/usr/bin/env node
/**
 * store/metadata.json の内容を App Store Connect に流し込む（アプリレコード作成後に実行）。
 *   node scripts/asc-setup.mjs            # メタデータ・カテゴリ・年齢制限・審査情報・スクリーンショット
 * ビルドの添付とプレビュー動画は別スクリプト（xcodebuild upload / asc-upload-preview.mjs）。
 */
import { readFileSync, statSync } from 'node:fs';
import { basename, resolve } from 'node:path';
import { api, appByBundleId, sleep, uploadAsset } from './asc-lib.mjs';

const M = JSON.parse(readFileSync(new URL('../store/metadata.json', import.meta.url), 'utf8'));
const app = await appByBundleId(M.bundleId);
console.log(`app ${app.attributes.name} (${app.id})`);

// 1) バージョン 1.0（レコード作成時に自動生成される）
const versions = await api('GET', `/apps/${app.id}/appStoreVersions?filter[platform]=IOS`);
let version = versions.data.find((v) => v.attributes.versionString === M.version) ?? versions.data[0];
if (!version) {
  version = (await api('POST', '/appStoreVersions', { data: { type: 'appStoreVersions', attributes: { platform: 'IOS', versionString: M.version }, relationships: { app: { data: { type: 'apps', id: app.id } } } } })).data;
}
console.log(`version ${version.attributes.versionString} (${version.attributes.appStoreState})`);

// 2) バージョンのローカリゼーション（説明・キーワード・URL など）
const vlocs = await api('GET', `/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
let vloc = vlocs.data.find((l) => l.attributes.locale === M.locale);
const vattrs = { description: M.description, keywords: M.keywords, promotionalText: M.promotionalText, supportUrl: M.supportUrl };  // whatsNew は初回バージョンでは編集不可
if (vloc) {
  await api('PATCH', `/appStoreVersionLocalizations/${vloc.id}`, { data: { type: 'appStoreVersionLocalizations', id: vloc.id, attributes: vattrs } });
} else {
  vloc = (await api('POST', '/appStoreVersionLocalizations', { data: { type: 'appStoreVersionLocalizations', attributes: { locale: M.locale, ...vattrs }, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } } } })).data;
}
console.log('version localization ok');

// 3) アプリ情報（名前・サブタイトル・プライバシーURL）とカテゴリ・年齢制限
const infos = await api('GET', `/apps/${app.id}/appInfos`);
const info = infos.data.find((i) => i.attributes.appStoreState !== 'READY_FOR_SALE') ?? infos.data[0];
const ilocs = await api('GET', `/appInfos/${info.id}/appInfoLocalizations`);
let iloc = ilocs.data.find((l) => l.attributes.locale === M.locale);
const iattrs = { name: M.name, subtitle: M.subtitle, privacyPolicyUrl: M.privacyPolicyUrl };
if (iloc) {
  await api('PATCH', `/appInfoLocalizations/${iloc.id}`, { data: { type: 'appInfoLocalizations', id: iloc.id, attributes: iattrs } });
} else {
  await api('POST', '/appInfoLocalizations', { data: { type: 'appInfoLocalizations', attributes: { locale: M.locale, ...iattrs }, relationships: { appInfo: { data: { type: 'appInfos', id: info.id } } } } });
}
await api('PATCH', `/appInfos/${info.id}`, { data: { type: 'appInfos', id: info.id, relationships: { primaryCategory: { data: { type: 'appCategories', id: M.primaryCategory } } } } });
const age = await api('GET', `/appInfos/${info.id}/ageRatingDeclaration`);
// 年齢制限アンケート: 取得した属性をすべて「なし」に（真偽値は false、列挙は NONE、kidsAgeBand は null）
const BOOL = new Set(['gambling', 'unrestrictedWebAccess', 'userGeneratedContent', 'parentalControls', 'advertising', 'messagingAndChat', 'lootBox', 'ageAssurance', 'healthOrWellnessTopics', 'socialMedia', 'socialMediaAgeRestricted']);
const ENUM = new Set(['alcoholTobaccoOrDrugUseOrReferences', 'contests', 'gamblingSimulated', 'gunsOrOtherWeapons', 'horrorOrFearThemes', 'matureOrSuggestiveThemes', 'medicalOrTreatmentInformation', 'profanityOrCrudeHumor', 'sexualContentGraphicAndNudity', 'sexualContentOrNudity', 'violenceCartoonOrFantasy', 'violenceRealistic', 'violenceRealisticProlongedGraphicOrSadistic', 'ageRatingOverride', 'koreaAgeRatingOverride']);
const ageAttrs = { kidsAgeBand: null };
for (const k of Object.keys(age.data.attributes)) {
  if (BOOL.has(k)) ageAttrs[k] = false;
  else if (ENUM.has(k)) ageAttrs[k] = 'NONE';
}
console.log('age rating attrs:', JSON.stringify(ageAttrs));
await api('PATCH', `/ageRatingDeclarations/${age.data.id}`, { data: { type: 'ageRatingDeclarations', id: age.data.id, attributes: ageAttrs } });
console.log('app info / category / age rating ok');

// 4) 審査情報
const rd = await api('GET', `/appStoreVersions/${version.id}/appStoreReviewDetail`).catch(() => ({ data: null }));
const rattrs = { contactFirstName: M.reviewContact.firstName, contactLastName: M.reviewContact.lastName, contactEmail: M.reviewContact.email, contactPhone: M.reviewContact.phone || undefined, demoAccountRequired: false, notes: M.reviewNotes };
if (rd.data) {
  await api('PATCH', `/appStoreReviewDetails/${rd.data.id}`, { data: { type: 'appStoreReviewDetails', id: rd.data.id, attributes: rattrs } });
} else {
  await api('POST', '/appStoreReviewDetails', { data: { type: 'appStoreReviewDetails', attributes: rattrs, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } } } });
}
console.log('review detail ok');

// 5) スクリーンショット（6.9 インチ = APP_IPHONE_67 枠）
const sets = await api('GET', `/appStoreVersionLocalizations/${vloc.id}/appScreenshotSets`);
let set = sets.data.find((s) => s.attributes.screenshotDisplayType === M.screenshotDisplayType);
if (!set) {
  set = (await api('POST', '/appScreenshotSets', { data: { type: 'appScreenshotSets', attributes: { screenshotDisplayType: M.screenshotDisplayType }, relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: vloc.id } } } } })).data;
}
const existing = await api('GET', `/appScreenshotSets/${set.id}/appScreenshots`);
if (existing.data.length) {
  console.log(`screenshots already present (${existing.data.length}), skipping upload`);
} else {
  for (const rel of M.screenshots) {
    const file = resolve(new URL('..', import.meta.url).pathname, rel);
    const id = await uploadAsset('appScreenshots', { data: { type: 'appScreenshots', attributes: { fileName: basename(file), fileSize: statSync(file).size }, relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } } } }, file);
    console.log(`screenshot uploaded ${basename(file)} (${id})`);
  }
  for (let i = 0; i < 30; i++) {
    const s = await api('GET', `/appScreenshotSets/${set.id}/appScreenshots`);
    const states = s.data.map((x) => x.attributes.assetDeliveryState?.state);
    if (states.every((x) => x === 'COMPLETE')) { console.log('screenshots COMPLETE'); break; }
    if (states.some((x) => x === 'FAILED')) throw new Error('screenshot processing failed');
    await sleep(5000);
  }
}
console.log('done');
