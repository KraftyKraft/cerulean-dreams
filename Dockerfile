# syntax=docker/dockerfile:1
#
# Builds the site without vendoring the Quartz engine into this repo.
# Quartz is cloned fresh from upstream on every build; only our content
# and a couple of config overrides (title, base URL) come from this repo.
FROM node:26-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch v5 https://github.com/jackyzha0/quartz.git /quartz
WORKDIR /quartz
RUN npm ci
RUN npx quartz plugin install

# Quartz reads quartz.config.yaml in preference to its own bundled default,
# so patch just the fields we care about onto a copy of that default rather
# than hand-maintaining a full duplicate of Quartz's plugin/layout config.
RUN node -e "\
const fs = require('fs'); \
const YAML = require('yaml'); \
const cfg = YAML.parse(fs.readFileSync('quartz.config.default.yaml', 'utf8')); \
cfg.configuration.pageTitle = 'Cerulean Dreams'; \
cfg.configuration.baseUrl = 'kraftykraft.github.io/cerulean-dreams'; \
fs.writeFileSync('quartz.config.yaml', YAML.stringify(cfg)); \
"

COPY . /content

RUN npx quartz build --directory /content --output /quartz/public

FROM scratch AS export
COPY --from=build /quartz/public /
