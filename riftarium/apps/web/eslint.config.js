import js from "@eslint/js"
import eslintConfigPrettier from "eslint-config-prettier"
import pluginVue from "eslint-plugin-vue"
import globals from "globals"

export default [
  { ignores: ["dist/**", "coverage/**"] },
  js.configs.recommended,
  ...pluginVue.configs["flat/recommended"],
  eslintConfigPrettier,
  {
    files: ["**/*.{js,vue}"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: { ...globals.browser }
    },
    rules: {
      "vue/multi-word-component-names": "off",
      "vue/max-attributes-per-line": "off",
      "vue/singleline-html-element-content-newline": "off",
      "vue/html-self-closing": "off",
      "vue/html-closing-bracket-newline": "off",
      "vue/first-attribute-linebreak": "off",
      "vue/attributes-order": "off",
      // Les trois v-html du site passent par escapeHtml (BeginnerGuideView, RulesView) :
      // chaque usage porte un eslint-disable-next-line, tout nouveau v-html est refusé.
      "vue/no-v-html": "error",
      "no-unused-vars": ["error", { argsIgnorePattern: "^_", caughtErrors: "none" }]
    }
  },
  {
    files: ["**/*.spec.js", "src/test/**/*.js"],
    languageOptions: {
      globals: { ...globals.browser, ...globals.vitest }
    }
  },
  {
    // Fichiers de configuration/outillage : exécutés par Node (Vite), pas par le
    // navigateur — ils accèdent à process, __dirname, etc.
    files: ["*.config.js"],
    languageOptions: {
      globals: { ...globals.node }
    }
  },
  {
    // Service worker : contexte dédié (self, caches, clients, skipWaiting…).
    files: ["public/sw.js"],
    languageOptions: {
      globals: { ...globals.serviceworker }
    }
  }
]
