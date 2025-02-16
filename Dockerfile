# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

ARG NODE_VERSION=22

################################################################################
# Use node image for base image for all stages.
FROM node:${NODE_VERSION}-alpine as base

# Set working directory for all build stages.
WORKDIR /usr/src/app

# Copy package.json and bun.lock
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* bun.lock* ./

# Detect the package manager and install it if necessary
RUN if [ -f "yarn.lock" ]; then \
        echo "Using Yarn as the package manager" && \
        npm install -g yarn; \
    elif [ -f "pnpm-lock.yaml" ]; then \
        echo "Using pnpm as the package manager" && \
        npm install -g pnpm; \
    elif [ -f "bun.lock" ]; then \
        echo "Using Bun as the package manager" && \
        npm install -g bun; \
    else \
        echo "Using npm as the package manager"; \
    fi

################################################################################
# Create a stage for installing production dependecies.
FROM base as deps

# Download dependencies as a separate step to take advantage of Docker's caching.
# Leverage a cache mount to /root/.npm to speed up subsequent builds.
# Leverage bind mounts to package.json and package-lock.json to avoid having to copy them
# into this layer.
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=bun.lock,target=bun.lock \
    --mount=type=bind,source=yarn.lock,target=yarn.lock \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.bun \
    if [ -f "yarn.lock" ]; then \
        yarn install --production; \
    elif [ -f "pnpm-lock.yaml" ]; then \
        pnpm install --production; \
    elif [ -f "bun.lock" ]; then \
        bun install --production; \
    else \
        npm ci --production; \
    fi

################################################################################
# Create a stage for building the application.
FROM deps as build

# Download additional development dependencies before building, as some projects require
# "devDependencies" to be installed to build. If you don't need this, remove this step.
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=bun.lock,target=bun.lock \
    --mount=type=bind,source=yarn.lock,target=yarn.lock \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.bun \
    if [ -f "yarn.lock" ]; then \
        yarn install; \
    elif [ -f "pnpm-lock.yaml" ]; then \
        pnpm install; \
    elif [ -f "bun.lock" ]; then \
        bun install; \
    else \
        npm install; \
    fi

# Copy the rest of the source files into the image.
COPY . .

# Run the build script.
RUN if [ -f "yarn.lock" ]; then \
        yarn build; \
    elif [ -f "pnpm-lock.yaml" ]; then \
        pnpm build; \
    elif [ -f "bun.lock" ]; then \
        bun run build; \
    else \
        npm run build; \
    fi

################################################################################
# Create a new stage to run the application with minimal runtime dependencies
# where the necessary files are copied from the build stage.
FROM base as final

# Use production node environment by default.
ENV NODE_ENV production

# Run the application as a non-root user.
USER node

# Copy package.json so that package manager commands can be used.
COPY package.json .

# Copy the production dependencies from the deps stage and also
# the built application from the build stage into the image.
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/.next/standalone ./
COPY --from=build /usr/src/app/.next/static ./.next/static
COPY --from=build /usr/src/app/public ./public

# Expose the port that the application listens on.
EXPOSE 3000

ENV PORT=3000

ENV HOSTNAME="0.0.0.0"

# Run database migrations and start the application
CMD if [ -f "yarn.lock" ]; then \
        yarn db:migrate && yarn start; \
    elif [ -f "pnpm-lock.yaml" ]; then \
        pnpm db:migrate && pnpm start; \
    elif [ -f "bun.lock" ]; then \
        bun run db:migrate && bun run start; \
    else \
        npm run db:migrate && npm start; \
    fi