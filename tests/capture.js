// Plays the web build in headless Chromium and saves README screenshots.
// Usage: node tests/capture.js <url of /play/ page> <output dir>
// Relies on the web-only hooks in Main.gd: window.pwState and window.pwCmd("wild").
const { chromium } = require('playwright');
const fs = require('fs');

const url = process.argv[2] || 'http://localhost:8000/';
const out = process.argv[3] || 'docs/screenshots';
fs.mkdirSync(out, { recursive: true });

(async () => {
  const browser = await chromium.launch();
  const errors = [];
  const watch = (page) => {
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('console', (m) => { if (m.type() === 'error' || /SCRIPT ERROR/.test(m.text())) errors.push(m.text()); });
  };
  const ready = (page) => page.waitForFunction(() => window.pwState && window.pwState.mode === 'title', null, { timeout: 120000 });
  const shot = (page, name) => page.screenshot({ path: `${out}/${name}.jpg`, type: 'jpeg', quality: 70 });

  const p = await browser.newPage({ viewport: { width: 900, height: 600 } });
  watch(p);
  await p.goto(url);
  await ready(p);
  await p.waitForTimeout(1500);
  const state = () => p.evaluate(() => window.pwState);
  const press = async (key, n = 1, wait = 300) => { for (let i = 0; i < n; i++) { await p.keyboard.press(key); await p.waitForTimeout(wait); } };
  const until = async (fn, max = 40) => { for (let i = 0; i < max; i++) { if (fn(await state())) return true; await press('z', 1, 800); } return false; };

  await shot(p, 'title');
  await p.mouse.click(450, 80);
  await press('z', 1, 1200);            // New Game
  await press('z', 2, 1500);            // Keeper Oda's intro lines
  await press('ArrowRight', 2, 300);    // pick the third partner
  await press('z', 2, 800);             // choose + confirm
  await until((s) => s.mode === 'over' && s.ui === 0);
  await p.waitForTimeout(1000);
  await shot(p, 'town');

  await p.keyboard.down('ArrowUp'); await p.waitForTimeout(4000); await p.keyboard.up('ArrowUp');
  await p.waitForTimeout(1200);
  await shot(p, 'route');

  await p.evaluate(() => window.pwCmd('wild'));
  await p.waitForTimeout(2500);
  await press('z', 6, 600);
  await p.waitForTimeout(800);
  await shot(p, 'battle');
  await until((s) => s.mode === 'over' && s.ui === 0);

  await press('Escape', 1, 800);
  await press('ArrowDown', 2, 250);
  await press('z', 1, 900);
  await shot(p, 'codex');
  await press('x', 3, 400);
  const final = await state();

  const m = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
  watch(m);
  await m.goto(url);
  await ready(m);
  await m.waitForTimeout(1500);
  await m.screenshot({ path: `${out}/mobile.jpg`, type: 'jpeg', quality: 70 });
  const scrollW = await m.evaluate(() => document.documentElement.scrollWidth);

  await browser.close();
  console.log('final state', JSON.stringify(final), 'mobile scrollWidth', scrollW);
  if (errors.length) { console.log('ERRORS', JSON.stringify(errors)); process.exit(1); }
  console.log('CAPTURE OK');
})();
