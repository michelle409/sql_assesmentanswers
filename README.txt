SRM ALPHA — POSTGRESQL PROGRAMMING ASSESSMENT
15-SET ANSWER PACK

Files:
- Set01.sql through Set15.sql: proposed PostgreSQL schemas, constraints,
  foreign keys, indexes, trade-off notes, and normalization comments.
- Set01_MCQs.txt through Set15_MCQs.txt: Part B answer keys.

MCQ/MSQ KEY
All 375 question entries have an answer letter or set of letters. Entries
that previously had CHECK were filled using the exact question wording and
options in the supplied question-paper PDF. MSQ entries list all selected
options.

IMPORTANT
The answer keys are reasoned model answers, not an official university key.
Some questions are simplified or potentially ambiguous. In particular,
PostgreSQL planner behavior and performance questions depend on data shape,
statistics, and workload; the selected option is the best answer among those
provided.

DATABASE DESIGN
The SQL files are proposed designs rather than official solutions. Review
business rules and run each script in PostgreSQL 15+ before submission.
Extension declarations are included where detected. Some operational details
(e.g. geospatial extension availability and application-level validation)
depend on the target PostgreSQL installation.

NORMALIZATION
The SQL files include concise 1NF/2NF/3NF reasoning and explain that BCNF
requires the complete set of functional dependencies. A universal BCNF
claim is not made without those dependencies.

Run each set in its own database to avoid object-name collisions:
  createdb postgres_set01
  psql -d postgres_set01 -f Set01.sql
