namespace LmsApi.Models;

public class LessonProgress
{
    public int Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public int LessonId { get; set; }
    public int CourseId { get; set; }
    public bool IsCompleted { get; set; } = false;
    public int WatchedSeconds { get; set; } = 0;   // seconds watched for video lessons
    public DateTime? CompletedAt { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation
    public ApplicationUser User { get; set; } = null!;
    public Lesson Lesson { get; set; } = null!;
    public Course Course { get; set; } = null!;
}
