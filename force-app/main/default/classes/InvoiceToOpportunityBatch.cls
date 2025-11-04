/**
 * Created by peterfriberg on 2025-05-09.
 */

public with sharing class InvoiceToOpportunityBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    static public final Integer PAGE_SIZE = 1;
    static public final String DEFAULT_QUERY = 'SELECT Id, Name, Account__c, Opportunity__c, Error__c, Invoice_JSON__c, Invoice_JSON_2__c, Invoice_JSON_3__c, Invoice_JSON_4__c, Invoice_JSON_5__c, RetryCount__c, Status__c, Subsidiary__c FROM PendingInvoice__c WHERE Status__c = \'Waiting\' ';
    static public final PPC_InvoiceAutoImportSettings__c SETTING = PPC_InvoiceAutoImportSettings__c.getInstance();

    @TestVisible private String query;

    public InvoiceToOpportunityBatch() {
        this.query = DEFAULT_QUERY;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(this.query);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<PendingInvoice__c> pendingInvoices = scope;
        for (PendingInvoice__c pendingInvoice : pendingInvoices) {
            System.debug('Processing pending invoice with record ID: ' + pendingInvoice.Id + ' and name: ' + pendingInvoice.Name);
            PortalCommerceApiInvoices.InvoiceInfo invoice = processInvoice(pendingInvoice);
            convertInvoiceToOpportunity(invoice, pendingInvoice);
        }
        System.debug('### Processed ' + pendingInvoices.size() + ' pending invoices.');
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('### FINISH');

        if (SETTING != null && SETTING.DeletePendingInvoices__c) {
            Integer daysToKeepDoneInvoices = (SETTING != null) ? Integer.valueOf(SETTING.DaysToKeepPendingInvoices__c) : 0;
            Datetime oldDate = System.now().addDays(-daysToKeepDoneInvoices);
            delete new List<PendingInvoice__c>([
                SELECT Id
                FROM PendingInvoice__c
                WHERE Status__c = 'Done'
                AND CreatedDate < :oldDate
            ]);
        }
    }

    @TestVisible
    private static void convertInvoiceToOpportunity(PortalCommerceApiInvoices.InvoiceInfo invoice, PendingInvoice__c pendingInvoice) {
        System.debug('Converting invoice to opportunity');
        try {
            // Logic to convert invoice to opportunity
            Opportunity oppty = PortalQuoteConverter.getOpportunity(pendingInvoice.Opportunity__c);
            PpcOpportunityProductMapper mapper = PpcOpportunityProductMapper.getInstance();
            System.debug('### Mapping opportunity line items');
            List<OpportunityLineItem> items = mapper.mapProducts(invoice, oppty, (Double) 1.0, new OpportunityProductMapper.LogData(), true);
            pendingInvoice.TotalLineItems__c = items.size();
            pendingInvoice.LineItemsInserted__c = 0;
            pendingInvoice.Status__c = 'Processing';
            update pendingInvoice;

            OpportunityData data = new OpportunityData(oppty.Id, 'Closing', items, pendingInvoice.Id);
            System.enqueueJob(new ProcessOpportunityLinesQueueable(data));

            // This is a placeholder for the actual conversion logic
            System.debug('Invoice converted to opportunity successfully: ' + invoice.invoiceNumber);
        } catch (Exception ex) {
            System.debug('Error converting invoice to opportunity: ' + ex.getMessage());
            pendingInvoice.Error__c = 'Error converting invoice to opportunity: ' + ex.getMessage();
            pendingInvoice.Status__c = 'Error';
            pendingInvoice.RetryCount__c += 1;
            update pendingInvoice;
        }
    }

    @TestVisible
    private static PortalCommerceApiInvoices.InvoiceInfo processInvoice(PendingInvoice__c pendingInvoice) {
        System.debug('Reading invoice from JSON');

        String completeJsonString = '';

        // Add the first part (always present if any data was stored)
        if (pendingInvoice.Invoice_JSON__c != null) {
            completeJsonString += pendingInvoice.Invoice_JSON__c;
        }

        // Add the second part if it exists
        if (String.isNotEmpty(pendingInvoice.Invoice_JSON_2__c)) {
            completeJsonString += pendingInvoice.Invoice_JSON_2__c;
        }

        // Add the third part if it exists
        if (String.isNotEmpty(pendingInvoice.Invoice_JSON_3__c)) {
            completeJsonString += pendingInvoice.Invoice_JSON_3__c;
        }

        // Add the third part if it exists
        if (String.isNotEmpty(pendingInvoice.Invoice_JSON_4__c)) {
            completeJsonString += pendingInvoice.Invoice_JSON_4__c;
        }

        // Add the third part if it exists
        if (String.isNotEmpty(pendingInvoice.Invoice_JSON_5__c)) {
            completeJsonString += pendingInvoice.Invoice_JSON_5__c;
        }

        PortalCommerceApiInvoices.InvoiceInfo invoice;
        try {
            invoice = (PortalCommerceApiInvoices.InvoiceInfo) JSON.deserialize(
                completeJsonString,
                PortalCommerceApiInvoices.InvoiceInfo.class);
            System.debug('Invoice deserialized successfully: ' + invoice.invoiceNumber);
            // Perform actions with the invoice object

            Map<String, PortalCommerceApiEntitlements.EntitlementPartnerInfo> partnerInfosMap = getEntitlementPartnerInfo(invoice);

            for (PortalCommerceApiInvoices.InvoiceItem item : invoice.items) {
                String entitlementId = item.entitlementId;
                if (entitlementId != null && partnerInfosMap.containsKey(entitlementId)) {
                    PortalCommerceApiEntitlements.EntitlementPartnerInfo entitlementPartnerInfo = partnerInfosMap.get(entitlementId);
                    System.debug('Entitlement display info retrieved: ' + entitlementPartnerInfo);
                    // Perform actions with the entitlementPartnerInfo object
                    item.entName = entitlementPartnerInfo.provisionedResource.name;
                    System.debug('*** Entitlement name set: ' + item.entName);
                } else {
                    System.debug('No entitlement display info found for entitlement ID: ' + entitlementId);
                }
            }
        }
        catch (Exception ex) {
            System.debug('Error processing invoice: ' + ex.getMessage());
            pendingInvoice.Error__c = 'Error processing invoice: ' + ex.getMessage();
            pendingInvoice.Status__c = 'Error';
            pendingInvoice.RetryCount__c += 1;
        }

        return invoice;
    }

    @TestVisible
    private static Map<String, PortalCommerceApiEntitlements.EntitlementPartnerInfo> getEntitlementPartnerInfo(PortalCommerceApiInvoices.InvoiceInfo invoice){
        System.debug('Getting entitlement display info');

        Map<String, PortalCommerceApiEntitlements.EntitlementPartnerInfo> partnerInfosMap = new Map<String, PortalCommerceApiEntitlements.EntitlementPartnerInfo>();

        Set<String> entitlementIds = new Set<String>();
        for (PortalCommerceApiInvoices.InvoiceItem lineItem : invoice.items) {
            String entitlementId = lineItem.entitlementId;
            if (entitlementId != null) {
                entitlementIds.add(entitlementId);
            }
        }

        for (String entitlementId : entitlementIds) {
            PortalCommerceApiEntitlements.EntitlementPartnerInfo entitlementPartnerInfo = PortalCommerceApiEntitlements.getEntitlementPartnerInfoStatic(invoice.office, entitlementId);
            if (entitlementPartnerInfo != null) {
                partnerInfosMap.put(entitlementId, entitlementPartnerInfo);
                System.debug('Entitlement display info retrieved: ' + entitlementPartnerInfo);
            } else {
                System.debug('No entitlement display info found for entitlement ID: ' + entitlementId);
            }
        }

        return partnerInfosMap;
    }
}