# Playwright Server image with pre-installed dependencies
# Build: podman build -t localhost/playwright-server:1.55.1 .

FROM mcr.microsoft.com/playwright:v1.55.1-jammy

# Install playwright CLI globally
RUN npm install -g playwright@1.55.1

EXPOSE 5000

CMD ["npx", "playwright", "run-server", "--host", "0.0.0.0", "--port", "5000"]
