# Use a lightweight Ubuntu base image
FROM ubuntu:22.04

# Avoid tzdata interactive prompt and install dependencies
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    python3 \
    make \
    ca-certificates \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy all project files
COPY . .

# Ensure all scripts are executable
RUN chmod +x briefing.sh custom-brief.sh scripts/*.sh

# Default to running the briefing script
ENTRYPOINT ["bash", "briefing.sh"]
