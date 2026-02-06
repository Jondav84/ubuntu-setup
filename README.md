# Ubuntu Setup

Ubuntu_setup is a modular workstation provisioning and configuration toolkit
for Ubuntu-based systems.

It is designed to bootstrap a fresh system into a **ready-to-use development
and operations environment** with reproducibility, logging, and service control
as first-class concerns.

This repository reflects how I structure system automation when I am responsible
for maintaining my own machines.

---

## Goals

- Reproducible system setup
- Explicit, script-driven configuration (no hidden state)
- Separation of concerns between user tools, system config, and services
- Safe re-runs (idempotent where possible)
- Local logging and traceability

---

## Repository Structure

Ubuntu_setup/
├── bin/ # Executable setup and utility scripts
├── config/ # Configuration files deployed by scripts
├── systemd/ # Custom systemd unit files and timers
├── docs/ # Design notes and usage documentation
├── logs/ # Local execution logs
└── README.md


---

## What It Does

Depending on the script invoked, this toolkit can:

- Install and configure development tools
- Apply opinionated system defaults
- Deploy configuration files into user and system locations
- Register and manage systemd services and timers
- Log execution output for later inspection

Scripts are intentionally explicit and readable rather than “one-liners.”

---

## Usage Model

This is **not** a one-click installer.

Each script in `bin/` is designed to be:
- read before execution
- run intentionally
- modified as needed for the target system

Typical usage:
```bash
bash bin/<script-name>.sh
Safety & Scope
No destructive disk operations

No hidden background services

System-level changes are explicit and inspectable

systemd units are version-controlled

The operator is expected to understand what they are applying.

Status
Core scripts: implemented

Documentation: partial

Logging: implemented

Planned improvements:

install ordering orchestration

dry-run / audit mode

distro-detection expansion

Portfolio Intent
This project demonstrates:

Linux system administration discipline

Practical automation (not configuration magic)

Understanding of systemd, logging, and OS layout

Reproducible workstation setup practices

It reflects how I approach owning and maintaining my own development systems.