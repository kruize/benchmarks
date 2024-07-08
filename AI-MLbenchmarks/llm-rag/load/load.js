const puppeteer = require('puppeteer');
const fs = require('fs');
const minimist = require('minimist');

// Function to read questions from a JSON file
function readQuestionsFromFile(filePath) {
  const rawData = fs.readFileSync(filePath);
  return JSON.parse(rawData);
}

// Function to run a browser instance
async function runBrowser(url, questions, duration, delay, headless) {
  const browser = await puppeteer.launch({ 
    headless: headless,
    args: ['--no-sandbox', '--disable-setuid-sandbox','--disable-features=BlockInsecurePrivateNetworkRequests']
  }); //,'--no-sandbox', '--disable-setuid-sandbox']});
  const page = await browser.newPage();
  await page.setCacheEnabled(false);
  await page.setRequestInterception(true);
  page.on('request', request => {
    if (request.url().startsWith('http://')) {
      request.continue();
    } else {
      request.abort();
    }
  });

  await page.goto(url, { waitUntil: 'networkidle2' });
  await page.waitForSelector('[data-testid="textbox"]', { timeout: 90000 });
  console.log("Page has come up!");

  // Start the time tracking
  const endTime = Date.now() + duration;

  while (Date.now() < endTime) {
    for (const question of questions) {
      console.log(question);
      await page.focus('[data-testid="textbox"]');
      await page.evaluate(() => {
        document.querySelector('[data-testid="textbox"]').value = '';
      });
      await page.type('[data-testid="textbox"]', question.question);

      await page.keyboard.press('Enter');
      // await page.waitForSelector('[data-testid="response-indicator"]', { timeout: 90000 });

      console.log("Entered the question and waited for the response indicator..");

      if (Date.now() >= endTime) break;
      await delayFunc(delay);
    }
  }

  await browser.close();
}

// Function to introduce a delay between questions
function delayFunc(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}


async function main(url, numberOfBrowsers, duration, delay, headless) {
  const questions = readQuestionsFromFile('./questions.json');

  const browserPromises = [];

  for (let i = 0; i < numberOfBrowsers; i++) {
    browserPromises.push(runBrowser(url, questions, duration, delay, headless));
    await delayFunc(20000);
  }

  await Promise.all(browserPromises);
}

// Parse command-line arguments
// Parameters: URL, number of browsers, duration in milliseconds, delay between questions in milliseconds, headless mode (true/false)
const args = minimist(process.argv.slice(2));

const url = args.url;
const numberOfBrowsers = parseInt(args.browsers) || 1;
const duration = parseInt(args.duration) || 300000; // default 5 minute
const delay = parseInt(args.delay) || 1000; // default 1 second
const headless = args.headless || 'true'; // default true

if (!url) {
  console.error('Error: URL parameter is required');
  process.exit(1);
}

main(url, numberOfBrowsers, duration, delay, headless)
  .then(() => console.log('All browsers completed'))
  .catch(error => console.error('Error:', error));

