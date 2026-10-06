/**
 * Step 2: Deletes only EmailMessage records whose archive copy has been VERIFIED,
 * and permanently removes them from the Recycle Bin.
 */
public without sharing class EmailDeleteBatch implements Database.Batchable<SObject>, Database.Stateful {

    private final Datetime cutoff;
    private final Integer archivedCount;
    private final Integer archiveErrors;
    private Integer deleted = 0;
    private Integer skipped = 0;
    private Integer failed = 0;

    public EmailDeleteBatch(Datetime cutoff) {
        this(cutoff, null, null);
    }

    public EmailDeleteBatch(Datetime cutoff, Integer archivedCount, Integer archiveErrors) {
        this.cutoff = cutoff;
        this.archivedCount = archivedCount;
        this.archiveErrors = archiveErrors;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM EmailMessage
            WHERE MessageDate < :cutoff
               OR (MessageDate = null AND CreatedDate < :cutoff)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<EmailMessage> scope) {
        Set<String> ids = new Set<String>();
        for (EmailMessage em : scope) {
            ids.add(String.valueOf(em.Id));
        }
        Set<String> archived = EmailArchiveService.findArchived(ids);

        List<EmailMessage> toDelete = new List<EmailMessage>();
        for (EmailMessage em : scope) {
            if (archived.contains(String.valueOf(em.Id))) {
                toDelete.add(em);
            } else {
                skipped++; // Never delete a record that isn't archived
            }
        }
        if (toDelete.isEmpty()) {
            return;
        }

        List<Id> deletedIds = new List<Id>();
        for (Database.DeleteResult dr : Database.delete(toDelete, false)) {
            if (dr.isSuccess()) {
                deletedIds.add(dr.getId());
            } else {
                failed++;
                System.debug(LoggingLevel.ERROR, 'Delete error: ' + dr.getErrors());
            }
        }
        deleted += deletedIds.size();

        if (!deletedIds.isEmpty()) {
            Database.emptyRecycleBin(deletedIds);
        }
    }

    public void finish(Database.BatchableContext bc) {
        String body =
            'EmailMessage archive/delete summary\n\n' +
            'Cutoff date: ' + cutoff.format() + '\n' +
            'Archived: ' + (archivedCount == null ? '-' : String.valueOf(archivedCount)) + '\n' +
            'Archive errors: ' + (archiveErrors == null ? '-' : String.valueOf(archiveErrors)) + '\n' +
            'Deleted: ' + deleted + '\n' +
            'Skipped (not found in archive): ' + skipped + '\n' +
            'Delete errors: ' + failed;
        System.debug(body);

        AsyncApexJob job = [SELECT CreatedBy.Email FROM AsyncApexJob WHERE Id = :bc.getJobId()];
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ job.CreatedBy.Email });
        mail.setSubject('EmailMessage cleanup summary');
        mail.setPlainTextBody(body);
        mail.setSaveAsActivity(false);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
    }
}