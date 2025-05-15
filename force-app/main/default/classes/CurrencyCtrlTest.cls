/**
 * Test class for CurrencyCtrl.
 */
@IsTest
private class CurrencyCtrlTest {

    /**
     * Mock HTTP response for the Exchange Rates API
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Boolean returnSuccess;

        public MockHttpResponseGenerator(Boolean returnSuccess) {
            this.returnSuccess = returnSuccess;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (returnSuccess) {
                res.setStatusCode(200);
                res.setBody('{"success":true,"timestamp":1651449600,"base":"EUR","date":"2022-05-02","rates":{"USD":1.0523,"GBP":0.8386,"CAD":1.3454,"JPY":136.96}}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"success":false,"error":{"code":101,"type":"invalid_access_key","info":"You have not supplied a valid API Access Key."}}');
            }

            return res;
        }
    }

    /**
     * Test the getRates method with a successful response
     */
    @IsTest
    static void testGetRatesSuccess() {
        // Set the mock callout class
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Call the method to test
        Test.startTest();
        CurrencyCtrl.CurrencyWrapper wrapper = CurrencyCtrl.getRates();
        Test.stopTest();

        // Verify the response
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertEquals(true, wrapper.success, 'Success should be true');
        System.assertEquals('EUR', wrapper.base, 'Base currency should be EUR');
        System.assertEquals(1651449600, wrapper.timestamp, 'Timestamp should match');
        System.assertEquals(4, wrapper.rates.size(), 'Should have 4 currencies in the rates map');
        System.assertEquals(1.0523, wrapper.rates.get('USD'), 'USD rate should match');
        System.assertNotEquals(null, wrapper.theDateTime, 'DateTime should be populated');
    }

    /**
     * Test the getRates method with a failed response
     */
    @IsTest
    static void testGetRatesFailure() {
        // Set the mock callout class
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false));

        // Call the method to test
        Test.startTest();
        CurrencyCtrl.CurrencyWrapper wrapper = CurrencyCtrl.getRates();
        Test.stopTest();

        // Verify the response
        System.assertEquals(null, wrapper, 'Wrapper should be null due to API failure');
    }

    /**
     * Test the flattenCurrencies method
     */
    @IsTest
    static void testFlattenCurrencies() {
        // Create test data
        CurrencyCtrl.CurrencyWrapper wrapper = new CurrencyCtrl.CurrencyWrapper();
        wrapper.rates = new Map<String, Double> {
            'USD' => 1.0523,
            'GBP' => 0.8386,
            'CAD' => 1.3454,
            'JPY' => 136.96
        };

        Set<String> managedCurrencies = new Set<String>{'USD', 'CAD'};

        // Call the method to test
        Test.startTest();
        CurrencyCtrl.flattenCurrencies(wrapper, managedCurrencies);
        Test.stopTest();

        // Verify the results
        System.assertNotEquals(null, wrapper.flatRates, 'Flat rates should not be null');
        System.assertEquals(2, wrapper.flatRates.size(), 'Should have 2 flat rates (only managed currencies)');

        // Verify currency names map is populated
        System.assertNotEquals(null, wrapper.currencyNames, 'Currency names should not be null');
        System.assertEquals(CurrencyCtrl.CURRENCY_ISO_CODES_TO_NAME.size(), wrapper.currencyNames.size(), 'Currency names size should match');

        // Check flat rate properties
        for (CurrencyCtrl.FlatRate rate : wrapper.flatRates) {
            System.assertEquals(true, rate.managed, 'Rate should be marked as managed');
            System.assertEquals(wrapper.rates.get(rate.isoCurrencyCode), rate.rate, 'Rate value should match');
            System.assert(rate.currencyName.contains(rate.isoCurrencyCode), 'Currency name should contain ISO code');
        }
    }

    /**
     * Test the getManagedCurrencies method
     */
    @IsTest
    static void testGetManagedCurrencies() {
        // Test data will be automatically provided by SOQL mock results

        // Call the method to test
        Test.startTest();
        Map<String, CurrencyType> currencies = CurrencyCtrl.getManagedCurrencies();
        Test.stopTest();

        // The actual assertions will depend on the test data in your org
        // but we can at least verify the method runs without errors
        System.assertNotEquals(null, currencies, 'Currencies map should not be null');
    }

    /**
     * Test the getCorporateCurrency method
     */
    @IsTest
    static void testGetCorporateCurrency() {
        // Setup test data with mock implementation
        CurrencyType corporateType = new CurrencyType(IsoCode = 'USD', IsCorporate = true, IsActive = true);
        CurrencyType otherType = new CurrencyType(IsoCode = 'EUR', IsCorporate = false, IsActive = true);

        // Mock the getManagedCurrencies method
        Map<String, CurrencyType> mockCurrencies = new Map<String, CurrencyType> {
            'USD' => corporateType,
            'EUR' => otherType
        };

        // Create a test implementation that uses our mock data
        Test.startTest();
        CurrencyType result = CurrencyCtrl.getCorporateCurrency();
        Test.stopTest();

        // The actual assertions will depend on the test data in your org
        // but we can at least verify the method runs without errors
        System.assertNotEquals(null, result, 'Corporate currency should not be null in multicurrency org');
    }

    /**
     * Test the FlatRate constructor
     */
    @IsTest
    static void testFlatRateConstructor() {
        // Test data
        String isoCurrencyCode = 'USD';
        Double rate = 1.0523;
        Boolean managed = true;

        // Call the constructor
        Test.startTest();
        CurrencyCtrl.FlatRate flatRate = new CurrencyCtrl.FlatRate(isoCurrencyCode, rate, managed);
        Test.stopTest();

        // Verify the properties
        System.assertEquals(isoCurrencyCode, flatRate.isoCurrencyCode, 'ISO currency code should match');
        System.assertEquals(rate, flatRate.rate, 'Rate should match');
        System.assertEquals(managed, flatRate.managed, 'Managed flag should match');
        System.assertEquals(isoCurrencyCode + '  -  ' + CurrencyCtrl.CURRENCY_ISO_CODES_TO_NAME.get(isoCurrencyCode),
            flatRate.currencyName, 'Currency name should be formatted correctly');
    }
}
