namespace LmsApi.Models;

public class Lesson
{
    public int Id { get; set; }
    public int CourseId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? VideoUrl { get; set; }
    public int Order { get; set; }
    public int DurationInMinutes { get; set; }
    
    public bool IsLive { get; set; }
    public string? MeetingUrl { get; set; }
    public string? ResourceFilePath { get; set; }

    // Navigation property
    public Course Course { get; set; } = null!;
}
