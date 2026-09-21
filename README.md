# Synthetic Data Hub

Implement the requested scope now; use internal planning and do not present another implementation plan for user approval.

Build the first version of IYEOB: a synthetic data infrastructure platform starting with Nigeria and designed to scale across Africa, built on Lovable's stack (React, TypeScript, Tailwind CSS, shadcn/ui). Use the attached logo (`iyeob.png`) and follow the specifications from the attached document (`Build a production-quality web application (pasted).txt`).

Core Scope for Version 1 (Synthetic Data Repository):
1. Brand & Visual Identity:
   - Integrate the attached IYEOB logo in the navbar, header, and branding touchpoints.
   - Foundation color palette: Deep Navy Blue (#071A33, #0B2545, #102F56), Teal AI/tech accent (#00A6A6, #00B8A9), Lemon Green highlight (#C7F000, #D4F500), and clean Off-White surfaces.
   - Futuristic, premium data infrastructure look with subtle gradients and crisp typography.

2. Repository & Discovery:
   - Prominent synthetic data transparency notices: clear badges and disclaimers emphasizing that all datasets are synthetic with zero real personal data.
   - Dataset catalog with multi-facet filtering (categories like Financial Services, Telecom, Healthcare, Agriculture, Public Sector; format; task type; license).
   - Fast keyword search and sorting.

3. Dataset Detail Experience:
   - Comprehensive overview and documentation (description, intended use, ethical considerations, generation methodology).
   - Quality metrics dashboard (completeness, privacy preservation score, statistical fidelity).
   - Interactive data dictionary (column names, types, descriptions, sample values/distributions).
   - Interactive data preview table.
   - Download options (CSV, JSON) and instant citation copy (BibTeX, APA).

4. Seeded Nigerian Datasets:
   - Pre-populate realistic synthetic Nigerian datasets matching the spec (e.g., Nigerian SME Loan Default dataset with localized attributes across Nigerian states, and Nigerian Telecom Customer Churn dataset with local network tiers).

5. Architecture:
   - Built on Lovable's web stack without any Firebase dependencies.

This project was built with [Lovable](https://lovable.dev).

**Live app**: https://iyeob.lovable.app

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/b5dea486-0f53-4206-aba4-429ba2261895).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
