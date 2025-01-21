# Stage 1: Build Angular application
FROM node:18-alpine AS build
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci

# Copy source code and build
COPY . .
RUN npm run build --configuration=production

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build /app/dist/cloudformation-frontend /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port and start Nginx
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]