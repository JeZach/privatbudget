# PrivEk Enkel Budget

En förenklad version av budgetappen med fokus på:

- Inkomster
- Fasta kostnader
- Kvar efter fasta kostnader

Appen använder samma Supabase-projekt och tabell (`budget_state`, id `main`) som den tidigare webbappen. Om den hittar den gamla datastrukturen migrerar den inkomster och fasta kostnader till den nya, enklare modellen.

## Kör lokalt

Öppna `index.html` i webbläsaren eller servera mappen statiskt.

## Deploy

Lägg upp innehållet i den här mappen på GitHub Pages eller annan statisk hosting:

```text
index.html
config.js
manifest.json
service-worker.js
icon.svg
```

## Datamodell

Den nya modellen sparas som:

```json
{
  "version": 4,
  "mode": "simple-fixed-budget",
  "months": {
    "2026-06": {
      "incomes": [{ "id": "...", "name": "Lön", "amount": 0 }],
      "fixedCosts": [{ "id": "...", "name": "Hyra", "amount": 0 }],
      "locked": false
    }
  }
}
```
