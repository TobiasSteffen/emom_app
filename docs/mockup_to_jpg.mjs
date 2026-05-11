import puppeteer from 'puppeteer';
import { readFileSync } from 'fs';
import { resolve } from 'path';

const mockupPath = 'C:/DiesDas/Projects/emom_app/docs/emom mockup.html';
const outputPath = 'C:/Users/tobia/Downloads/emom_mockup.jpg';

const html = readFileSync(mockupPath, 'utf8');

const browser = await puppeteer.launch({ headless: 'new' });
const page    = await browser.newPage();

await page.setContent(html, { waitUntil: 'domcontentloaded', timeout: 10000 });
await new Promise(r => setTimeout(r, 1500)); // kurz warten bis Fonts geladen

// Fit to content width/height
const bodyHandle = await page.$('body');
const { width, height } = await bodyHandle.boundingBox();
await page.setViewport({ width: Math.ceil(width), height: Math.ceil(height), deviceScaleFactor: 2 });
await page.setContent(html, { waitUntil: 'domcontentloaded', timeout: 10000 });
await new Promise(r => setTimeout(r, 1500));

await page.screenshot({
  path: outputPath,
  type: 'jpeg',
  quality: 95,
  fullPage: true,
});

await browser.close();
console.log('JPG gespeichert:', outputPath);
