namespace LmsApi.Models;

public class Quiz
{
    public int Id { get; set; }
    public int CourseId { get; set; }
    public string Title { get; set; } = string.Empty;
    public decimal PassingScore { get; set; } = 70.0m; // Default 70% to pass

    // Navigation properties
    public Course Course { get; set; } = null!;
    public ICollection<Question> Questions { get; set; } = new List<Question>();
}
