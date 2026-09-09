namespace LmsApi.DTOs;

public record RegisterDto(string FirstName, string LastName, string Email, string Password, bool IsInstructor = false);
public record LoginDto(string Email, string Password);
public record AuthResponseDto(string Token, string Email, string FullName, IList<string> Roles, string? ProfilePictureUrl);
public record UploadProfilePictureDto(string Base64Image);
