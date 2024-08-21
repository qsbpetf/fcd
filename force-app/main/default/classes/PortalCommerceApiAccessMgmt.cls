/**
 * This class provides methods to manage access to custom permissions
 * related to the Eficode office, and it checks the existence of named
 * credentials for different office locations.
 */

public with sharing class PortalCommerceApiAccessMgmt {

    /**
     * Returns a list of custom permissions related to the Eficode offices
     *
     * @return List of custom permissions names
     */
    public static List<String> getEficodeOfficeCustomPermissions() {
        List<String> customPermissions = new List<String>();

        // Query the CustomPermission object
        List<CustomPermission> permList = [SELECT DeveloperName FROM CustomPermission];

        // Add the names to the customPermissions list
        for (CustomPermission perm : permList) {
            if (perm.DeveloperName.startsWith('Eficode_Office_')) {
                customPermissions.add(perm.DeveloperName);
            }
        }

        return customPermissions;
    }

    /**
     * Returns a map of office locators and custom permission names for Eficode offices
     * that the running user has access to
     *
     * @return Map of office locators and custom permission names
     */
    public static Map<String, String> getOfficesAccess() {
        List<String> allOffices = getEficodeOfficeCustomPermissions();
        Map<String, String> officesAccess = new Map<String, String>();
        for (String office : allOffices) {
            if (FeatureManagement.checkPermission(office)) {
                String officeLocator = office.substringAfter('Eficode_Office_');
                officesAccess.put(officeLocator, office);
            }
        }
        return officesAccess;
    }

    /**
     * Checks if the running user has access to a specific Eficode office
     *
     * @param office The office locator
     *
     * @return True if the running user has access to the office, false otherwise
     */
    public static Boolean hasOfficeAccess(String office) {
        return getOfficesAccess().containsKey(office);
    }

    /**
     * Checks if a named credential exists for a specific Eficode office
     *
     * @param office The office locator
     *
     * @return True if the named credential exists, false otherwise
     */
    public static Boolean namedCredentialExists(String office) {
        String name = 'Eficode_Office_' + office;
        List<NamedCredential> creds = new List<NamedCredential>([SELECT Id FROM NamedCredential WHERE DeveloperName = :name]);
        return creds.size() > 0;
    }
}