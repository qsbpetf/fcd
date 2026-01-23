/**
 * Created for promo code matching functionality.
 * Matches quote line items against active promo codes using the same product mapping logic as the import process.
 */
public with sharing class PromoCodeMatcher {

    /**
     * Get matching promo codes for a quote.
     * Uses the same product mapping logic as PpcOpportunityProductMapper to ensure
     * we match against the Product2 records that will be used for OpportunityLineItems.
     * 
     * @param quoteInfoJson JSON string representation of PortalCommerceApiQuotes.QuoteInfo
     * @return List of PromoCodeMatch objects containing matching promo codes and product information
     */
    @AuraEnabled(cacheable=false)
    public static List<PromoCodeMatch> getMatchingPromoCodes(String quoteInfoJson) {
        try {
            // Deserialize the quote info
            PortalCommerceApiQuotes.QuoteInfo quoteInfo = (PortalCommerceApiQuotes.QuoteInfo) JSON.deserialize(
                quoteInfoJson, 
                PortalCommerceApiQuotes.QuoteInfo.class
            );

            if (quoteInfo == null || quoteInfo.upcomingBills == null || 
                quoteInfo.upcomingBills.lines == null || quoteInfo.upcomingBills.lines.isEmpty()) {
                return new List<PromoCodeMatch>();
            }

            // Step 1: Use same mapping as import process
            PpcPortalProductMapper portalProductMapper = PpcPortalProductMapper.getInstance();
            Map<String, Product2> mappedProducts = new Map<String, Product2>();
            Set<Id> productIds = new Set<Id>();

            for (PortalCommerceApiQuotes.BillLineItem quoteLine : quoteInfo.upcomingBills.lines) {
                PortalProductMapper.MappingResult mapResult = portalProductMapper.mapProduct(quoteLine.description);
                if (mapResult.found && mapResult.product != null) {
                    mappedProducts.put(quoteLine.description, mapResult.product);
                    productIds.add(mapResult.product.Id);
                }
            }

            if (productIds.isEmpty()) {
                // No products mapped, no matches possible
                return new List<PromoCodeMatch>();
            }

            // Step 2: Query Product2 records that will become OpportunityLineItems
            Map<Id, Product2> productsById = new Map<Id, Product2>([
                SELECT Id, Name, Family
                FROM Product2
                WHERE Id IN :productIds
            ]);

            // Step 3: Query all active PromotionCode__c records
            List<PromotionCode__c> activePromoCodes = [
                SELECT Id, PromoCode__c, Partner__c, SearchString__c,
                       Platform__c, Edition__c,
                       CodeUrl__c, StartDate__c, EndDate__c, IsActive__c
                FROM PromotionCode__c
                WHERE IsActive__c = true
                AND SearchString__c != null
                AND SearchString__c != ''
            ];

            if (activePromoCodes.isEmpty()) {
                return new List<PromoCodeMatch>();
            }

            // Step 4: Build a map of SearchString to List of PromotionCode__c for efficient lookup
            Map<String, List<PromotionCode__c>> promoCodeMap = new Map<String, List<PromotionCode__c>>();
            for (PromotionCode__c promoCode : activePromoCodes) {
                String searchString = promoCode.SearchString__c;
                if (String.isBlank(searchString)) {
                    continue;
                }
                if (!promoCodeMap.containsKey(searchString)) {
                    promoCodeMap.put(searchString, new List<PromotionCode__c>());
                }
                promoCodeMap.get(searchString).add(promoCode);
            }

            // Step 5: Match SearchString__c against quote line item product name using the map.
            // Ensure each promo code is returned only once even if it matches multiple lines.
            List<PromoCodeMatch> matches = new List<PromoCodeMatch>();
            Set<Id> addedPromoCodeIds = new Set<Id>();
            
            for (PortalCommerceApiQuotes.BillLineItem quoteLine : quoteInfo.upcomingBills.lines) {
                // Prefer the explicit productName from the quote line; fall back to description if needed
                String lineProductName = String.isNotBlank(quoteLine.productName)
                    ? quoteLine.productName
                    : quoteLine.description;
                if (String.isBlank(lineProductName)) {
                    continue;
                }

                // Check each search string against the product name
                for (String searchString : promoCodeMap.keySet()) {
                    // Case-insensitive contains matching
                    if (lineProductName.containsIgnoreCase(searchString)) {
                        // Match found! Add all promo codes with this search string
                        for (PromotionCode__c promoCode : promoCodeMap.get(searchString)) {
                            // Skip if we've already added this promo code from another line or match
                            if (addedPromoCodeIds.contains(promoCode.Id)) {
                                continue;
                            }

                            // Respect optional Platform__c and Edition__c filters.
                            // If they are set on the promo code, they MUST match the quote line.
                            if (!matchesPlatformFilter(promoCode.Platform__c, lineProductName)) {
                                continue;
                            }
                            if (!matchesEditionFilter(promoCode.Edition__c, lineProductName)) {
                                continue;
                            }

                            PromoCodeMatch match = new PromoCodeMatch();
                            match.promoCode = promoCode;
                            match.matchedProductName = lineProductName;
                            match.quoteLineDescription = quoteLine.description;
                            match.searchString = searchString;
                            matches.add(match);
                            addedPromoCodeIds.add(promoCode.Id);
                        }
                    }
                }
            }

            return matches;

        } catch (Exception e) {
            System.debug('Error in PromoCodeMatcher.getMatchingPromoCodes: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Return empty list on error - don't break the UI
            return new List<PromoCodeMatch>();
        }
    }

    /**
     * Check if the quote line product name matches the optional Platform__c filter.
     * If platformFilter is blank, it always matches.
     */
    private static Boolean matchesPlatformFilter(String platformFilter, String lineProductName) {
        if (String.isBlank(platformFilter)) {
            return true;
        }
        String nameLower = lineProductName.toLowerCase();
        String platformLower = platformFilter.toLowerCase();

        if (platformLower == 'cloud') {
            return nameLower.contains('cloud');
        }
        if (platformLower == 'datacenter') {
            // Allow both \"datacenter\" and \"data center\"
            return nameLower.contains('datacenter') || nameLower.contains('data center');
        }
        if (platformLower == 'services') {
            return nameLower.contains('service');
        }
        // Fallback: generic contains
        return nameLower.contains(platformLower);
    }

    /**
     * Check if the quote line product name matches the optional Edition__c filter.
     * If editionFilter is blank, it always matches.
     */
    private static Boolean matchesEditionFilter(String editionFilter, String lineProductName) {
        if (String.isBlank(editionFilter)) {
            return true;
        }
        String nameLower = lineProductName.toLowerCase();
        String editionLower = editionFilter.toLowerCase();
        return nameLower.contains(editionLower);
    }

    /**
     * Wrapper class to return promo code matches with product context.
     */
    public class PromoCodeMatch {
        @AuraEnabled public PromotionCode__c promoCode;
        @AuraEnabled public String matchedProductName;        // Quote line product name / description
        @AuraEnabled public String quoteLineDescription;      // Original quote line description
        @AuraEnabled public String searchString;              // The SearchString that matched
    }
}
