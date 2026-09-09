namespace LmsApi.DTOs;

public record QuizDto(int Id, int CourseId, string Title, decimal PassingScore);
public record CreateQuizDto(string Title, decimal PassingScore);

public record QuestionDto(int Id, int QuizId, string QuestionText, List<AnswerOptionDto> Options);
public record CreateQuestionDto(string QuestionText, List<CreateAnswerOptionDto> Options);

public record AnswerOptionDto(int Id, string OptionText, bool IsCorrect);
public record CreateAnswerOptionDto(string OptionText, bool IsCorrect);

// Student Exam DTOs (no IsCorrect exposed)
public record StudentQuizDto(int Id, int CourseId, string Title, decimal PassingScore, List<StudentQuestionDto> Questions);
public record StudentQuestionDto(int Id, string QuestionText, List<StudentAnswerOptionDto> Options);
public record StudentAnswerOptionDto(int Id, string OptionText);

// Submission DTOs
public record QuizSubmissionDto(List<QuestionAnswerDto> Answers);
public record QuestionAnswerDto(int QuestionId, int SelectedOptionId);
public record QuizResultDto(int Score, bool Passed);
