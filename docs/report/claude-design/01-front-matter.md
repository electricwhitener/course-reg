Create the first three pages of the report: the cover page, the certificate and the abstract. Copy the layout, fonts, font sizes, bold and italic styling, spacing and logo positions of the attached template images "template-page-1-cover.png" and "template-page-2-certificate.png" exactly. Use the attached logo files "logo-emblem.png" (the round emblem) and "logo-muj-wordmark.png" (the "MANIPAL UNIVERSITY JAIPUR" logo) in the places the template has them; a line like [logo-emblem.png] below means "place this image here". The labels "PAGE 1", "PAGE 2" and "PAGE 3" are instructions, not text. These three pages have no page numbers. Use the text below exactly, with no changes.

---

PAGE 1 (cover page, every line centred as in the template)

A Lab Project Report
on
COURSE REGISTRATION AND WAITLIST MANAGEMENT SYSTEM USING MYSQL
carried out as part of the RDBMS Lab (CSC2131)
Submitted
by
Eknoor Brar (2502052701)
Bhavya Ransiwal (2502052706)
in partial fulfilment for the award of the degree of
[logo-emblem.png]
Bachelor of Technology
in
Computer Science and Engineering
Submitted To
Dr. Abhishek Dwivedi & Dr. Santosh Rajak
[logo-muj-wordmark.png]
School of Computer Science and Engineering
Department of Computer Science and Engineering
MANIPAL UNIVERSITY JAIPUR, JAIPUR
RAJASTHAN, INDIA
August-November 2026

PAGE 2 (certificate)

CERTIFICATE

This is to certify that the RDBMS Lab project titled **Course Registration and Waitlist Management System using MySQL** is a record of the bonafide work done by **EKNOOR BRAR** (2502052701) and **BHAVYA RANSIWAL** (2502052706) submitted in partial fulfilment of the requirements for the award of the Degree of Bachelor of Technology in Computer Science and Engineering of Manipal University Jaipur, Jaipur during the academic year 2026-27.

**Dr. Abhishek Dwivedi**
*Assistant Professor (Senior Scale),*
Course Instructor, *Department of Computer Science and Engineering*
*Manipal University Jaipur, Jaipur*

PAGE 3 (abstract: heading centred, Times New Roman 14 bold; two justified paragraphs)

ABSTRACT

Every semester, course registration opens at a fixed time and hundreds of students try to get into the
same few sections at once. Seats are limited, so the system has to check prerequisites, credit limits
and timetable clashes, and it must never give the last seat to two people. A registration system that
reads the seat count and then inserts the student as two separate steps can overbook a section when
two requests arrive together. This is the lost update problem that database courses describe in
theory. The aim of this project was to build a course registration database in MySQL 8.0 that stays
correct under that kind of concurrent load. Every registration rule runs inside the database itself,
as stored procedures, functions and triggers, instead of in application code.

Most small registration systems, including typical student projects, treat the database as passive
storage and check seat availability in the application, so the check and the insert are not atomic.
Our system runs each registration as one transaction that locks the section row with
`SELECT ... FOR UPDATE`. It adds a first-come-first-served waitlist with automatic promotion, an audit
trail written by triggers, and least-privilege roles. In a scripted race between two users for the
last seat, the unlocked version overbooked the section (2 students in 1 seat), while the locked
version gave exactly one seat and one waitlist place in all 10 runs. The project also measures the
four isolation levels, deadlock detection and the effect of indexes on query plans.
