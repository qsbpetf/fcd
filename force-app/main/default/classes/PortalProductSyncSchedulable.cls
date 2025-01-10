/**
 * Created by peterfriberg on 2024-12-09.
 */

public with sharing class PortalProductSyncSchedulable implements Schedulable {

    public void execute(SchedulableContext context) {
        System.debug('### PortalProductSyncSchedulable.execute()');
        System.enqueueJob(new PortalProductSyncQueueable());
    }
}