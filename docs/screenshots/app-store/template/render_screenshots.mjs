#!/usr/bin/env node
/**
 * Render KXSF App Store marketing screenshots for iPhone 17 Pro (1206x2622).
 *
 * Usage:
 *   node render_screenshots.mjs
 *   node render_screenshots.mjs --only listen
 */

import { spawn } from 'node:child_process';
import { mkdir, access, writeFile, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '../../..'); // docs/screenshots/app-store/template -> docs
const SCREENSHOTS_DIR = path.resolve(__dirname, '../..'); // docs/screenshots
const OUT_DIR = path.resolve(__dirname, '../exports');
const TEMPLATE = path.join(__dirname, 'master.html');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const CANVAS = { width: 1206, height: 2622 };

const SHOTS = [
  {
    id: '01-listen-live',
    source: 'kxsf-feedback-polished-iphone17pro-ios27.png',
    eyebrow: 'KXSF 102.5 FM',
    title: 'Listen live',
    subtitle: 'Your San Francisco community radio, rebuilt.',
  },
  {
    id: '02-whats-on',
    source: 'kxsf-schedule-artwork-iphone17pro-ios27.png',
    eyebrow: 'OFFICIAL SCHEDULE',
    title: 'Know what’s on',
    subtitle: 'Browse KXSF shows and the hosts behind them.',
  },
  {
    id: '03-keep-close',
    source: 'kxsf-widget-polished-iphone17pro-ios27.png',
    eyebrow: 'ALWAYS NEARBY',
    title: 'Keep KXSF close',
    subtitle: 'Now Playing on Home Screen and Lock Screen.',
  },
];

function parseArgs(argv) {
  const onlyIndex = argv.indexOf('--only');
  return {
    only: onlyIndex >= 0 ? argv[onlyIndex + 1] : null,
  };
}

async function exists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

function buildFileUrl(shot) {
  const imagePath = path.join(SCREENSHOTS_DIR, shot.source);
  const params = new URLSearchParams({
    eyebrow: shot.eyebrow,
    title: shot.title,
    subtitle: shot.subtitle,
    image: pathToFileURL(imagePath).href,
  });
  return `${pathToFileURL(TEMPLATE).href}?${params.toString()}`;
}

async function renderWithChrome(url, outPath) {
  const userDataDir = path.join(OUT_DIR, '.chrome-profile');
  await mkdir(userDataDir, { recursive: true });

  // Chrome headless screenshot dumps the full page using --screenshot.
  // We force window size + device scale so the CSS 1206x2622 canvas maps 1:1.
  const args = [
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--force-device-scale-factor=1',
    `--window-size=${CANVAS.width},${CANVAS.height}`,
    `--user-data-dir=${userDataDir}`,
    `--screenshot=${outPath}`,
    url,
  ];

  await new Promise((resolve, reject) => {
    const child = spawn(CHROME, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (d) => {
      stderr += d.toString();
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`Chrome exited ${code}\n${stderr}`));
    });
  });
}

async function verifyPng(outPath) {
  // Lightweight PNG header / IHDR dimension check without external deps.
  const buf = await readFile(outPath);
  if (buf.length < 24 || buf.toString('binary', 0, 8) !== '\x89PNG\r\n\x1a\n') {
    throw new Error(`${outPath} is not a PNG`);
  }
  const width = buf.readUInt32BE(16);
  const height = buf.readUInt32BE(20);
  if (width !== CANVAS.width || height !== CANVAS.height) {
    throw new Error(`${path.basename(outPath)} is ${width}x${height}, expected ${CANVAS.width}x${CANVAS.height}`);
  }
  return { width, height, bytes: buf.length };
}

async function main() {
  const { only } = parseArgs(process.argv.slice(2));
  if (!(await exists(CHROME))) {
    throw new Error(`Google Chrome not found at ${CHROME}`);
  }
  if (!(await exists(TEMPLATE))) {
    throw new Error(`Missing template: ${TEMPLATE}`);
  }

  await mkdir(OUT_DIR, { recursive: true });

  const selected = SHOTS.filter((s) => {
    if (!only) return true;
    return s.id.includes(only) || s.source.includes(only) || s.title.toLowerCase().includes(only.toLowerCase());
  });

  if (!selected.length) {
    throw new Error(`No shots matched --only ${only}`);
  }

  const results = [];
  for (const shot of selected) {
    const sourcePath = path.join(SCREENSHOTS_DIR, shot.source);
    if (!(await exists(sourcePath))) {
      throw new Error(`Missing source screenshot: ${sourcePath}`);
    }

    const outPath = path.join(OUT_DIR, `${shot.id}.png`);
    const url = buildFileUrl(shot);
    process.stdout.write(`Rendering ${shot.id}...\n`);
    await renderWithChrome(url, outPath);
    const meta = await verifyPng(outPath);
    results.push({ id: shot.id, outPath, ...meta, title: shot.title, source: shot.source });
    process.stdout.write(`  -> ${outPath} (${meta.width}x${meta.height}, ${meta.bytes} bytes)\n`);
  }

  const manifest = {
    generatedAt: new Date().toISOString(),
    canvas: CANVAS,
    device: 'iPhone 17 Pro (6.3-inch)',
    template: 'docs/screenshots/app-store/template/master.html',
    notes: [
      'Marketing screenshots for App Store Connect.',
      'No alpha channel / transparency in final export.',
      'Device frame + title live above the real simulator capture.',
    ],
    shots: results.map((r) => ({
      id: r.id,
      file: path.relative(ROOT, r.outPath),
      title: r.title,
      source: r.source,
      width: r.width,
      height: r.height,
    })),
  };

  const manifestPath = path.join(OUT_DIR, 'manifest.json');
  await writeFile(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  process.stdout.write(`Wrote ${manifestPath}\n`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
