/**
 * Created by peterfriberg on 2024-08-21.
 */

public with sharing class PortalCommerceApiAccessMgmt {

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

    public static Boolean hasOfficeAccess(String office) {
        return getOfficesAccess().containsKey(office);
    }

    public static Boolean namedCredentialExists(String office) {
        String name = 'Eficode_Office_' + office;
        List<NamedCredential> creds = new List<NamedCredential>([SELECT Id FROM NamedCredential WHERE DeveloperName = :name]);
        return creds.size() > 0;
    }
}