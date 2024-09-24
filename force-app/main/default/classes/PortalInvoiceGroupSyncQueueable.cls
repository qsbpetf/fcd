/**
 * Created by peterfriberg on 2024-08-22.
 */

public class PortalInvoiceGroupSyncQueueable implements Queueable, Database.AllowsCallouts {

    private final static PortalCommerceApiInvoiceGroups invoiceGroups = PortalCommerceApiInvoiceGroups.getInstance();
    private final static Integer PAGE_SIZE = 50;
    @TestVisible private final String nextId = null;
    @TestVisible private final Integer currentOfficeIdx;
    private final static List<String> OFFICE_LIST = PortalCommerceApiAccessMgmt.getAllOffices();

    public PortalInvoiceGroupSyncQueueable() {
        this.currentOfficeIdx = 0;
    }

    public PortalInvoiceGroupSyncQueueable(Integer currentOfficeIdx) {
        this.currentOfficeIdx = currentOfficeIdx;
    }

    public PortalInvoiceGroupSyncQueueable(Integer currentOfficeIdx, String nextId) {
        this.nextId = nextId;
        this.currentOfficeIdx = currentOfficeIdx;
    }

    public void execute(QueueableContext context) {
        syncInvoiceGroups();
    }

    @TestVisible
    private void syncInvoiceGroups() {
        String office = OFFICE_LIST[this.currentOfficeIdx];
        System.debug('### Syncing office (' + this.currentOfficeIdx + '): ' + office + ' with nextId: ' + this.nextId);
        PortalCommerceApiInvoiceGroups.InvoiceGroupList invoiceGroupList = invoiceGroups.getInvoiceGroups(office, PAGE_SIZE, this.nextId);
        if (invoiceGroupList.error != null) {
            System.debug('Error fetching invoice groups for office: ' + office + '. Error: ' + invoiceGroupList.error);
            nextOffice();
            return;
        }

        Set<String> taxIds = new Set<String>();
        for (PortalCommerceApiInvoiceGroups.InvoiceGroupInfo invoiceGroup : invoiceGroupList.data) {
            System.debug('-- Syncing invoice group: ' + invoiceGroup.id + ' with taxId: ' + invoiceGroup?.shipToParty?.taxId);
//            if (invoiceGroup?.shipToParty?.taxId != null) {
//                taxIds.add(invoiceGroup.shipToParty.taxId);
//            }
        }

//        List<Account> accs = new List<Account>([
//            SELECT Id, Vat_Tax_ID__c
//            FROM Account
//            WHERE Vat_Tax_ID__c IN :taxIds]);
//
//        Map<String, Id> accountByVatId = new Map<String, Id>();
//        for (Account acc : accs) {
//            System.debug('++ Account: ' + acc.Id + ' has tax id: ' + acc.Vat_Tax_ID__c);
//            accountByVatId.put(acc.Vat_Tax_ID__c, acc.Id);
//        }

        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>();
        for (PortalCommerceApiInvoiceGroups.InvoiceGroupInfo invoiceGroup : invoiceGroupList.data) {
            InvoiceGroup__c invGroup = new InvoiceGroup__c();
            invGroup.Name = invoiceGroup.name;
            invGroup.AtlassianInvoiceGroupId__c = invoiceGroup.id;
            invGroup.Version__c = invoiceGroup.version;
            invGroup.CurrencyIsoCode = invoiceGroup.isoCurrency;
            invGroup.Active__c = invoiceGroup.active;
            invGroup.CreatedAt__c = (invoiceGroup.createdAt != null) ? Datetime.newInstance(invoiceGroup.createdAt).date() : null;
            invGroup.ShipToPartyVatTaxId__c = invoiceGroup?.shipToParty?.taxId;
            invGroup.ShipToPartyName__c = invoiceGroup?.shipToParty?.name;
            invGroup.LastSynchronized__c = Datetime.now();
            invGroup.CV_Subsidiary__c = office;
            invGroup.Slug__c = invoiceGroup.slug;
            invoiceGroups.add(invGroup);
        }

        System.debug('// Updating ' + invoiceGroups.size() + ' invoice groups');
        upsert invoiceGroups AtlassianInvoiceGroupId__c;

        if (invoiceGroupList.nextId != null) {
            nextSyncBatch(invoiceGroupList.nextId, office);
        } else if (this.currentOfficeIdx < OFFICE_LIST.size() - 1) {
            nextOffice();
        } else {
            System.debug('### All offices synced');
        }
    }

    @TestVisible
    private void nextSyncBatch(String nextId, String office) {
        System.debug('### Scheduling next sync with nextId: ' + nextId + ' for office ' + office);
        if (Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new PortalInvoiceGroupSyncQueueable(this.currentOfficeIdx, nextId));
    }

    @TestVisible
    private void nextOffice() {
        if (this.currentOfficeIdx < OFFICE_LIST.size() - 1) {
            String office = OFFICE_LIST[this.currentOfficeIdx + 1];
            System.debug('### Scheduling next sync with next office: ' + office);
            if (Test.isRunningTest()) {
                return;
            }
            System.enqueueJob(new PortalInvoiceGroupSyncQueueable(this.currentOfficeIdx + 1));
        }
    }
}