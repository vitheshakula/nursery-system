# Nursery Vendor Inventory & Settlement System

A full-stack nursery operations system for managing vendor inventory sessions, item issue/return tracking, billing, and settlement workflows.

## Project Overview

This repository contains a backend API built with NestJS and Prisma, a Flutter frontend client, and supporting product and system design documents. The app is designed to help nursery staff manage vendor sessions from login through inventory movement and final session summary.

## Tech Stack

- Backend: NestJS, Prisma, PostgreSQL, JWT authentication
- Frontend: Flutter, Dart, `http`
- Documentation: Markdown

## Features

- JWT-based authentication for protected API access
- Vendor management and balance tracking
- Session start flow for vendors
- Item issue and return operations per session
- Session summary with issued, returned, sold, and bill totals
- Clean separation between backend, frontend, and documentation

## Folder Structure

```text
nursery-system/
|-- backend/          # NestJS + Prisma API
|-- frontend/         # Flutter mobile client
|-- API DESIGN.md
|-- Database Design.md
|-- PRD.md
|-- README.md
`-- System Design.md
```

## Backend

The backend is a NestJS service with Prisma models for vendors, plants, sessions, payments, and authentication.

Common setup:

```bash
cd backend
cp .env.example .env
npm install
npm run prisma:generate
npm run start:dev
```

Required environment variables:

- `DATABASE_URL`
- `JWT_SECRET`
- `JWT_EXPIRES_IN`
- `PORT`

## Frontend

The frontend is a Flutter app that talks to the backend API.

Common setup:

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

For Android emulators, `10.0.2.2` points to the host machine. For desktop or other simulators, use the appropriate local backend URL.

## Documentation

The root documentation files capture product requirements, database design, API design, and system design decisions for the project.
