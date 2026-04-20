const puppeteer = require('puppeteer');
const fs = require('fs');
const minimist = require('minimist');

function readQuestionsFromFile(filePath) {
  const rawData = fs.readFileSync(filePath);
  return JSON.parse(rawData);
}

async function askQuestions(page, questions, endTime, delay) {
  let questionsAnswered = 0;
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
   
       // Wait for the bot's response to appear
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
              const maxRetries = 5; // Adjust based on your needs
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
      questionsAnswered++;
      await delayFunc(delay);
  }
  return questionsAnswered;


}

// Function to run a browser instance
async function runBrowser(url, questions, duration, delay, headless) {
  const headlessBool = (headless === 'true');
  const browser = await puppeteer.launch({
	  headless: headlessBool, 
	  args: ['--no-sandbox', '--disable-setuid-sandbox','--disable-features=BlockInsecurePrivateNetworkRequests'] });
  const page = await browser.newPage();
  await page.setCacheEnabled(false);
  if (url.startsWith('http://')) {
    await page.setRequestInterception(true);
  }
  page.on('request', request => {
    const requestUrl = request.url();
    if (url.startsWith('http://')) {
      if (requestUrl.includes('https')) {
	request.abort();
      } else {
	request.continue();
      }
    }
  });

  await page.goto(url, { waitUntil: 'networkidle2', timeout: 60000 });
  await page.waitForSelector('[data-testid="textbox"]', { timeout: 120000 });
  console.log("Page has come up!");
  let questionsBrowserAnswered = 0;
  const endTime = Date.now() + duration;
  const startQATime = performance.now();  
  if (duration) {
    console.log("Duration to run the load is set. Loops over the questions until the duration specified!");
    while(Date.now() < endTime) {
      const questionsBrowserAnsweredtemp = await askQuestions(page, questions, endTime, delay);
      questionsBrowserAnswered += questionsBrowserAnsweredtemp;
    }
  } else {
    console.log("No duration is set");
    if (loop) {
      console.log(`Runs all the 8 questions ${loop} times`);
      for (let round = 0; round < loop; round++) {
        const questionsBrowserAnsweredtemp = await askQuestions(page, questions, null, delay); 
	questionsBrowserAnswered += questionsBrowserAnsweredtemp;
      }
    }
  }
  const endQATime = performance.now(); 
  const QATime = (endQATime - startQATime) / 1000;
  //console.log(`Time taken to get answers for ${questionsBrowserAnswered} questions : ${(endQATime - startQATime) / 1000} seconds`);
  return { questionsBrowserAnswered, QATime };
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
    await delayFunc(5000);
  }
	
  const results = await Promise.all(browserPromises);
  results.forEach((result, index) => {
    const { questionsBrowserAnswered, QATime } = result;
    console.log(`Browser ${index + 1} answered ${questionsBrowserAnswered} questions in ${QATime} seconds.`);
  });

  await Promise.all(browserPromises);
  const endSetTime = performance.now(); 
  console.log(`Time taken to complete the load run: ${(endSetTime - startSetTime) / 1000} seconds`);
}

// Parse command-line arguments
// Parameters: URL, number of browsers, duration in milliseconds, delay between questions in milliseconds, headless mode (true/false)
const args = minimist(process.argv.slice(2));

const url = args.url;
const numberOfBrowsers = parseInt(args.browsers) || 1;
const duration = parseInt(args.duration) || null;
const loop = parseInt(args.loop) || 1;
const delay = parseInt(args.delay) || 100;
const headless = args.headless || 'true'; 

if (!url) {
  console.error('Error: URL parameter is required');
  process.exit(1);
}

main(url, numberOfBrowsers, duration, delay, headless)
  .then(() => console.log('All browsers completed'))
  .catch(error => console.error('Error:', error));

