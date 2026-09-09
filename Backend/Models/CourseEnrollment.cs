namespace LmsApi.Models;

public class CourseEnrollment
{
    public int Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public int CourseId { get; set; }
    public DateTime EnrolledAt { get; set; } = DateTime.UtcNow;
    public decimal ProgressPercentage { get; set; } = 0;

    // Navigation properties
    public ApplicationUser User { get; set; } = null!;
    public Course Course { get; set; } = null!;
}
