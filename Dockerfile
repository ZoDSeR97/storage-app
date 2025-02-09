# Use Node.js 20 as the base image
FROM node:20-alpine as base

# Install Bun
RUN apk add --no-cache curl unzip \
    && curl -fsSL https://bun.sh/install | bash \
    && apk del curl unzip

# Set the working directory
WORKDIR /app

# Copy package.json and bun.lock
COPY package.json bun.lock ./

# Install dependencies using Bun
RUN bun install

# Copy the rest of the application code
COPY . .

# Build the Next.js application
RUN bun run build

# Use a smaller Node.js 20 image for the final stage
FROM node:20-alpine as production

# Set the working directory
WORKDIR /app

# Copy only the necessary files from the base stage
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/.next ./.next
COPY --from=base /app/public ./public
COPY --from=base /app/package.json ./package.json
COPY --from=base /app/bun.lock ./bun.lock
COPY --from=base /app/next.config.js ./next.config.js
COPY --from=base /app/drizzle.config.ts ./drizzle.config.ts
COPY --from=base /app/migrations ./migrations
COPY --from=base /app/src ./src
COPY --from=base /app/tailwind.config.ts ./tailwind.config.ts
COPY --from=base /app/postcss.config.mjs ./postcss.config.mjs
COPY --from=base /app/tsconfig.json ./tsconfig.json

# Expose the port the app runs on
EXPOSE 3000

# Run database migrations and start the application
CMD bun run db:migrate && bun run start