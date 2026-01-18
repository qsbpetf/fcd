@isTest
private class MeddpicImporterTest {

    @isTest
    static void getJsonFile_returnsVersionDataAndDeletesDocument() {
        // GIVEN
        String expectedJson = '{"key":"value"}';

        // Insert a ContentVersion record. This automatically creates a related ContentDocument.
        ContentVersion cv = new ContentVersion(
            Title = 'Test MEDDPICC JSON',
            PathOnClient = 'meddpic.json',
            VersionData = Blob.valueOf(expectedJson)
        );
        insert cv;

        // Re-query to get all generated fields, including ContentDocumentId.
        cv = [
            SELECT Id, ContentDocumentId, VersionData
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        Id contentVersionId = cv.Id;
        Id contentDocumentId = cv.ContentDocumentId;

        Test.startTest();
        String result = MeddpicImporter.getJsonFile(
            null,
            contentVersionId,
            contentDocumentId,
            null
        );
        Test.stopTest();

        // THEN: The returned string should match the original version data.
        System.assertEquals(
            expectedJson,
            result,
            'Expected getJsonFile to return the original JSON stored in VersionData.'
        );

        // AND: The ContentDocument should have been deleted.
        Integer remainingDocs = [
            SELECT COUNT()
            FROM ContentDocument
            WHERE Id = :contentDocumentId
        ];
        System.assertEquals(
            0,
            remainingDocs,
            'Expected associated ContentDocument to be deleted by MeddpicImporter.getJsonFile.'
        );
    }
}