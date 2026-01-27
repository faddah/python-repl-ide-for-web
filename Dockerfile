# Use Node.js 24.13.0 LTS with Alpine Linux
FROM node:24.13.0-alpine

# Set working directory
WORKDIR /app

# Install build dependencies needed for native modules
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install dependencies (includes dev dependencies for build)
RUN npm ci

# Copy the entire project
COPY . .

# Build the application (builds both client and server)
RUN npm run build

# Remove dev dependencies to reduce image size
RUN npm prune --production

# Expose the application port
EXPOSE 3000

# Set environment to production
ENV NODE_ENV=production

# Start the application
CMD ["npm", "start"]
