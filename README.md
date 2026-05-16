# PrivEk för GitHub Pages + Supabase

Den här versionen av PrivEk är gjord för att publiceras på GitHub Pages och använda Supabase för inloggning och gemensam datalagring.

## Vad som ingår

- Dashboarden som statiska filer för GitHub Pages
- Supabase-inloggning via e-post och lösenord
- Gemensam budgetdata i Supabase
- Utlägg/köp sparar vilken inloggad användare som registrerade kostnaden
- Adminvy för att lägga till fler tillåtna användare
- Budgetmall som sätts en gång och används som grund varje månad
- Egna sidor för inkomster, utgifter och sparande
- Löneunderlag: faktisk inkomst i en månad används mot nästa månads kostnader
- Snabbköp i mobilen med kvittoläsning, röstinmatning och godkännande innan köp förs in i budgeten
- Rapportvy med AI-kommentar, månadssammanfattning, varningar, sparprognos och CSV-export
- Sparmål med målbelopp, måldatum och prognos
- Historik med återställning av tidigare budgetversioner
- Tydligare översikt med utgiftsläge, sparande mot årsmål och AI-kommentar

## 1. Skapa Supabase-projekt

1. Skapa ett nytt projekt i Supabase.
2. Öppna SQL Editor.
3. Klistra in innehållet från `supabase-schema.sql`.
4. Kör SQL-koden.

Du kan köra filen igen när appen uppdateras. Den skapar tabeller för admin/användare, snabbköpsinkorg och historik. Budgetstrukturen sparas fortfarande i tabellen `budget_state`.

## 2. Hämta nycklar

I Supabase:

1. Gå till Project Settings.
2. Öppna API.
3. Kopiera Project URL.
4. Kopiera `anon public` key.

Fyll sedan i dem i `config.js`:

```js
window.PRIVATBUDGET_SUPABASE = {
  url: "https://ditt-projekt.supabase.co",
  anonKey: "din-anon-public-key",
};
```

## 3. Publicera på GitHub

1. Skapa ett repo, till exempel `privatbudget`.
2. Ladda upp alla filer i den här mappen till repot.
3. Gå till Settings -> Pages.
4. Välj Deploy from a branch.
5. Välj `main` och `/root`.
6. Öppna länken GitHub visar.

## 4. Användare

Första gången tabellen `app_users` är tom blir det första inloggade kontot admin. Därefter kan admin lägga till fler användare inne i appen under sidan **Användare**.

En tillagd användare behöver skapa konto/logga in med samma e-postadress.

## 5. Snabbköp i mobilen

Öppna `quick.html` från mobilen och lägg till den på hemskärmen om ni vill ha en separat webbapp för köp. Sidan använder PIN och kan lägga in köp utan vanlig inloggning. Nya installationer får ingen känd standard-PIN, så sätt en egen PIN direkt efter att `supabase-schema.sql` har körts.

Byt PIN i Supabase SQL Editor med:

```sql
update public.app_settings
set quick_pin = 'ny-pin'
where id = 'main';
```

Snabbköp hamnar först under **Godkänn köp** i huvudappen. Där kan ni kontrollera och godkänna köpet innan det förs in i budgeten.

Kvitto-OCR görs i första hand med AI om funktionen nedan är aktiverad. Om AI-funktionen saknas försöker sidan fortfarande läsa kvittot lokalt i webbläsaren och plockar bara ut butik och totalsumma.

## 6. AI för kvitto och röst

För att AI-läsa kvitton och tolka röstkommandon behöver Supabase Edge Function-filen i `supabase/functions/ai-parse-purchase` publiceras i ert Supabase-projekt.

I Supabase behöver ni även lägga in en OpenAI-nyckel som hemlig inställning:

```bash
supabase secrets set OPENAI_API_KEY=din-openai-nyckel
supabase functions deploy ai-parse-purchase
```

När det är gjort kan snabbköpssidan tolka exempel som: "Jag köpte mat på Ica Maxi idag för 733 kronor." Den fyller då i butik/beskrivning, belopp, datum och föreslagen kategori. Ni kontrollerar alltid uppgifterna innan köpet skickas till **Godkänn köp**.

Under **Godkänn köp** kan admin lägga till kategoriregler, till exempel `ICA Maxi` -> `Mat`. De reglerna skickas med till AI-tolkningen så att kvitto och röst blir bättre över tid.

## 7. Rapport och export

Sidan **Rapport** visar månadens korta sammanfattning, största varningar och sparprognos. Knappen **Exportera CSV** hämtar vald månads budget, utfall och avvikelse till en fil som kan öppnas i Numbers eller Excel.

Knappen **Sammanfatta månaden** använder samma Supabase Edge Function och OpenAI-nyckel som snabbköp. Den kräver att användaren är inloggad i budgetappen.

## 8. Sparmål och historik

På sidan **Sparande** kan varje sparpost få målbelopp och måldatum. Rapporten räknar ut ungefär när målet nås med nuvarande takt.

Sidan **Historik** visar tidigare sparade versioner av budgeten och kan återställa en tidigare version. Kör alltid senaste `supabase-schema.sql` efter uppdatering så funktionerna `save_budget_state` och `restore_budget_history` finns i Supabase.

## 9. ChatGPT som köpklient

Det går att låta en egen GPT i ChatGPT lägga köp i samma godkännandekö som mobilwebbappen. Funktionen finns i samma Supabase Edge Function och använder läget `chatgpt_purchase`.

1. Lägg till en Supabase secret som heter `CHATGPT_ACTION_KEY` med ett eget långt hemligt värde.
2. Deploya `supabase/functions/ai-parse-purchase/index.ts` igen.
3. Skapa en egen GPT i ChatGPT och lägg till en Action.
4. Klistra in schemat från `chatgpt-action-openapi.json`.
5. Lägg in headern `x-budget-action-key` med samma hemliga värde.

Exempel att säga i ChatGPT: "Lägg till ett köp: Jag handlade en smörgås på Mackeriet för 85 kr." Köpet hamnar då under **Godkänn köp**.

## Ekonomilogik

- **Budgetmall** sätts en gång.
- **Inkomster** registreras som faktiskt utfall per månad.
- **Utgifter** registreras som faktiskt utfall per månad mot budgetmallen.
- **Sparande** har egen plan och eget månadsutfall.
- Inkomster i en månad används som tillgång för nästa månads utgifter och sparande.

För en mer privat familjeapp kan du stänga av öppen registrering i Supabase och skapa/bjuda in användare därifrån.

## Viktigt om säkerhet

`anon public`-nyckeln är tänkt att ligga i frontend. Säkerheten styrs av Supabase-inloggning och Row Level Security-reglerna i `supabase-schema.sql`.
