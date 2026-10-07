# AGENTS.md

## Purpose

This repository contains a Salesforce solution and the technical documentation under `docs/`.

This file is for someone who clones the repo on another computer and wants to use AI to keep documenting the solution in a safe, consistent, and repo-specific way.

The AI should be able to:

- understand how the solution is built
- keep extending `docs/` without breaking the structure or the navigation
- keep verified facts separate from assumptions
- respect Salesforce architecture, metadata, and integration boundaries
- update the index and the in-org document viewer in a consistent way

Act as a senior Salesforce engineer, integration architect, and technical writer.

Prefer:

- correctness over speed
- observations from this repo over generic advice
- small, traceable changes over broad rewrites
- readable documentation over impressive documentation that is hard to maintain

---

## Important context for this repo

This repo contains:

- Salesforce code and metadata under `force-app/main/default`
- technical documentation under `docs/`
- a Lightning web component that renders that markdown inside Salesforce
- Mermaid diagrams written as fenced `mermaid` blocks in the markdown, rendered in the org from the `MermaidLib` static resource
- highlighted code blocks rendered from the `HighlightJsLib` static resource

The pages are in English. Write new documentation in English unless the user explicitly asks for another language.

The documentation has been built up iteratively. It currently covers Partner Portal Commerce (quote and invoice import, invoice groups, monthly auto-import, currency rates, default opportunity owner, promotion codes, credential health, PDF preview), Atlassian deal and service registration, Make.com webhooks, MEDDPICC, the opportunity product editor, opportunity splits, and tier calculation.

Documentation work here is not only "write markdown". It also means:

- reading the metadata and the code
- keeping `docs/index.json` up to date
- keeping the pages navigable
- copying the published pages into the `MarkdownDemo` static resource when they should appear in Salesforce
- writing markdown that the viewer actually renders

The OpenAPI spec and the Postman collection in `docs/` are reference files. They are not part of the viewer. Do not copy them into `MarkdownDemo`.

---

## First files to read

Always read these first:

- `README.md`
- `docs/AGENTS.md`
- `docs/README.md`
- `docs/index.json`
- `docs/Docs_Viewer.md`
- `sfdx-project.json`
- `package.json`

If the task is about the documentation, then read:

- the relevant pages under `docs/`
- `force-app/main/default/staticresources/MarkdownDemo/docs/` if you need to see what Salesforce is currently serving

If the task is about the in-org viewer, also read:

- `force-app/main/default/lwc/fbMarkdownViewer/fbMarkdownViewer.js`
- `force-app/main/default/lwc/fbMarkdownViewer/markdownParser.js`
- `force-app/main/default/lwc/fbMarkdownViewer/__tests__/fbMarkdownViewer.test.js`
- `force-app/main/default/lwc/fbMarkdownInline/`
- `force-app/main/default/lwc/fbMarkdownList/`
- `force-app/main/default/lwc/fbMarkdownMermaid/`
- `force-app/main/default/lwc/fbMarkdownCodeBlock/`

The component API names stay `fbMarkdown*`. The HTML uses `c-fb-markdown-inline`, `c-fb-markdown-list`, `c-fb-markdown-mermaid`, and `c-fb-markdown-code-block`.

If the task is about a particular part of the system, also read the relevant Apex classes, triggers, flows, object metadata, permission sets, and named credentials.

---

## Documentation principles

Documentation in this repo should be:

- in English, unless the user explicitly asks for another language
- concrete
- specific to this repo
- technically useful
- clear about what is fact and what is an assumption

It should help a developer, architect, administrator, or support person understand:

1. what the system does
2. which parts are central
3. how data moves
4. how integrations work
5. where the risks and the open questions are
6. how to troubleshoot and extend the solution

Avoid:

- generic Salesforce prose that says nothing about this solution
- speculative statements that are not marked as assumptions
- long documents that only repeat the code without explaining the context
- describing "how Salesforce usually works" when this repo does something else

When the code and a comment or an older design note disagree, follow the code.

---

## Facts versus assumptions

This is a core requirement.

### Facts

Use this when something can be verified in the repo, for example through:

- Apex code
- Flow metadata
- custom object metadata
- custom metadata
- permission sets
- named credentials
- remote site settings
- sites
- profiles
- LWC code
- test code

### Assumptions

Use this when something looks likely but cannot be fully proved from the repo.

Examples:

- that a particular flow is the one actually used in production
- that an external credential is configured in the org but not in the repo
- that a process is historical or has been replaced
- that a standard field is central when the repo does not say so

When something is uncertain:

- say so
- say why it looks likely
- point out what would be needed to verify it

Scheduled jobs, user names, and org-only settings are facts only after they have been checked in the org. Do not invent them from a comment.

---

## Structure of `docs/`

The pages are flat markdown files in `docs/`, named in Pascal_Snake case. `docs/README.md` is the start page and the map. `docs/index.json` is the menu the viewer uses.

Current groups:

- Start: `README.md`
- Partner Portal Commerce: overview, invoice groups, quote and invoice import, monthly invoice auto-import, currency rates, default opportunity owner, promotion codes, credential health, PDF preview
- Deal registration: `Atlassian_Deal_Registration.md` only
- Other features: Make.com webhooks, MEDDPICC, opportunity product editor, opportunity splits, tier calculation
- For developers: this file, `docs/AGENTS.md`, and `Docs_Viewer.md`

The developer guide for maintaining the pages lives at `docs/AGENTS.md`. It is not a product document. The Documentation app renders it as HTML like the other pages.

`docs/Deal Registration APIs_Spec.yaml` and `docs/Deal Registration APIs.postman_collection.json` stay in `docs/`. They are not markdown and the viewer does not render them.

When you add a new page:

1. Put the markdown file in `docs/`.
2. Link it from `docs/README.md` when it belongs in the reading order.
3. Add it to `docs/index.json` with the same `{ label, path }` or `{ label, children }` shape.
4. Make the file name, the README link, and the index label describe the same page.
5. Copy the markdown tree into `staticresources/MarkdownDemo/docs/` when the page should show in Salesforce.

Screenshots live in `docs/_images/` and are included from a page as one image on its own line, for example `![Sweden card, Unhealthy](_images/ppc-credential-health-unhealthy.png)`. The viewer resolves that path from the page. Copy `_images/` into the static resource with the markdown.

---

## `docs/index.json` is a contract

Treat `docs/index.json` as navigation configuration, not as an optional list.

If you add, move, rename, or delete a page, update `docs/index.json` in the same change.

The index must:

- match the real pages
- use clear English labels
- group pages by area
- contain no broken paths

`README.md` is the first document. A page that is not in the index does not appear in the viewer menu.

If `docs/index.json` is not updated, the in-org navigation becomes wrong or incomplete.

---

## How the pages reach Salesforce

`docs/` is the source. Salesforce does not read that folder.

`fbMarkdownViewer` loads the static resource `MarkdownDemo`. This package keeps the published copy at `force-app/main/default/staticresources/MarkdownDemo/docs/`, including `index.json`. On deploy, Salesforce zips that folder. The resource metadata is `application/zip` with public cache control.

To refresh the org:

1. Edit the markdown under `docs/`.
2. Update `docs/index.json` when the menu changes.
3. Copy the markdown files, `index.json`, and `docs/_images/` into `force-app/main/default/staticresources/MarkdownDemo/docs/`. Leave the OpenAPI spec and the Postman collection out.
4. Deploy the `MarkdownDemo` static resource to the Eficode GoLive sandbox unless the user asked not to deploy.

The component looks for `index.json` at the resource root and under `docs/`. This package uses `docs/`.

The viewer is opened from the **Documentation** tab. That tab points at the `Documentation_Viewer` app page, which hosts `fbMarkdownViewer`. The `Documentation` app and the `Documentation_Access` permission set make the tab visible. UI strings in the Lightning components are English.

---

## Markdown rendering in the LWC

The viewer is:

- `force-app/main/default/lwc/fbMarkdownViewer/fbMarkdownViewer.js`
- `force-app/main/default/lwc/fbMarkdownViewer/markdownParser.js`

Supported:

- headings `#`, `##`, `###`
- paragraphs
- bullet lists with `-` or `*` and ordered lists, including nested lists
- blockquotes
- tables with a header separator row
- fenced code blocks, highlighted through `HighlightJsLib`
- fenced `mermaid` blocks, rendered through `MermaidLib`
- a standalone image whose URL ends in `.mmd`, rendered as a Mermaid diagram
- other standalone images
- inline code, bold, italic, and links

Verified limits:

- headings deeper than `###` are not headings
- this is not full GitHub-flavored markdown
- do not rely on raw HTML
- a markdown construct that has not been checked in the viewer may not render

Practical consequence:

- write pages that render in this viewer, not only in a desktop markdown preview
- prefer short paragraphs, lists, and tables over layout that only a full markdown engine understands

If a page looks right as a raw file and wrong in the viewer, simplify it.

If you change the viewer or the parser:

- update the Jest tests
- state which markdown features are now supported

---

## Links in the documentation

Use relative links between pages, for example `Quote_And_Invoice_Import.md`.

Use a heading hash to jump inside a page, for example `#product-mapping`, or `Quote_And_Invoice_Import.md#product-mapping` to open another page at a heading. The viewer scrolls to that heading. It does not download the link.

The heading id is the heading text in lower case, with punctuation removed and spaces turned into hyphens. Punctuation that sits between words leaves a double hyphen, as in `commerce-api-invoice-line--opportunity-product`.

Do not use absolute filesystem links. They break when the repo is cloned on another computer, and the viewer cannot follow them.

External `http`, `https`, `mailto`, and `tel` links open as normal links.

If you change the link style, do it consistently. Do not leave half the pages relative and half absolute without saying so.

---

## Mermaid diagrams

Diagrams in this repo belong in the markdown as fenced `mermaid` blocks. The viewer renders them in Salesforce from `MermaidLib`. You do not need a separate `.png` for the in-org page.

If a diagram is stored as a `.mmd` file and included as an image, the viewer can render that too. That is not the pattern used by the current Eficode pages.

Keep labels short. A crowded diagram is harder to read in the viewer than two smaller ones.

Do not plan on custom Mermaid icons unless the user has verified that they render here.

---

## Documentation workflow

When you receive a documentation task:

1. Understand what the user wants the page to help with.
2. Find the relevant code and metadata.
3. Collect facts that the repo, or a stated org query, can verify.
4. Write or update the page.
5. Update `docs/README.md` when the reading order changes.
6. Update `docs/index.json`.
7. Copy the changed markdown and `index.json` into `staticresources/MarkdownDemo/docs/` when the user wants the org updated.
8. Check that the new page is linked from the portal and the menu.
9. Summarize what changed, what was verified, and what is still unclear.

For a central process, describe both the business flow and the technical flow. Name the entry points, the objects, the integrations, and the failure handling when those exist.

---

## What is worth documenting

Prefer, in this order:

- the behavior a user or operator actually hits
- the exact trigger conditions in the code
- integrations and named credentials
- auth and the security model
- the data model for the central objects
- operational runbooks
- deploy and release notes when the user asks for them

When the overview pages already exist, the next useful work is a deeper page: field-level mapping, which flow or trigger or class owns a step, or the difference between an active path and an obsolete one.

Do not duplicate an existing page. Link to it.

Create a new page when:

- the content is too large for the current page
- the subject is genuinely new
- a separate page makes the menu easier to use

---

## Current documentation

These pages already exist. Extend them instead of writing a near-duplicate:

- `docs/README.md`
- `docs/Atlassian_PPC_Overview.md`
- `docs/Invoice_Groups.md`
- `docs/Quote_And_Invoice_Import.md`
- `docs/Monthly_Invoice_Auto_Import.md`
- `docs/Currency_Rates.md`
- `docs/Default_Opportunity_Owner.md`
- `docs/Promotion_Codes.md`
- `docs/PPC_Credential_Health.md`
- `docs/Quote_And_Invoice_PDF_Preview.md`
- `docs/Atlassian_Deal_Registration.md`
- `docs/Make_Webhooks.md`
- `docs/MEDDPICC.md`
- `docs/Opportunity_Product_Editor.md`
- `docs/Opportunity_Splits.md`
- `docs/Tier_Calculation.md`
- `docs/Docs_Viewer.md`

---

## When the user says "continue the documentation"

Do not:

- start writing generic pages without reading the repo
- rewrite large parts of an existing page without a reason
- add a page without updating the portal and the index
- claim that a flow or an integration behaves a certain way without a source

Do this instead:

- map what is already in `docs/`
- find the next gap that would help a reader
- make the smallest change that closes that gap
- keep the page inside the current `docs/` structure

---

## Salesforce requirements still apply

Even when the task is documentation, think as a senior Salesforce developer.

Documentation of code and metadata should account for:

- the sharing model
- CRUD and field-level security
- guest access
- external users
- named credentials and external credentials
- batch size and governor limits
- recursion
- event-driven integration patterns
- deploy and metadata dependencies

When you describe Apex, triggers, flows, or integrations:

- be explicit about security assumptions
- name risks early
- describe batch and async behavior as the code does it
- do not tidy up a design that is actually complicated

---

## Code changes versus documentation changes

If the user asked for documentation:

- do not change business code unless they asked for that
- keep the change to the pages, the index, the static-resource copy, and the viewer when the viewer is part of the task

If you must change the viewer:

- keep the change small
- read the parser, the viewer, and the tests first
- update the tests

If you must change other code so the viewer can work:

- say why
- call out the deploy impact
- update `docs/Docs_Viewer.md` when the publish steps change

---

## Testing

If the task is only markdown, the index, or the static-resource copy:

- Apex tests are not normally required
- say that no tests were run if you did not run any

If the task changes the viewer or the parser:

- update or add Jest tests
- check rendering and error handling

If you cannot run the tests, say exactly what should be run.

---

## How to report the work

Be concrete. Say what changed, which files were touched, whether the static resource was updated, whether anything was deployed, and whether tests were run.

When a documentation change is done, summarize:

- new or updated pages
- whether `docs/index.json` changed
- whether `MarkdownDemo` was updated
- remaining gaps

---

## Safe-change policy

Unless the user says otherwise:

- do not delete a page without saying so
- do not rename a page without updating every reference, including `docs/index.json` and `MarkdownDemo`
- do not break `docs/index.json`
- do not change code or metadata outside the documentation area unless the task needs it
- do not deploy unless the user asks

---

## Definition of done

A documentation change is done when:

- the content is specific to this repo and useful to a technical reader
- facts and assumptions are separate
- the page is in `docs/`
- `docs/README.md` was updated if the reading order changed
- `docs/index.json` was updated if the menu changed
- the markdown and `index.json` were copied into `staticresources/MarkdownDemo/docs/` when the org should show them
- the page stays within what the viewer can render
- viewer or parser test needs are called out
- remaining uncertainties are stated plainly

---

## Short checklist

1. Read `docs/AGENTS.md`, `README.md`, `docs/README.md`, `docs/index.json`, and `docs/Docs_Viewer.md`.
2. See which pages already exist.
3. Find the next gap that is worth writing.
4. Read the matching code and metadata before writing.
5. Write in English unless asked otherwise.
6. Keep facts and assumptions separate.
7. Update `docs/index.json`.
8. Use relative `.md` links and heading hashes.
9. Respect the viewer's markdown limits.
10. Copy the tree into `MarkdownDemo` when the pages should be published.
11. Summarize what changed and what is still missing.
