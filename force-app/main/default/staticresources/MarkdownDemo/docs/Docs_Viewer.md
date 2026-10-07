# Docs viewer

`fbMarkdownViewer` shows these markdown pages inside Salesforce. It reads them from the static resource `MarkdownDemo`. The pages in `docs/` are the source. The static resource is the copy Salesforce serves.

`README.md` is the first page. The left-hand menu is `docs/index.json`. A page that is not listed there is not in the menu.

## Refresh the pages in Salesforce

1. Edit the markdown under `docs/`.
2. When you add, rename, or remove a page, update `docs/index.json` with the same `{ label, path }` and `{ label, children }` shape.
3. Copy the markdown files, `index.json`, and `docs/_images/` into `force-app/main/default/staticresources/MarkdownDemo/docs/`. Leave the OpenAPI spec and the Postman collection out of that folder. The viewer does not render them.
4. Deploy the `MarkdownDemo` static resource.

The component looks for `index.json` at the resource root and under `docs/`. This package keeps it under `docs/`.

Diagrams in `mermaid` fences use the `MermaidLib` static resource. Fenced code blocks use `HighlightJsLib`.

After deploy, open the **Documentation** tab. That tab is the app page `Documentation_Viewer`.
