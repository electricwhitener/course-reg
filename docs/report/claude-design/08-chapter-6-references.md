Add Chapter 6 below on a new page after Chapter 5, then the References (heading "7. References") on a new page, then Annexure A on a new page. Keep the reference list exactly as written, with its numbers in square brackets. Follow the layout rules from my first message. Text in backticks is code: show it in Courier New 11 pt without the backticks, as in the abstract. Use the text below exactly as written: do not rewrite, shorten, summarise or add anything. Keep every table complete, with its caption above it. Render each "[Insert Fig. X.Y]" line as an empty light-grey box, full text width and about 7 cm tall, with the figure caption centred on the line below it. I will add the images later.

---

## 6. Conclusion

We built a course registration database in MySQL 8.0 in which every rule lives in the database: 11
tables in BCNF, 8 views, 4 functions, 6 procedures, 4 triggers, a scheduled event and 3 roles. The
central result is the race test. Without a lock, two students both got the single seat of CS302-A;
with `SELECT … FOR UPDATE` inside one transaction, exactly one student was enrolled and the other
waitlisted in every one of 10 runs. The second transaction visibly waited about 2 seconds for the
lock. The same project gave measured results for the four isolation levels, a deadlock detected and
resolved by InnoDB, and an index that cut a query from about 46 ms to under 0.1 ms. All 43 SQL tests pass on a
fresh database.

Putting the rules in stored procedures had a practical benefit too. The two of us worked on separate
machines (Linux and Windows) and separate layers, and the procedures acted as a fixed contract
between the database and the interface. The system has limits: it has no real login, it runs on a
single database server, and the demo users have development passwords. Future work could add
authentication, priority rules for the waitlist (for example final-year students first), e-mail
notification on promotion, and connection pooling for heavier load.

---

## 7. References

[1] A. Silberschatz, H. F. Korth and S. Sudarshan, *Database System Concepts*, 7th ed. New York, NY,
USA: McGraw-Hill, 2019, ISBN 978-0-07-802215-9.

[2] Oracle Corporation, "MySQL 8.0 Reference Manual." [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/. Accessed: Oct. 24, 2026.

[3] Pallets Projects, "Flask Documentation." [Online]. Available:
https://flask.palletsprojects.com/en/stable/. Accessed: Oct. 24, 2026.

[4] Oracle Corporation, "MySQL Connector/Python Developer Guide." [Online]. Available:
https://dev.mysql.com/doc/connector-python/en/. Accessed: Oct. 24, 2026.

[5] Bootstrap Team, "Bootstrap 5.3 Documentation." [Online]. Available:
https://getbootstrap.com/docs/5.3/. Accessed: Oct. 24, 2026.

[6] E. F. Codd, "A relational model of data for large shared data banks," *Communications of the
ACM*, vol. 13, no. 6, pp. 377–387, 1970, doi: 10.1145/362384.362685.

[7] R. Elmasri and S. B. Navathe, *Fundamentals of Database Systems*, 7th ed. Boston, MA, USA:
Pearson, 2016, ISBN 978-0-13-397077-7.

[8] Oracle Corporation, "Window Functions," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/window-functions.html. Accessed: Oct. 24, 2026.

[9] Oracle Corporation, "Stored Objects," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/stored-objects.html. Accessed: Oct. 24, 2026.

[10] Oracle Corporation, "Using the Event Scheduler," in *MySQL 8.0 Reference Manual*. [Online].
Available: https://dev.mysql.com/doc/refman/8.0/en/event-scheduler.html. Accessed: Oct. 24, 2026.

[11] Oracle Corporation, "Transaction Isolation Levels," in *MySQL 8.0 Reference Manual*. [Online].
Available: https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-isolation-levels.html.
Accessed: Oct. 24, 2026.

[12] Oracle Corporation, "Locking Reads," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html. Accessed: Oct. 24, 2026.

[13] Oracle Corporation, "Deadlocks in InnoDB," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/innodb-deadlocks.html. Accessed: Oct. 24, 2026.

[14] Oracle Corporation, "Using Roles," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/roles.html. Accessed: Oct. 24, 2026.

## Annexure A: SQL Scripts

The complete SQL scripts (schema, views, functions, procedures, triggers and events, security, seed data and tests) are kept in the project's GitHub repository and are available from the authors on request.
