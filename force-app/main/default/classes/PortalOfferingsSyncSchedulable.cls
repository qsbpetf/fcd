/**
 * Created by peterfriberg on 2025-01-08.
 */

public with sharing class PortalOfferingsSyncSchedulable implements Schedulable {

    public void execute(SchedulableContext context) {
        System.debug('### PortalOfferingsSyncBatch startBatch');
        PortalOfferingsSyncBatch.run();
    }
}