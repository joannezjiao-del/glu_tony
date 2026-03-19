FROM node:22-slim

# Install OpenClaw CLI globally.
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw@latest

WORKDIR /app

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# WebSocket port for the OpenClaw Gateway.
ENV PORT=18789

EXPOSE 18789

# Run a long-lived foreground process (required by Railway).
CMD ["/app/start.sh"]

