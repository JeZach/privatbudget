# Privatbudget för GitHub Pages + Supabase

Den här versionen är gjord för att publiceras på GitHub Pages och använda Supabase för inloggning och gemensam datalagring.

## Vad som ingår

- Dashboarden som statiska filer för GitHub Pages
- Supabase-inloggning via e-post och lösenord
- Gemensam budgetdata i Supabase
- Utlägg/köp sparar vilken inloggad användare som registrerade kostnaden

## 1. Skapa Supabase-projekt

1. Skapa ett nytt projekt i Supabase.
2. Öppna SQL Editor.
3. Klistra in innehållet från `supabase-schema.sql`.
4. Kör SQL-koden.

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

Första gången kan du skapa konto direkt i appen. Om Supabase kräver e-postbekräftelse behöver du klicka på länken i mejlet innan inloggning.

För en mer privat familjeapp kan du stänga av öppen registrering i Supabase och skapa/bjuda in användare därifrån.

## Viktigt om säkerhet

`anon public`-nyckeln är tänkt att ligga i frontend. Säkerheten styrs av Supabase-inloggning och Row Level Security-reglerna i `supabase-schema.sql`.
