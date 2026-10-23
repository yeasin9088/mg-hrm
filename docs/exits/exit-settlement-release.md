# Exit deduction and confidential report — implementation checkpoint

Date: 2026-10-23 (Asia/Dhaka)
Repository baseline: `5f4809ab956ecf0810db74f2fd63dc4463c10b4c`
Status: historical pre-deployment checkpoint; production migration applied 2026-10-23. GitHub Pages publication and device acceptance are tracked separately.

## Delivered

- Calendar anniversary applicability: under one completed year defaults on, anniversary onward defaults off; manual override requires a reason. Leap-day anniversaries follow PostgreSQL calendar arithmetic.
- Expected amount defaults to BDT 3,000. Tracks full, partial, pending, waived and not-applicable outcomes, actual deduction/deposit, dates, receipt, recipient, reason, authority, notes and optional follow-up.
- Separate All Reports entry: **Exit Deduction & Deposit Report (Confidential)**, using the existing date/project/designation/status controls plus financial-state/search filters. Print/PDF preview and formula-safe CSV usable in Excel.
- Ordinary Monthly Exits preview, print and CSV continue to use their existing explicit ordinary fields. Confidential data is never added to `DATA.exits`, generic activity detail, localStorage or normal reports.
- Confidential records/history in a separate unexposed `exit_private` schema. No direct authenticated table grants; public invoker APIs call private functions with the existing approved-operator identity check. No new user roles/accounts.
- Atomic exit, optional linked-transfer cancellation and financial recording. Identical retry IDs replay safely; different payloads using the same ID fail. A failed financial record rolls back the employee, exit, linked cancellation and audit changes.
- Version checks prevent stale-device overwrites; restricted before/after history preserves corrections.
- Generic optional follow-up To-Do uses a reference only: no employee identity, money, receipt, financial reason or notes. Resolving financial balances closes the generated follow-up. Reminder scheduling uses the existing one-shot scheduler and office-window controls.
- Verified live defect repaired: `complete_exit` used the forbidden employee status `Exited`; now uses the deployed `Inactive` status. Reactivation keeps completed exit history intact instead of attempting forbidden `Reactivated` exit status. Removed the client fallback that bypassed failed reactivation RPCs.
- Exit deletion waits for its server result, soft-archives the exit, retains restricted history and closes the generated follow-up.
- Small browser modules separate calculations, data access, form/editor, reporting and CSS. Public asset packaging and service-worker version updated.

## Validation performed

- 51 focused Node model/regression/package checks passed (exit rules, transfers, registration, disciplinary and inline JavaScript parsing).
- 15 isolated PostgreSQL/PGlite integration checks passed, including deployed employee/exit status constraints, rollback, idempotency, privacy, role denial, historical data, reactivation and stale versions.
- Synthetic Chromium checks passed at 390px and 1440px: form flow, anniversary override, duplicate clicks, separate confidential preview/print/export, ordinary print isolation, CSV formula protection and HTML escaping.
- JavaScript syntax checks, static public-site packaging and `git diff --check` passed.
- Live Supabase inspection was read-only. No real employee, salary, exit or financial records changed. Tests do not prove production scheduler delivery or real-device persistence.

## Deployment checklist (historical plan; migration completed 2026-10-23)

The attached project context requires explicit approval before commit/push/deployment. After approval:

1. Recheck the repository head for concurrent edits; preserve unrelated changes.
2. Already applied in production: `supabase/migrations/20261023173930_exit_confidential_settlement.sql` to project `enkggoozsvvkgbjeghbf` before publishing the frontend.
3. Run catalog/API authorization postflight and relevant Supabase advisors. Verify `exit_private` is not configured as an exposed Data API schema. No need to expose it.
4. Commit/push the reviewed changes to `main`; verify GitHub Pages deployment and all five new assets.
5. User confirms save/reload on two devices and prints both report types.

## Recovery

Before migration, capture the current `complete_exit` and `reactivate_employee` definitions and ACLs. If publishing fails, leave the additive private schema/data intact and retry publishing. For containment, revoke authenticated execution on the five new public exit-settlement/archive APIs and corresponding private functions; keep confidential tables/history. Do not drop the schema, financial records, history or generated task evidence. Reverting only the frontend does not require restoring the known-invalid status functions.

## ব্যবহারকারীর সংক্ষিপ্ত পরীক্ষা (লাইভ করার পরে)

1. এক বছরের কম মেয়াদের কর্মী: কর্তন ডিফল্ট চালু এবং ৩,০০০ টাকা দেখুন।
2. এক বছর পূর্ণ কর্মী: ডিফল্ট বন্ধ; চালু করলে কারণ চায় কি না দেখুন।
3. আংশিক কর্তন ও আংশিক জমা লিখে বাকি দুই অঙ্ক মিলিয়ে দেখুন।
4. সেভের পর রিলোড এবং অন্য ডিভাইসে আলাদা রিপোর্টে একই তথ্য দেখুন।
5. সাধারণ Monthly Exits প্রিন্ট/CSV-তে কর্তন, রিসিপ্ট বা গোপন নোট নেই নিশ্চিত করুন।
6. গোপনীয় রিপোর্টে মাস/প্রজেক্ট/অবস্থা ফিল্টার দিয়ে প্রিন্ট ও CSV পরীক্ষা করুন। পুরোনো তথ্যহীন রেকর্ডে “Not recorded” থাকবে।
