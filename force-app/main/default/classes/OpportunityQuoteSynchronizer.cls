/**
 * Classe permettant de lier une Opportunity et ses OLI a une Quote et ses QLI.
 * Pour savoir quels champs sont liés, elle utilise les tables MappageOpportuniteDevis__c et MappageOliQli__c.
 * @version 1.0.0
 * @historic
 * 1.0.0 12/06/2022 Première version.
 * @author AF
 * @test OpportunityQuoteSynchronizerTest
 */
public without sharing class OpportunityQuoteSynchronizer
{
    /// Mapping entre Opportunity et Quote.
    public static Map<String, String> getParentsMapping()
    {
        Map<String, String> quoteFieldsByOpportunityFields = new Map<String, String>();

        for(MappageOpportuniteDevis__c mapping : [
            SELECT Id, Name, ChampDevis__c
            FROM MappageOpportuniteDevis__c
        ])
        {
            quoteFieldsByOpportunityFields.put(
                mapping.Name,
                mapping.ChampDevis__c
            );
        }

        return quoteFieldsByOpportunityFields;
    }

    /// Mapping entre OLI et QLI.
    public static Map<String, String> getChildrenMapping()
    {
        Map<String, String> qliFieldsByOliFields = new Map<String, String>();

        for(MappageOliQli__c mapping : [
            SELECT Id, Name, ChampLigneDeDevis__c
            FROM MappageOliQli__c
        ])
        {
            qliFieldsByOliFields.put(
                mapping.Name,
                mapping.ChampLigneDeDevis__c
            );
        }

        return qliFieldsByOliFields;
    }

    public static void copyOpportunityInQuote(Opportunity opp, Quote q, Map<String, String> quoteFieldsByOpportunityFields)
    {
        for(String opportunityField : quoteFieldsByOpportunityFields.keySet())
        {
            q.put(
                quoteFieldsByOpportunityFields.get(opportunityField),
                opp.get(opportunityField)
            );
        }
    }

    public static QuoteLineItem fillQliWithOli(QuoteLineItem qli, OpportunityLineItem oli, Map<String, String> qliFieldsByOliFields)
    {
        for(String oliField : qliFieldsByOliFields.keySet())
        {
            qli.put(
                qliFieldsByOliFields.get(oliField),
                oli.get(oliField)
            );
        }

        return qli;
    }

    public static OpportunityLineItem generateOliFromQli(QuoteLineItem qli, Map<String, String> qliFieldsByOliFields)
    {
        OpportunityLineItem oli = new OpportunityLineItem(
            Id = qli.OpportunityLineItemId
        );

        for(String oliField : qliFieldsByOliFields.keySet())
        {
            oli.put(
                oliField,
                qli.get(qliFieldsByOliFields.get(oliField))
            );
        }

        return oli;
    }

    public static Opportunity generateOpportunityFromQuote(Quote q, Map<String, String> quoteFieldsByOpportunityFields)
    {
        Opportunity opp = new Opportunity(
            Id = q.OpportunityId
        );

        for(String opportunityField : quoteFieldsByOpportunityFields.keySet())
        {
            opp.put(
                opportunityField,
                q.get(quoteFieldsByOpportunityFields.get(opportunityField))
            );
        }

        return opp;
    }

    public static List<Opportunity> queryOpportunities(Set<Id> opportunityIds, Map<String, String> parentsMapping)
    {
        List<String> parentFields = new List<String>(parentsMapping.keySet());
        parentFields.add('Id');
        String query = 'SELECT ' + String.join(parentFields, ',')
        + ' FROM Opportunity WHERE Id IN :opportunityIds';
        
        return (List<Opportunity>)Database.query(query);
    }

    public static List<OpportunityLineItem> queryOpportunityLineItems(Set<Id> oliIds, Map<String, String> childrenMapping)
    {
        List<String> childFields = new List<String>(childrenMapping.keySet());
        childFields.add('PricebookEntryId');
        childFields.add('Quantity');
        childFields.add('UnitPrice');
        childFields.add('Product2Id');
        String query = 'SELECT ' + String.join(childFields, ',') + ' FROM OpportunityLineItem WHERE Id IN :oliIds';
        
        return (List<OpportunityLineItem>)Database.query(query);
    }

    public static List<Quote> queryQuoteLineItems(Set<Id> quoteIds, Map<String, String> mapping)
    {
        List<String> fields = new List<String>(mapping.values());
        fields.add('OpportunityLineItemId');
        String query = 'SELECT (SELECT ' + String.join(fields, ',') + ' FROM QuoteLineItems)'
        + ' FROM Quote WHERE Id IN :quoteIds';

        return (List<Quote>)Database.query(query);
    }

    public static List<Quote> queryQuoteLineItems(Set<Id> quoteIds, Set<Id> oliIds, Map<String, String> mapping)
    {
        List<String> fields = new List<String>(mapping.values());
        fields.add('OpportunityLineItemId');
        String query = 'SELECT (SELECT ' + String.join(fields, ',') + ' FROM QuoteLineItems WHERE OpportunityLineItemId IN :oliIds) FROM Quote WHERE Id IN :quoteIds';

        return (List<Quote>)Database.query(query);
    }

    public static void newQuotes(List<Quote> quotes)
    {
        Set<Id> opportunityIds = new Set<Id>();
        for(Quote q : quotes)
            opportunityIds.add(q.OpportunityId);

        Map<String, String> parentsMapping = getParentsMapping();
        Map<Id, Opportunity> opportunities;
        
        opportunities = new Map<Id, Opportunity>(queryOpportunities(
            opportunityIds,
            parentsMapping
        ));

        Opportunity opp;
        for(Quote q : quotes)
        {
            opp = opportunities.get(q.OpportunityId);
            copyOpportunityInQuote(opp, q, parentsMapping);
        }
    }

    public static void newQuoteLineItems(List<QuoteLineItem> qlis)
    {
        List<QuoteLineItem> syncedQlis = new List<QuoteLineItem>();
        Set<Id> oliIds = new Set<Id>();
        for(QuoteLineItem qli : qlis)
        {
            if(qli.OpportunityLineItemId != null)
            {
                oliIds.add(qli.OpportunityLineItemId);
                syncedQlis.add(qli);
            }
        }

        Map<String, String> childrenMapping = getChildrenMapping();
        
        Map<Id, OpportunityLineItem> olis = new Map<Id, OpportunityLineItem>(queryOpportunityLineItems(
            oliIds,
            childrenMapping
        ));

        // System.assertNotEquals(0, existingQliIdsByOliIds.size());

        for(QuoteLineItem qli : syncedQlis)
        {
            fillQliWithOli(
                qli, olis.get(qli.OpportunityLineItemId), childrenMapping
            );
        }
    }

    public static void quotesUpdated(List<Quote> quotes, Map<Id, Quote> olds)
    {
        List<Quote> syncQuotes = new List<Quote>();
        Set<Id> quoteIds = new Set<Id>();
        for(Quote q : quotes)
        {
            if(q.IsSyncing == true && olds.get(q.Id).IsSyncing == false)
            {
                quoteIds.add(q.Id);
                syncQuotes.add(q);
            }
        }

        if(syncQuotes.isEmpty())
            return;

        Map<String, String> parentsMapping = getParentsMapping();
        Map<String, String> childrenMapping =  getChildrenMapping();
        List<Opportunity> opportunities = new List<Opportunity>();
        List<OpportunityLineItem> items = new List<OpportunityLineItem>();
        Map<Id, Quote> quoteLineItems = new Map<Id, Quote>(queryQuoteLineItems(quoteIds, childrenMapping));

        for(Quote q : syncQuotes)
        {
            opportunities.add(
                generateOpportunityFromQuote(q, parentsMapping)
            );

            for(QuoteLineItem qli : quoteLineItems.get(q.Id).QuoteLineItems)
            {
                if(qli.OpportunityLineItemId != null)
                    items.add(generateOliFromQli(qli, childrenMapping));
            }
        }

        update opportunities;
        update items;
    }

    public static void quoteLinesUpdated(List<QuoteLineItem> qlis, Map<Id, QuoteLineItem> olds)
    {
        Map<String, String> mapping = getChildrenMapping();
        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        for(QuoteLineItem qli : qlis)
        {
            if(qli.OpportunityLineItemId != null)
            {
                generateOliFromQli(qli, mapping);
            }
        }
        update olis;
    }

    public static void newOpportunityLineItems(List<OpportunityLineItem> olis)
    {
        Set<Id> quoteIds = new Set<Id>();
        for(OpportunityLineItem oli : [
            SELECT Opportunity.SyncedQuoteId FROM OpportunityLineItem WHERE Id IN :olis
        ])
            quoteIds.add(oli.Opportunity.SyncedQuoteId);

        Map<String, String> mapping = OpportunityQuoteSynchronizer.getChildrenMapping();
        List<OpportunityLineItem> items = new List<OpportunityLineItem>();

        for(Quote q : queryQuoteLineItems(quoteIds, Trigger.newMap.keySet(), mapping))
        {
            for(QuoteLineItem qli : q.QuoteLineItems)
            {
                items.add(OpportunityQuoteSynchronizer.generateOliFromQli(qli, mapping));
            }
        }

        update items;
    }

    // création d'un devis = copy opportunité dans devis (avec OLI)
    // devis synchronisé = copy du devis dans l'opportunité (avec QLI : màj, création, suppression)
}