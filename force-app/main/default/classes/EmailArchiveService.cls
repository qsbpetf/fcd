/**
 * Single access point for the Email_Message_Archive__b big object.
 * Big objects don't support test isolation, so only the actual write/read calls
 * run outside of tests; all remaining logic is covered by unit tests.
 */
public without sharing class EmailArchiveService {

    @TestVisible
    private static Set<String> mockArchivedIds;

    /** Writes rows to the big object and returns the number of failures. Re-writing the same Id overwrites the existing row. */
    public static Integer archive(List<Email_Message_Archive__b> rows) {
        if (rows == null || rows.isEmpty()) {
            return 0;
        }
        return countErrors(writeRows(rows));
    }

    /** Returns the subset of the given EmailMessage Ids that exist in the archive. */
    public static Set<String> findArchived(Set<String> emailIds) {
        Set<String> result = new Set<String>();
        if (emailIds == null || emailIds.isEmpty()) {
            return result;
        }
        for (String archivedId : readArchivedIds(emailIds)) {
            if (emailIds.contains(archivedId)) {
                result.add(archivedId);
            }
        }
        return result;
    }

    @TestVisible
    private static Integer countErrors(List<Database.SaveResult> results) {
        Integer errors = 0;
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                errors++;
                System.debug(LoggingLevel.ERROR, 'Archive error: ' + sr.getErrors());
            }
        }
        return errors;
    }

    private static List<Database.SaveResult> writeRows(List<Email_Message_Archive__b> rows) {
        if (Test.isRunningTest()) {
            if (mockArchivedIds == null) {
                mockArchivedIds = new Set<String>();
            }
            for (Email_Message_Archive__b r : rows) {
                mockArchivedIds.add(r.Email_Message_Id__c);
            }
            return new List<Database.SaveResult>();
        }
        return Database.insertImmediate(rows);
    }

    private static List<String> readArchivedIds(Set<String> emailIds) {
        List<String> ids = new List<String>();
        if (Test.isRunningTest()) {
            if (mockArchivedIds != null) {
                ids.addAll(mockArchivedIds);
            }
            return ids;
        }
        for (Email_Message_Archive__b a : [
            SELECT Email_Message_Id__c
            FROM Email_Message_Archive__b
            WHERE Email_Message_Id__c IN :emailIds
        ]) {
            ids.add(a.Email_Message_Id__c);
        }
        return ids;
    }
}