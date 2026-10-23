FROM node:20-slim AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Vite inlines VITE_* vars at build time, so this must be a build arg, not a
# runtime env var — Railway lets you set build args per-service.
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
RUN npm run build

FROM node:20-slim

WORKDIR /app

RUN npm install -g serve

COPY --from=build /app/dist ./dist

EXPOSE 4173

CMD ["sh", "-c", "serve -s dist -l ${PORT:-4173}"]
