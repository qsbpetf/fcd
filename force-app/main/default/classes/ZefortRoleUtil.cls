public class ZefortRoleUtil {
    public static String normalizeRole(String role) {
        if (String.isBlank(role)) {
            return 'signer';
        }
        String normalized = role.toLowerCase();
        if (normalized == 'signer' || normalized == 'approver' || normalized == 'cc') {
            return normalized;
        }
        return 'signer';
    }
}