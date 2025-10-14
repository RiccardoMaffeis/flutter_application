// eslint.config.cjs (flat config per ESLint 9)
const tsParser = require("@typescript-eslint/parser");
const tsPlugin = require("@typescript-eslint/eslint-plugin");

module.exports = [
  // ignora output e deps
  { ignores: ["lib/**", "node_modules/**"] },

  // regole per i .ts
  {
    files: ["**/*.ts"],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaVersion: 2022,
        sourceType: "module",
        project: "./tsconfig.json", // se non usi type-aware rules, puoi togliere questa riga
      },
    },
    plugins: { "@typescript-eslint": tsPlugin },
    rules: {
      "linebreak-style": "off", // non bloccare CRLF su Windows
      "max-len": ["warn", { code: 120, ignoreStrings: true, ignoreTemplateLiterals: true }],
      "object-curly-spacing": "off",
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-non-null-assertion": "off",
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }],
    },
  },
];
