@IsTest
private class ZefortServiceTest {
    private static Integer mockStatusCode = 200;
    private static String mockBody = '{}';
    private static Blob mockBodyBlob;
    private static Boolean mockThrowCallout = false;
    private static HttpRequest mockLastRequest;

    private class ConfigurableMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            mockLastRequest = req;
            if (mockThrowCallout) {
                throw new CalloutException('simulated callout failure');
            }

            HttpResponse response = new HttpResponse();
            response.setStatusCode(mockStatusCode);
            response.setHeader('Content-Type', 'application/json');
            if (mockBodyBlob != null) {
                response.setBodyAsBlob(mockBodyBlob);
            } else {
                response.setBody(mockBody);
            }
            return response;
        }
    }

    private static void resetMock() {
        mockStatusCode = 200;
        mockBody = '{}';
        mockBodyBlob = null;
        mockThrowCallout = false;
        mockLastRequest = null;
    }

    @IsTest
    static void testMakeZefortRequestBuildsUrlAndAuthorization() {
        resetMock();
        mockBody = '{"ok":true}';
        Test.setMock(HttpCalloutMock.class, new ConfigurableMock());

        Test.startTest();
        Map<String, Object> response = (Map<String, Object>) ZefortService.makeZefortRequest(
            'contracts/',
            null,
            null,
            new Map<String, String>{
                'q' => 'Jane Doe',
                'skip' => null
            },
            'api-key',
            'sandbox',
            null
        );
        Test.stopTest();

        System.assertEquals(true, response.get('ok'));
        System.assertEquals('GET', mockLastRequest.getMethod());
        System.assert(mockLastRequest.getEndpoint().contains('callout:ZefortAPI/contracts/?q=Jane+Doe'));
        System.assertEquals(
            'Basic ' + EncodingUtil.base64Encode(Blob.valueOf('api-key:')),
            mockLastRequest.getHeader('Authorization')
        );
    }

    @IsTest
    static void testMakeZefortRequestAddsBodyForWriteMethods() {
        resetMock();
        mockBody = '{"id":"123"}';
        Test.setMock(HttpCalloutMock.class, new ConfigurableMock());

        Test.startTest();
        ZefortService.makeZefortRequest(
            'parties/',
            'post',
            new Map<String, Object>{'name' => 'Acme'},
            null,
            'api-key',
            'eu',
            null
        );
        Test.stopTest();

        System.assertEquals('POST', mockLastRequest.getMethod());
        System.assert(mockLastRequest.getBody().contains('"name":"Acme"'));
    }

    @IsTest
    static void testMakeZefortRequestThrowsApiExceptionWithDetail() {
        resetMock();
        mockStatusCode = 400;
        mockBody = '{"error":"bad request"}';
        Test.setMock(HttpCalloutMock.class, new ConfigurableMock());

        Boolean thrown = false;
        try {
            Test.startTest();
            ZefortService.makeZefortRequest(
                'parties/',
                'GET',
                null,
                null,
                'api-key',
                'sandbox',
                null
            );
            Test.stopTest();
        } catch (Exception e) {
            thrown = true;
            System.assert(e instanceof ZefortService.ZefortApiException);
            System.assert(e.getMessage().contains('HTTP 400'));
            System.assert(e.getMessage().contains('bad request'));
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testMakeZefortRequestWrapsUnexpectedError() {
        resetMock();
        mockThrowCallout = true;
        Test.setMock(HttpCalloutMock.class, new ConfigurableMock());

        Boolean thrown = false;
        try {
            Test.startTest();
            ZefortService.makeZefortRequest(
                'parties/',
                'GET',
                null,
                null,
                'api-key',
                'sandbox',
                null
            );
            Test.stopTest();
        } catch (Exception e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testMakeZefortMultipartRequestUsesDefaults() {
        resetMock();
        mockBody = '{"documents":[{"id":"doc-1"}]}';
        Test.setMock(HttpCalloutMock.class, new ConfigurableMock());

        Test.startTest();
        Map<String, Object> response = (Map<String, Object>) ZefortService.makeZefortMultipartRequest(
            'contracts/1/add_file/',
            null,
            null,
            null,
            null,
            Blob.valueOf('abc'),
            new Map<String, String>{'foo' => 'bar'},
            'api-key',
            'us',
            null
        );
        Test.stopTest();

        String bodyString = mockLastRequest.getBodyAsBlob().toString();
        System.assertEquals('POST', mockLastRequest.getMethod());
        System.assert(mockLastRequest.getHeader('Content-Type').contains('multipart/form-data; boundary='));
        System.assert(mockLastRequest.getEndpoint().contains('callout:ZefortUS/contracts/1/add_file/?foo=bar'));
        System.assert(bodyString.contains('name="blob"'));
        System.assert(bodyString.contains('filename="upload.bin"'));
        System.assertEquals(1, ((List<Object>) response.get('documents')).size());
    }

    @IsTest
    static void testMakeZefortMultipartRequestThrowsApiException() {
        resetMock();
        mockStatusCode = 422;
        mockBody = '{"errors":["upload failed"]}';
        Test.setMock(HttpCalloutMock.class, new ConfigurableMock());

        Boolean thrown = false;
        try {
            Test.startTest();
            ZefortService.makeZefortMultipartRequest(
                'contracts/1/add_file/',
                'POST',
                'blob',
                'doc.pdf',
                'application/pdf',
                Blob.valueOf('abc'),
                null,
                'api-key',
                'sandbox',
                null
            );
            Test.stopTest();
        } catch (Exception e) {
            thrown = true;
            System.assert(e instanceof ZefortService.ZefortApiException);
            System.assert(e.getMessage().contains('HTTP 422'));
            System.assert(e.getMessage().contains('upload failed'));
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testMakeZefortBinaryRequestReturnsBlob() {
        resetMock();
        mockBodyBlob = Blob.valueOf('signed-pdf');
        Test.setMock(HttpCalloutMock.class, new ConfigurableMock());

        Test.startTest();
        Blob response = ZefortService.makeZefortBinaryRequest(
            'esigns/esign-1/documents/doc-main/download/',
            null,
            new Map<String, String>{ 'type' => 'signed' },
            'api-key',
            'sandbox',
            null
        );
        Test.stopTest();

        System.assertEquals('signed-pdf', response.toString());
        System.assertEquals('GET', mockLastRequest.getMethod());
        System.assert(
            mockLastRequest.getEndpoint().contains(
                'callout:ZefortAPI/esigns/esign-1/documents/doc-main/download/?type=signed'
            )
        );
        System.assertEquals(
            'Basic ' + EncodingUtil.base64Encode(Blob.valueOf('api-key:')),
            mockLastRequest.getHeader('Authorization')
        );
    }

    @IsTest
    static void testMakeZefortBinaryRequestThrowsApiException() {
        resetMock();
        mockStatusCode = 404;
        mockBody = '{"detail":"Document not found"}';
        Test.setMock(HttpCalloutMock.class, new ConfigurableMock());

        Boolean thrown = false;
        try {
            Test.startTest();
            ZefortService.makeZefortBinaryRequest(
                'esigns/esign-1/documents/doc-main/download/',
                'GET',
                new Map<String, String>{ 'type' => 'signed' },
                'api-key',
                'sandbox',
                null
            );
            Test.stopTest();
        } catch (Exception e) {
            thrown = true;
            System.assert(e instanceof ZefortService.ZefortApiException);
            System.assert(e.getMessage().contains('HTTP 404'));
            System.assert(e.getMessage().contains('Document not found'));
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testGetBaseAndUiBaseUrlVariants() {
        System.assertEquals('callout:ZefortAPI/', ZefortService.getBaseUrl(null, null));
        System.assertEquals('callout:ZefortEU/', ZefortService.getBaseUrl('eu', null));
        System.assertEquals('callout:ZefortUS/', ZefortService.getBaseUrl('us', null));
        System.assertEquals('https://dedicated.example.com/api/', ZefortService.getBaseUrl('dedicated', 'dedicated.example.com'));
        System.assertEquals('callout:ZefortAPI/', ZefortService.getBaseUrl('unknown', null));

        System.assertEquals('https://sandbox.zefort.com', ZefortService.getUiBaseUrl(null, null));
        System.assertEquals('https://my.zefort.com', ZefortService.getUiBaseUrl('eu', null));
        System.assertEquals('https://us.zefort.com', ZefortService.getUiBaseUrl('us', null));
        System.assertEquals('https://dedicated.example.com', ZefortService.getUiBaseUrl('dedicated', 'dedicated.example.com'));
        System.assertEquals('https://sandbox.zefort.com', ZefortService.getUiBaseUrl('unknown', null));
    }

    @IsTest
    static void testGetCurrentUiBaseUrlUsesSettings() {
        ZefortSettings__c settings = ZefortSettings__c.getInstance();
        settings.Region__c = 'dedicated';
        settings.CustomDomain__c = 'tenant.example.com';
        upsert settings;

        String url = ZefortService.getCurrentUiBaseUrl();
        System.assertEquals('https://tenant.example.com', url);
    }
}