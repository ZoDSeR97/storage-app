# Use an official Node.js runtime as a parent image
FROM node:18-alpine as base

# Install Bun
RUN apk add --no-cache curl unzip \
    && curl -fsSL https://bun.sh/install | bash \
    && apk del curl unzip

# Set the working directory
WORKDIR /app

# Copy package.json and bun.lockb
COPY package.json bun.lockb ./

# Install dependencies using Bun
RUN bun install

# Copy the rest of the application code
COPY . .

# Build the Next.js application
RUN bun run build

# Use a smaller image for the final stage
FROM node:18-alpine as production

# Set the working directory
WORKDIR /app

# Copy only the necessary files from the base stage
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/.next ./.next
COPY --from=base /app/public ./public
COPY --from=base /app/package.json ./package.json
COPY --from=base /app/bun.lockb ./bun.lock
COPY --from=base /app/next.config.js ./next.config.js
COPY --from=base /app/drizzle.config.ts ./drizzle.config.ts
COPY --from=base /app/migrations ./migrations

# Expose the port the app runs on
EXPOSE 3000

# Run the application
CMD ["bun", "run", "start"]