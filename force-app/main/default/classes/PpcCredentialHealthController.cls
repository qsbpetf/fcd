/**
 * AuraEnabled façade for the PPC credential health Home page LWC.
 */
public with sharing class PpcCredentialHealthController {

    private static final Integer STALE_AFTER_MINUTES = 45;

    @AuraEnabled
    public static List<StatusRow> getStatuses() {
        Map<String, String> subsidiaryLabels = getSubsidiaryLabels();
        List<StatusRow> rows = new List<StatusRow>();
        Datetime staleBefore = Datetime.now().addMinutes(-STALE_AFTER_MINUTES);

        for (PpcCredentialStatus__c rec : [
            SELECT
                Id, Name, NamedCredentialName__c, CV_Subsidiary__c, TransactionAccountId__c,
                Status__c, HttpStatusCode__c, LastChecked__c, LastSuccess__c, LastFailure__c,
                ErrorMessage__c, ConsecutiveFailures__c, ResponseTimeMs__c
            FROM PpcCredentialStatus__c
            ORDER BY NamedCredentialName__c
        ]) {
            StatusRow row = new StatusRow();
            row.id = rec.Id;
            row.name = rec.Name;
            row.namedCredentialName = rec.NamedCredentialName__c;
            row.subsidiary = rec.CV_Subsidiary__c;
            row.subsidiaryLabel = subsidiaryLabels.containsKey(rec.CV_Subsidiary__c)
                ? subsidiaryLabels.get(rec.CV_Subsidiary__c)
                : rec.CV_Subsidiary__c;
            row.transactionAccountId = rec.TransactionAccountId__c;
            row.status = rec.Status__c;
            row.httpStatusCode = rec.HttpStatusCode__c;
            row.lastChecked = rec.LastChecked__c;
            row.lastSuccess = rec.LastSuccess__c;
            row.lastFailure = rec.LastFailure__c;
            row.errorMessage = rec.ErrorMessage__c;
            row.consecutiveFailures = rec.ConsecutiveFailures__c;
            row.responseTimeMs = rec.ResponseTimeMs__c;
            row.isStale = rec.LastChecked__c == null || rec.LastChecked__c < staleBefore;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static String probeNow() {
        Id jobId = PpcCredentialHealthQueueable.enqueue();
        if (jobId == null) {
            throw new AuraHandledException('A PPC credential health check is already running.');
        }
        return jobId;
    }

    private static Map<String, String> getSubsidiaryLabels() {
        Map<String, String> labels = new Map<String, String>();
        for (Schema.PicklistEntry entry : PpcCredentialStatus__c.CV_Subsidiary__c.getDescribe().getPicklistValues()) {
            labels.put(entry.getValue(), entry.getLabel());
        }
        return labels;
    }

    public class StatusRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String namedCredentialName;
        @AuraEnabled public String subsidiary;
        @AuraEnabled public String subsidiaryLabel;
        @AuraEnabled public String transactionAccountId;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal httpStatusCode;
        @AuraEnabled public Datetime lastChecked;
        @AuraEnabled public Datetime lastSuccess;
        @AuraEnabled public Datetime lastFailure;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Decimal consecutiveFailures;
        @AuraEnabled public Decimal responseTimeMs;
        @AuraEnabled public Boolean isStale;
    }
}
