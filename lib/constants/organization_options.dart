enum SignupRole { admin, employee, partialAdmin }

extension SignupRoleX on SignupRole {
  String get label {
    switch (this) {
      case SignupRole.admin:
        return 'ADMIN';
      case SignupRole.employee:
        return 'EMPLOYEE';
      case SignupRole.partialAdmin:
        return 'PARTIAL ADMIN';
    }
  }

  List<String> get allowedRoles => OrganizationOptions.roleMappings[this]!;
}

class OrganizationOptions {
  static const teams = [
    'TECH',
    'OPERATIONS',
    'SALES',
    'ANALYST',
    'MARKETING',
    'CEO',
    'DIRECTOR',
  ];

  static const Map<SignupRole, List<String>> roleMappings = {
    SignupRole.admin: ['ADMIN', 'MANAGER', 'HR', 'CEO', 'DIRECTOR'],
    SignupRole.employee: [
      'SENIOR SOFTWARE DEVELOPER',
      'JUNIOR SOFTWARE DEVELOPER',
      'DEVELOPER',
      'TESTER',
      'RELATIONSHIP MANAGER',
      'EXECUTIVE',
      'EMPLOYEE',
      'CEO',
      'DIRECTOR',
    ],
    SignupRole.partialAdmin: ['TECH_LEAD', 'TEAM_LEAD'],
  };

  static List<String> get employeeRoles => roleMappings[SignupRole.employee]!;

  static List<String> get adminRoles => roleMappings[SignupRole.admin]!;

  static List<String> get partialAdminRoles =>
      roleMappings[SignupRole.partialAdmin]!;
}
