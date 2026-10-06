/**
 * Step 1: Copies EmailMessage records older than the retention period (default 3 years)
 * into the Email_Message_Archive__b big object, then chains the delete batch.
 */
public without sharing class EmailArchiveBatch implements Database.Batchable<SObject>, Database.Stateful {

    private final Datetime cutoff;
    private Integer processed = 0;
    private Integer failed = 0;

    public EmailArchiveBatch() {
        this(3);
    }

    public EmailArchiveBatch(Integer retentionYears) {
        this.cutoff = Datetime.now().addYears(-retentionYears);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, MessageDate, CreatedDate, Subject, FromAddress, FromName,
                   ToAddress, CcAddress, BccAddress, TextBody,
                   ParentId, RelatedToId, ActivityId, Incoming, Status
            FROM EmailMessage
            WHERE MessageDate < :cutoff
               OR (MessageDate = null AND CreatedDate < :cutoff)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<EmailMessage> scope) {
        Datetime now = Datetime.now();
        List<Email_Message_Archive__b> rows = new List<Email_Message_Archive__b>();

        for (EmailMessage em : scope) {
            rows.add(new Email_Message_Archive__b(
                Email_Message_Id__c = String.valueOf(em.Id),
                Message_Date__c     = em.MessageDate != null ? em.MessageDate : em.CreatedDate,
                Subject__c          = em.Subject != null ? em.Subject.abbreviate(255) : null,
                From_Address__c     = em.FromAddress != null ? em.FromAddress.abbreviate(255) : null,
                From_Name__c        = em.FromName != null ? em.FromName.abbreviate(255) : null,
                To_Address__c       = em.ToAddress,
                Cc_Address__c       = em.CcAddress,
                Bcc_Address__c      = em.BccAddress,
                Text_Body__c        = em.TextBody,
                Parent_Id__c        = em.ParentId != null ? String.valueOf(em.ParentId) : null,
                Related_To_Id__c    = em.RelatedToId != null ? String.valueOf(em.RelatedToId) : null,
                Activity_Id__c      = em.ActivityId != null ? String.valueOf(em.ActivityId) : null,
                Incoming__c         = em.Incoming ? 1 : 0,
                Status__c           = em.Status,
                Archived_Date__c    = now
            ));
        }

        failed += EmailArchiveService.archive(rows);
        processed += scope.size();
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('EmailArchiveBatch finished. Processed: ' + processed + ', errors: ' + failed);
        // The delete batch skips any record that isn't archived, so chaining is always safe.
        if (!Test.isRunningTest()) {
            Database.executeBatch(new EmailDeleteBatch(cutoff, processed, failed), 200);
        }
    }
}