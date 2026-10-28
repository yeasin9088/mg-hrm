# Active project scope — 28 October 2026

Verified production data: 53 undeleted projects, 44 Active and 9 Closed. Meeting scope includes 41; three excluded meeting projects are independent of parade scope. The actual parade omissions were three active projects with no demand row: KGS Group (RB Agro), Biswas Classic Feed Depo, CTG, and Nabaron Jut Mill (6, 6, 4 active staff respectively).

Parade rows now originate from the active project register, not nonzero demand rows. Missing/zero demand projects remain visible; missing demand is disclosed without inventing staffing requirements. Canonical name/ID aliases prevent staff being split by spelling/casing or counted twice. Closed/deleted projects and staff are excluded. The existing supervisor substitution calculation remains. Verified source snapshot: 44 rows, 358 actual staff, 371 configured demand. Display, print, CSV and dashboard parade calculations share computeParade.

Owner additionally requested closed projects hidden throughout project choices and reports. Active scope now applies to project table rows, employee project choices/table/print matching, transfer choices and filtering, disciplinary/exit lists, uniform project selectors, standard report source views/exports, confidential exit report filtering, leave/salary/increment presentation, meeting historical project membership and report source rows. Persistence arrays and historical server records remain intact. No data/schema migration. UI cache v62.

Tests cover missing/zero demand, meeting exclusion independence, closed/deleted projects, canonical aliases, duplicate demand, workforce totals, supervisor substitution, and presentation-only filtering preserving historical source arrays. Existing regression suites and deployment workflows are required before completion.

## Project management exception and CSV export

Owner requested a management path for closed/inactive projects. The Projects screen defaults to Active, with explicit Closed/inactive and All views. Its existing project popup exposes Reopen Project; reopening now requires a matching server-returned ID before claiming success. Other project choices/reports continue to use active scope. Export CSV is a dropdown with Only active projects and With closed projects, independent of the displayed filter. CSV includes ID, English/Bengali names, status, admin, phone, address and active staff, with UTF-8 BOM, escaped quotes/newlines and spreadsheet formula protection. Deleted records are never included. Cache v63.
