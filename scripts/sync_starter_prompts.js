#!/usr/bin/env node
// Sync iOS starter_prompts.json from the canonical wechat-miniprogram source.
// Source: ../../../wechat-miniprogram/utils/prompts.js (160 prompts, full schema)
// Target: ../PromptVault/Resources/starter_prompts.json (iOS schema: title/body/tags)
//
// Why this exists: iOS App ships with embedded JSON, but the source-of-truth
// (wechat-miniprogram/utils/prompts.js) is updated independently. Running this
// script before each iOS release keeps the pack in lockstep without manual copy.
//
// Usage (from repo root):
//   node scripts/sync_starter_prompts.js
//   node scripts/sync_starter_prompts.js --dry-run   # show diff without writing
//   node scripts/sync_starter_prompts.js --check     # exit 1 if out of sync (CI gate)

const fs = require('fs');
const path = require('path');

const SOURCE = path.resolve(__dirname, '..', '..', '..', 'wechat-miniprogram', 'utils', 'prompts.js');
const TARGET = path.resolve(__dirname, '..', 'PromptVault', 'Resources', 'starter_prompts.json');
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const check = args.includes('--check');

if (!fs.existsSync(SOURCE)) {
  console.error(`✗ source not found: ${SOURCE}`);
  console.error('  Make sure the autoapp monorepo is checked out at the expected layout.');
  process.exit(1);
}

const source = require(SOURCE);

// iOS schema keeps only title/body/tags. Source body is whichever language was
// authored as primary (EN for some, ZH for most). That matches user intent —
// the prompt body is what gets pasted into the AI tool.
const transformed = source.map((p) => ({
  title: p.title,
  body: p.body,
  tags: Array.isArray(p.tags) ? p.tags : [],
}));

const newJson = JSON.stringify(transformed, null, 2) + '\n';

let oldJson = '';
if (fs.existsSync(TARGET)) {
  oldJson = fs.readFileSync(TARGET, 'utf-8');
}

const oldCount = oldJson ? (JSON.parse(oldJson).length || 0) : 0;
const newCount = transformed.length;
const inSync = newJson === oldJson;

console.log(`source: ${newCount} prompts | target: ${oldCount} prompts | in-sync: ${inSync}`);

if (check) {
  if (!inSync) {
    console.error('✗ out of sync. run: node scripts/sync_starter_prompts.js');
    process.exit(1);
  }
  console.log('✅ in sync');
  process.exit(0);
}

if (inSync) {
  console.log('✅ already in sync — no write');
  process.exit(0);
}

if (dryRun) {
  console.log('--- dry-run: would write the following changes ---');
  console.log(`  count: ${oldCount} → ${newCount} (${newCount - oldCount >= 0 ? '+' : ''}${newCount - oldCount})`);
  if (oldJson) {
    const oldTitles = new Set(JSON.parse(oldJson).map(p => p.title));
    const newTitles = transformed.map(p => p.title);
    const added = newTitles.filter(t => !oldTitles.has(t));
    if (added.length) {
      console.log(`  added titles (${added.length}):`);
      added.slice(0, 20).forEach(t => console.log(`    + ${t}`));
      if (added.length > 20) console.log(`    ... and ${added.length - 20} more`);
    }
  }
  process.exit(0);
}

fs.writeFileSync(TARGET, newJson);
console.log(`✅ wrote ${newCount} prompts to ${path.relative(process.cwd(), TARGET)}`);
console.log('   next: rebuild iOS app (xcodegen + xcodebuild) so the new JSON is bundled.');
