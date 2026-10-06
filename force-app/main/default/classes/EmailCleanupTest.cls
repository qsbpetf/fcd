@IsTest
private class EmailCleanupTest {

    private static EmailMessage buildEmail(String subject, Datetime messageDate) {
        return new EmailMessage(
            Subject     = subject,
            FromAddress = 'sender@example.com',
            FromName    = 'Sender',
            ToAddress   = 'receiver@example.com',
            CcAddress   = 'cc@example.com',
            TextBody    = 'Body of ' + subject,
            Status      = '3',
            Incoming    = false,
            MessageDate = messageDate
        );
    }

    @TestSetup
    static void setup() {
        insert new List<EmailMessage>{
            buildEmail('Old archived', Datetime.now().addYears(-4)),
            buildEmail('Old not archived', Datetime.now().addYears(-4)),
            buildEmail('Recent', Datetime.now().addMonths(-6))
        };
    }

    @IsTest
    static void archiveBatchDoesNotDeleteAnything() {
        Test.startTest();
        Database.executeBatch(new EmailArchiveBatch(), 200);
        Test.stopTest();

        Assert.areEqual(3, [SELECT COUNT() FROM EmailMessage], 'The archive step must not delete any records');
    }

    @IsTest
    static void deleteBatchDeletesOnlyArchivedOldRecords() {
        EmailMessage oldArchived = [SELECT Id FROM EmailMessage WHERE Subject = 'Old archived'];
        EmailArchiveService.mockArchivedIds = new Set<String>{ String.valueOf(oldArchived.Id) };

        Test.startTest();
        Database.executeBatch(new EmailDeleteBatch(Datetime.now().addYears(-3)), 200);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM EmailMessage WHERE Subject = 'Old archived'], 'Archived old record should be deleted');
        Assert.areEqual(1, [SELECT COUNT() FROM EmailMessage WHERE Subject = 'Old not archived'], 'Record not in archive must be kept');
        Assert.areEqual(1, [SELECT COUNT() FROM EmailMessage WHERE Subject = 'Recent'], 'Recent record must be kept');
    }

    @IsTest
    static void deleteBatchSkipsWhenNothingArchived() {
        Test.startTest();
        Database.executeBatch(new EmailDeleteBatch(Datetime.now().addYears(-3)), 200);
        Test.stopTest();

        Assert.areEqual(3, [SELECT COUNT() FROM EmailMessage], 'No record should be deleted when nothing is archived');
    }

    @IsTest
    static void archiveServiceWritesAndFinds() {
        EmailMessage em = [SELECT Id FROM EmailMessage WHERE Subject = 'Recent'];
        String emId = String.valueOf(em.Id);

        Integer errors = EmailArchiveService.archive(new List<Email_Message_Archive__b>{
            new Email_Message_Archive__b(Email_Message_Id__c = emId)
        });

        Assert.areEqual(0, errors);
        Assert.isTrue(EmailArchiveService.findArchived(new Set<String>{ emId }).contains(emId));
        Assert.isFalse(EmailArchiveService.findArchived(new Set<String>{ 'notArchived' }).contains('notArchived'));
        Assert.areEqual(0, EmailArchiveService.archive(new List<Email_Message_Archive__b>()));
        Assert.isTrue(EmailArchiveService.findArchived(new Set<String>()).isEmpty());
    }

    @IsTest
    static void countErrorsCountsFailures() {
        Database.SaveResult ok = (Database.SaveResult) JSON.deserialize(
            '{"success":true}', Database.SaveResult.class);
        Database.SaveResult bad = (Database.SaveResult) JSON.deserialize(
            '{"success":false,"errors":[{"message":"Test error","statusCode":"UNKNOWN_EXCEPTION"}]}',
            Database.SaveResult.class);

        Assert.areEqual(1, EmailArchiveService.countErrors(new List<Database.SaveResult>{ ok, bad }));
    }

    @IsTest
    static void schedulerRegistersJob() {
        Test.startTest();
        String jobId = System.schedule('EmailCleanup Test', '0 0 2 ? * SUN', new EmailCleanupScheduler());
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM CronTrigger WHERE Id = :jobId]);
    }
}