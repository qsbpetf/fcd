/**
 * Probes each Atlassian PPC named credential and upserts PpcCredentialStatus__c.
 * Runs as a Queueable so HTTP callouts are allowed. One job covers all offices.
 */
public without sharing class PpcCredentialHealthQueueable implements Queueable, Database.AllowsCallouts {

    @TestVisible static Boolean forceOverlap = false;

    public void execute(QueueableContext context) {
        probeAllOffices();
    }

    /**
     * Enqueues a probe unless another health-check Queueable is already running.
     *
     * @return Job Id, or null if skipped because a job is already executing
     */
    public static Id enqueue() {
        if (forceOverlap || jobIsExecuting()) {
            System.debug('### PpcCredentialHealthQueueable already executing, skipping this run');
            return null;
        }
        return System.enqueueJob(new PpcCredentialHealthQueueable());
    }

    public static void probeAllOffices() {
        Map<String, PPC_TransactionAccount__mdt> accountsByDevName = PPC_TransactionAccount__mdt.getAll();
        List<String> officeNames = new List<String>(accountsByDevName.keySet());
        officeNames.sort();

        Set<String> namedCredentialNames = new Set<String>();
        for (String officeName : officeNames) {
            namedCredentialNames.add(PortalCommerceApiAccessMgmt.getNamedCredentialDeveloperName(officeName));
        }

        Map<String, PpcCredentialStatus__c> existingByNamedCredential = new Map<String, PpcCredentialStatus__c>();
        for (PpcCredentialStatus__c rec : [
            SELECT
                Id, Name, NamedCredentialName__c, CV_Subsidiary__c, TransactionAccountId__c,
                Status__c, HttpStatusCode__c, LastChecked__c, LastSuccess__c, LastFailure__c,
                ErrorMessage__c, ConsecutiveFailures__c, ResponseTimeMs__c
            FROM PpcCredentialStatus__c
            WHERE NamedCredentialName__c IN :namedCredentialNames
        ]) {
            existingByNamedCredential.put(rec.NamedCredentialName__c, rec);
        }

        PortalCommerceApiClient client = PortalCommerceApiClient.getInstance();
        List<PpcCredentialStatus__c> toUpsert = new List<PpcCredentialStatus__c>();
        Datetime now = Datetime.now();

        for (String officeName : officeNames) {
            PPC_TransactionAccount__mdt item = accountsByDevName.get(officeName);
            PortalCommerceApiClient.ProbeResult result = client.probeOffice(officeName);
            String namedCredentialName = result.namedCredentialName != null
                ? result.namedCredentialName
                : PortalCommerceApiAccessMgmt.getNamedCredentialDeveloperName(officeName);

            PpcCredentialStatus__c rec = existingByNamedCredential.containsKey(namedCredentialName)
                ? existingByNamedCredential.get(namedCredentialName)
                : new PpcCredentialStatus__c(NamedCredentialName__c = namedCredentialName);

            rec.Name = namedCredentialName?.left(80);
            rec.NamedCredentialName__c = namedCredentialName;
            rec.CV_Subsidiary__c = item.SubsidiaryApiName__c;
            rec.TransactionAccountId__c = item.MasterLabel;
            rec.HttpStatusCode__c = result.statusCode;
            rec.LastChecked__c = now;
            rec.ResponseTimeMs__c = result.responseTimeMs;
            rec.Status__c = result.status;
            rec.ErrorMessage__c = result.errorMessage;

            if (result.status == PortalCommerceApiClient.STATUS_HEALTHY) {
                rec.LastSuccess__c = now;
                rec.ConsecutiveFailures__c = 0;
            } else {
                rec.LastFailure__c = now;
                Decimal previousFailures = rec.ConsecutiveFailures__c == null ? 0 : rec.ConsecutiveFailures__c;
                rec.ConsecutiveFailures__c = previousFailures + 1;
            }
            toUpsert.add(rec);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert NamedCredentialName__c;
        }
    }

    @TestVisible
    private static Boolean jobIsExecuting() {
        List<AsyncApexJob> apexJobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'PpcCredentialHealthQueueable'
            AND JobType = 'Queueable'
            AND Status IN ('Queued', 'Preparing', 'Processing', 'Holding')
        ];
        return !apexJobs.isEmpty();
    }
}
