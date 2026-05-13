const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) throw new Error("OPENAI_API_KEY saknas i Supabase secrets.");

    const body = await req.json();
    const categories = Array.isArray(body.categories) ? body.categories : [];
    const inputText = String(body.text || "");
    const imageDataUrl = String(body.imageDataUrl || "");

    const content: unknown[] = [
      {
        type: "input_text",
        text: [
          "Tolka ett privat köp på svenska.",
          "Returnera endast JSON enligt schemat.",
          "Välj categoryId från listan om det är rimligt, annars tom sträng.",
          "Om en kategori har rules som matchar butik eller text, prioritera den kategorin.",
          "Om datum saknas, returnera tom date.",
          "Belopp ska vara totalsumma inklusive ören om det finns.",
          `Kategorier: ${JSON.stringify(categories)}`,
          `Text: ${inputText}`,
        ].join("\n"),
      },
    ];

    if (imageDataUrl) {
      content.push({ type: "input_image", image_url: imageDataUrl });
    }

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        input: [{ role: "user", content }],
        text: {
          format: {
            type: "json_schema",
            name: "purchase_parse",
            strict: true,
            schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                store: { type: "string" },
                amount: { type: "number" },
                date: { type: "string" },
                categoryId: { type: "string" },
                categoryName: { type: "string" },
                confidence: { type: "number" },
                note: { type: "string" },
              },
              required: ["store", "amount", "date", "categoryId", "categoryName", "confidence", "note"],
            },
          },
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(errorText);
    }

    const result = await response.json();
    const text = result.output_text || result.output?.flatMap((item: { content?: Array<{ text?: string }> }) => item.content || []).map((item: { text?: string }) => item.text || "").join("");
    const parsed = JSON.parse(text);

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "AI-tolkningen misslyckades.";
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
