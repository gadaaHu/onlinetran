namespace LmsApi.Models;

public class QuizResult
{
    public int Id { get; set; }
    
    public int QuizId { get; set; }
    public Quiz Quiz { get; set; } = null!;
    
    public string StudentId { get; set; } = string.Empty;
    public ApplicationUser Student { get; set; } = null!;
    
    public int Score { get; set; }
    public bool Passed { get; set; }
    public DateTime CompletedAt { get; set; } = DateTime.UtcNow;
}
