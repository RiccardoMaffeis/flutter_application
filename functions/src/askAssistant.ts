import { onRequest } from "firebase-functions/v2/https";
import { GoogleGenAI } from "@google/genai";

const PROJECT = process.env.GOOGLE_CLOUD_PROJECT || "tesi-2025-a0d0c";
const LOCATION = process.env.GOOGLE_CLOUD_LOCATION || "us-central1";
const MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";
const DATASTORE = process.env.VERTEX_DATA_STORE!;

export const askAssistant = onRequest({ cors: true, region: "us-central1" }, async (req, res) => {
  try {
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Headers", "content-type,x-lang");
      res.status(204).send("");
      return;
    }

    const { query, lang: bodyLang } = (req.body ?? {}) as { query?: string; lang?: string };
    if (!query) { res.status(400).json({ error: "missing query" }); return; }

    // 'en' fisso, oppure prendi da header/body (x-lang / Accept-Language)
    const pref = (bodyLang || String(req.headers["x-lang"] || req.headers["accept-language"] || "en")).toLowerCase();
    const lang = pref.startsWith("it") ? "it" : "en";

    const languageRule = lang === "it"
      ? "LINGUA: Rispondi sempre in italiano, anche se i documenti o la domanda sono in un’altra lingua. Traduci in italiano mantenendo numeri/unità e codici ABB."
      : "LANGUAGE: Always reply in English, even if the documents or the user message are in another language. Translate to English while preserving numbers/units and ABB product codes.";

    const ai = new GoogleGenAI({
      vertexai: true,
      project: PROJECT,
      location: LOCATION,
      apiVersion: "v1",
    });

    const retrievalTool = { retrieval: { vertexAiSearch: { datastore: DATASTORE } } } as const;

    const resp = await ai.models.generateContent({
      model: MODEL,
      contents: [{ role: "user", parts: [{ text: query }] }],
      config: {
        // Se TypeScript si lamenta del tipo stringa, usa { parts: [{ text: "..."}] }
        systemInstruction: [
          "Answer ONLY from the documents; if not found: 'Not available in the documents'.",
          languageRule,
        ].join("\n"),
        tools: [retrievalTool],
        temperature: 0.2,
        responseMimeType: "text/markdown",
      },
    });

    const answer =
      (resp as any).text ??
      resp?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text ?? "").join("") ??
      "";

    const gm: any =
      (resp as any).groundingMetadata ??
      resp?.candidates?.[0]?.groundingMetadata ?? {};

    const chunks = gm.groundingChunks ?? gm.groundingSupports ?? [];
    const sources = chunks
      .map((c: any, i: number) => {
        const rc = c.retrievedContext || c.context || {};
        const src = rc.source || {};
        const url = src.uri || rc.uri || "";
        const title = src.title || rc.title || url || "Document";
        if (!url && !title) return null;
        return {
          idx: i + 1,
          title,
          url,
          page: rc.pageNumber ?? rc.metadata?.pageNumber ?? c.pageNumber ?? 1,
        };
      })
      .filter(Boolean);

    res.set("Access-Control-Allow-Origin", "*").json({ answer, sources, lang });
  } catch (e: any) {
    console.error("askAssistant error:", e?.response ?? e);
    res.status(e?.status || e?.code || 500).json({
      error: e?.message || String(e),
      details: e?.response || e?.result || null,
    });
  }
});
