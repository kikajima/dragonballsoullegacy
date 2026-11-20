// Run after: npm install --prefix generated/sprites/browser-test playwright
const {chromium}=require('../generated/sprites/browser-test/node_modules/playwright');
const {pathToFileURL}=require('node:url');
const path=require('node:path');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true});
 try {
  const page=await browser.newPage({viewport:{width:1440,height:1000}}), errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(pathToFileURL(path.resolve('generated/sprites/catalog/index.html')).href);
  await page.waitForFunction(()=>document.querySelector('#sheet').naturalWidth>0);
  assert.equal(await page.locator('#files option').count(),344);
  await page.locator('#query').fill('Goku__47770');
  await page.waitForFunction(()=>document.querySelector('#sheet').complete&&document.querySelector('#sheet').naturalWidth===2016);
  assert.equal(await page.locator('#files option').count(),1);
  await page.locator('#action').fill('walk');
  assert.equal(await page.locator('#poses option').count(),1);
  await page.locator('#play').click();
  await page.waitForTimeout(250);
  assert.equal(await page.locator('#play').innerText(),'Parar');
  await page.locator('#status').selectOption('provisional');
  assert.equal(await page.locator('#poses option').count(),0);
  await page.locator('#action').fill('');
  assert.ok(await page.locator('#poses option').count()>0);
  await page.locator('#notes').fill('Teste de exportação — corrigir recortes.');
  await page.locator('#decision').selectOption('split');
  await page.locator('#save').click();
  const [download]=await Promise.all([page.waitForEvent('download'),page.locator('#export').click()]);
  const file=path.resolve('generated/sprites/browser-test/curation-test.json');
  await download.saveAs(file);
  await page.reload();
  await page.locator('#status').selectOption('provisional');
  assert.equal(await page.locator('#notes').inputValue(),'Teste de exportação — corrigir recortes.');
  await page.locator('#import').setInputFiles(file);
  await page.waitForFunction(()=>document.querySelector('#saved').textContent.includes('Decisões salvas'));
  await page.screenshot({path:'generated/sprites/catalog/catalog-preview.png'});
  await page.locator('#query').fill('ZZZ nonexistent');
  assert.equal(await page.locator('#files option').count(),0);
  assert.equal(await page.locator('#mark').isVisible(),false);
  assert.deepEqual(errors,[]);
  console.log('PASS: browser sources, filters, animation, empty results, persistence, export/import; no JS errors.');
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
