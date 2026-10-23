public with sharing class ZefortSignedFileImportQueueable {
    @future(callout=true)
    public static void enqueueImport(
        List<Id> signRequestIds,
        List<String> esignIds,
        List<String> documentIds,
        List<String> documentFileNames,
        List<String> requestTitles
    ) {
        Integer workItemCount = determineWorkItemCount(
            signRequestIds,
            esignIds,
            documentIds,
            documentFileNames,
            requestTitles
        );
        if (workItemCount == 0) {
            return;
        }

        for (Integer index = 0; index < workItemCount; index++) {
            ZefortSignService.importCompletedSignedDocument(
                signRequestIds[index],
                esignIds[index],
                documentIds[index],
                documentFileNames[index],
                requestTitles[index]
            );
        }
    }

    private static Integer determineWorkItemCount(
        List<Id> signRequestIds,
        List<String> esignIds,
        List<String> documentIds,
        List<String> documentFileNames,
        List<String> requestTitles
    ) {
        if (
            signRequestIds == null ||
            esignIds == null ||
            documentIds == null ||
            documentFileNames == null ||
            requestTitles == null
        ) {
            return 0;
        }
        Integer workItemCount = signRequestIds.size();
        workItemCount = Math.min(workItemCount, esignIds.size());
        workItemCount = Math.min(workItemCount, documentIds.size());
        workItemCount = Math.min(workItemCount, documentFileNames.size());
        workItemCount = Math.min(workItemCount, requestTitles.size());
        return workItemCount;
    }
}