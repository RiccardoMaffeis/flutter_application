import { onRequest } from "firebase-functions/v2/https";
import { GoogleGenAI } from "@google/genai";

const MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";
const DATA_STORE = process.env.VERTEX_DATA_STORE!;

export const askAssistant = onRequest({ cors: true }, async (req, res) => {
  try {
    const { query } = (req.body ?? {}) as { query?: string };
    if (!query) {
      res.status(400).json({ error: "missing query" });
      return;
    }

    const ai = new GoogleGenAI({ apiVersion: "v1" });

    const tool = {
      retrieval: {
        vertexAiSearch: { datastore: DATA_STORE },
      },
    } as const;

    const sys = [
      "Sei un assistente tecnico. Rispondi SOLO usando i documenti recuperati.",
      "Se un'informazione non è nei documenti, scrivi: 'Non disponibile nei documenti'.",
      "Per confronti, usa tabella Markdown: Modello | In | V | Poli | Icu/Ics | Protezioni | Dimensioni | Note",
    ].join("\n");

    const response = await ai.models.generateContent({
      model: MODEL,
      contents: [
        { role: "system", parts: [{ text: sys }] },
        { role: "user", parts: [{ text: query }] },
      ],
      config: { tools: [tool], temperature: 0.2 },
    });

    const answer = (response as any).text ?? "";

    const gm: any =
      (response as any).groundingMetadata ??
      (response as any).response?.groundingMetadata ??
      {};
    const chunks: any[] = gm.groundingChunks ?? [];
    const sources = chunks
      .map((c, i) => {
        const rc = c.retrievedContext;
        if (rc?.source) {
          const title = rc.source.title || rc.source.uri || "Documento";
          const url = rc.source.uri || "";
          const page = rc.pageNumber || rc.metadata?.pageNumber || 1;
          return { idx: i + 1, title, page, url };
        }
        return null;
      })
      .filter(Boolean);

    res.json({ answer, sources });
    return;
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
    return;
  }
});
