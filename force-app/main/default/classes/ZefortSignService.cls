public with sharing class ZefortSignService {
    public class ContactOption {
        @AuraEnabled
        public String id;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String email;
    }

    public class RecordFileInfo {
        @AuraEnabled
        public String contentVersionId;

        @AuraEnabled
        public String contentDocumentId;

        @AuraEnabled
        public String title;

        @AuraEnabled
        public String fileName;

        @AuraEnabled
        public Integer fileSize;

        @AuraEnabled
        public Datetime modifiedAt;
    }

    public class LaunchContext {
        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public String message;

        @AuraEnabled
        public String objectApiName;

        @AuraEnabled
        public String accountId;

        @AuraEnabled
        public String contextContactId;

        @AuraEnabled
        public List<ContactOption> contacts;

        @AuraEnabled
        public ZefortParticipantPrefillService.PrefillParticipant internalSignerPrefill;

        @AuraEnabled
        public List<ZefortParticipantPrefillService.PrefillParticipant> prefills;

        @AuraEnabled
        public List<RecordFileInfo> files;

        public LaunchContext() {
            this.success = false;
            this.message = '';
            this.contacts = new List<ContactOption>();
            this.internalSignerPrefill = null;
            this.prefills = new List<ZefortParticipantPrefillService.PrefillParticipant>();
            this.files = new List<RecordFileInfo>();
        }
    }

    public class ParticipantSelection {
        @AuraEnabled
        public String contactId { get; set; }

        @AuraEnabled
        public String name { get; set; }

        @AuraEnabled
        public String email { get; set; }

        @AuraEnabled
        public String role { get; set; }
    }

    public class LaunchSubmissionResult {
        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public String message;

        @AuraEnabled
        public String signRequestId;

        @AuraEnabled
        public String zefortEsignId;

        @AuraEnabled
        public String zefortContractId;
    }

    private class ResolvedParticipant {
        public String contactId;
        public String key;
        public String name;
        public String email;
        public String role;
    }

    private class SyncOutcome {
        public Id requestId;
        public String esignId;
        public String requestTitle;
        public Boolean success;
        public String title;
        public String status;
        public Datetime statusSavedAt;
        public Datetime syncedAt;
        public String errorMessage;
        public String signedDocumentId;
        public String signedDocumentFileName;
        public List<Object> rawParties;
    }

    private without sharing class SignRequestDataAccess {
        public List<Zefort_Sign_Request__c> listSignRequestsBySourceRecord(
            String sourceRecordId,
            Integer maxRows
        ) {
            Integer safeLimit = maxRows == null || maxRows <= 0 ? 200 : Math.min(maxRows, 500);
            return [
                SELECT
                    Id,
                    Request_Title__c,
                    Zefort_Esign_Id__c,
                    Status__c,
                    Status_Saved_At__c,
                    Last_Synced_At__c,
                    Error_Message__c
                FROM Zefort_Sign_Request__c
                WHERE Source_Record_Id__c = :sourceRecordId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT :safeLimit
            ];
        }

        public List<Id> listSignRequestIdsBySourceRecordForInitiator(
            String sourceRecordId,
            Id initiatorUserId,
            Integer maxRows
        ) {
            Integer safeLimit = maxRows == null || maxRows <= 0 ? 50 : Math.min(maxRows, 200);
            List<Id> requestIds = new List<Id>();
            if (String.isBlank(sourceRecordId) || initiatorUserId == null) {
                return requestIds;
            }
            for (Zefort_Sign_Request__c row : [
                SELECT Id
                FROM Zefort_Sign_Request__c
                WHERE Source_Record_Id__c = :sourceRecordId
                    AND Zefort_Esign_Id__c != null
                    AND (
                        Initiator_User_Id__c = :initiatorUserId
                        OR (Initiator_User_Id__c = null AND CreatedById = :initiatorUserId)
                    )
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT :safeLimit
            ]) {
                requestIds.add(row.Id);
            }
            return requestIds;
        }

        public Zefort_Sign_Request__c getSignRequestForAccessCheck(Id signRequestId) {
            List<Zefort_Sign_Request__c> rows = [
                SELECT Id, Source_Record_Id__c
                FROM Zefort_Sign_Request__c
                WHERE Id = :signRequestId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public List<Zefort_Sign_Request_Party__c> listPartiesBySignRequest(
            Id signRequestId,
            Integer maxRows
        ) {
            Integer safeLimit = maxRows == null || maxRows <= 0 ? 500 : Math.min(maxRows, 1000);
            return [
                SELECT
                    Id,
                    Sign_Request__c,
                    Name__c,
                    Email__c,
                    Role__c,
                    Status__c,
                    Forwarded_To__c,
                    Updated_At__c
                FROM Zefort_Sign_Request_Party__c
                WHERE Sign_Request__c = :signRequestId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate ASC
                LIMIT :safeLimit
            ];
        }

        public List<Id> listSyncCandidateRequestIds(Integer maxRows) {
            Integer safeLimit = maxRows == null || maxRows <= 0 ? 100 : Math.min(maxRows, 200);
            List<Id> requestIds = new List<Id>();
            for (Zefort_Sign_Request__c requestRow : [
                SELECT Id
                FROM Zefort_Sign_Request__c
                WHERE Zefort_Esign_Id__c != null
                    AND (
                        Status__c NOT IN ('completed', 'declined', 'canceled', 'expired', 'failed')
                        OR (Status__c = 'completed' AND Signed_Content_Document_Id__c = null)
                    )
                WITH SECURITY_ENFORCED
                ORDER BY Last_Synced_At__c ASC NULLS FIRST, CreatedDate ASC
                LIMIT :safeLimit
            ]) {
                requestIds.add(requestRow.Id);
            }
            return requestIds;
        }

        public List<Zefort_Sign_Request__c> listSignRequestsByIds(Set<Id> requestIds) {
            if (requestIds == null || requestIds.isEmpty()) {
                return new List<Zefort_Sign_Request__c>();
            }
            return [
                SELECT
                    Id,
                    Initiator_User_Id__c,
                    CreatedById,
                    Source_Record_Id__c,
                    Request_Title__c,
                    Zefort_Esign_Id__c,
                    Signed_Content_Document_Id__c,
                    Signed_File_Imported_At__c,
                    Status__c,
                    Status_Saved_At__c,
                    Last_Synced_At__c,
                    Error_Message__c
                FROM Zefort_Sign_Request__c
                WHERE Id IN :requestIds
                WITH SECURITY_ENFORCED
            ];
        }

        public List<Zefort_Sign_Request_Party__c> listExistingPartiesByRequestIds(
            Set<Id> requestIds
        ) {
            if (requestIds == null || requestIds.isEmpty()) {
                return new List<Zefort_Sign_Request_Party__c>();
            }
            return [
                SELECT Id
                FROM Zefort_Sign_Request_Party__c
                WHERE Sign_Request__c IN :requestIds
                WITH SECURITY_ENFORCED
            ];
        }

        public void updateSignRequests(List<Zefort_Sign_Request__c> rows) {
            if (rows == null || rows.isEmpty()) {
                return;
            }
            update rows;
        }

        public void deleteSignRequestParties(List<Zefort_Sign_Request_Party__c> rows) {
            if (rows == null || rows.isEmpty()) {
                return;
            }
            delete rows;
        }

        public void insertSignRequestParties(List<Zefort_Sign_Request_Party__c> rows) {
            if (rows == null || rows.isEmpty()) {
                return;
            }
            insert rows;
        }
    }

    public class SignRequestSummary {
        @AuraEnabled
        public String id;

        @AuraEnabled
        public String zefortEsignId;

        @AuraEnabled
        public String title;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public Datetime statusSavedAt;

        @AuraEnabled
        public Datetime lastSyncedAt;

        @AuraEnabled
        public String errorMessage;
    }

    public class SignRequestPartySummary {
        @AuraEnabled
        public String id;

        @AuraEnabled
        public String signRequestId;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String email;

        @AuraEnabled
        public String role;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String forwardedTo;

        @AuraEnabled
        public Datetime updatedAt;
    }

    public class AccountSearchOption {
        @AuraEnabled
        public String id;

        @AuraEnabled
        public String label;
    }

    private static final Integer ACCOUNT_SEARCH_LIMIT = 20;
    private static final Integer MAX_FILE_BYTES_FOR_APEX_UPLOAD = 4500000;
    private static final SignRequestDataAccess signRequestDataAccess = new SignRequestDataAccess();

    @AuraEnabled(cacheable=true)
    public static LaunchContext getLaunchContext(String recordId, String objectApiName) {
        LaunchContext context = new LaunchContext();
        if (String.isBlank(recordId)) {
            context.message = 'Record ID is required.';
            return context;
        }

        ZefortRecordResolver.ResolutionResult resolution = ZefortRecordResolver.resolveRecordContext(
            recordId,
            objectApiName
        );
        if (resolution != null) {
            context.objectApiName = resolution.objectApiName;
            context.contextContactId = resolution.contextContactId;
        }
        context.files = listRecordFiles(recordId);
        context.internalSignerPrefill = buildInternalSignerPrefill();

        if (resolution == null || !resolution.success || String.isBlank(resolution.accountId)) {
            context.message = resolution == null
                ? 'Unable to resolve record context.'
                : resolution.message;
            return context;
        }

        context.accountId = resolution.accountId;
        context.contacts = listAccountContacts(resolution.accountId);
        context.prefills = ZefortParticipantPrefillService.getPrefilledParticipants(
            recordId,
            resolution.objectApiName
        );
        context.success = true;
        context.message = '';
        return context;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContactOption> listAccountContacts(String accountId) {
        List<ContactOption> options = new List<ContactOption>();
        if (String.isBlank(accountId)) {
            return options;
        }

        for (Contact contact : [
            SELECT Id, Name, Email
            FROM Contact
            WHERE AccountId = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
            LIMIT 1000
        ]) {
            ContactOption option = new ContactOption();
            option.id = String.valueOf(contact.Id);
            option.name = contact.Name;
            option.email = contact.Email;
            options.add(option);
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountSearchOption> searchAccounts(String searchTerm) {
        List<AccountSearchOption> options = new List<AccountSearchOption>();
        String normalizedTerm = String.isBlank(searchTerm) ? null : searchTerm.trim();
        if (String.isBlank(normalizedTerm) || normalizedTerm.length() < 2) {
            return options;
        }

        String likeTerm = '%' + normalizedTerm + '%';
        for (Account account : [
            SELECT Id, Name
            FROM Account
            WHERE Name LIKE :likeTerm
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
            LIMIT :ACCOUNT_SEARCH_LIMIT
        ]) {
            AccountSearchOption option = new AccountSearchOption();
            option.id = String.valueOf(account.Id);
            option.label = account.Name;
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordFileInfo> listRecordFiles(String recordId) {
        List<RecordFileInfo> files = new List<RecordFileInfo>();
        if (String.isBlank(recordId)) {
            return files;
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            WITH SECURITY_ENFORCED
            ORDER BY SystemModstamp DESC
            LIMIT 200
        ];
        if (links.isEmpty()) {
            return files;
        }

        Set<Id> documentIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            documentIds.add(link.ContentDocumentId);
        }

        Map<Id, ContentVersion> latestVersionByDocumentId = new Map<Id, ContentVersion>();
        for (ContentVersion version : [
            SELECT Id, ContentDocumentId, Title, PathOnClient, ContentSize, LastModifiedDate
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :documentIds
            WITH SECURITY_ENFORCED
        ]) {
            latestVersionByDocumentId.put(version.ContentDocumentId, version);
        }

        for (ContentDocumentLink link : links) {
            ContentVersion version = latestVersionByDocumentId.get(link.ContentDocumentId);
            if (version == null) {
                continue;
            }

            RecordFileInfo info = new RecordFileInfo();
            info.contentVersionId = String.valueOf(version.Id);
            info.contentDocumentId = String.valueOf(version.ContentDocumentId);
            info.title = version.Title;
            info.fileName = version.PathOnClient;
            info.fileSize = Integer.valueOf(version.ContentSize);
            info.modifiedAt = version.LastModifiedDate;
            files.add(info);
        }

        return files;
    }

    @AuraEnabled
    public static LaunchSubmissionResult startSignRequestFromClient(
        String recordId,
        String objectApiName,
        String mainFileId,
        List<String> attachmentFileIds,
        String participantsJson,
        String manualAccountId
    ) {
        return startSignRequestInternal(
            recordId,
            objectApiName,
            mainFileId,
            attachmentFileIds,
            parseParticipantSelections(participantsJson),
            manualAccountId
        );
    }

    @AuraEnabled
    public static LaunchSubmissionResult startSignRequest(
        String recordId,
        String objectApiName,
        String mainFileId,
        List<String> attachmentFileIds,
        List<ParticipantSelection> participants,
        String manualAccountId
    ) {
        return startSignRequestInternal(
            recordId,
            objectApiName,
            mainFileId,
            attachmentFileIds,
            participants,
            manualAccountId
        );
    }

    private static List<ParticipantSelection> parseParticipantSelections(String participantsJson) {
        if (String.isBlank(participantsJson)) {
            return new List<ParticipantSelection>();
        }

        try {
            List<ParticipantSelection> participants = (List<ParticipantSelection>) JSON.deserialize(
                participantsJson,
                List<ParticipantSelection>.class
            );
            return participants == null ? new List<ParticipantSelection>() : participants;
        } catch (Exception parseError) {
            throw new AuraHandledException('Participant payload is invalid.');
        }
    }

    private static LaunchSubmissionResult startSignRequestInternal(
        String recordId,
        String objectApiName,
        String mainFileId,
        List<String> attachmentFileIds,
        List<ParticipantSelection> participants,
        String manualAccountId
    ) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Record ID is required.');
        }
        if (String.isBlank(mainFileId)) {
            throw new AuraHandledException('Main file is required.');
        }
        if (participants == null || participants.isEmpty()) {
            throw new AuraHandledException('At least one participant is required.');
        }

        LaunchContext context = getLaunchContext(recordId, objectApiName);
        if ((context == null || !context.success || String.isBlank(context.accountId)) && !String.isBlank(manualAccountId)) {
            context = hydrateManualAccountContext(recordId, objectApiName, context, manualAccountId);
        }
        if (context == null || !context.success || String.isBlank(context.accountId)) {
            String message = context == null || String.isBlank(context.message)
                ? 'Could not resolve account for this source record.'
                : context.message;
            throw new AuraHandledException(message);
        }

        Map<String, RecordFileInfo> filesById = new Map<String, RecordFileInfo>();
        for (RecordFileInfo file : context.files) {
            if (file != null && !String.isBlank(file.contentVersionId)) {
                filesById.put(file.contentVersionId, file);
            }
        }

        List<String> selectedFileIds = new List<String>{mainFileId};
        for (String attachmentId : attachmentFileIds == null ? new List<String>() : attachmentFileIds) {
            if (String.isBlank(attachmentId) || attachmentId == mainFileId) {
                continue;
            }
            if (!selectedFileIds.contains(attachmentId)) {
                selectedFileIds.add(attachmentId);
            }
        }

        for (String selectedFileId : selectedFileIds) {
            if (!filesById.containsKey(selectedFileId)) {
                throw new AuraHandledException('Selected file is not available on this record.');
            }
            RecordFileInfo fileInfo = filesById.get(selectedFileId);
            if (fileInfo != null && fileInfo.fileSize != null && fileInfo.fileSize > MAX_FILE_BYTES_FOR_APEX_UPLOAD) {
                throw new AuraHandledException(
                    'Selected file "' +
                    deriveDisplayFileName(fileInfo) +
                    '" is too large to process in Salesforce. Maximum supported size is approximately 4.5 MB per file.'
                );
            }
        }

        Map<String, ContactOption> contactsById = new Map<String, ContactOption>();
        for (ContactOption contact : context.contacts) {
            if (contact != null && !String.isBlank(contact.id)) {
                contactsById.put(contact.id, contact);
            }
        }
        if (
            context.internalSignerPrefill != null &&
            !String.isBlank(context.internalSignerPrefill.contactId) &&
            !String.isBlank(context.internalSignerPrefill.email)
        ) {
            ContactOption internalSigner = new ContactOption();
            internalSigner.id = context.internalSignerPrefill.contactId;
            internalSigner.name = context.internalSignerPrefill.name;
            internalSigner.email = context.internalSignerPrefill.email;
            contactsById.put(internalSigner.id, internalSigner);
        }

        List<ResolvedParticipant> resolvedParticipants = new List<ResolvedParticipant>();
        Set<String> participantKeys = new Set<String>();
        for (ParticipantSelection participant : participants) {
            if (participant == null) {
                continue;
            }

            String normalizedRole = normalizeRole(participant.role);
            if (!String.isBlank(participant.contactId)) {
                if (!contactsById.containsKey(participant.contactId)) {
                    throw new AuraHandledException(
                        'Selected participant is not an allowed Salesforce contact for this request.'
                    );
                }
                ContactOption contact = contactsById.get(participant.contactId);
                if (contact == null || String.isBlank(contact.email)) {
                    throw new AuraHandledException('Selected participants must have an e-mail address.');
                }

                String participantKey = 'contact:' + participant.contactId;
                if (participantKeys.contains(participantKey)) {
                    continue;
                }

                ResolvedParticipant resolved = new ResolvedParticipant();
                resolved.key = participantKey;
                resolved.contactId = participant.contactId;
                resolved.name = contact.name;
                resolved.email = contact.email;
                resolved.role = normalizedRole;
                resolvedParticipants.add(resolved);
                participantKeys.add(participantKey);
                continue;
            }

            if (
                !String.isBlank(participant.email) ||
                !String.isBlank(participant.name)
            ) {
                throw new AuraHandledException(
                    'Selected participants must be Salesforce contacts allowed for this request.'
                );
            }
        }
        if (resolvedParticipants.isEmpty()) {
            throw new AuraHandledException('At least one participant is required.');
        }

        Integer signerOrApproverCount = 0;
        for (ResolvedParticipant participant : resolvedParticipants) {
            if (participant.role == 'signer' || participant.role == 'approver') {
                signerOrApproverCount += 1;
            }
        }
        if (signerOrApproverCount == 0) {
            throw new AuraHandledException('At least one signer or approver is required.');
        }

        Map<String, Id> contentVersionIdsByString = new Map<String, Id>();
        for (String selectedFileId : selectedFileIds) {
            Id parsedId = tryParseId(selectedFileId);
            if (parsedId == null) {
                throw new AuraHandledException('Invalid file selection.');
            }
            contentVersionIdsByString.put(selectedFileId, parsedId);
        }

        ZefortAPI.createParty(context.accountId);

        RecordFileInfo mainFileInfo = filesById.get(mainFileId);
        String contractTitle = deriveContractTitle(mainFileInfo, recordId);
        Map<String, Object> contractResponse = ZefortAPI.createContract(contractTitle);
        String contractId = stringValue(contractResponse.get('id'));
        if (String.isBlank(contractId)) {
            throw new AuraHandledException('Failed to create contract in Zefort.');
        }

        String mainDocumentId;
        List<String> attachmentDocumentIds = new List<String>();
        for (Integer index = 0; index < selectedFileIds.size(); index++) {
            String selectedFileId = selectedFileIds[index];
            ContentVersion version = loadContentVersionBlob(contentVersionIdsByString.get(selectedFileId));
            if (version == null || version.VersionData == null) {
                throw new AuraHandledException('Selected file content is no longer available.');
            }
            String fileName = deriveUploadFileName(version);
            String contentType = deriveContentType(version, fileName);

            try {
                Map<String, Object> uploadResponse = ZefortAPI.uploadContractFile(
                    contractId,
                    fileName,
                    contentType,
                    version.VersionData
                );
                List<String> uploadedDocumentIds = extractDocumentIds(uploadResponse);
                if (uploadedDocumentIds.isEmpty()) {
                    throw new AuraHandledException('No uploaded document id returned from Zefort.');
                }

                if (index == 0) {
                    mainDocumentId = uploadedDocumentIds[0];
                } else {
                    attachmentDocumentIds.add(uploadedDocumentIds[0]);
                }
            } catch (Exception uploadError) {
                throw new AuraHandledException(buildUploadErrorMessage(fileName, uploadError));
            }
        }

        if (String.isBlank(mainDocumentId)) {
            throw new AuraHandledException('Main document upload failed.');
        }

        User initiator = [
            SELECT Id, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        String ownerId;
        String ownerFallbackMessage;
        if (!String.isBlank(initiator.Email)) {
            try {
                Map<String, Object> owner = ZefortAPI.findZefortUserByEmail(initiator.Email);
                ownerId = stringValue(owner.get('id'));
                if (String.isBlank(ownerId)) {
                    ownerFallbackMessage =
                        'No matching Zefort user found for initiator email ' + initiator.Email + '.';
                }
            } catch (Exception ownerError) {
                ownerFallbackMessage =
                    'Owner mapping failed for initiator email ' + initiator.Email + '.';
            }
        } else {
            ownerFallbackMessage = 'Initiator e-mail is empty in Salesforce user profile.';
        }

        List<Map<String, Object>> partyPayload = new List<Map<String, Object>>();
        for (ResolvedParticipant participant : resolvedParticipants) {
            partyPayload.add(
                new Map<String, Object>{
                    'name' => participant.name,
                    'email' => participant.email,
                    'role' => normalizeRole(participant.role),
                    'authentication_type' => 'email'
                }
            );
        }

        Map<String, Object> esignResponse;
        try {
            esignResponse = ZefortAPI.createEsign(
                contractId,
                mainDocumentId,
                attachmentDocumentIds,
                partyPayload,
                ownerId,
                contractTitle
            );
        } catch (ZefortService.ZefortApiException createError) {
            if (String.isBlank(ownerId) || !isOwnerOverrideDenied(createError)) {
                throw createError;
            }

            ownerFallbackMessage = appendFallbackMessage(
                ownerFallbackMessage,
                'Owner override denied for initiator email ' +
                    initiator.Email +
                    '; eSign created without owner override.'
            );
            ownerId = null;
            esignResponse = ZefortAPI.createEsign(
                contractId,
                mainDocumentId,
                attachmentDocumentIds,
                partyPayload,
                null,
                contractTitle
            );
        }
        String esignId = stringValue(esignResponse.get('id'));
        if (String.isBlank(esignId)) {
            throw new AuraHandledException('Failed to create eSign in Zefort.');
        }

        Map<String, Object> activatedEsign = ZefortAPI.activateEsign(esignId);
        List<Object> activatedParties = activatedEsign == null
            ? null
            : (List<Object>) activatedEsign.get('parties');
        Datetime nowValue = System.now();
        String requestStatus = deriveRequestStatus(
            stringValue(activatedEsign.get('status')),
            activatedParties
        );
        Datetime statusSavedAt = parseApiDatetime(activatedEsign.get('status_saved_at'));
        if (statusSavedAt == null) {
            statusSavedAt = nowValue;
        }

        Zefort_Sign_Request__c requestRow = new Zefort_Sign_Request__c();
        requestRow.Source_Record_Id__c = recordId;
        requestRow.Source_Object__c = context.objectApiName;
        requestRow.Resolved_Account_Id__c = context.accountId;
        requestRow.Request_Title__c = contractTitle;
        requestRow.Zefort_Esign_Id__c = esignId;
        requestRow.Zefort_Contract_Id__c = contractId;
        requestRow.Zefort_Owner_Id__c = ownerId;
        requestRow.Status__c = requestStatus;
        requestRow.Status_Saved_At__c = statusSavedAt;
        requestRow.Last_Synced_At__c = nowValue;
        requestRow.Initiator_User_Id__c = initiator.Id;
        requestRow.Initiator_Email__c = initiator.Email;
        if (!String.isBlank(ownerFallbackMessage)) {
            requestRow.Error_Message__c = ownerFallbackMessage;
        }
        ensureObjectCreateable(
            Zefort_Sign_Request__c.SObjectType,
            'Insufficient permissions to create sign request records.'
        );
        requestRow = (Zefort_Sign_Request__c) Security.stripInaccessible(
            AccessType.CREATABLE,
            new List<SObject>{requestRow}
        )
            .getRecords()[0];
        insert requestRow;

        List<Zefort_Sign_Request_Party__c> partyRows = new List<Zefort_Sign_Request_Party__c>();
        if (activatedParties != null && !activatedParties.isEmpty()) {
            for (Object rawParty : activatedParties) {
                Map<String, Object> party = asMap(rawParty);
                Zefort_Sign_Request_Party__c row = new Zefort_Sign_Request_Party__c();
                row.Sign_Request__c = requestRow.Id;
                row.Zefort_Party_Id__c = stringValue(party.get('id'));
                row.Name__c = stringValue(party.get('name'));
                row.Email__c = stringValue(party.get('email'));
                row.Role__c = normalizeRole(stringValue(party.get('role')));
                row.Status__c = normalizePartyStatus(stringValue(party.get('status')));
                row.Forwarded_To__c = stringValue(party.get('forwarded_to'));
                row.Updated_At__c = parseApiDatetime(party.get('status_saved_at'));
                if (row.Updated_At__c == null) {
                    row.Updated_At__c = statusSavedAt;
                }
                partyRows.add(row);
            }
        } else {
            for (ResolvedParticipant participant : resolvedParticipants) {
                Zefort_Sign_Request_Party__c row = new Zefort_Sign_Request_Party__c();
                row.Sign_Request__c = requestRow.Id;
                row.Name__c = participant.name;
                row.Email__c = participant.email;
                row.Role__c = normalizeRole(participant.role);
                row.Status__c = 'pending';
                row.Updated_At__c = statusSavedAt;
                partyRows.add(row);
            }
        }
        if (!partyRows.isEmpty()) {
            ensureObjectCreateable(
                Zefort_Sign_Request_Party__c.SObjectType,
                'Insufficient permissions to create sign request party records.'
            );
            List<Zefort_Sign_Request_Party__c> sanitizedPartyRows = castPartyRows(
                Security.stripInaccessible(AccessType.CREATABLE, partyRows).getRecords()
            );
            if (!sanitizedPartyRows.isEmpty()) {
                insert sanitizedPartyRows;
            }
        }

        LaunchSubmissionResult result = new LaunchSubmissionResult();
        result.success = true;
        result.message = 'Sign request launched successfully.';
        result.signRequestId = String.valueOf(requestRow.Id);
        result.zefortEsignId = esignId;
        result.zefortContractId = contractId;
        return result;
    }

    @AuraEnabled
    public static List<SignRequestSummary> listSignRequests(String sourceRecordId) {
        List<SignRequestSummary> rows = new List<SignRequestSummary>();
        if (String.isBlank(sourceRecordId)) {
            return rows;
        }
        if (!canReadSourceRecord(sourceRecordId)) {
            return rows;
        }

        for (Zefort_Sign_Request__c signRequest : signRequestDataAccess.listSignRequestsBySourceRecord(
            sourceRecordId,
            200
        )) {
            SignRequestSummary summary = new SignRequestSummary();
            summary.id = String.valueOf(signRequest.Id);
            summary.title = signRequest.Request_Title__c;
            summary.zefortEsignId = signRequest.Zefort_Esign_Id__c;
            summary.status = signRequest.Status__c;
            summary.statusSavedAt = signRequest.Status_Saved_At__c;
            summary.lastSyncedAt = signRequest.Last_Synced_At__c;
            summary.errorMessage = signRequest.Error_Message__c;
            rows.add(summary);
        }

        return rows;
    }

    @AuraEnabled
    public static List<SignRequestPartySummary> listSignRequestParties(String signRequestId) {
        List<SignRequestPartySummary> rows = new List<SignRequestPartySummary>();
        if (String.isBlank(signRequestId)) {
            return rows;
        }
        Id parsedSignRequestId = tryParseId(signRequestId);
        if (parsedSignRequestId == null) {
            return rows;
        }

        Zefort_Sign_Request__c requestRow = signRequestDataAccess.getSignRequestForAccessCheck(
            parsedSignRequestId
        );
        if (
            requestRow == null ||
            String.isBlank(requestRow.Source_Record_Id__c) ||
            !canReadSourceRecord(requestRow.Source_Record_Id__c)
        ) {
            return rows;
        }

        for (Zefort_Sign_Request_Party__c party : signRequestDataAccess.listPartiesBySignRequest(
            parsedSignRequestId,
            500
        )) {
            SignRequestPartySummary summary = new SignRequestPartySummary();
            summary.id = String.valueOf(party.Id);
            summary.signRequestId = String.valueOf(party.Sign_Request__c);
            summary.name = party.Name__c;
            summary.email = party.Email__c;
            summary.role = party.Role__c;
            summary.status = party.Status__c;
            summary.forwardedTo = party.Forwarded_To__c;
            summary.updatedAt = party.Updated_At__c;
            rows.add(summary);
        }

        return rows;
    }

    @AuraEnabled
    public static Integer refreshSignRequestsForRecord(String sourceRecordId) {
        if (String.isBlank(sourceRecordId)) {
            return 0;
        }
        if (!canReadSourceRecord(sourceRecordId)) {
            return 0;
        }

        List<Id> requestIds = signRequestDataAccess.listSignRequestIdsBySourceRecordForInitiator(
            sourceRecordId,
            UserInfo.getUserId(),
            50
        );
        return syncSignRequestIds(requestIds);
    }

    public static List<Id> listSyncCandidateRequestIds(Integer maxRows) {
        return signRequestDataAccess.listSyncCandidateRequestIds(maxRows);
    }

    public static Integer syncSignRequestIds(List<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) {
            return 0;
        }
        Set<Id> normalizedRequestIds = new Set<Id>();
        for (Id requestId : requestIds) {
            if (requestId != null) {
                normalizedRequestIds.add(requestId);
            }
        }
        if (normalizedRequestIds.isEmpty()) {
            return 0;
        }

        List<Zefort_Sign_Request__c> rows = signRequestDataAccess.listSignRequestsByIds(
            normalizedRequestIds
        );
        Map<Id, Zefort_Sign_Request__c> rowsById = new Map<Id, Zefort_Sign_Request__c>(rows);

        List<SyncOutcome> outcomes = new List<SyncOutcome>();
        Integer syncedCount = 0;
        for (Zefort_Sign_Request__c row : rows) {
            if (String.isBlank(row.Zefort_Esign_Id__c)) {
                continue;
            }

            SyncOutcome outcome = new SyncOutcome();
            outcome.requestId = row.Id;
            outcome.esignId = row.Zefort_Esign_Id__c;
            outcome.requestTitle = row.Request_Title__c;
            Datetime nowValue = System.now();
            try {
                Map<String, Object> esign = ZefortAPI.getEsign(row.Zefort_Esign_Id__c);
                Datetime statusSavedAt = parseApiDatetime(esign.get('status_saved_at'));
                if (statusSavedAt == null) {
                    statusSavedAt = nowValue;
                }

                outcome.success = true;
                outcome.title = stringValue(esign.get('title'));
                outcome.rawParties = (List<Object>) esign.get('parties');
                outcome.status = deriveRequestStatus(
                    stringValue(esign.get('status')),
                    outcome.rawParties
                );
                outcome.statusSavedAt = statusSavedAt;
                outcome.syncedAt = nowValue;
                outcome.errorMessage = null;
                syncedCount += 1;

                if (shouldQueueSignedFileImport(row, outcome)) {
                    List<Object> rawDocuments = asList(esign.get('documents'));
                    outcome.signedDocumentId = extractPrimaryDocumentId(rawDocuments);
                    outcome.signedDocumentFileName = extractPrimaryDocumentFileName(rawDocuments);
                    if (String.isBlank(outcome.signedDocumentId)) {
                        outcome.errorMessage = appendFallbackMessage(
                            outcome.errorMessage,
                            'Completed signed document import failed: No downloadable document was returned by Zefort.'
                        );
                    }
                }
            } catch (Exception syncError) {
                outcome.success = false;
                outcome.status = null;
                outcome.statusSavedAt = null;
                outcome.syncedAt = nowValue;
                outcome.errorMessage = 'Sync failed: ' + syncError.getMessage();
                outcome.rawParties = null;
            }
            outcomes.add(outcome);
        }

        List<Zefort_Sign_Request__c> updates = new List<Zefort_Sign_Request__c>();
        Map<Id, List<Object>> partiesByRequest = new Map<Id, List<Object>>();
        Map<Id, Datetime> fallbackUpdatedAtByRequest = new Map<Id, Datetime>();

        for (SyncOutcome outcome : outcomes) {
            Zefort_Sign_Request__c updateRow = new Zefort_Sign_Request__c(Id = outcome.requestId);
            updateRow.Last_Synced_At__c = outcome.syncedAt;

            if (outcome.success) {
                if (!String.isBlank(outcome.title)) {
                    updateRow.Request_Title__c = outcome.title;
                }
                updateRow.Status__c = outcome.status;
                updateRow.Status_Saved_At__c = outcome.statusSavedAt;
                updateRow.Error_Message__c = outcome.errorMessage;
                partiesByRequest.put(outcome.requestId, outcome.rawParties);
                fallbackUpdatedAtByRequest.put(outcome.requestId, outcome.statusSavedAt);
            } else {
                updateRow.Error_Message__c = outcome.errorMessage;
            }

            updates.add(updateRow);
        }

        if (!updates.isEmpty()) {
            ensureObjectUpdateable(
                Zefort_Sign_Request__c.SObjectType,
                'Insufficient permissions to update sign request records.'
            );
            List<Zefort_Sign_Request__c> sanitizedUpdates = castRequestRows(
                Security.stripInaccessible(AccessType.UPDATABLE, updates).getRecords()
            );
            if (!sanitizedUpdates.isEmpty()) {
                signRequestDataAccess.updateSignRequests(sanitizedUpdates);
            }
        }
        if (!partiesByRequest.isEmpty()) {
            replaceRequestParties(partiesByRequest, fallbackUpdatedAtByRequest);
        }
        enqueueSignedFileImports(outcomes, rowsById);

        return syncedCount;
    }

    public static void importCompletedSignedDocument(
        Id signRequestId,
        String esignId,
        String documentId,
        String documentFileName,
        String requestTitle
    ) {
        if (signRequestId == null || String.isBlank(esignId) || String.isBlank(documentId)) {
            return;
        }

        List<Zefort_Sign_Request__c> rows = [
            SELECT
                Id,
                Source_Record_Id__c,
                Status__c,
                Signed_Content_Document_Id__c,
                Signed_File_Imported_At__c,
                Error_Message__c
            FROM Zefort_Sign_Request__c
            WHERE Id = :signRequestId
            LIMIT 1
            FOR UPDATE
        ];
        if (rows.isEmpty()) {
            return;
        }

        Zefort_Sign_Request__c requestRow = rows[0];
        if (requestRow.Status__c != 'completed' || !String.isBlank(requestRow.Signed_Content_Document_Id__c)) {
            return;
        }

        Id sourceRecordId = tryParseId(requestRow.Source_Record_Id__c);
        if (sourceRecordId == null) {
            ensureObjectUpdateable(
                Zefort_Sign_Request__c.SObjectType,
                'Insufficient permissions to update sign request records.'
            );
            requestRow.Error_Message__c = 'Completed signed document import failed: Source record is missing or invalid.';
            update requestRow;
            return;
        }

        try {
            Blob signedPdf = ZefortAPI.downloadSignedEsignDocument(esignId, documentId);
            if (signedPdf == null || signedPdf.size() == 0) {
                throw new AuraHandledException('Downloaded signed document was empty.');
            }

            ensureObjectCreateable(
                ContentVersion.SObjectType,
                'Insufficient permissions to create Salesforce files for completed sign requests.'
            );

            String pathOnClient = deriveSignedPathOnClient(requestTitle, documentFileName);
            ContentVersion versionRow = new ContentVersion(
                Title = deriveContentVersionTitle(pathOnClient),
                PathOnClient = pathOnClient,
                VersionData = signedPdf,
                FirstPublishLocationId = sourceRecordId
            );
            insert versionRow;

            Id contentDocumentId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :versionRow.Id
                LIMIT 1
            ].ContentDocumentId;

            ensureObjectUpdateable(
                Zefort_Sign_Request__c.SObjectType,
                'Insufficient permissions to update sign request records.'
            );
            requestRow.Signed_Content_Document_Id__c = String.valueOf(contentDocumentId);
            requestRow.Signed_File_Imported_At__c = System.now();
            requestRow.Error_Message__c = null;
            update requestRow;
        } catch (Exception importError) {
            ensureObjectUpdateable(
                Zefort_Sign_Request__c.SObjectType,
                'Insufficient permissions to update sign request records.'
            );
            requestRow.Error_Message__c =
                'Completed signed document import failed: ' + importError.getMessage();
            update requestRow;
        }
    }

    private static LaunchContext hydrateManualAccountContext(
        String recordId,
        String objectApiName,
        LaunchContext context,
        String manualAccountId
    ) {
        Id parsedAccountId = tryParseId(manualAccountId);
        if (parsedAccountId == null) {
            throw new AuraHandledException('Invalid manual account selection.');
        }

        LaunchContext hydrated = context == null ? new LaunchContext() : context;
        hydrated.accountId = String.valueOf(parsedAccountId);
        hydrated.contacts = listAccountContacts(hydrated.accountId);
        hydrated.internalSignerPrefill = buildInternalSignerPrefill();
        hydrated.prefills = new List<ZefortParticipantPrefillService.PrefillParticipant>();
        hydrated.success = true;
        hydrated.message = '';

        if (String.isBlank(hydrated.objectApiName)) {
            ZefortRecordResolver.ResolutionResult resolution = ZefortRecordResolver.resolveRecordContext(
                recordId,
                objectApiName
            );
            hydrated.objectApiName = resolution == null ? objectApiName : resolution.objectApiName;
        }
        return hydrated;
    }

    private static ZefortParticipantPrefillService.PrefillParticipant buildInternalSignerPrefill() {
        ZefortSettings.ContactOption configuredSigner = ZefortSettings.getConfiguredInternalSigner();
        if (
            configuredSigner == null ||
            String.isBlank(configuredSigner.id) ||
            String.isBlank(configuredSigner.email)
        ) {
            return null;
        }

        ZefortParticipantPrefillService.PrefillParticipant participant =
            new ZefortParticipantPrefillService.PrefillParticipant(
                configuredSigner.id,
                configuredSigner.role,
                'internal_signer'
            );
        participant.name = configuredSigner.name;
        participant.email = configuredSigner.email;
        return participant;
    }

    private static ContentVersion loadContentVersionBlob(Id contentVersionId) {
        if (contentVersionId == null) {
            return null;
        }
        List<ContentVersion> rows = [
            SELECT Id, Title, PathOnClient, FileType, ContentSize, VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        ContentVersion version = rows[0];
        if (version.ContentSize != null && Integer.valueOf(version.ContentSize) > MAX_FILE_BYTES_FOR_APEX_UPLOAD) {
            throw new AuraHandledException(
                'Selected file "' +
                deriveUploadFileName(version) +
                '" is too large to process in Salesforce. Maximum supported size is approximately 4.5 MB per file.'
            );
        }
        return version;
    }

    private static String deriveContractTitle(RecordFileInfo mainFile, String recordId) {
        if (mainFile != null && !String.isBlank(mainFile.title)) {
            return mainFile.title;
        }
        return 'Salesforce sign request ' + recordId;
    }

    private static String deriveDisplayFileName(RecordFileInfo file) {
        if (file == null) {
            return 'selected file';
        }
        if (!String.isBlank(file.fileName)) {
            return file.fileName;
        }
        if (!String.isBlank(file.title)) {
            return file.title;
        }
        return 'selected file';
    }

    private static void enqueueSignedFileImports(
        List<SyncOutcome> outcomes,
        Map<Id, Zefort_Sign_Request__c> rowsById
    ) {
        if (outcomes == null || outcomes.isEmpty() || rowsById == null || rowsById.isEmpty()) {
            return;
        }

        List<Id> signRequestIds = new List<Id>();
        List<String> esignIds = new List<String>();
        List<String> documentIds = new List<String>();
        List<String> documentFileNames = new List<String>();
        List<String> requestTitles = new List<String>();

        for (SyncOutcome outcome : outcomes) {
            if (outcome == null || !outcome.success || String.isBlank(outcome.signedDocumentId)) {
                continue;
            }

            Zefort_Sign_Request__c row = rowsById.get(outcome.requestId);
            if (!shouldQueueSignedFileImport(row, outcome)) {
                continue;
            }

            signRequestIds.add(outcome.requestId);
            esignIds.add(outcome.esignId);
            documentIds.add(outcome.signedDocumentId);
            documentFileNames.add(firstNonBlank(outcome.signedDocumentFileName, '', ''));
            requestTitles.add(firstNonBlank(outcome.title, outcome.requestTitle, 'signed-document'));
        }

        if (!signRequestIds.isEmpty()) {
            ZefortSignedFileImportQueueable.enqueueImport(
                signRequestIds,
                esignIds,
                documentIds,
                documentFileNames,
                requestTitles
            );
        }
    }

    private static void replaceRequestParties(
        Map<Id, List<Object>> partiesByRequest,
        Map<Id, Datetime> fallbackUpdatedAtByRequest
    ) {
        if (partiesByRequest == null || partiesByRequest.isEmpty()) {
            return;
        }

        List<Zefort_Sign_Request_Party__c> existingRows = signRequestDataAccess.listExistingPartiesByRequestIds(
            partiesByRequest.keySet()
        );
        if (!existingRows.isEmpty()) {
            ensureObjectDeleteable(
                Zefort_Sign_Request_Party__c.SObjectType,
                'Insufficient permissions to delete sign request party records.'
            );
            signRequestDataAccess.deleteSignRequestParties(existingRows);
        }

        List<Zefort_Sign_Request_Party__c> inserts = new List<Zefort_Sign_Request_Party__c>();
        for (Id signRequestId : partiesByRequest.keySet()) {
            List<Object> rawParties = partiesByRequest.get(signRequestId);
            if (rawParties == null || rawParties.isEmpty()) {
                continue;
            }

            for (Object rawParty : rawParties) {
                Map<String, Object> party = asMap(rawParty);
                Zefort_Sign_Request_Party__c row = new Zefort_Sign_Request_Party__c();
                row.Sign_Request__c = signRequestId;
                row.Zefort_Party_Id__c = stringValue(party.get('id'));
                row.Name__c = stringValue(party.get('name'));
                row.Email__c = stringValue(party.get('email'));
                row.Role__c = normalizeRole(stringValue(party.get('role')));
                row.Status__c = normalizePartyStatus(stringValue(party.get('status')));
                row.Forwarded_To__c = stringValue(party.get('forwarded_to'));
                row.Updated_At__c = parseApiDatetime(party.get('status_saved_at'));
                if (row.Updated_At__c == null) {
                    row.Updated_At__c = fallbackUpdatedAtByRequest.get(signRequestId);
                }
                inserts.add(row);
            }
        }

        if (!inserts.isEmpty()) {
            ensureObjectCreateable(
                Zefort_Sign_Request_Party__c.SObjectType,
                'Insufficient permissions to create sign request party records.'
            );
            List<Zefort_Sign_Request_Party__c> sanitizedInserts = castPartyRows(
                Security.stripInaccessible(AccessType.CREATABLE, inserts).getRecords()
            );
            if (!sanitizedInserts.isEmpty()) {
                signRequestDataAccess.insertSignRequestParties(sanitizedInserts);
            }
        }
    }

    private static Boolean canReadSourceRecord(String sourceRecordId) {
        Id parsedSourceRecordId = tryParseId(sourceRecordId);
        if (parsedSourceRecordId == null) {
            return false;
        }

        try {
            String objectApiName = parsedSourceRecordId.getSObjectType().getDescribe().getName();
            if (String.isBlank(objectApiName) || !Pattern.matches('^[A-Za-z0-9_]+$', objectApiName)) {
                return false;
            }
            String query = 'SELECT Id FROM ' + objectApiName + ' WHERE Id = :parsedSourceRecordId WITH SECURITY_ENFORCED LIMIT 1';
            List<SObject> rows = Database.query(query);
            return !rows.isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    private static String deriveUploadFileName(ContentVersion version) {
        if (version == null) {
            return 'upload.bin';
        }
        if (!String.isBlank(version.PathOnClient)) {
            return version.PathOnClient;
        }
        if (!String.isBlank(version.Title)) {
            return version.Title;
        }
        return 'upload.bin';
    }

    private static Boolean shouldQueueSignedFileImport(
        Zefort_Sign_Request__c requestRow,
        SyncOutcome outcome
    ) {
        return requestRow != null &&
            outcome != null &&
            outcome.success &&
            outcome.status == 'completed' &&
            String.isBlank(requestRow.Signed_Content_Document_Id__c);
    }

    private static String extractPrimaryDocumentId(List<Object> rawDocuments) {
        if (rawDocuments == null || rawDocuments.isEmpty()) {
            return null;
        }
        for (Object rawDocument : rawDocuments) {
            Map<String, Object> document = asMap(rawDocument);
            String documentId = stringValue(document.get('id'));
            if (!String.isBlank(documentId)) {
                return documentId;
            }
        }
        return null;
    }

    private static String extractPrimaryDocumentFileName(List<Object> rawDocuments) {
        if (rawDocuments == null || rawDocuments.isEmpty()) {
            return null;
        }
        for (Object rawDocument : rawDocuments) {
            Map<String, Object> document = asMap(rawDocument);
            String fileName = stringValue(document.get('filename'));
            if (!String.isBlank(fileName)) {
                return fileName;
            }
        }
        return null;
    }

    private static String deriveSignedPathOnClient(String requestTitle, String documentFileName) {
        String originalName = firstNonBlank(documentFileName, requestTitle, 'signed-document');
        String baseName = originalName;
        if (originalName.toLowerCase().endsWith('.pdf')) {
            baseName = originalName.substring(0, originalName.length() - 4);
        }
        if (!baseName.toLowerCase().endsWith(' signed')) {
            baseName += ' signed';
        }
        return baseName + '.pdf';
    }

    private static String deriveContentVersionTitle(String pathOnClient) {
        if (String.isBlank(pathOnClient)) {
            return 'signed-document';
        }
        if (pathOnClient.toLowerCase().endsWith('.pdf') && pathOnClient.length() > 4) {
            return pathOnClient.substring(0, pathOnClient.length() - 4);
        }
        return pathOnClient;
    }

    private static String deriveContentType(ContentVersion version, String fileName) {
        String extension;
        if (!String.isBlank(fileName) && fileName.contains('.')) {
            Integer lastDot = fileName.lastIndexOf('.');
            if (lastDot >= 0 && lastDot < fileName.length() - 1) {
                extension = fileName.substring(lastDot + 1).toLowerCase();
            }
        }
        if (String.isBlank(extension) && version != null && !String.isBlank(version.FileType)) {
            extension = version.FileType.toLowerCase();
        }

        Map<String, String> mimeByExtension = new Map<String, String>{
            'pdf' => 'application/pdf',
            'doc' => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xls' => 'application/vnd.ms-excel',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'ppt' => 'application/vnd.ms-powerpoint',
            'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'txt' => 'text/plain',
            'csv' => 'text/csv',
            'png' => 'image/png',
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg'
        };

        if (!String.isBlank(extension) && mimeByExtension.containsKey(extension)) {
            return mimeByExtension.get(extension);
        }
        return 'application/octet-stream';
    }

    private static List<String> extractDocumentIds(Map<String, Object> uploadResponse) {
        List<String> documentIds = new List<String>();
        if (uploadResponse == null) {
            return documentIds;
        }

        List<Object> documents = (List<Object>) uploadResponse.get('documents');
        if (documents == null) {
            return documentIds;
        }

        for (Object rawDocument : documents) {
            Map<String, Object> document = asMap(rawDocument);
            String documentId = stringValue(document.get('id'));
            if (!String.isBlank(documentId)) {
                documentIds.add(documentId);
            }
        }
        return documentIds;
    }

    private static String buildUploadErrorMessage(String fileName, Exception uploadError) {
        String fallbackMessage = 'Upload failed for ' + fileName + '.';
        if (uploadError == null || String.isBlank(uploadError.getMessage())) {
            return fallbackMessage;
        }

        String apiDetail = extractApiErrorDetail(uploadError.getMessage());
        if (String.isBlank(apiDetail)) {
            return fallbackMessage + ' ' + uploadError.getMessage();
        }
        return 'Upload failed for ' + fileName + ': ' + apiDetail;
    }

    private static Boolean isOwnerOverrideDenied(Exception error) {
        if (error == null || String.isBlank(error.getMessage())) {
            return false;
        }

        String message = error.getMessage().toLowerCase();
        return message.contains('http 403') &&
            message.contains('another user as an owner of the e-sign');
    }

    private static String appendFallbackMessage(String existingMessage, String newMessage) {
        if (String.isBlank(newMessage)) {
            return existingMessage;
        }
        if (String.isBlank(existingMessage)) {
            return newMessage;
        }
        return existingMessage + ' ' + newMessage;
    }

    private static String extractApiErrorDetail(String message) {
        if (String.isBlank(message)) {
            return null;
        }

        Integer jsonStart = message.indexOf('{');
        if (jsonStart < 0) {
            return message;
        }

        String jsonPayload = message.substring(jsonStart);
        try {
            Object parsed = JSON.deserializeUntyped(jsonPayload);
            String extracted = firstErrorValue(parsed);
            return String.isBlank(extracted) ? message : extracted;
        } catch (Exception parseError) {
            return message;
        }
    }

    private static String firstErrorValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof String) {
            return String.valueOf(value);
        }
        if (value instanceof List<Object>) {
            for (Object item : (List<Object>) value) {
                String nested = firstErrorValue(item);
                if (!String.isBlank(nested)) {
                    return nested;
                }
            }
            return null;
        }
        if (value instanceof Map<Object, Object>) {
            for (String key : ((Map<String, Object>) value).keySet()) {
                String nested = firstErrorValue(((Map<String, Object>) value).get(key));
                if (!String.isBlank(nested)) {
                    return nested;
                }
            }
            return null;
        }
        return String.valueOf(value);
    }

    private static Datetime parseApiDatetime(Object rawValue) {
        if (rawValue == null) {
            return null;
        }

        String value = String.valueOf(rawValue).trim();
        if (String.isBlank(value)) {
            return null;
        }

        String normalized = value.replace('T', ' ');
        if (normalized.endsWith('Z')) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        Integer timezoneIndex = Math.max(normalized.lastIndexOf('+'), normalized.lastIndexOf('-'));
        if (timezoneIndex > 10 && timezoneIndex + 6 <= normalized.length()) {
            normalized = normalized.substring(0, timezoneIndex);
        }

        Integer dotIndex = normalized.indexOf('.');
        if (dotIndex > 0) {
            normalized = normalized.substring(0, dotIndex);
        }

        try {
            return Datetime.valueOfGmt(normalized);
        } catch (Exception firstError) {
            try {
                return Datetime.valueOf(normalized);
            } catch (Exception secondError) {
                return null;
            }
        }
    }

    private static String normalizeRole(String role) {
        return ZefortRoleUtil.normalizeRole(role);
    }

    private static List<Object> asList(Object value) {
        if (value == null) {
            return new List<Object>();
        }
        if (value instanceof List<Object>) {
            return (List<Object>) value;
        }
        return new List<Object>();
    }

    private static String firstNonBlank(String firstValue, String secondValue, String fallbackValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }
        if (!String.isBlank(secondValue)) {
            return secondValue;
        }
        return fallbackValue;
    }

    private static Boolean isLikelyEmail(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String candidate = value.trim();
        Integer atIndex = candidate.indexOf('@');
        if (atIndex <= 0 || atIndex != candidate.lastIndexOf('@')) {
            return false;
        }
        Integer dotIndex = candidate.lastIndexOf('.');
        return dotIndex > atIndex + 1 && dotIndex < candidate.length() - 1;
    }

    private static String normalizeRequestStatus(String status) {
        if (String.isBlank(status)) {
            return 'pending';
        }
        String normalized = status.toLowerCase();
        if (normalized == 'draft') {
            return 'draft';
        }
        if (normalized == 'completed') {
            return 'completed';
        }
        if (normalized == 'declined' || normalized == 'rejected') {
            return 'declined';
        }
        if (normalized == 'canceled' || normalized == 'cancelled') {
            return 'canceled';
        }
        if (normalized == 'expired') {
            return 'expired';
        }
        if (normalized == 'failed') {
            return 'failed';
        }
        return 'pending';
    }

    private static String deriveRequestStatus(String status, List<Object> rawParties) {
        String normalized = normalizeRequestStatus(status);
        if (normalized == 'pending' && hasPartyStatus(rawParties, 'bounced')) {
            return 'bounced';
        }
        return normalized;
    }

    private static String normalizePartyStatus(String status) {
        if (String.isBlank(status)) {
            return 'pending';
        }
        String normalized = status.toLowerCase();
        if (
            normalized == 'draft' ||
            normalized == 'pending' ||
            normalized == 'bounced' ||
            normalized == 'completed' ||
            normalized == 'declined' ||
            normalized == 'canceled' ||
            normalized == 'expired' ||
            normalized == 'failed' ||
            normalized == 'forwarded'
        ) {
            return normalized;
        }
        if (normalized == 'rejected') {
            return 'declined';
        }
        if (normalized == 'cancelled') {
            return 'canceled';
        }
        return 'pending';
    }

    private static Boolean hasPartyStatus(List<Object> rawParties, String expectedStatus) {
        if (rawParties == null || rawParties.isEmpty() || String.isBlank(expectedStatus)) {
            return false;
        }
        for (Object rawParty : rawParties) {
            Map<String, Object> party = asMap(rawParty);
            if (normalizePartyStatus(stringValue(party.get('status'))) == expectedStatus) {
                return true;
            }
        }
        return false;
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Map<String, Object> asMap(Object value) {
        if (value == null) {
            return new Map<String, Object>();
        }
        if (value instanceof Map<String, Object>) {
            return (Map<String, Object>) value;
        }
        if (value instanceof Map<Object, Object>) {
            Map<String, Object> normalized = new Map<String, Object>();
            Map<Object, Object> source = (Map<Object, Object>) value;
            for (Object key : source.keySet()) {
                normalized.put(String.valueOf(key), source.get(key));
            }
            return normalized;
        }
        return new Map<String, Object>();
    }

    private static List<Zefort_Sign_Request__c> castRequestRows(List<SObject> records) {
        List<Zefort_Sign_Request__c> rows = new List<Zefort_Sign_Request__c>();
        if (records == null) {
            return rows;
        }
        for (SObject recordValue : records) {
            rows.add((Zefort_Sign_Request__c) recordValue);
        }
        return rows;
    }

    private static List<Zefort_Sign_Request_Party__c> castPartyRows(List<SObject> records) {
        List<Zefort_Sign_Request_Party__c> rows = new List<Zefort_Sign_Request_Party__c>();
        if (records == null) {
            return rows;
        }
        for (SObject recordValue : records) {
            rows.add((Zefort_Sign_Request_Party__c) recordValue);
        }
        return rows;
    }

    private static void ensureObjectCreateable(Schema.SObjectType objectType, String message) {
        if (objectType == null || !objectType.getDescribe().isCreateable()) {
            throw new AuraHandledException(message);
        }
    }

    private static void ensureObjectUpdateable(Schema.SObjectType objectType, String message) {
        if (objectType == null || !objectType.getDescribe().isUpdateable()) {
            throw new AuraHandledException(message);
        }
    }

    private static void ensureObjectDeleteable(Schema.SObjectType objectType, String message) {
        if (objectType == null || !objectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(message);
        }
    }

    private static Id tryParseId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception e) {
            return null;
        }
    }
}