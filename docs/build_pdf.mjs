import { readFileSync } from 'fs';
import { marked } from 'marked';
import puppeteer from 'puppeteer';

const markdownPath = 'C:/DiesDas/Projects/emom_app/docs/emom_app_spezifikation.md';
const mockupPath   = 'C:/DiesDas/Projects/emom_app/docs/emom mockup.html';
const mockupJpg    = 'C:/Users/tobia/Downloads/emom_mockup.jpg';
const outputPath   = 'C:/DiesDas/Projects/emom_app/docs/emom_app_spezifikation.pdf';

const mdContent     = readFileSync(markdownPath, 'utf8');
const mockupContent = readFileSync(mockupPath, 'utf8');

// Bild als Base64 einbetten damit puppeteer es rendern kann
const imgBase64 = readFileSync(mockupJpg).toString('base64');
const imgDataUrl = `data:image/jpeg;base64,${imgBase64}`;

const specHtml = marked(mdContent)
  .replace(/C:\/Users\/tobia\/Downloads\/emom_mockup\.jpg/g, imgDataUrl);

const combinedHtml = `<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=DM+Mono:wght@300;400;500&display=swap" rel="stylesheet">
<style>
  /* ── SPEC STYLES ── */
  body {
    font-family: 'DM Mono', monospace;
    font-size: 13px;
    line-height: 1.7;
    color: #e0e0e0;
    background: #0d0d0d;
    margin: 0;
    padding: 0;
  }
  #spec {
    max-width: 820px;
    margin: 0 auto;
    padding: 60px 56px 80px;
  }
  h1 {
    font-family: 'Bebas Neue', sans-serif;
    font-size: 36px;
    letter-spacing: 6px;
    color: #fff;
    margin-bottom: 4px;
  }
  h2 {
    font-family: 'Bebas Neue', sans-serif;
    font-size: 18px;
    letter-spacing: 4px;
    color: #888;
    margin-top: 40px;
    margin-bottom: 14px;
    border-bottom: 1px solid #1e1e1e;
    padding-bottom: 6px;
  }
  h3 {
    font-family: 'Bebas Neue', sans-serif;
    font-size: 14px;
    letter-spacing: 3px;
    color: #555;
    margin-top: 24px;
    margin-bottom: 8px;
  }
  h4 {
    font-size: 11px;
    letter-spacing: 2px;
    text-transform: uppercase;
    color: #444;
    margin-top: 18px;
    margin-bottom: 6px;
  }
  p { margin-bottom: 10px; color: #aaa; }
  ul { padding-left: 20px; margin-bottom: 12px; }
  li { color: #888; margin-bottom: 4px; }
  li strong { color: #ccc; }
  code {
    font-family: 'DM Mono', monospace;
    background: #141414;
    border: 1px solid #222;
    border-radius: 4px;
    padding: 1px 6px;
    font-size: 11px;
    color: #FF6B00;
  }
  pre {
    background: #111;
    border: 1px solid #1e1e1e;
    border-radius: 8px;
    padding: 16px 20px;
    overflow: auto;
    margin-bottom: 16px;
  }
  pre code {
    background: none;
    border: none;
    padding: 0;
    color: #666;
    font-size: 11px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 20px;
    font-size: 12px;
  }
  th {
    text-align: left;
    padding: 8px 12px;
    font-size: 9px;
    letter-spacing: 2px;
    text-transform: uppercase;
    color: #444;
    border-bottom: 1px solid #1e1e1e;
  }
  td {
    padding: 9px 12px;
    color: #777;
    border-bottom: 1px solid #141414;
  }
  td code { color: #FF6B00; }
  hr {
    border: none;
    border-top: 1px solid #151515;
    margin: 36px 0;
  }
  strong { color: #ccc; }

  /* ── MOCKUP IMAGE IN SPEC ── */
  #spec img {
    width: 100%;
    border-radius: 12px;
    margin: 8px 0 24px;
  }

  /* ── MOCKUP PAGE ── */
  #mockup-page {
    page-break-before: always;
    background: #1a1a2e;
    min-height: 100vh;
  }
</style>
</head>
<body>

<div id="spec">
${specHtml}
</div>

<div id="mockup-page">
${mockupContent
  .replace(/^[\s\S]*?<body[^>]*>/i, '')
  .replace(/<\/body>[\s\S]*$/i, '')
  .replace(/<link[^>]*googleapis[^>]*>/gi, '')
  .replace(/position:\s*fixed/gi, 'position: relative')
}
</div>

</body>
</html>`;

const browser = await puppeteer.launch({ headless: 'new' });
const page    = await browser.newPage();
await page.setContent(combinedHtml, { waitUntil: 'domcontentloaded', timeout: 10000 });
await new Promise(r => setTimeout(r, 1500));
await page.pdf({
  path: outputPath,
  format: 'A4',
  printBackground: true,
  margin: { top: '0', right: '0', bottom: '0', left: '0' },
});
await browser.close();

console.log('PDF gespeichert:', outputPath);
