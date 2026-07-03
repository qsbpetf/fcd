public class JiraTicketCreator {
    
    @InvocableMethod(label='Create Jira Ticket' description='Creates a Jira ticket for the given Opportunity')
    public static void createTicket(List<JiraRequest> requests) {
        JiraRequest req = requests[0];
        createTicketAsync(req.opportunityName, req.accountName);
    }
    
    @future(callout=true)
    public static void createTicketAsync(String oppName, String accountName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Jira_API/rest/api/2/issue');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        String body = '{"fields": {'
            + '"project": {"key": "PROJE_KEY"},'
            + '"summary": "' + oppName + ' - Sales Support Requested",'
            + '"description": "Opportunity: ' + oppName + '\\nAccount: ' + accountName + '",'
            + '"issuetype": {"name": "Task"}'
            + '}}';
        
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 201) {
            System.debug('Jira ticket creation failed: ' + res.getBody());
        }
    }
    
    public class JiraRequest {
        @InvocableVariable(required=true)
        public String opportunityName;
        
        @InvocableVariable(required=true)
        public String accountName;
    }
}