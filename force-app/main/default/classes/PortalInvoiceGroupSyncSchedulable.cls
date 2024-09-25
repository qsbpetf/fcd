/**
 * Created by peterfriberg on 2024-09-25.
 */

public with sharing class PortalInvoiceGroupSyncSchedulable implements Schedulable {

    public void execute(SchedulableContext context) {
        System.debug('### PortalInvoiceGroupSyncSchedulable.execute()');
        System.enqueueJob(new PortalInvoiceGroupSyncQueueable());
    }
}