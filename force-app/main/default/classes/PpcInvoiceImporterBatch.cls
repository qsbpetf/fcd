/**
 * Created by peterfriberg on 2025-03-04.
 */

public with sharing class PpcInvoiceImporterBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    static public final Integer DEFAULT_N_DAYS = 5;
    static public final Integer PAGE_SIZE = 1;
    static public final String DEFAULT_QUERY = 'SELECT Id, Name, Special_Instructions_to_Accounts__c, Payment_Terms_Licenses__c, Payment_terms__c FROM Account WHERE AutoInvoiceImport__c = TRUE';
    static public final PPC_InvoiceAutoImportSettings__c SETTING = PPC_InvoiceAutoImportSettings__c.getInstance();

    private Map<Id, Account> accountMap;
    @TestVisible private Integer lastNDays;
    @TestVisible private String query;

    public PpcInvoiceImporterBatch() {
        this.query = DEFAULT_QUERY;
        if (SETTING != null) {
            this.lastNDays = Integer.valueOf(SETTING.LastDays__c);
            System.debug('### Using lastNDays from SETTING = ' + this.lastNDays);
            if (!SETTING.AutomationEnabled__c) {
                this.query += ' LIMIT 0';
            }
        }
        if (this.lastNDays == null) {
            this.lastNDays = DEFAULT_N_DAYS;
        }
        System.debug('### Using lastNDays = ' + this.lastNDays);
    }

    public static String run() {
        if (jobIsExecuting(PpcInvoiceImporterBatch.class.toString()) ||
            jobIsExecuting(InvoiceToOpportunityBatch.class.toString())) {
            System.debug('### Job is already executing, skipping this run');
            return null;
        }
        return Database.executeBatch(new PpcInvoiceImporterBatch(), PAGE_SIZE);
    }

    public static String run(Integer daysBack) {
        if (jobIsExecuting(PpcInvoiceImporterBatch.class.toString()) ||
            jobIsExecuting(InvoiceToOpportunityBatch.class.toString())) {
            System.debug('### Job is already executing, skipping this run');
            return null;
        }
        PpcInvoiceImporterBatch batch = new PpcInvoiceImporterBatch();
        batch.lastNDays = daysBack;
        System.debug('### Starting job with days back = ' + daysBack);

        return Database.executeBatch(batch, PAGE_SIZE);
    }

    public void execute(SchedulableContext sc) {
        run();
    }

    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(this.query);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>> invoicesToImportByAccount = new Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>>();
        this.accountMap = new Map<Id, Account>();
        Integer totalInvoices = 0;

        for (SObject record : scope) {
            Account account = (Account) record;
            this.accountMap.put(account.Id, account);
            invoicesToImportByAccount.put(account.Id, new List<PortalCommerceApiInvoices.InvoiceInfo>());
            System.debug('### Importing invoices for account: ' + account.Name);
            List<PortalCommerceApiInvoices.InvoiceList> invoices = PortalCommerceApiController.getPaidInvoices(account.Id);
            System.debug('### Retrieved ' + invoices.size() + ' batch(es) of invoices');

            for (PortalCommerceApiInvoices.InvoiceList invoiceBatch : invoices) {
                System.debug('  ### Got ' + invoiceBatch.data.size() + ' invoices in batch');

                for (PortalCommerceApiInvoices.InvoiceInfo invoice : invoiceBatch.data) {
                    if (invoiceWithinTimespan(invoice)) {
                        invoicesToImportByAccount.get(account.Id).add(invoice);
                        totalInvoices++;
                    }
                }
            }
        }

        System.debug('### FOUND ' + totalInvoices + ' invoice(s) for potential import');

        Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>> invoicesToImport = filterInvoices(invoicesToImportByAccount);
        importInvoices(invoicesToImport);
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('### FINISH');
        // start nex adjacent batch job.
        if (!Test.isRunningTest()) {
            Database.executeBatch(new InvoiceToOpportunityBatch(), InvoiceToOpportunityBatch.PAGE_SIZE);
        }
    }

    @TestVisible
    private Boolean invoiceWithinTimespan(PortalCommerceApiInvoices.InvoiceInfo invoice) {
        // Create a DateTime object from the milliseconds
        Datetime createdAtDateTime = Datetime.newInstance(invoice.createdAt);

        // If you need just the Date part
        Date createdAtDate = createdAtDateTime.date();
        return createdAtDate.daysBetween(Date.today()) <= lastNDays;
    }

    @TestVisible
    private static Boolean invoiceIsCardMonthly(PortalCommerceApiInvoices.InvoiceInfo invoice) {
        Boolean isCard = invoice?.paymentMethodObj?.type == 'CARD';
        Boolean isMonthly = false;

        for (PortalCommerceApiInvoices.InvoiceItem lineItem : invoice.items) {
            if (lineItem?.planObj?.cycle?.interval == 'MONTHLY') {
                isMonthly = true;
                break;
            }
        }
        return isCard && isMonthly;
    }

    @TestVisible
    private static Map<Id, Map<String, Opportunity>> getMonthlyCardInvoiceOpportunitiesByInvoiceNumber(Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>> invoicesByAccount) {
        Set<String> invoiceNumbers = new Set<String>();
        for (List<PortalCommerceApiInvoices.InvoiceInfo> invoices : invoicesByAccount.values()) {
            for (PortalCommerceApiInvoices.InvoiceInfo invoice : invoices) {
                invoiceNumbers.add(invoice.invoiceNumber);
            }
        }

        Map<Id, Map<String, Opportunity>> opportunitiesByAccount = new Map<Id, Map<String, Opportunity>>();
        for (Opportunity opportunity : [
            SELECT Id, Name, AccountId, ImportedInvoiceNumber__c
            FROM Opportunity
            WHERE AccountId IN :invoicesByAccount.keySet()
            AND ImportedInvoiceNumber__c IN :invoiceNumbers
        ]) {
            if (!opportunitiesByAccount.containsKey(opportunity.AccountId)) {
                opportunitiesByAccount.put(opportunity.AccountId, new Map<String, Opportunity>());
            }
            opportunitiesByAccount.get(opportunity.AccountId).put(opportunity.ImportedInvoiceNumber__c, opportunity);
        }

        System.debug('OPPTYS-BY-ACCOUNT: ' + opportunitiesByAccount);

        return opportunitiesByAccount;
    }

    @TestVisible
    private static Boolean invoiceAlreadyImported(
        Id accountId,
        PortalCommerceApiInvoices.InvoiceInfo invoice,
        Map<Id, Map<String, Opportunity>> opportunitiesByInvoiceNumber)
    {
        return opportunitiesByInvoiceNumber.containsKey(accountId) &&
            opportunitiesByInvoiceNumber.get(accountId).containsKey(invoice.invoiceNumber);
    }

    @TestVisible
    private Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>> filterInvoices(Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>> invoicesByAccount) {
        Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>> invoicesToImport = new Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>>();
        Map<Id, Map<String, Opportunity>> opportunitiesByInvoiceNumber = getMonthlyCardInvoiceOpportunitiesByInvoiceNumber(invoicesByAccount);

        for (Id accountId : invoicesByAccount.keySet()) {
            invoicesToImport.put(accountId, new List<PortalCommerceApiInvoices.InvoiceInfo>());
            List<PortalCommerceApiInvoices.InvoiceInfo> invoices = invoicesByAccount.get(accountId);
            System.debug('### Identified ' + invoices.size() + ' invoice(s) for account: ' + this.accountMap.get(accountId).Name);

            for (PortalCommerceApiInvoices.InvoiceInfo invoice : invoices) {
                if (invoiceIsCardMonthly(invoice) && !invoiceAlreadyImported(accountId, invoice, opportunitiesByInvoiceNumber)) {
                    invoicesToImport.get(accountId).add(invoice);
                }
            }

            System.debug('### Found ' + invoicesToImport.get(accountId).size() + ' monthly card invoice(s) to import for account ' + this.accountMap.get(accountId).Name);
        }

        return invoicesToImport;
    }

    @TestVisible
    private Opportunity createOpportunity(Id accountId, PortalCommerceApiInvoices.InvoiceInfo invoice) {
        Datetime createdAtDateTime = Datetime.newInstance(invoice.createdAt);
        Date createdAtDate = Date.newInstance(
            createdAtDateTime.year(),
            createdAtDateTime.month(),
            createdAtDateTime.day()
        );

        Account acc = this.accountMap.get(accountId);
        String paymentTerms = String.isNotBlank(acc.Payment_Terms_Licenses__c) ? acc.Payment_Terms_Licenses__c : acc.Payment_terms__c;

        Opportunity oppty = new Opportunity();
        oppty.AccountId = accountId;
        oppty.Name = this.accountMap.get(accountId).Name.abbreviate(70) + ' - Monthly - ' + invoice.invoiceNumber;
        oppty.CloseDate = createdAtDate;
        oppty.StageName = 'Explore';
        oppty.LeadSource = 'Renewal';
        oppty.ImportedInvoiceNumber__c = invoice.invoiceNumber;
        oppty.Special_Instructions_to_Accounts__c = acc.Special_Instructions_to_Accounts__c;
        oppty.Atlassian_AT_Quote_ref__c = invoice.invoiceNumber;
        oppty.Type = 'Customer_Opp';
        oppty.Payment_Terms__c = paymentTerms;
        oppty.Monthly_Cloud_Opp__c = true;
        return oppty;
    }

    @TestVisible
    private void importInvoices(Map<Id, List<PortalCommerceApiInvoices.InvoiceInfo>> invoicesByAccount) {
        List<InvoiceData> invoiceDataList = new List<InvoiceData>();
        List<Opportunity> newOpptys = new List<Opportunity>();

        for (Id accountId : invoicesByAccount.keySet()) {
            List<PortalCommerceApiInvoices.InvoiceInfo> invoices = invoicesByAccount.get(accountId);
            System.debug('### Importing ' + invoices.size() + ' invoice(s) for account: ' + this.accountMap.get(accountId).Name);

            for (PortalCommerceApiInvoices.InvoiceInfo invoice : invoices) {
                System.debug('  ### Importing invoice: ' + invoice.invoiceNumber);
                Opportunity oppty = createOpportunity(accountId, invoice);
                invoiceDataList.add(new InvoiceData(invoice, oppty, this.accountMap.get(accountId)));
                newOpptys.add(oppty);
            }
        }

        System.debug('Opptys to create (' + newOpptys.size() + ') : ' + newOpptys);
        insert newOpptys;
        System.debug('Created opportunities: ' + newOpptys);

        Map<Id, Opportunity> opptyMap = new Map<Id, Opportunity>([
            SELECT Id, AccountId, Name, ImportedInvoiceNumber__c, Pricebook2Id, StageName, CloseDate, LeadSource, CurrencyIsoCode, Pricebook2.Name
            FROM Opportunity
            WHERE Id IN :newOpptys
        ]);

        System.debug('InvoiceDataList: ' + invoiceDataList);

        List<OpportunityLineItem> allItems = new List<OpportunityLineItem>();
        List<PendingInvoice__c> pendingInvoices = new List<PendingInvoice__c>();

        for (InvoiceData invoiceData : invoiceDataList) {
            System.debug('  ### Importing invoice: ' + invoiceData.invoice.invoiceNumber);
            Opportunity oppty = opptyMap.get(invoiceData.oppty.Id);
            PortalCommerceApiInvoices.InvoiceInfo invoice = invoiceData.invoice;
            PpcOpportunityProductMapper mapper = PpcOpportunityProductMapper.getInstance();

            List<OpportunityLineItem> items = mapper.mapProducts(invoice, oppty, (Double) 1.0, new OpportunityProductMapper.LogData(), true);
            allItems.addAll(items);

            System.debug('### Mapped ' + items.size() + ' products for invoice: ' + invoice.invoiceNumber);
            for (OpportunityLineItem item : items) {
                System.debug('  ### Product: ' + item);
            }

            PendingInvoice__c pendingInvoice = new PendingInvoice__c();
            pendingInvoice.Name = invoice.invoiceNumber;
            pendingInvoice.InvoiceId__c = invoice.id;
            pendingInvoice.Invoice_JSON__c = '';
            pendingInvoice.Invoice_JSON_2__c = '';
            pendingInvoice.Invoice_JSON_3__c = '';
            pendingInvoice.Invoice_JSON_4__c = '';
            pendingInvoice.Invoice_JSON_5__c = '';
            pendingInvoice.Status__c = 'Waiting';
            pendingInvoice.Error__c = null;
            pendingInvoice.RetryCount__c = 0;
            pendingInvoice.Account__c = invoiceData.acc.Id;
            pendingInvoice.Opportunity__c = oppty.Id;
            pendingInvoices.add(pendingInvoice);
        }

        System.debug('### Inserting ' + pendingInvoices.size() + ' Pending Invoice records');
        insert pendingInvoices;
    }

    private static Boolean jobIsExecuting(String apexClassName) {
        List<AsyncApexJob> apexJobs = new List<AsyncApexJob>([
            SELECT
                ApexClass.Name,
                Status
            FROM AsyncApexJob
            WHERE ApexClass.Name = :ApexClassName
            AND JobType = 'BatchApex'
            AND Status IN ('Queued', 'Preparing', 'Processing', 'Holding')
        ]);
        return (apexJobs.size() > 0);
    }

    public class InvoiceData {
        public PortalCommerceApiInvoices.InvoiceInfo invoice;
        public Opportunity oppty;
        public Account acc;

        public InvoiceData(PortalCommerceApiInvoices.InvoiceInfo invoice, Opportunity oppty, Account acc) {
            this.invoice = invoice;
            this.oppty = oppty;
            this.acc = acc;
        }
    }
}