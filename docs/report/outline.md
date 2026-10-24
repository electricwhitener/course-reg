# Report outline (CSC2131 RDBMS Lab format)

The official chapter structure from "CSC2131 RDBMS Lab Project Report Format Final.docx", mapped to
where the material already exists in this repo and who writes each part. The A/B split follows
PLAN.md §2.

## Formatting rules (from the official format)
- **Length: 15 to 20 pages.** Plagiarism under 15%, **AI plagiarism under 20%**.
- A4, all margins 0.7". Page numbers at the bottom right, continuous from the Introduction.
- Body: Times New Roman 12, justified, 1.15 line spacing.
- Headings: Times New Roman 14 bold. Sub-headings numbered 1.1, 1.2, …, in Times New Roman 12 italic.
- **Figure captions go below** the figure, **table captions above** the table, both numbered by chapter (Fig. 2.1, Table 2.1).
- References in **IEEE format**, numbered in the order they are first cited.
- Front matter, in order: cover page, certificate, abstract (1 to 2 paragraphs), list of tables,
  list of figures, table of contents.
- Delete the "General Guidelines" page before submitting.

## Chapters

| Section | Owner | Material in the repo | Still needed |
|---|---|---|---|
| 1.1 Project overview / problem statement | B | PLAN.md "Context" | write it |
| 1.2 Objectives | B | PLAN.md "Context", scope tiers | write it |
| 1.3 Software & hardware requirements | B | CLAUDE.md "Stack"; MySQL 8.0.46, Python 3.12, Flask 3.1, mysql-connector-python 9.1, Bootstrap 5.3 | hardware specs of both laptops |
| 2.1 ER diagram | A | — | **draw it** (see below) |
| 2.2 Relational schema / mapping | A | `db/01_schema.sql` | schema diagram + ER-to-table mapping notes |
| 2.3 Data dictionary | A | `docs/report/data-dictionary.md` | format as tables |
| 3.1 Functional dependencies | A | `docs/report/normalization.md` | — |
| 3.2 Normalization steps | A | `docs/report/normalization.md` | write it in your own words |
| 4.1 DDL | A | `db/01_schema.sql`, `02_views.sql` | pick key excerpts; full scripts in an annexure |
| 4.2 DML | A | `db/07_seed.sql`, and the INSERT/UPDATE/DELETE inside the procedures | excerpts |
| 4.3 Awards and Recognitions | ? | — | **ask the instructor**: this looks like a leftover from another template |
| 4.4 Advanced SQL queries | A | views: window functions (`RANK`, `ROW_NUMBER`, running `SUM() OVER`), CTEs, `HAVING`, relational division (`fn_prereqs_met`), `JSON_TABLE`, recursive CTE (`demo/explain_indexes.sql`); EXPLAIN in `db-results.md` §5 | excerpts + outputs |
| 4.5 PL/SQL components | A | procedures, functions, triggers, cursor, handlers, event, roles (`db/03`–`06`); transactions and locking (`db-results.md` §2–4) | write it; see note below |
| 5.1 GUI screenshots | B | Flask app | screenshots of the finished pages |
| 5.2 Query output snapshots | A + B | `db/tests.sql` output, race / deadlock / isolation output, EXPLAIN | screenshots of terminal / Workbench output |
| 6 Conclusion | B | — | write it |
| References | both | — | IEEE list (see below) |
| Annexure (optional) | A | full SQL scripts | attach if pages allow |

## Notes
- **"PL/SQL" in 4.5:** PL/SQL is Oracle's language. The MySQL equivalent is *stored programs*
  (procedures, functions, triggers and events, written in SQL/PSM). Say so in a sentence and cover
  ours under that heading.
- **No separate chapter for transactions:** the template has none, but the race demo is the
  project's centrepiece. Put the explanation (ACID, `FOR UPDATE`, isolation levels, deadlock) in 4.5
  next to `sp_register`, and the measured outputs in 5.2.
- **The page limit is tight** for this much material. Use excerpts in the chapters and move full
  scripts to an annexure.
- **ER diagram (2.1):** use MySQL Workbench → Database → Reverse Engineer, connecting to
  `localhost:3306` as `coursereg_dev`, to get the schema diagram for 2.2. If the instructor expects
  Chen notation (entities, attributes, relationship diamonds) for 2.1, draw that separately. Ask
  which they want.
- **Reference candidates (verify each and format in IEEE):** the MySQL 8.0 Reference Manual
  chapters on InnoDB locking, transaction isolation levels, stored programs and window functions; the
  course textbook (e.g. Silberschatz, Korth and Sudarshan, *Database System Concepts*, or Elmasri and
  Navathe, *Fundamentals of Database Systems*); and the Flask and Bootstrap documentation.
