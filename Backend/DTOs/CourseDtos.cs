namespace LmsApi.DTOs;

public record CourseDto(int Id, string Title, string Description, decimal Price, bool IsPublished, string InstructorName, DateTime CreatedAt);
public record CreateCourseDto(string Title, string Description, decimal Price);
public record UpdateCourseDto(string Title, string Description, decimal Price, bool IsPublished);
public record LessonDto(int Id, int CourseId, string Title, string? VideoUrl, int Order, int DurationInMinutes, bool IsLive, string? MeetingUrl, string? ResourceFilePath);
public record CreateLessonDto(string Title, string? VideoUrl, int Order, int DurationInMinutes, bool IsLive, string? MeetingUrl);
public record EnrollmentDto(int Id, int CourseId, string CourseTitle, decimal ProgressPercentage, DateTime EnrolledAt, bool HasCertificate);
public record PagedResult<T>(IEnumerable<T> Items, int TotalCount, int Page, int PageSize);
