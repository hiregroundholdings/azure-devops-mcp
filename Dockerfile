# Use Node.js 20 LTS
FROM node:20-alpine as builder

# Set working directory
WORKDIR /app

# Copy all source files first (needed for prebuild script that generates version.ts)
COPY . .

# Install all dependencies (including dev dependencies for building)
RUN npm ci

# Build the application
RUN npm run build

# Production stage
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies without running scripts
RUN npm ci --only=production --ignore-scripts

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist

# Expose port
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Run the application
CMD ["node", "dist/server.js"]
