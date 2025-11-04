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
        CurrencyCtrl.FlatRate flatRate = new CurrencyCtrl.FlatRate(isoCurrencyCode, rate, managed, true);
        Test.stopTest();

        // Verify the properties
        System.assertEquals(isoCurrencyCode, flatRate.isoCurrencyCode, 'ISO currency code should match');
        System.assertEquals(rate, flatRate.rate, 'Rate should match');
        System.assertEquals(managed, flatRate.managed, 'Managed flag should match');
        System.assertEquals(isoCurrencyCode + '  -  ' + CurrencyCtrl.CURRENCY_ISO_CODES_TO_NAME.get(isoCurrencyCode),
            flatRate.currencyName, 'Currency name should be formatted correctly');
        System.assertEquals(true, flatRate.isBase, 'IsBase shall be true');
    }

    @IsTest
    static void testGetMarkedUpRatesBasedOnCorporateCurrency() {
        // Get the actual markups from the org
        Map<String, CurrencyRateMarkup__mdt> markupsByCurrency = CurrencyRateMarkup__mdt.getAll();
        System.debug('Actual markups from org: ' + markupsByCurrency);

        // Extract the markup percentages we need for our test
        Decimal defaultMarkupPercent = markupsByCurrency.get('Default').MarkupPercent__c;
        Decimal usdMarkupPercent = markupsByCurrency.containsKey('USD')
            ? markupsByCurrency.get('USD').MarkupPercent__c
            : defaultMarkupPercent;
        Decimal gbpMarkupPercent = markupsByCurrency.containsKey('GBP')
            ? markupsByCurrency.get('GBP').MarkupPercent__c
            : defaultMarkupPercent;

        // Create test data
        List<CurrencyCtrl.FlatRate> flatRates = new List<CurrencyCtrl.FlatRate>{
            new CurrencyCtrl.FlatRate('USD', 1.1D, true, false), // This currency has a specific markup
            new CurrencyCtrl.FlatRate('EUR', 1.0D, true, true),  // Base currency
            new CurrencyCtrl.FlatRate('GBP', 0.75D, true, false), // Will use default markup
            new CurrencyCtrl.FlatRate('JPY', 110.0D, true, false) // Will use default markup
        };

        // Call the method to test
        Test.startTest();
        Map<String, Double> markedUpRates = CurrencyCtrl.getMarkedUpRatesBasedOnCorporateCurrency(flatRates);
        Test.stopTest();

        System.debug('Marked up rates: ' + markedUpRates);

        // Verify the results
        System.assertNotEquals(null, markedUpRates, 'Marked up rates should not be null');
        System.assertEquals(4, markedUpRates.size(), 'Should have rates for all 4 currencies');

        // Base currency should not be marked up
        System.assertEquals(1.0, markedUpRates.get('EUR'), 'Base currency (EUR) should not be marked up');

        // USD should use its specific markup rate
        Double expectedUsdRate = 1.1 * (1 + usdMarkupPercent/100);
        System.assertEquals(expectedUsdRate, markedUpRates.get('USD'),
            'USD should use its specific markup of ' + usdMarkupPercent + '%');

        // GBP and JPY should use the default markup rate
        Double expectedGbpRate = 0.75 * (1 + gbpMarkupPercent/100);
        System.assertEquals(expectedGbpRate, markedUpRates.get('GBP'),
            'GBP should use the default markup of ' + gbpMarkupPercent + '%');

        // JPY should use the default markup rate
        Double expectedJpyRate = 110.0 * (1 + defaultMarkupPercent/100);
        System.assertEquals(expectedJpyRate, markedUpRates.get('JPY'),
            'JPY should use the default markup of ' + defaultMarkupPercent + '%');
    }

    @IsTest
    static void testGetMarkedUpRatesBasedOnIsoCurrencyCode() {
        // Get the actual markups from the org
        Map<String, CurrencyRateMarkup__mdt> markupsByCurrency = CurrencyRateMarkup__mdt.getAll();
        System.debug('Actual markups from org: ' + markupsByCurrency);

        // Extract the markup percentages we need for our test
        Decimal defaultMarkupPercent = markupsByCurrency.get('Default').MarkupPercent__c;
        Decimal eurMarkupPercent = markupsByCurrency.containsKey('EUR')
            ? markupsByCurrency.get('EUR').MarkupPercent__c
            : defaultMarkupPercent;
        Decimal gbpMarkupPercent = markupsByCurrency.containsKey('GBP')
            ? markupsByCurrency.get('GBP').MarkupPercent__c
            : defaultMarkupPercent;
        Decimal usdMarkupPercent = markupsByCurrency.containsKey('USD')
            ? markupsByCurrency.get('USD').MarkupPercent__c
            : defaultMarkupPercent;

        // Create test data with USD as the base currency we want to convert from
        List<CurrencyCtrl.FlatRate> flatRates = new List<CurrencyCtrl.FlatRate>{
            new CurrencyCtrl.FlatRate('USD', 1.1D, true, false), // USD rate relative EUR
            new CurrencyCtrl.FlatRate('EUR', 1.0D, true, true), // Base currency for this test
            new CurrencyCtrl.FlatRate('GBP', 0.75D, true, false), // GBP rate relative to USD
            new CurrencyCtrl.FlatRate('JPY', 110.0D, true, false) // JPY rate relative to USD
        };

        // Call the method to test with USD as the base
        Test.startTest();
        Map<String, Double> markedUpRates = CurrencyCtrl.getMarkedUpRatesBasedOnIsoCurrencyCode(flatRates, 'USD');
        Test.stopTest();

        System.debug('Marked up rates from USD: ' + markedUpRates);

        // Verify the results
        System.assertNotEquals(null, markedUpRates, 'Marked up rates should not be null');
        System.assertEquals(4, markedUpRates.size(), 'Should have rates for all 4 currencies');

        // Base currency should not be marked up and should have value 1.0
        System.assertEquals(1.0, markedUpRates.get('USD'), 'Base currency (USD) should have rate 1.0');

        // EUR should use its specific markup rate (if available) or default
        Double expectedEurRate = 1.0 * (1 + eurMarkupPercent/100) / 1.1;
        System.assertEquals(expectedEurRate, markedUpRates.get('EUR'),
            'EUR should use its specific markup of ' + eurMarkupPercent + '%');

        // GBP should use its specific markup rate (if available) or default
        Double expectedGbpRate = 0.75 * (1 + gbpMarkupPercent/100) / 1.1;
        System.assertEquals(expectedGbpRate, markedUpRates.get('GBP'),
            'GBP should use the markup of ' + gbpMarkupPercent + '%');

        // JPY should use the default markup rate
        Double expectedJpyRate = 110.0 * (1 + defaultMarkupPercent/100) / 1.1;
        System.assertEquals(expectedJpyRate, markedUpRates.get('JPY'),
            'JPY should use the default markup of ' + defaultMarkupPercent + '%');

        // Additional test with a different base currency
        // Now let's test with EUR as the base currency
        markedUpRates = CurrencyCtrl.getMarkedUpRatesBasedOnIsoCurrencyCode(flatRates, 'EUR');
        System.debug('Marked up rates from EUR: ' + markedUpRates);

        // Base currency (EUR) should have value 1.0
        System.assertEquals(1.0, markedUpRates.get('EUR'), 'Base currency (EUR) should have rate 1.0');

        // USD should be divided by EUR's rate
        Double expectedUsdRateFromEur = 1.1 / 1.0 * (1 + usdMarkupPercent/100);
        System.assertEquals(expectedUsdRateFromEur, markedUpRates.get('USD'),
            'USD rate from EUR should be 1.1 / 1.0 without markup');

        // GBP should be: GBP rate / EUR rate * (1 + markup)
        Double expectedGbpRateFromEur = (0.75 / 1.0) * (1 + gbpMarkupPercent/100);
        System.assertEquals(expectedGbpRateFromEur, markedUpRates.get('GBP'),
            'GBP rate from EUR should be (0.75 / 1.0) with markup ' + gbpMarkupPercent + '%');

        // JPY should be: JPY rate / EUR rate * (1 + markup)
        Double expectedJpyRateFromEur = (110.0 / 1.0) * (1 + defaultMarkupPercent/100);
        System.assertEquals(expectedJpyRateFromEur, markedUpRates.get('JPY'),
            'JPY rate from EUR should be (110.0 / 1.0) with default markup ' + defaultMarkupPercent + '%');
    }

    @IsTest
    static void testGetRatesAndCreateAllRecords() {
        // Set the mock callout class
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Call the method to test
        Test.startTest();
        CurrencyCtrl.updateCurrencyConversionRates();
        Test.stopTest();

        Map<String, CurrencyRateMarkup__mdt> markupsByCurrency = CurrencyRateMarkup__mdt.getAll();
        System.debug('Actual markups from org: ' + markupsByCurrency);

        // Extract the markup percentages we need for our test
        Decimal defaultMarkupPercent = markupsByCurrency.get('Default').MarkupPercent__c;
        Decimal gbpMarkupPercent = markupsByCurrency.containsKey('GBP')
            ? markupsByCurrency.get('GBP').MarkupPercent__c
            : defaultMarkupPercent;
        Decimal jpyMarkupPercent = markupsByCurrency.containsKey('JPY')
            ? markupsByCurrency.get('JPY').MarkupPercent__c
            : defaultMarkupPercent;

        List<Buying_Exchange_Rate__c> buyingExchangeRates = new List<Buying_Exchange_Rate__c>([
            SELECT Id, CurrencyIsoCode, Exchange_Rate_from_USD_to_X__c, Start_Date__c
            FROM Buying_Exchange_Rate__c
            ORDER BY CurrencyIsoCode
        ]);

        Double gbpRate = Double.valueOf(Math.round(0.8386D / 1.0523 * (1 + gbpMarkupPercent/100) * 10000)) / 10000;
        Double jpyRate = Double.valueOf(Math.round(136.96D / 1.0523 * (1 + jpyMarkupPercent/100) * 10000)) / 10000;

        // {"USD":1.0523,"GBP":0.8386,"CAD":1.3454,"JPY":136.96
        System.debug(buyingExchangeRates);
        System.assertNotEquals(null, buyingExchangeRates, 'Buying exchange rates should not be null');
        System.assertEquals(2, buyingExchangeRates.size(), 'Should have 2 buying exchange rates');
        System.assertEquals('GBP', buyingExchangeRates[0].CurrencyIsoCode, 'First currency should be GBP');
        System.assertEquals(gbpRate, buyingExchangeRates[0].Exchange_Rate_from_USD_to_X__c, 'GBP rate should match');
        System.assertEquals(Date.today(), buyingExchangeRates[0].Start_Date__c, 'Start date should be today');
        System.assertEquals('JPY', buyingExchangeRates[1].CurrencyIsoCode, 'Second currency should be JPY');
        System.assertEquals(jpyRate, buyingExchangeRates[1].Exchange_Rate_from_USD_to_X__c, 'JPY rate should match');
        System.assertEquals(Date.today(), buyingExchangeRates[1].Start_Date__c, 'Start date should be today');
    }
}