const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  
  page.on('pageerror', err => {
    console.log('Uncaught Exception:', err.toString());
  });

  await page.goto('file://' + process.cwd() + '/index.html', { waitUntil: 'networkidle0' });
  await browser.close();
})();
