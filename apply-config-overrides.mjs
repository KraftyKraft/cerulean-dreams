import fs from "fs"
import YAML from "yaml"

const cfg = YAML.parse(fs.readFileSync("quartz.config.default.yaml", "utf8"))

cfg.configuration.pageTitle = "Cerulean Dreams"
cfg.configuration.baseUrl = "kraftykraft.github.io/cerulean-dreams"

fs.writeFileSync("quartz.config.yaml", YAML.stringify(cfg))
