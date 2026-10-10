---
name: Finance Manager
description: |
  Use when working with the business-trip money ledger (командировочные) of МКАИР
  in ~/Documents/finance_manager: recording advances/funding, expenses (tickets, hostels, taxis,
  per diem 700 ₽/day), pulling tickets and receipts from Gmail, attaching PDF
  receipts, answering "сколько мне должны / я должен", building the monthly
  Excel report. Triggers on: командировка, командировочные, подотчёт,
  авансовый отчёт, суточные, Ленск, билет, чек, такси, хостел, мне должны,
  я должен, trip, отчёт по командировкам, gmail билет.
  The ledger lives at ~/Documents/finance_manager — read its AGENTS.md for the full
  operating manual before acting.
---

# Командировочные средства (МКАИР)

Система учёта командировочных денег живёт в `~/Documents/finance_manager`.
**Полная инструкция — в `~/Documents/finance_manager/AGENTS.md`**: прочитай её, прежде
чем что-либо менять.

Кратко:

- CLI — команда `trip` (данные: `~/Documents/finance_manager/data/trips.sqlite3`).
- `trip status` → сколько мне должны / я должен.
- `trip report` → `out/Командировки.xlsx` (сводка + лист на месяц).
- Кошельки: `podotchet` (деньги МКАИР под отчёт) и `personal` (деньги «не в
  отчёт», напр. директор лично).
- Чеки: `receipts/inbox/` — оттуда `trip receipt attach <expense_id> <файл>`.
- Билеты/чеки из почты — через Gmail-MCP (`gmail_search`,
  `gmail_get`, `gmail_download_attachments`).
- ⚠️ Леджер и БД синкаются через Syncthing (`~/Documents`) на весь флот — правь
  с ОДНОЙ машины за раз (иначе `*.sync-conflict*`); `trip report` коммитит и
  **пушит в GitHub**. Детали — в AGENTS.md, раздел «Несколько машин, Syncthing и offsite».

Главное правило: суммы не выдумывать, при неоднозначности — уточнять у
пользователя.
