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

FROM nginx:1.27-alpine

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# nginx's docker-entrypoint runs envsubst over templates/*.conf.template using
# only names that are actual env vars (not nginx's own $uri etc.), so this is
# safe — unlike `serve`, nginx reliably binds IPv4 0.0.0.0, which `serve`
# doesn't (it binds IPv6-only `::`, invisible to Railway's IPv4 edge proxy).
ENV PORT=4173
EXPOSE 4173
