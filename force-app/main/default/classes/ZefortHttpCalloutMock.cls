@IsTest
global class ZefortHttpCalloutMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        String endpoint = req.getEndpoint() == null ? '' : req.getEndpoint();
        String lowerEndpoint = endpoint.toLowerCase();
        String method = req.getMethod() == null ? 'GET' : req.getMethod().toUpperCase();

        if (lowerEndpoint.contains('/contracts/') && lowerEndpoint.contains('/add_file/')) {
            res.setBody('{"documents":[{"id":"doc-main"}]}');
        } else if (lowerEndpoint.contains('/contracts') && method == 'POST') {
            res.setBody('{"id":"contract-1"}');
        } else if (lowerEndpoint.contains('contracts') && lowerEndpoint.contains('party=')) {
            res.setBody('{"results": [{"id": "123", "attributes": {"title": "Test Contract"}, "status": "signed", "receive_time": "2023-01-01T10:00:00Z", "parties": [{"id": "party123", "name": "Test Party"}]}], "count": 1, "total": 1}');
        } else if (lowerEndpoint.contains('parties') && method == 'GET' && lowerEndpoint.contains('external_id=')) {
            res.setBody('{"results": [{"id": "party123", "name": "Test Party", "external_id": "test123", "country": "US"}], "count": 1, "total": 1}');
        } else if (lowerEndpoint.contains('parties') && method == 'PUT') {
            res.setBody('{"id": "party123", "name": "Test Party", "external_id": "test123"}');
        } else if (lowerEndpoint.contains('/users/')) {
            if (
                lowerEndpoint.contains('exact-match@example.com') ||
                lowerEndpoint.contains('exact-match%40example.com')
            ) {
                res.setBody('{"results":[{"id":"user-1","email":"exact-match@example.com"}]}');
            } else if (
                lowerEndpoint.contains('close-match@example.com') ||
                lowerEndpoint.contains('close-match%40example.com')
            ) {
                res.setBody('{"results":[{"id":"user-2","email":"other@example.com"}]}');
            } else {
                res.setBody('{"results":[]}');
            }
        } else if (lowerEndpoint.contains('/esigns/') && lowerEndpoint.contains('/documents/') && lowerEndpoint.contains('/download/')) {
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(Blob.valueOf('signed-pdf'));
        } else if (lowerEndpoint.contains('/esigns/') && lowerEndpoint.contains('/activate/')) {
            res.setBody(
                '{"id":"esign-1","title":"NDA","status":"pending","status_saved_at":"2026-01-01T00:00:00Z","documents":[{"id":"doc-main","filename":"NDA.pdf"}],"parties":[{"id":"party-1","name":"Jane Doe","email":"jane@example.com","role":"signer","status":"pending","status_saved_at":"2026-01-01T00:00:00Z"}]}'
            );
        } else if (lowerEndpoint.contains('/esigns/') && method == 'POST') {
            res.setBody('{"id":"esign-1"}');
        } else if (lowerEndpoint.contains('/esigns/') && method == 'GET') {
            res.setBody(
                '{"id":"esign-1","title":"NDA","status":"completed","status_saved_at":"2026-01-02T00:00:00Z","documents":[{"id":"doc-main","filename":"NDA.pdf"}],"parties":[{"id":"party-1","name":"Jane Doe","email":"jane@example.com","role":"signer","status":"completed","status_saved_at":"2026-01-02T00:00:00Z"}]}'
            );
        } else {
            res.setBody('{}');
        }

        res.setStatusCode(200);
        return res;
    }
}