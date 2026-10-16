namespace LmsApi.DTOs;

public record UserManagementDto(
    string Id,
    string FirstName,
    string LastName,
    string Email,
    bool IsActive,
    List<string> Roles,
    int EnrollmentCount
);

public record SetRoleDto(string Role);

public record CreateUserDto(
    string FirstName,
    string LastName,
    string Email,
    string Password,
    string Role
);
