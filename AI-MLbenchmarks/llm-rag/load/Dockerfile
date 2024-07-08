# Use an official Node.js runtime as a parent image
FROM node:18

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the package.json and package-lock.json files
COPY package*.json ./

# Install any needed packages
RUN npm install

# Install dependencies required by Puppeteer
RUN apt-get update && apt-get install -y \
  wget \
  gnupg \
  ca-certificates \
  --no-install-recommends

# Install Chromium
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list' \
  && apt-get update \
  && apt-get install -y google-chrome-stable \
  && rm -rf /var/lib/apt/lists/*

RUN echo "Google Chrome installed at $(which google-chrome)" 

# Copy the rest of the application code
COPY . .

# Check the path of Google Chrome executable as pptruser
RUN echo "Google Chrome path:  $(which google-chrome)"

# Add user so we don't need --no-sandbox.
RUN groupadd -r pptruser && useradd -r -g pptruser -G audio,video pptruser \
  && mkdir -p /home/pptruser/Downloads \
  && chown -R pptruser:pptruser /home/pptruser

# After installing Google Chrome
RUN chmod +x /usr/bin/google-chrome && chown pptruser:pptruser /usr/bin/google-chrome
# Expose port if your app runs a server (optional)
# EXPOSE 8080

# Run everything after as non-privileged user.
USER pptruser

# Check the path of Google Chrome executable as pptruser
RUN echo "Google Chrome- path:  $(which google-chrome)"

# Command to run the script
CMD ["node", "load.js", "--url", "http://example.com", "--browsers", "1", "--duration", "60000", "--delay", "1000", "--headless", "true"]

