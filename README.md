# Privatbudget för GitHub Pages + Supabase

Den här versionen är gjord för att publiceras på GitHub Pages och använda Supabase för inloggning och gemensam datalagring.

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
- Rapportvy med månadssammanfattning, varningar, sparprognos och CSV-export

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

Öppna `quick.html` från mobilen och lägg till den på hemskärmen om ni vill ha en separat webbapp för köp. Sidan använder PIN och kan lägga in köp utan vanlig inloggning. Standard-PIN efter att `supabase-schema.sql` körts är `1234`.

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

## Ekonomilogik

- **Budgetmall** sätts en gång.
- **Inkomster** registreras som faktiskt utfall per månad.
- **Utgifter** registreras som faktiskt utfall per månad mot budgetmallen.
- **Sparande** har egen plan och eget månadsutfall.
- Inkomster i en månad används som tillgång för nästa månads utgifter och sparande.

För en mer privat familjeapp kan du stänga av öppen registrering i Supabase och skapa/bjuda in användare därifrån.

## Viktigt om säkerhet

`anon public`-nyckeln är tänkt att ligga i frontend. Säkerheten styrs av Supabase-inloggning och Row Level Security-reglerna i `supabase-schema.sql`.
