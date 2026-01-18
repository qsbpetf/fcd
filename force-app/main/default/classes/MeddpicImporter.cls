public with sharing class MeddpicImporter {
    @AuraEnabled
    public static String getJsonFile(String contentBodyId, String contentVersionId, String documentId, String oppId) {
        String versionDataString = '';

        // Getting the Content Data
        ContentVersion cv = [
            SELECT Id, Title, VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        versionDataString = cv.VersionData.toString();

        // Deleting the ContentDocument
        ContentDocument cd = [
            SELECT Id
            FROM ContentDocument
            WHERE Id = :documentId
            LIMIT 1
        ];
        delete cd;

        return versionDataString;
    }
}