Add Chapter 1 below, starting on a new page after the Abstract. This page is page 1 of the report: start the page numbers here (bottom right) and keep them continuous to the end. Follow the layout rules from my first message. Text in backticks is code: show it in Courier New 11 pt without the backticks, as in the abstract. Use the text below exactly as written: do not rewrite, shorten, summarise or add anything. Keep every table complete, with its caption above it. Render each "[Insert Fig. X.Y]" line as an empty light-grey box, full text width and about 7 cm tall, with the figure caption centred on the line below it. I will add the images later.

---

## 1. Introduction & System Requirements

### 1.1 Project Overview / Problem Statement

A college runs its course registration in short windows, and demand is uneven. Popular sections fill
in minutes while others stay half empty. Each request has to pass several rules before a seat is
given: the student must have completed the course's prerequisites, must stay within their credit
limit, must not already hold a section of the same course, and must not have a class at the same
time. When a section is full, the student should be placed on a waitlist and promoted automatically
when someone drops.

The hard part is concurrency. If two students request the last seat at the same moment, both
requests can read "1 seat left" before either one writes, and both get enrolled. Database textbooks
call this a lost update [1]. The problem statement for this project is: *design a normalized
relational database for course registration that enforces every rule itself and stays correct when
requests run concurrently.* We used MySQL 8.0 with the InnoDB storage engine [2], and a small web
interface on top that only calls the database's procedures.

### 1.2 Objectives

1. Design a relational schema for departments, students, instructors, courses, prerequisites,
   sections, timetables, enrollments and waitlists, normalized to BCNF.
2. Enforce all registration rules (prerequisites, credit limit, duplicate course, timetable clash,
   capacity) inside MySQL using stored procedures, functions and triggers.
3. Prevent overbooking under concurrent requests using transactions and row-level locking, and
   demonstrate the failure that occurs without locking.
4. Keep a waitlist that promotes students in request order when seats become free.
5. Record every registration event in an audit log automatically.
6. Restrict access with database roles, so the application can only call procedures and read views.
7. Study isolation levels, deadlocks and indexing with measured results.
8. Provide a web interface that shows the database at work.

### 1.3 Software & Hardware Requirements

**Table 1.1: Software requirements**

| Component | Version / detail | Purpose |
|---|---|---|
| MySQL Community Server | 8.0.46 (InnoDB, REPEATABLE READ) | Database server |
| Python | 3.12 | Runs the web application and demo scripts |
| Flask | 3.1.0 [3] | Web framework (routes and JSON API) |
| mysql-connector-python | 9.1.0 [4] | Python driver for MySQL |
| Bootstrap | 5.3.3 [5] | Page layout and styling |
| MySQL Workbench | 8.0 | Schema diagram |
| Git and GitHub | – | Version control and collaboration |
| Operating systems | Ubuntu 24.04 on WSL2 (Windows 11); Windows | Development machines of the two members |

**Table 1.2: Hardware requirements**

| Item | Member 1 (Eknoor Brar) | Member 2 (Bhavya Ransiwal) | Minimum needed |
|---|---|---|---|
| Laptop | Acer Predator PHN16-71 | (to be added) | – |
| Processor | Intel Core i7-13700HX (16 cores, 24 threads) | (to be added) | Any 64-bit dual-core |
| RAM | 16 GB | (to be added) | 4 GB |
| Storage | 1 TB SSD | (to be added) | 2 GB free |
| Operating system | Windows 11 Home, with Ubuntu 24.04 on WSL2 | (to be added) | Windows 10/11 or Linux |
