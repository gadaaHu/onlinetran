namespace LmsApi.Models;

public class AnswerOption
{
    public int Id { get; set; }
    public int QuestionId { get; set; }
    public string OptionText { get; set; } = string.Empty;
    public bool IsCorrect { get; set; }

    // Navigation properties
    public Question Question { get; set; } = null!;
}
