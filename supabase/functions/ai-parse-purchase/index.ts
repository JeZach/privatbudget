const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-budget-action-key",
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
    const pin = String(body.pin || "");
    const mode = String(body.mode || "");

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) throw new Error("Supabase-miljön saknar URL eller anon key.");

    if (mode === "chatgpt_purchase") {
      const actionKey = Deno.env.get("CHATGPT_ACTION_KEY");
      const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (!actionKey) throw new Error("CHATGPT_ACTION_KEY saknas i Supabase secrets.");
      if (!serviceRoleKey) throw new Error("SUPABASE_SERVICE_ROLE_KEY saknas i Supabase secrets.");
      if (req.headers.get("x-budget-action-key") !== actionKey) throw new Error("Saknar behörighet.");

      const stateResponse = await fetch(`${supabaseUrl}/rest/v1/budget_state?id=eq.main&select=data`, {
        headers: {
          "apikey": serviceRoleKey,
          "Authorization": `Bearer ${serviceRoleKey}`,
        },
      });
      if (!stateResponse.ok) throw new Error("Kunde inte läsa budgeten.");
      const stateRows = await stateResponse.json();
      const budgetData = stateRows?.[0]?.data || {};
      const fixed = budgetData?.budgetTemplate?.fixedCosts || [];
      const variable = budgetData?.budgetTemplate?.variableCosts || [];
      const budgetCategories = [...fixed, ...variable].filter((row) => row?.id && row?.name).map((row) => ({ id: row.id, name: row.name }));
      if (!budgetCategories.length) throw new Error("Inga budgetposter finns att välja.");

      const parseResponse = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4.1-mini",
          input: [{
            role: "user",
            content: [{
              type: "input_text",
              text: [
                "Tolka ett svenskt köp som ska läggas i en godkännandekö.",
                "Välj categoryId från listan om möjligt.",
                "Om datum saknas, returnera tom date.",
                "Belopp ska vara totalsumma.",
                "Returnera endast JSON enligt schemat.",
                `Kategorier: ${JSON.stringify(budgetCategories)}`,
                `Text: ${inputText}`,
              ].join("\n"),
            }],
          }],
          text: {
            format: {
              type: "json_schema",
              name: "chatgpt_purchase_parse",
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
      if (!parseResponse.ok) throw new Error(await parseResponse.text());
      const parseResult = await parseResponse.json();
      const parseText = parseResult.output_text || parseResult.output?.flatMap((item: { content?: Array<{ text?: string }> }) => item.content || []).map((item: { text?: string }) => item.text || "").join("");
      const parsed = JSON.parse(parseText);
      const targetId = budgetCategories.some((row) => row.id === parsed.categoryId) ? parsed.categoryId : budgetCategories[0].id;
      const date = /^\d{4}-\d{2}-\d{2}$/.test(parsed.date || "") ? parsed.date : new Date().toISOString().slice(0, 10);
      if (!parsed.amount || parsed.amount <= 0) throw new Error("Belopp saknas.");

      const insertResponse = await fetch(`${supabaseUrl}/rest/v1/purchase_inbox`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "apikey": serviceRoleKey,
          "Authorization": `Bearer ${serviceRoleKey}`,
          "Prefer": "return=representation",
        },
        body: JSON.stringify({
          purchase_date: date,
          month_key: String(body.monthKey || "maj-27"),
          target_id: targetId,
          description: String(parsed.store || "ChatGPT-köp").slice(0, 120),
          amount: parsed.amount,
          receipt_text: inputText,
          source: "voice_ai",
          status: "pending",
        }),
      });
      if (!insertResponse.ok) throw new Error(await insertResponse.text());
      const inserted = await insertResponse.json();
      return new Response(JSON.stringify({
        ok: true,
        id: inserted?.[0]?.id || "",
        description: parsed.store || "ChatGPT-köp",
        amount: parsed.amount,
        date,
        categoryId: targetId,
        categoryName: budgetCategories.find((row) => row.id === targetId)?.name || parsed.categoryName || "",
        status: "pending",
        message: "Köpet är skickat till Godkänn köp.",
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (mode === "monthly_report") {
      const authorization = req.headers.get("Authorization") || "";
      const authResponse = await fetch(`${supabaseUrl}/rest/v1/rpc/is_budget_user`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "apikey": supabaseAnonKey,
          "Authorization": authorization,
        },
        body: "{}",
      });
      const allowed = authResponse.ok ? await authResponse.json() : false;
      if (!allowed) throw new Error("Saknar behörighet.");

      const reportResponse = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4.1-mini",
          input: [{
            role: "user",
            content: [{
              type: "input_text",
              text: [
                "Du är en svensk privatekonomisk budgetcoach.",
                "Sammanfatta månaden kort, konkret och utan moraliserande ton.",
                "Lyft främsta avvikelser, sparande och 2-4 praktiska åtgärder.",
                "Returnera endast JSON enligt schemat.",
                `Budgetdata: ${JSON.stringify(body.report || {})}`,
              ].join("\n"),
            }],
          }],
          text: {
            format: {
              type: "json_schema",
              name: "monthly_budget_report",
              strict: true,
              schema: {
                type: "object",
                additionalProperties: false,
                properties: {
                  summary: { type: "string" },
                  positives: { type: "array", items: { type: "string" } },
                  risks: { type: "array", items: { type: "string" } },
                  actions: { type: "array", items: { type: "string" } },
                },
                required: ["summary", "positives", "risks", "actions"],
              },
            },
          },
        }),
      });

      if (!reportResponse.ok) {
        const errorText = await reportResponse.text();
        throw new Error(errorText);
      }

      const reportResult = await reportResponse.json();
      const reportText = reportResult.output_text || reportResult.output?.flatMap((item: { content?: Array<{ text?: string }> }) => item.content || []).map((item: { text?: string }) => item.text || "").join("");
      return new Response(JSON.stringify(JSON.parse(reportText)), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const pinResponse = await fetch(`${supabaseUrl}/rest/v1/rpc/quick_pin_ok`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": supabaseAnonKey,
        "Authorization": `Bearer ${supabaseAnonKey}`,
      },
      body: JSON.stringify({ p_pin: pin }),
    });
    const pinOk = pinResponse.ok ? await pinResponse.json() : false;
    if (!pinOk) throw new Error("Fel PIN-kod.");

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
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
