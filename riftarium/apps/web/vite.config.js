import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));

// En production, nginx sert /data/rules-fr.json ; en dev, ce middleware s'en charge.
const rulesFile = process.env.RULES_DATA || path.resolve(here, "../../../le-codex/data/rules-fr.json");
const serveRulesData = {
  name: "serve-rules-data",
  configureServer(server) {
    server.middlewares.use("/data/rules-fr.json", (req, res) => {
      res.setHeader("Content-Type", "application/json; charset=utf-8");
      fs.createReadStream(rulesFile).pipe(res);
    });
  }
};

export default defineConfig({
  plugins: [vue(), serveRulesData],
  server: {
    host: true,
    // Les bind mounts Windows/Docker ne propagent pas les événements de fichiers : polling.
    watch: process.env.VITE_POLLING ? { usePolling: true, interval: 300 } : undefined,
    proxy: {
      // agent: false — pas de keep-alive : si le conteneur api est recréé (nouvelle IP),
      // chaque requête re-résout le DNS au lieu de servir des 502 sur des sockets mortes.
      "/api": { target: process.env.API_PROXY || "http://localhost:8000", changeOrigin: true, agent: false }
    }
  },
  test: {
    environment: "jsdom",
    setupFiles: "src/test/setup.js"
  }
});
