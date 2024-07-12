const puppeteer = require('puppeteer');
const fs = require('fs');
const minimist = require('minimist');

function readQuestionsFromFile(filePath) {
  const rawData = fs.readFileSync(filePath);
  return JSON.parse(rawData);
}

async function askQuestions(page, questions, endTime, delay) {
  for (const question of questions) {
      if(endTime != null) {
        if (Date.now() >= endTime) break;
      }
      console.log(question);
      await page.focus('[data-testid="textbox"]');
      await page.evaluate(() => {
        document.querySelector('[data-testid="textbox"]').value = '';
      });

      await page.type('[data-testid="textbox"]', question.question);

      await page.keyboard.press('Enter');

      console.log("Entered the question and waiting for the response indicator..");
   
      const initialResponses = await page.$$('button[data-testid="bot"]');
      const initialResponseCount = initialResponses.length;
      //console.log(initialResponseCount)
      await page.waitForFunction(
              initialCount => {
                      const responses = document.querySelectorAll('button[data-testid="bot"]');
                      //console.log(`Current response count: ${responses.length}, Initial response: ${responses}`);
                      return responses.length > initialCount;
              },
              {},
              initialResponseCount,
              { timeout: 100 }
      );
      console.log("Waiting for response....")
      const latestResponseIndex = initialResponseCount + 1;
      let stable = false;
      let lastResponse = '';
      const stabilityCheckDelay = 5; 
      const stabilityCheckDuration = 1000; 
      let stabilityCheckCounter = 0;
      // Monitor changes in the bot's latest response area until the content stabilizes
      while (!stable) {
              let currentResponse;
              const botButtons = await page.$$('button[data-testid="bot"]');
              //const buttonCount = botButtons.length;
              //console.log(`Number of bot buttons found: ${buttonCount}`);

              let retries = 0;
              const maxRetries = 5; 
              while (retries < maxRetries) {
                      try {
                              currentResponse = await botButtons[latestResponseIndex - 1].evaluate(el => el.innerText);
                              //console.log(currentResponse);
                              break; 
                      } catch (error) {
                              console.error(`Failed to find element: button[data-testid="bot"]:nth-of-type(${latestResponseIndex})`, error);
                              retries++;
                              await new Promise(resolve => setTimeout(resolve, delay1));
                      }
              }

              if (retries === maxRetries) {
                      console.error('Failed to find the current response after multiple attempts.');
                      break;
              }
              if (currentResponse.includes('Loading content')) {
                      //console.log("Response is still loading...");
                      stabilityCheckCounter = 0; 
              } else if (currentResponse === lastResponse) {
                      stabilityCheckCounter += stabilityCheckDelay;
                      if (stabilityCheckCounter >= stabilityCheckDuration) {
                              stable = true;
                      }
              } else {
                      lastResponse = currentResponse;
                      stabilityCheckCounter = 0;
              }
              await new Promise(resolve => setTimeout(resolve, stabilityCheckDelay));
      }
      await delayFunc(delay);
  }
}

async function runBrowser(url, questions, duration, delay, headless) {
  const headlessBool = (headless === 'true');
  const browser = await puppeteer.launch({
	  headless: headlessBool, 
	  args: ['--no-sandbox', '--disable-setuid-sandbox','--disable-features=BlockInsecurePrivateNetworkRequests'] 
  });
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
  
  const endTime = Date.now() + duration;
  let questionsAnswered = 0;
  const startQATime = performance.now();  
  if (duration) {
    console.log("Duration to run the load is set. Loops over the questions until the duration specified!");
    while(Date.now() < endTime) {
	    await askQuestions(page, questions, endTime, delay);
    }
  } else {
	  console.log("No duration is set. Runs all the questions once");
	  await askQuestions(page, questions, null, delay);
  }
  const endQATime = performance.now(); 
  console.log(`Time taken to run Q and A: ${(endQATime - startQATime) / 1000} seconds`);
  await browser.close();
}

function delayFunc(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main(url, numberOfBrowsers, duration, delay, headless) {
  const startSetTime = performance.now(); 
  const questions = readQuestionsFromFile('./questions.json');
  const browserPromises = [];

  for (let i = 0; i < numberOfBrowsers; i++) {
    browserPromises.push(runBrowser(url, questions, duration, delay, headless));
    await delayFunc(10000);
  }

  await Promise.all(browserPromises);
  const endSetTime = performance.now(); 
  console.log(`Time taken to complete the load run: ${(endSetTime - startSetTime) / 1000} seconds`);
}

// Parameters: URL, number of browsers, duration in milliseconds, delay between questions in milliseconds, headless mode (true/false)
const args = minimist(process.argv.slice(2));

const url = args.url;
const numberOfBrowsers = parseInt(args.browsers) || 1;
const duration = parseInt(args.duration) || null;
const delay = parseInt(args.delay) || 100; // default 100ms
const headless = args.headless || 'true'; // default true

if (!url) {
  console.error('Error: URL parameter is required');
  process.exit(1);
}

main(url, numberOfBrowsers, duration, delay, headless)
  .then(() => console.log('All browsers completed'))
  .catch(error => console.error('Error:', error));

