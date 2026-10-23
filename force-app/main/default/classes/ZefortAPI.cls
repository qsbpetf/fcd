public with sharing class ZefortAPI {
    private class RequestContext {
        public String apiKey;
        public String region;
        public String customDomain;
    }

    /**
     * Gets contracts for a specific party (Account) from Zefort
     * @param partyId The Salesforce Account ID used as external_id in Zefort
     * @return Object containing the contract results or error message
     */
    @AuraEnabled(cacheable=true)
    public static Object getContractsForParty(String partyId) {
        try {
            if (String.isBlank(partyId)) {
                throw new AuraHandledException('Account ID is required');
            }
            
            // Get region settings and API key
            ZefortSettings__c settings = ZefortSettings__c.getInstance();
            String apiKey = ZefortAuthService.getUserApiKey();
            
            // Get region in a safe way that works during installation
            String region = ZefortRegion.getRegion();
            String customDomain = settings.CustomDomain__c;
            
            // First, look up the party in Zefort to get its internal ID
            Map<String, String> partyQueryParams = new Map<String, String>{
                'external_id' => partyId
            };
            
            Object partyResponse = ZefortService.makeZefortRequest(
                'parties/',     // endpoint 
                'GET',          // method
                null,           // no payload for GET
                partyQueryParams, // query params
                apiKey,         // API key
                region,         // region
                customDomain    // custom domain
            );
            
            Map<String, Object> partyData = (Map<String, Object>) partyResponse;
            List<Object> partyResults = (List<Object>) partyData.get('results');
            
            if (partyResults == null || partyResults.isEmpty()) {
                Map<String, Object> response = new Map<String, Object>{
                    'results' => new List<Object>(),
                    'message' => 'Party not found in Zefort'
                };
                return response;
            }
            
            // Find the party with matching external_id (Salesforce Account ID)
            String zefortPartyId = null;
            for (Object partyObj : partyResults) {
                Map<String, Object> party = (Map<String, Object>) partyObj;
                if (partyId.equals(party.get('external_id')) || partyId.equals(party.get('org_id'))) {
                    zefortPartyId = (String) party.get('id');
                    break;
                }
            }
            
            if (zefortPartyId == null) {
                Map<String, Object> response = new Map<String, Object>{
                    'results' => new List<Object>(),
                    'message' => 'Party not found in Zefort'
                };
                return response;
            }
            
            // Get contracts for specific party using the API's filtering capability
            // Use party parameter to filter contracts by party ID directly on the API side
            Map<String, String> contractQueryParams = new Map<String, String>{
                'party' => zefortPartyId
            };
            
            Object contractsResponse = ZefortService.makeZefortRequest(
                'contracts/',   // endpoint
                'GET',          // method
                null,           // no payload for GET
                contractQueryParams, // query params to filter by party
                apiKey,         // API key
                region,         // region (using the variable we set earlier)
                customDomain    // custom domain
            );
            
            // The response already contains only contracts for this party
            Map<String, Object> response = new Map<String, Object>{
                'results' => ((Map<String, Object>)contractsResponse).get('results')
            };
            return response;
            
        } catch (Exception e) {
            // Provide more specific error messages based on error type
            String userMessage = 'Error fetching contracts. Please verify your API key and try again.';
            if (e instanceof System.CalloutException) {
                userMessage = 'Connection error when contacting Zefort API. Please try again later.';
            } else if (e.getMessage().contains('API key')) {
                userMessage = 'Invalid API key. Please verify your Zefort API settings.';
            }
            
            throw new AuraHandledException(userMessage);
        }
    }
    
    /**
     * Creates or updates a party in Zefort based on a Salesforce Account
     * Using Zefort's update-or-create pattern
     * @param accountId The Salesforce Account ID
     * @return The created or updated party object from Zefort
     */
    @AuraEnabled
    public static Object createParty(String accountId) {
        try {
            if (String.isBlank(accountId)) {
                throw new AuraHandledException('Account ID is required');
            }
            
            // Get region settings and API key
            ZefortSettings__c settings = ZefortSettings__c.getInstance();
            String apiKey = ZefortAuthService.getUserApiKey();
            
            // Get region in a safe way that works during installation
            String region = ZefortRegion.getRegion();
            String customDomain = settings.CustomDomain__c;
            
            // Get Account details
            Account acc = [
                SELECT Id, Name, BillingCountry
                FROM Account
                WHERE Id = :accountId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            // Convert country name to ISO code if needed
            String countryCode = convertCountryNameToCode(acc.BillingCountry);

            // Create party payload
            Map<String, Object> partyPayload = new Map<String, Object>{
                'name' => acc.Name,
                'external_id' => accountId,                
                'managed' => true,
                'public' => true
            };
            
            // Only add country if we have a valid code
            if (!String.isBlank(countryCode)) {
                partyPayload.put('country', countryCode);
            }
            
            // Query parameters to check for existing party with this external_id
            Map<String, String> queryParams = new Map<String, String>{
                'external_id' => accountId
            };
            
            // Use PUT with query params for create-or-update pattern
            return ZefortService.makeZefortRequest(
                'parties/',     // endpoint
                'PUT',          // method for create-or-update
                partyPayload,   // payload
                queryParams,    // query params to check for existing party
                apiKey,         // API key
                region,         // region (using the variable we set earlier)
                customDomain    // custom domain
            );
        } catch (Exception e) {
            // Provide more specific error messages for better user experience
            String userMessage = 'Error creating party in Zefort.';
            if (e instanceof System.CalloutException) {
                userMessage = 'Connection error when contacting Zefort API. Please try again later.';
            } else if (e.getMessage().contains('API key')) {
                userMessage = 'API key error. Please check your Zefort settings.';
            }
            
            throw new AuraHandledException(userMessage);
        }
    }
    
    /**
     * Checks if a party exists in Zefort
     * @param accountId The Salesforce Account ID
     * @return Object containing whether the party exists and party details if found
     */
    @AuraEnabled(cacheable=true)
    public static Object checkParty(String accountId) {
        try {
            if (String.isBlank(accountId)) {
                throw new AuraHandledException('Account ID is required');
            }
            
            // Get region settings and API key
            ZefortSettings__c settings = ZefortSettings__c.getInstance();
            String apiKey = ZefortAuthService.getUserApiKey();
            
            // Get region in a safe way that works during installation
            String region = ZefortRegion.getRegion();
            String customDomain = settings.CustomDomain__c;
            
            Map<String, String> queryParams = new Map<String, String>{
                'external_id' => accountId
            };
            
            Object response = ZefortService.makeZefortRequest(
                'parties/',     // endpoint
                'GET',          // method
                null,           // no payload for GET
                queryParams,    // query params
                apiKey,         // API key
                region,         // region
                customDomain    // custom domain
            );
            
            if (response == null) {
                Map<String, Object> result = new Map<String, Object>{
                    'exists' => false,
                    'message' => 'No response from Zefort API'
                };
                return result;
            }
            
            Map<String, Object> partyData = (Map<String, Object>) response;
            List<Object> results = (List<Object>) partyData.get('results');
            
            // Check if any party has matching external_id
            if (results != null && !results.isEmpty()) {
                for (Object partyObj : results) {
                    if (partyObj == null) continue;
                    
                    try {
                        Map<String, Object> party = (Map<String, Object>) partyObj;
                        Object externalId = party.get('external_id');
                        
                        if (externalId != null && accountId.equals(externalId)) {
                            Map<String, Object> result = new Map<String, Object>{
                                'exists' => true,
                                'party' => party
                            };
                            return result;
                        }
                    } catch (Exception e) {
                        // Continue checking other results
                    }
                }
            }
            
            // No matching party found
            Map<String, Object> result = new Map<String, Object>{
                'exists' => false
            };
            return result;
        } catch (Exception e) {
            // Provide user-friendly error messages
            String userMessage = 'Error checking party in Zefort.';
            if (e instanceof System.CalloutException) {
                userMessage = 'Connection error when contacting Zefort API. Please try again later.';
            } else if (e.getMessage().contains('API key')) {
                userMessage = 'API key error. Please check your Zefort settings.';
            } else if (e instanceof AuraHandledException) {
                // Pass through AuraHandledExceptions as they're already user-friendly
                throw e;
            }
            
            throw new AuraHandledException(userMessage);
        }
    }

    public static Map<String, Object> createContract(String title) {
        RequestContext context = getRequestContext();
        Map<String, Object> payload = new Map<String, Object>();
        if (!String.isBlank(title)) {
            payload.put('title', title);
        }

        Object response = ZefortService.makeZefortRequest(
            'contracts/',
            'POST',
            payload,
            null,
            context.apiKey,
            context.region,
            context.customDomain
        );
        return asMap(response);
    }

    public static Map<String, Object> uploadContractFile(
        String contractId,
        String fileName,
        String contentType,
        Blob fileBlob
    ) {
        if (String.isBlank(contractId)) {
            throw new AuraHandledException('Contract ID is required.');
        }
        if (fileBlob == null) {
            throw new AuraHandledException('File content is required.');
        }

        RequestContext context = getRequestContext();
        Object response = ZefortService.makeZefortMultipartRequest(
            'contracts/' + contractId + '/add_file/',
            'POST',
            'blob',
            fileName,
            contentType,
            fileBlob,
            null,
            context.apiKey,
            context.region,
            context.customDomain
        );
        return asMap(response);
    }

    public static Map<String, Object> findZefortUserByEmail(String email) {
        Map<String, Object> emptyResult = new Map<String, Object>();
        if (String.isBlank(email)) {
            return emptyResult;
        }

        RequestContext context = getRequestContext();
        Map<String, String> queryParams = new Map<String, String>{
            'q' => email
        };
        Object response = ZefortService.makeZefortRequest(
            'users/',
            'GET',
            null,
            queryParams,
            context.apiKey,
            context.region,
            context.customDomain
        );
        Map<String, Object> body = asMap(response);

        List<Object> rows = (List<Object>) body.get('results');
        if (rows == null || rows.isEmpty()) {
            return emptyResult;
        }

        String wantedEmail = email.trim().toLowerCase();
        for (Object row : rows) {
            Map<String, Object> user = asMap(row);
            String candidateEmail = String.valueOf(user.get('email'));
            if (!String.isBlank(candidateEmail) && candidateEmail.trim().toLowerCase() == wantedEmail) {
                return user;
            }
        }

        return emptyResult;
    }

    public static Map<String, Object> createEsign(
        String contractId,
        String mainDocumentId,
        List<String> attachmentDocumentIds,
        List<Map<String, Object>> parties,
        String ownerId,
        String title
    ) {
        if (String.isBlank(contractId)) {
            throw new AuraHandledException('Contract ID is required.');
        }
        if (String.isBlank(mainDocumentId)) {
            throw new AuraHandledException('Main document ID is required.');
        }
        if (parties == null || parties.isEmpty()) {
            throw new AuraHandledException('At least one participant is required.');
        }

        List<Object> documents = new List<Object>{mainDocumentId};
        List<Object> attachments = new List<Object>();
        for (String attachmentId : attachmentDocumentIds == null ? new List<String>() : attachmentDocumentIds) {
            if (!String.isBlank(attachmentId)) {
                attachments.add(attachmentId);
            }
        }

        List<Object> partyPayload = new List<Object>();
        for (Map<String, Object> party : parties) {
            partyPayload.add(party);
        }

        Map<String, Object> payload = new Map<String, Object>{
            'contract' => contractId,
            'documents' => documents,
            'parties' => partyPayload
        };
        if (!attachments.isEmpty()) {
            payload.put('attachments', attachments);
        }
        if (!String.isBlank(ownerId)) {
            payload.put('owner', ownerId);
        }
        if (!String.isBlank(title)) {
            payload.put('title', title);
        }

        RequestContext context = getRequestContext();
        Object response = ZefortService.makeZefortRequest(
            'esigns/',
            'POST',
            payload,
            null,
            context.apiKey,
            context.region,
            context.customDomain
        );
        return asMap(response);
    }

    public static Map<String, Object> activateEsign(String esignId) {
        if (String.isBlank(esignId)) {
            throw new AuraHandledException('eSign ID is required.');
        }

        RequestContext context = getRequestContext();
        Object response = ZefortService.makeZefortRequest(
            'esigns/' + esignId + '/activate/',
            'POST',
            new Map<String, Object>(),
            null,
            context.apiKey,
            context.region,
            context.customDomain
        );
        return asMap(response);
    }

    public static Map<String, Object> getEsign(String esignId) {
        if (String.isBlank(esignId)) {
            throw new AuraHandledException('eSign ID is required.');
        }

        RequestContext context = getRequestContext();
        Object response = ZefortService.makeZefortRequest(
            'esigns/' + esignId + '/',
            'GET',
            null,
            null,
            context.apiKey,
            context.region,
            context.customDomain
        );
        return asMap(response);
    }

    public static Blob downloadSignedEsignDocument(String esignId, String documentId) {
        if (String.isBlank(esignId)) {
            throw new AuraHandledException('eSign ID is required.');
        }
        if (String.isBlank(documentId)) {
            throw new AuraHandledException('Document ID is required.');
        }

        RequestContext context = getRequestContext();
        return ZefortService.makeZefortBinaryRequest(
            'esigns/' + esignId + '/documents/' + documentId + '/download/',
            'GET',
            new Map<String, String>{ 'type' => 'signed' },
            context.apiKey,
            context.region,
            context.customDomain
        );
    }

    private static RequestContext getRequestContext() {
        ZefortSettings__c settings = ZefortSettings__c.getInstance();
        RequestContext context = new RequestContext();
        context.apiKey = ZefortAuthService.getUserApiKey();
        context.region = ZefortRegion.getRegion();
        context.customDomain = settings == null ? null : settings.CustomDomain__c;
        return context;
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
        throw new AuraHandledException('Unexpected response payload shape from Zefort API.');
    }
    
    /**
     * Converts a country name to a two-letter ISO code
     * @param countryName The country name
     * @return The two-letter ISO code or null if not found
     */
    private static String convertCountryNameToCode(String countryName) {
        if (String.isBlank(countryName)) {
            return null;
        }
        
        // This is a simplified mapping - in a real implementation, this would be more comprehensive
        // or use a custom metadata type for country mappings
        Map<String, String> countryCodeMap = new Map<String, String>{
            'United States' => 'US',
            'USA' => 'US',
            'United Kingdom' => 'GB',
            'UK' => 'GB',
            'Finland' => 'FI',
            'Sweden' => 'SE',
            'Norway' => 'NO',
            'Denmark' => 'DK',
            'Germany' => 'DE',
            'France' => 'FR',
            'Canada' => 'CA',
            'Australia' => 'AU',
            'Japan' => 'JP'
            // Add more countries as needed
        };
        
        // Check if the input is already a two-letter code
        if (countryName.length() == 2) {
            return countryName.toUpperCase();
        }
        
        // Look up in our map
        String code = countryCodeMap.get(countryName);
        if (code != null) {
            return code;
        }
        
        // If not found, as a fallback, return the original value
        // This may not work with the Zefort API, but it's better than returning null
        return countryName;
    }
}