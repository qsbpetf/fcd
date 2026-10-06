# Quote and invoice PDF preview

**Preview PDF** on the Commerce API quote importer, and the preview action on the Account invoice list, open a Visualforce page in a new browser tab. The page downloads the Atlassian PDF and embeds it. Salesforce does not store the file.

JSON quote upload has no preview button. The Opportunity invoice importer (`partnerPortalApiInvoiceImporter`) does not open this page. The Account invoice list does.

---

## Table of Contents

1. [Quote](#quote)
2. [Invoice](#invoice)
3. [What the page shows](#what-the-page-shows)

---

## Quote

On `partnerPortalApiQuoteImporter`, **Preview PDF** runs `handlePreview` after a quote has been fetched.

The new tab is `/apex/PreviewQuote?OFFICE={office}&QUOTE_ID={quoteId}`.

`office` is `quote.data[0].office`, the subsidiary already resolved for that fetch. `QUOTE_ID` is the quote id on the button (`data-id`).

`PreviewQuoteCtrl` requires both query parameters. It calls `PortalCommerceApiController.getQuotePdfStatic`, which calls `PortalCommerceApiQuotes.getQuotePdf`.

`PortalCommerceApiClient.getQuotePdf` sends:

`GET callout:Eficode_Office_{CODE}/commerce/api/v3/quotes/{quoteId}/download?transactionAccountId={uuid}`

The office code and the transaction-account UUID come from `PPC_TransactionAccount__mdt`, the same lookup as other Commerce API calls. The call still goes through `generateEndpoint`, so the running user needs custom permission `Eficode_Office_{CODE}`. See [Atlassian PPC overview](Atlassian_PPC_Overview.md).

HTTP 200 is base64-encoded and embedded. Any other status returns the response body as the error text. The page does not check that the body is a PDF.

---

## Invoice

On `partnerPortalApiInvoiceViewer` (Account), preview runs `handlePreview`.

The new tab is `/apex/PreviewInvoice?OFFICE={office}&INVOICE_ID={invoiceId}`.

`OFFICE` and `INVOICE_ID` come from `data-office` and `data-id` on that row.

`PreviewInvoiceCtrl` requires both parameters and calls `PortalCommerceApiController.getInvoicePdfStatic`, then `PortalCommerceApiInvoices.getInvoicePdf`.

`PortalCommerceApiClient.getInvoicePdf` sends:

`GET callout:Eficode_Office_{CODE}/commerce/api/v1/invoices/{invoiceId}/download?transactionAccountId={uuid}`

The same credential, permission, and 200-versus-body rules apply as for quotes.

When the invoice list truncates line items, the row text tells the user to use Preview for the full invoice. That preview is this PDF, not a longer JSON table.

---

## What the page shows

`PreviewQuote` and `PreviewInvoice` hide the Salesforce header and sidebar. `contenttype` is `application/pdf`. The page embeds `data:application/pdf;base64,{pdf}`.

Missing `OFFICE` or the id shows "Sorry for the inconvenience! Required parameters are missing." A thrown exception shows "Sorry for the inconvenience! Error when generating PDF from Atlassian PPC ." and the exception message under it. A non-200 response that does not throw is still passed to the embed as if it were base64, because only an exception sets `errorMessage`.
