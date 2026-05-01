# Bilingual README Design

## 1. Background

The repository currently describes **Presence**, a minimalist iOS attendance app focused on automatic, privacy-first clock-in tracking through geofencing. The project is still in an **early-stage, design-first** state: product requirements, technical decisions, and visual directions are being explored, but the repository does not yet present itself as a polished, production-ready open-source app.

At the moment, the repository has no README entry point. This makes the project harder to understand for first-time visitors and weakens the repository's open-source presentation.

## 2. Goal

Create a bilingual README setup that:

1. gives the repository a clear open-source landing page,
2. accurately represents the current maturity of the project,
3. works well for both English-speaking and Chinese-speaking readers,
4. leaves room for future screenshots, licensing, and implementation progress.

## 3. Deliverables

Two mirrored README files will be added:

- `README.md`: primary English document
- `README.zh-CN.md`: Chinese document

The two files should share the same structure and communicate the same facts, with language adapted naturally rather than translated mechanically.

## 4. Positioning

The README set should follow the style of a modern open-source project homepage, but it must stay honest about the repository state.

The positioning is:

- **design-first**
- **early-stage**
- **privacy-first**
- **minimalist iOS product**

The README must not imply that the app is already publicly released, fully implemented, or ready for installation from the App Store.

## 5. Information Architecture

Both README files should use the same information hierarchy:

1. Project title and one-line summary
2. Language switch link
3. Badge area
4. Short project introduction / hero section
5. Why this project
6. Highlights / key features
7. Project status
8. Screenshots section
9. Roadmap
10. Repository structure
11. Contributing
12. License

## 6. Content Rules

### 6.1 Title and summary

The title should clearly present the name **Presence**. The one-line summary should describe it as a minimalist, privacy-first iOS attendance tracker or attendance companion.

### 6.2 Language navigation

Each README should link to the other language near the top:

- English README links to `README.zh-CN.md`
- Chinese README links to `README.md`

### 6.3 Badges

The badge area should be lightweight and informative. It may include:

- stage badge such as `Early Stage`
- platform badge such as `iOS`
- language badge such as `English` / `中文`

If license metadata is not yet present in the repository, the README should not fabricate a formal license badge.

### 6.4 Hero introduction

The hero section should explain:

- what Presence is,
- the core experience it aims to provide,
- why it is different from manual punch-in apps.

The tone should be crisp, direct, and aligned with open-source project landing pages.

### 6.5 Why this project

This section should explain the motivation behind the product:

- reduce manual attendance friction,
- make tracking feel invisible,
- respect user privacy through local-first storage.

### 6.6 Highlights

This section should present the key capabilities and principles, such as:

- automatic attendance logging through geofencing,
- minimalist dashboard,
- local-first data handling,
- thoughtful workday statistics,
- native iOS design direction.

The README can use a small amount of emoji to improve scanability, but emoji should remain restrained.

### 6.7 Project status

This section must explicitly state that the repository is in an early stage. It should communicate that the project is currently centered on:

- product definition,
- technical architecture decisions,
- interaction and visual exploration,
- prototype/design iteration.

It should avoid any wording that suggests finished functionality or public release readiness.

### 6.8 Screenshots

The README should reserve a screenshots section, but since no image assets currently exist in the repository, it should:

- mention that screenshots will be added after device testing,
- define the intended asset location under `screenshots/`,
- avoid broken links or fake placeholder images.

Suggested future asset examples:

- `screenshots/dashboard.png`
- `screenshots/setup-map.png`

### 6.9 Roadmap

The roadmap should focus on near-term, credible milestones rather than vague ambition. Example topics may include:

- building the native iOS foundation,
- implementing geofencing and permission flow,
- shaping the dashboard UI,
- validating attendance rules,
- adding screenshots and public project materials.

### 6.10 Repository structure

The README should briefly explain the current meaningful directories and files, especially those that help visitors understand why the repository looks design-heavy today.

It should mention the role of:

- `requirement.md`
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`
- `figma/`

The wording should make it clear that `figma/` is currently design/prototype-related rather than the final production app stack.

### 6.11 Contributing

The project should welcome:

- issues,
- discussions,
- feedback,
- future pull requests.

The wording should invite collaboration without pretending the contribution process is fully formalized.

### 6.12 License

No `LICENSE` file currently exists in the repository. Therefore the README should state that licensing information is to be added, instead of inventing a license.

## 7. Tone and Style

The README should feel:

- calm,
- modern,
- product-aware,
- open-source friendly.

It should avoid:

- exaggerated marketing language,
- fake maturity signals,
- verbose internal planning details,
- inaccurate installation or usage claims.

Emoji are allowed, but they should be used sparingly to support visual scanning instead of decoration.

## 8. Error-Avoidance Rules

To keep the README trustworthy:

1. do not include an installation guide that implies a runnable app if the repository is not yet ready for that,
2. do not reference screenshots that do not exist,
3. do not claim a license that has not been added,
4. do not describe prototype assets as the final production implementation.

## 9. Testing / Review Expectations

Review should confirm:

- both README files mirror the same structure,
- English and Chinese content stay aligned in meaning,
- repository maturity is described consistently,
- all referenced files and directories actually exist,
- no broken screenshot or license references are introduced.

## 10. Final Decision

The approved direction is:

- **Approach A as the base**: vision + current status + roadmap
- enhanced with a small amount of **Approach B** presentation quality
- while preserving a small amount of **Approach C** repository guidance

This gives the project a strong open-source entry point without overstating implementation maturity.
