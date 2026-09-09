using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using LmsApi.Data;
using LmsApi.Models;
using LmsApi.DTOs;
using System.Security.Claims;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace LmsApi.Controllers;

[ApiController]
[Route("api/courses")]
public class QuizzesController : ControllerBase
{
    private readonly AppDbContext _context;

    public QuizzesController(AppDbContext context)
    {
        _context = context;
    }

    [HttpPost("{courseId}/quizzes")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> CreateQuiz(int courseId, [FromBody] CreateQuizDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var course = await _context.Courses.FindAsync(courseId);

        if (course == null) return NotFound();
        if (course.InstructorId != userId && !User.HasClaim(ClaimTypes.Role, "Admin")) return Forbid();

        var quiz = new Quiz
        {
            CourseId = courseId,
            Title = dto.Title,
            PassingScore = dto.PassingScore
        };

        _context.Quizzes.Add(quiz);
        await _context.SaveChangesAsync();

        return Ok(new QuizDto(quiz.Id, quiz.CourseId, quiz.Title, quiz.PassingScore));
    }

    [HttpPost("{courseId}/quizzes/{quizId}/questions")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> AddQuestion(int courseId, int quizId, [FromBody] CreateQuestionDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var course = await _context.Courses.FindAsync(courseId);

        if (course == null) return NotFound();
        if (course.InstructorId != userId && !User.HasClaim(ClaimTypes.Role, "Admin")) return Forbid();

        var quiz = await _context.Quizzes.FirstOrDefaultAsync(q => q.Id == quizId && q.CourseId == courseId);
        if (quiz == null) return NotFound();

        var question = new Question
        {
            QuizId = quizId,
            QuestionText = dto.QuestionText,
            Options = dto.Options.Select(o => new AnswerOption
            {
                OptionText = o.OptionText,
                IsCorrect = o.IsCorrect
            }).ToList()
        };

        _context.Questions.Add(question);
        await _context.SaveChangesAsync();

        var optionsDto = question.Options.Select(o => new AnswerOptionDto(o.Id, o.OptionText, o.IsCorrect)).ToList();
        return Ok(new QuestionDto(question.Id, question.QuizId, question.QuestionText, optionsDto));
    }

    [HttpGet("{courseId}/quizzes")]
    [Authorize]
    public async Task<IActionResult> GetQuizForCourse(int courseId)
    {
        var quiz = await _context.Quizzes
            .Include(q => q.Questions)
            .ThenInclude(q => q.Options)
            .FirstOrDefaultAsync(q => q.CourseId == courseId);

        if (quiz == null) return NotFound();

        var questionsDto = quiz.Questions.Select(q => new StudentQuestionDto(
            q.Id,
            q.QuestionText,
            q.Options.Select(o => new StudentAnswerOptionDto(o.Id, o.OptionText)).ToList()
        )).ToList();

        var quizDto = new StudentQuizDto(quiz.Id, quiz.CourseId, quiz.Title, quiz.PassingScore, questionsDto);

        return Ok(quizDto);
    }

    [HttpPost("{courseId}/quizzes/{quizId}/submit")]
    [Authorize]
    public async Task<IActionResult> SubmitQuiz(int courseId, int quizId, [FromBody] QuizSubmissionDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        var quiz = await _context.Quizzes
            .Include(q => q.Questions)
            .ThenInclude(q => q.Options)
            .FirstOrDefaultAsync(q => q.Id == quizId && q.CourseId == courseId);

        if (quiz == null) return NotFound();

        int correctAnswers = 0;
        int totalQuestions = quiz.Questions.Count;

        if (totalQuestions == 0) return BadRequest("Quiz has no questions.");

        foreach (var answer in dto.Answers)
        {
            var question = quiz.Questions.FirstOrDefault(q => q.Id == answer.QuestionId);
            if (question != null)
            {
                var option = question.Options.FirstOrDefault(o => o.Id == answer.SelectedOptionId);
                if (option != null && option.IsCorrect)
                {
                    correctAnswers++;
                }
            }
        }

        int score = (int)Math.Round((double)correctAnswers / totalQuestions * 100);
        bool passed = score >= quiz.PassingScore;

        var result = new QuizResult
        {
            QuizId = quizId,
            StudentId = userId,
            Score = score,
            Passed = passed,
            CompletedAt = DateTime.UtcNow
        };

        _context.QuizResults.Add(result);
        await _context.SaveChangesAsync();

        return Ok(new QuizResultDto(score, passed));
    }

    [HttpGet("{courseId}/result")]
    [Authorize]
    public async Task<IActionResult> GetStudentResult(int courseId)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        // Find the best passing result for this course for the user
        var result = await _context.QuizResults
            .Include(r => r.Quiz)
            .Where(r => r.Quiz.CourseId == courseId && r.StudentId == userId && r.Passed)
            .OrderByDescending(r => r.Score)
            .FirstOrDefaultAsync();

        if (result == null)
            return NotFound(new { message = "No passing result found." });

        return Ok(new QuizResultDto(result.Score, result.Passed));
    }

    [HttpGet("{courseId}/certificate")]
    [Authorize]
    public async Task<IActionResult> GetCertificate(int courseId)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        var result = await _context.QuizResults
            .Include(r => r.Quiz)
                .ThenInclude(q => q.Course)
                    .ThenInclude(c => c.Instructor)
            .Include(r => r.Student)
            .Where(r => r.Quiz.CourseId == courseId && r.StudentId == userId && r.Passed)
            .OrderByDescending(r => r.Score)
            .FirstOrDefaultAsync();

        if (result == null)
            return Forbid("You must pass the course exam to download a certificate.");

        QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

        var studentName  = $"{result.Student.FirstName} {result.Student.LastName}";
        var courseTitle  = result.Quiz.Course.Title;
        var instructorName = $"{result.Quiz.Course.Instructor.FirstName} {result.Quiz.Course.Instructor.LastName}";
        var completedDate = result.CompletedAt.ToString("MMMM dd, yyyy");
        var score        = result.Score;

        var navy   = "#0D2B6E";
        var gold   = "#C9A84C";
        var silver = "#8B9AAF";
        var white  = "#FFFFFF";
        var lightBg = "#F8F9FF";

        var document = QuestPDF.Fluent.Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(QuestPDF.Helpers.PageSizes.A4.Landscape());
                page.Margin(0);
                page.PageColor(lightBg);
                page.DefaultTextStyle(x => x.FontFamily("Arial").FontColor(navy));

                page.Content().Column(col =>
                {
                    // Top navy bar + gold stripe
                    col.Item().Height(12).Background(navy);
                    col.Item().Height(4).Background(gold);

                    // Main content area — single border box, generous padding
                    col.Item()
                        .PaddingHorizontal(32).PaddingVertical(16)
                        .Border(2).BorderColor(navy)
                        .Padding(6).Border(1).BorderColor(gold)
                        .Padding(20)
                        .Column(body =>
                        {
                            // ── Header row: EduVerse name + Seal ─────────────
                            body.Item().Row(row =>
                            {
                                row.RelativeItem().Column(c =>
                                {
                                    c.Item().Text("ICS Training")
                                        .Bold().FontSize(14).FontColor(navy);
                                    c.Item().Text("Immigration & Citizenship Service")
                                        .FontSize(9).FontColor(silver);
                                });

                                row.ConstantItem(80).Height(80)
                                    .Background(navy)
                                    .Border(2).BorderColor(gold)
                                    .AlignCenter().AlignMiddle()
                                    .Column(seal =>
                                    {
                                        seal.Item().AlignCenter().Text("★")
                                            .FontSize(22).FontColor(gold);
                                        seal.Item().AlignCenter().Text("CERTIFIED")
                                            .Bold().FontSize(7).FontColor(gold);
                                        seal.Item().AlignCenter().Text($"{score}%")
                                            .Bold().FontSize(14).FontColor(white);
                                    });
                            });

                            // ── Title ─────────────────────────────────────────
                            body.Item().PaddingTop(18).AlignCenter()
                                .Text("Certificate of Completion")
                                .Bold().FontSize(30).FontColor(navy);

                            // Gold divider
                            body.Item().PaddingVertical(10).PaddingHorizontal(80)
                                .Height(2).Background(gold);

                            // ── Certify text ──────────────────────────────────
                            body.Item().AlignCenter()
                                .Text("This is to proudly certify that")
                                .Italic().FontSize(13).FontColor(silver);

                            // ── Student Name ──────────────────────────────────
                            body.Item().PaddingTop(8).AlignCenter()
                                .Text(studentName)
                                .Bold().FontSize(34).FontColor(navy);

                            body.Item().PaddingTop(4).AlignCenter()
                                .Text("has successfully completed the course")
                                .Italic().FontSize(13).FontColor(silver);

                            // ── Course Title Banner ───────────────────────────
                            body.Item().PaddingTop(10).PaddingHorizontal(40)
                                .Background(navy).Padding(12).AlignCenter()
                                .Text(courseTitle)
                                .Bold().FontSize(18).FontColor(white);

                            // ── Score + Date row ──────────────────────────────
                            body.Item().PaddingTop(16).AlignCenter().Row(r =>
                            {
                                r.AutoItem().PaddingHorizontal(12).PaddingVertical(5)
                                    .Border(1).BorderColor(gold)
                                    .Text($"Score: {score}%")
                                    .Bold().FontSize(12).FontColor(navy);

                                r.AutoItem().Width(24);

                                r.AutoItem().PaddingHorizontal(12).PaddingVertical(5)
                                    .Border(1).BorderColor(gold)
                                    .Text($"Date: {completedDate}")
                                    .FontSize(12).FontColor(navy);
                            });

                            // ── Signatures ────────────────────────────────────
                            body.Item().PaddingTop(28).PaddingHorizontal(40)
                                .Row(sig =>
                                {
                                    sig.RelativeItem().Column(s =>
                                    {
                                        s.Item().Height(1).Background(navy);
                                        s.Item().PaddingTop(4).Text(instructorName)
                                            .Bold().FontSize(11).FontColor(navy);
                                        s.Item().Text("Course Instructor")
                                            .FontSize(9).FontColor(silver);
                                    });

                                    sig.ConstantItem(80);

                                    sig.RelativeItem().Column(s =>
                                    {
                                        s.Item().Height(1).Background(navy);
                                        s.Item().PaddingTop(4).Text("ICS Training College")
                                            .Bold().FontSize(11).FontColor(navy);
                                        s.Item().Text("Authorized Signature")
                                            .FontSize(9).FontColor(silver);
                                    });
                                });
                        });

                    // Bottom gold stripe + navy bar
                    col.Item().Height(4).Background(gold);
                    col.Item().Height(12).Background(navy);
                });
            });
        });

        var pdfBytes = document.GeneratePdf();
        return File(pdfBytes, "application/pdf", $"ICS_Certificate_{studentName.Replace(" ", "_")}_{courseTitle.Replace(" ", "_")}.pdf");
    }
}
