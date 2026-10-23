@IsTest
private class ZefortRegionTest {
    @IsTest
    static void testGetRegionDefaultsToSandbox() {
        delete [SELECT Id FROM ZefortSettings__c];

        String region = ZefortRegion.getRegion();
        System.assertEquals('sandbox', region);
    }

    @IsTest
    static void testSetRegionDedicatedRequiresDomain() {
        Boolean thrown = false;
        try {
            ZefortRegion.setRegion('dedicated', null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testSetRegionNormalizesAndStoresValues() {
        ZefortRegion.setRegion('  dedicated ', '  tenant.example.com  ');
        ZefortSettings__c settings = ZefortSettings__c.getInstance();
        System.assertEquals('dedicated', settings.Region__c);
        System.assertEquals('tenant.example.com', settings.CustomDomain__c);

        ZefortRegion.setRegion('EU', 'ignored.example.com');
        settings = ZefortSettings__c.getInstance();
        System.assertEquals('eu', settings.Region__c);
        System.assertEquals(null, settings.CustomDomain__c);
    }

    @IsTest
    static void testSetRegionRejectsUnsupportedValue() {
        Boolean thrown = false;
        try {
            ZefortRegion.setRegion('moon', null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void testRegionOptions() {
        Map<String, String> options = ZefortRegion.getRegionOptions();
        System.assertEquals('https://sandbox.zefort.com', options.get('sandbox'));
        System.assertEquals('https://my.zefort.com', options.get('eu'));
        System.assertEquals('https://us.zefort.com', options.get('us'));
        System.assertEquals('Custom Domain', options.get('dedicated'));
    }
}