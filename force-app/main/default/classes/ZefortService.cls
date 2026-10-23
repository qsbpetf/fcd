public with sharing class ZefortService {
    private static final Integer ZEFORT_CALLOUT_TIMEOUT_MS = 120000;
    
    /**
     * Makes a direct request to the Zefort API
     * @param endpoint API endpoint path (e.g. 'contracts/' or 'parties/')
     * @param method HTTP method (GET, POST, etc.)
     * @param payload Request payload for POST/PUT requests
     * @param queryParams Query parameters for GET requests
     * @param apiKey Zefort API key
     * @param region Zefort region (sandbox, eu, us, or dedicated)
     * @param customDomain Custom domain for dedicated instances
     * @return Deserialized API response
     */
    @AuraEnabled
    public static Object makeZefortRequest(String endpoint, String method, 
                                          Object payload, Map<String, String> queryParams, 
                                          String apiKey, String region, String customDomain) {
        try {
            Http http = new Http();
            HttpRequest httpRequest = new HttpRequest();
            String normalizedMethod = String.isBlank(method)
                ? 'GET'
                : method.trim().toUpperCase();
            
            // Construct base URL based on region
            String baseUrl = getBaseUrl(region, customDomain);
            String fullUrl = buildUrl(baseUrl + endpoint, queryParams);
            
            httpRequest.setEndpoint(fullUrl);
            httpRequest.setMethod(normalizedMethod);
            httpRequest.setHeader('Content-Type', 'application/json');
            httpRequest.setHeader('Accept', 'application/json');
            httpRequest.setTimeout(ZEFORT_CALLOUT_TIMEOUT_MS);
            
            // Set auth header with API key using basic auth
            if (apiKey != null) {
                Blob headerValue = Blob.valueOf(apiKey + ':');
                String authHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
                httpRequest.setHeader('Authorization', authHeader);
            }
            
            // Add payload for POST/PUT requests
            if (
                (normalizedMethod == 'POST' || normalizedMethod == 'PUT' || normalizedMethod == 'PATCH') &&
                payload != null
            ) {
                String requestBody = JSON.serialize(payload);
                httpRequest.setBody(requestBody);
            }
            
            HttpResponse response = http.send(httpRequest);
            
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                return JSON.deserializeUntyped(response.getBody());
            } else {
                throw buildZefortApiException(response);
            }
        } catch (Exception e) {
            if (e instanceof ZefortApiException) {
                throw e;
            }
            throw new AuraHandledException('Error while calling Zefort API: ' + e.getMessage());
        }
    }

    /**
     * Makes a multipart/form-data request to the Zefort API.
     * Used for endpoints that accept binary file payloads (e.g. contracts/{id}/add_file/).
     */
    public static Object makeZefortMultipartRequest(
        String endpoint,
        String method,
        String fieldName,
        String fileName,
        String contentType,
        Blob fileBlob,
        Map<String, String> queryParams,
        String apiKey,
        String region,
        String customDomain
    ) {
        try {
            Http http = new Http();
            HttpRequest httpRequest = new HttpRequest();

            String baseUrl = getBaseUrl(region, customDomain);
            String fullUrl = buildUrl(baseUrl + endpoint, queryParams);

            String normalizedMethod = String.isBlank(method)
                ? 'POST'
                : method.trim().toUpperCase();
            String boundary = '--------------------------' + String.valueOf(Math.abs(Crypto.getRandomLong()));

            httpRequest.setEndpoint(fullUrl);
            httpRequest.setMethod(normalizedMethod);
            httpRequest.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            httpRequest.setHeader('Accept', 'application/json');
            httpRequest.setTimeout(ZEFORT_CALLOUT_TIMEOUT_MS);

            if (apiKey != null) {
                Blob headerValue = Blob.valueOf(apiKey + ':');
                String authHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
                httpRequest.setHeader('Authorization', authHeader);
            }

            Blob requestBody = buildMultipartBody(
                boundary,
                String.isBlank(fieldName) ? 'blob' : fieldName,
                fileName,
                contentType,
                fileBlob
            );
            httpRequest.setBodyAsBlob(requestBody);

            HttpResponse response = http.send(httpRequest);
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                return JSON.deserializeUntyped(response.getBody());
            }

            throw buildZefortApiException(response);
        } catch (Exception e) {
            if (e instanceof ZefortApiException) {
                throw e;
            }
            throw new AuraHandledException('Error while calling Zefort API: ' + e.getMessage());
        }
    }

    /**
     * Makes a request to the Zefort API and returns the raw binary response body.
     */
    public static Blob makeZefortBinaryRequest(
        String endpoint,
        String method,
        Map<String, String> queryParams,
        String apiKey,
        String region,
        String customDomain
    ) {
        try {
            Http http = new Http();
            HttpRequest httpRequest = new HttpRequest();
            String normalizedMethod = String.isBlank(method)
                ? 'GET'
                : method.trim().toUpperCase();

            String baseUrl = getBaseUrl(region, customDomain);
            String fullUrl = buildUrl(baseUrl + endpoint, queryParams);

            httpRequest.setEndpoint(fullUrl);
            httpRequest.setMethod(normalizedMethod);
            httpRequest.setHeader('Accept', 'application/pdf, application/octet-stream');
            httpRequest.setTimeout(ZEFORT_CALLOUT_TIMEOUT_MS);

            if (apiKey != null) {
                Blob headerValue = Blob.valueOf(apiKey + ':');
                String authHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
                httpRequest.setHeader('Authorization', authHeader);
            }

            HttpResponse response = http.send(httpRequest);
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                return response.getBodyAsBlob();
            }

            throw buildZefortApiException(response);
        } catch (Exception e) {
            if (e instanceof ZefortApiException) {
                throw e;
            }
            throw new AuraHandledException('Error while calling Zefort API: ' + e.getMessage());
        }
    }
    
    /**
     * Get the base URL for the Zefort API based on region and custom domain
     * @param region Zefort region (sandbox, eu, us, or dedicated)
     * @param customDomain Custom domain for dedicated instances
     * @return Base URL for Zefort API
     */
    @AuraEnabled
    public static String getBaseUrl(String region, String customDomain) {
        // Handle null/empty region (for new installations)
        if (String.isBlank(region)) {
            region = 'sandbox'; // Default to sandbox
        }
        
        if (region == 'dedicated' && !String.isBlank(customDomain)) {
            return 'https://' + customDomain + '/api/';
        }
        
        // Prefer Named Credentials for managed endpoints.
        Map<String, String> baseUrls = new Map<String, String>{
            'sandbox' => 'callout:ZefortAPI/',
            'eu' => 'callout:ZefortEU/',
            'us' => 'callout:ZefortUS/'
        };
        
        String baseUrl = baseUrls.get(region);
        if (baseUrl == null) {
            // Default to sandbox if region is invalid
            baseUrl = baseUrls.get('sandbox');
        }
        
        return baseUrl;
    }
    
    
    /**
     * Get the base URL for the Zefort UI (without /api/ suffix)
     * @param region Zefort region (sandbox, eu, us, or dedicated)
     * @param customDomain Custom domain for dedicated instances
     * @return Base URL for Zefort UI
     */
    @AuraEnabled
    public static String getUiBaseUrl(String region, String customDomain) {
        // Handle null/empty region (for new installations)
        if (String.isBlank(region)) {
            region = 'sandbox'; // Default to sandbox
        }
        
        if (region == 'dedicated' && !String.isBlank(customDomain)) {
            return 'https://' + customDomain;
        }
        
        Map<String, String> baseUrls = new Map<String, String>{
            'sandbox' => 'https://sandbox.zefort.com',
            'eu' => 'https://my.zefort.com',
            'us' => 'https://us.zefort.com'
        };
        
        String baseUrl = baseUrls.get(region);
        if (baseUrl == null) {
            // Default to sandbox if region is invalid
            baseUrl = baseUrls.get('sandbox');
        }
        
        return baseUrl;
    }

    /**
     * Returns the UI base URL for the current org settings.
     * This avoids clients needing to fetch region and custom domain separately.
     */
    @AuraEnabled(cacheable=true)
    public static String getCurrentUiBaseUrl() {
        ZefortSettings__c settings = ZefortSettings__c.getInstance();
        String region = ZefortRegion.getRegion();
        String customDomain = settings != null ? settings.CustomDomain__c : null;
        return getUiBaseUrl(region, customDomain);
    }

    private static String buildUrl(String baseUrl, Map<String, String> queryParams) {
        String fullUrl = baseUrl;
        if (queryParams == null || queryParams.isEmpty()) {
            return fullUrl;
        }

        Boolean isFirstParam = true;
        for (String key : queryParams.keySet()) {
            String value = queryParams.get(key);
            if (value == null) {
                continue;
            }
            fullUrl +=
                (isFirstParam ? '?' : '&') +
                key +
                '=' +
                EncodingUtil.urlEncode(value, 'UTF-8');
            isFirstParam = false;
        }
        return fullUrl;
    }

    private static Blob buildMultipartBody(
        String boundary,
        String fieldName,
        String fileName,
        String contentType,
        Blob fileBlob
    ) {
        String safeFieldName = String.isBlank(fieldName) ? 'blob' : fieldName;
        String safeFileName = String.isBlank(fileName) ? 'upload.bin' : fileName;
        safeFileName = safeFileName.replace('"', '\'');
        String safeContentType = String.isBlank(contentType)
            ? 'application/octet-stream'
            : contentType;
        Blob safeBlob = fileBlob == null ? Blob.valueOf('') : fileBlob;

        String prefix =
            '--' +
            boundary +
            '\r\n' +
            'Content-Disposition: form-data; name="' +
            safeFieldName +
            '"; filename="' +
            safeFileName +
            '"\r\n' +
            'Content-Type: ' +
            safeContentType +
            '\r\n\r\n';
        String suffix = '\r\n--' + boundary + '--\r\n';

        String bodyHex =
            EncodingUtil.convertToHex(Blob.valueOf(prefix)) +
            EncodingUtil.convertToHex(safeBlob) +
            EncodingUtil.convertToHex(Blob.valueOf(suffix));
        return EncodingUtil.convertFromHex(bodyHex);
    }

    private static ZefortApiException buildZefortApiException(HttpResponse response) {
        Integer statusCode = response == null ? 0 : response.getStatusCode();
        String detail = response == null ? null : extractApiErrorDetail(response.getBody());
        String message = 'Error calling Zefort API: HTTP ' + statusCode;
        if (!String.isBlank(detail)) {
            message += ' ' + detail;
        }
        return new ZefortApiException(message);
    }

    private static String extractApiErrorDetail(String body) {
        if (String.isBlank(body)) {
            return null;
        }

        try {
            Object parsed = JSON.deserializeUntyped(body);
            String extracted = firstErrorValue(parsed);
            return String.isBlank(extracted) ? null : extracted;
        } catch (Exception parseError) {
            return null;
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

    /**
     * Custom exception for Zefort API errors
     */
    public class ZefortApiException extends Exception {}
}