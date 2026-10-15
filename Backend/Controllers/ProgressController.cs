using LmsApi.Data;
using LmsApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LmsApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProgressController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;

    public ProgressController(AppDbContext db, UserManager<ApplicationUser> userManager)
    {
        _db = db;
        _userManager = userManager;
    }

    // GET /api/progress/course/{courseId} — student's progress in a course
    [HttpGet("course/{courseId}")]
    public async Task<IActionResult> GetCourseProgress(int courseId)
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        // Check enrollment
        var enrollment = await _db.CourseEnrollments
            .FirstOrDefaultAsync(e => e.UserId == user.Id && e.CourseId == courseId);
        if (enrollment == null) return NotFound(new { message = "Not enrolled" });

        var totalLessons = await _db.Lessons.CountAsync(l => l.CourseId == courseId);
        var completedLessons = await _db.LessonProgresses
            .CountAsync(lp => lp.UserId == user.Id && lp.CourseId == courseId && lp.IsCompleted);

        var lessonDetails = await _db.LessonProgresses
            .Where(lp => lp.UserId == user.Id && lp.CourseId == courseId)
            .Select(lp => new
            {
                lp.LessonId,
                lp.IsCompleted,
                lp.WatchedSeconds,
                lp.CompletedAt,
                lp.UpdatedAt
            }).ToListAsync();

        // Recalculate and persist enrollment progress
        var progressPercent = totalLessons == 0 ? 0 : (decimal)completedLessons / totalLessons * 100;
        enrollment.ProgressPercentage = Math.Round(progressPercent, 1);
        await _db.SaveChangesAsync();

        // Check quiz results for this course
        var quizIds = await _db.Quizzes
            .Where(q => q.CourseId == courseId)
            .Select(q => q.Id).ToListAsync();

        var quizResults = await _db.QuizResults
            .Where(qr => qr.StudentId == user.Id && quizIds.Contains(qr.QuizId))
            .Select(qr => new { qr.QuizId, qr.Score, isPassed = qr.Passed, takenAt = qr.CompletedAt })
            .ToListAsync();

        return Ok(new
        {
            courseId,
            totalLessons,
            completedLessons,
            progressPercentage = enrollment.ProgressPercentage,
            isCompleted = enrollment.ProgressPercentage >= 100,
            lessonDetails,
            quizResults
        });
    }

    // POST /api/progress/lesson/{lessonId}/complete — mark a lesson complete
    [HttpPost("lesson/{lessonId}/complete")]
    public async Task<IActionResult> CompleteLesson(int lessonId, [FromBody] LessonProgressDto dto)
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        var lesson = await _db.Lessons.FindAsync(lessonId);
        if (lesson == null) return NotFound(new { message = "Lesson not found" });

        // Verify enrolled
        var enrolled = await _db.CourseEnrollments
            .AnyAsync(e => e.UserId == user.Id && e.CourseId == lesson.CourseId);
        if (!enrolled) return Forbid();

        var progress = await _db.LessonProgresses
            .FirstOrDefaultAsync(lp => lp.UserId == user.Id && lp.LessonId == lessonId);

        if (progress == null)
        {
            progress = new LessonProgress
            {
                UserId = user.Id,
                LessonId = lessonId,
                CourseId = lesson.CourseId,
                IsCompleted = true,
                WatchedSeconds = dto.WatchedSeconds,
                CompletedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _db.LessonProgresses.Add(progress);
        }
        else
        {
            progress.IsCompleted = true;
            progress.WatchedSeconds = Math.Max(progress.WatchedSeconds, dto.WatchedSeconds);
            progress.CompletedAt ??= DateTime.UtcNow;
            progress.UpdatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();

        // Recalculate overall course progress
        var totalLessons = await _db.Lessons.CountAsync(l => l.CourseId == lesson.CourseId);
        var completedLessons = await _db.LessonProgresses
            .CountAsync(lp => lp.UserId == user.Id && lp.CourseId == lesson.CourseId && lp.IsCompleted);

        var enrollment = await _db.CourseEnrollments
            .FirstOrDefaultAsync(e => e.UserId == user.Id && e.CourseId == lesson.CourseId);

        if (enrollment != null)
        {
            enrollment.ProgressPercentage = totalLessons == 0 ? 0 :
                Math.Round((decimal)completedLessons / totalLessons * 100, 1);

            // If course completed, send a notification!
            if (enrollment.ProgressPercentage >= 100)
            {
                var course = await _db.Courses.FindAsync(lesson.CourseId);
                _db.Notifications.Add(new Notification
                {
                    UserId = user.Id,
                    Title = "🎉 Course Completed!",
                    Message = $"Congratulations! You have completed '{course?.Title}'. Your certificate is ready.",
                    Type = "success",
                    ActionUrl = $"/courses/{lesson.CourseId}/certificate"
                });
            }

            await _db.SaveChangesAsync();
        }

        return Ok(new
        {
            message = "Lesson marked as complete",
            lessonId,
            courseProgress = enrollment?.ProgressPercentage ?? 0
        });
    }

    // POST /api/progress/lesson/{lessonId}/watch — update watch time without marking complete
    [HttpPost("lesson/{lessonId}/watch")]
    public async Task<IActionResult> UpdateWatchTime(int lessonId, [FromBody] LessonProgressDto dto)
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        var lesson = await _db.Lessons.FindAsync(lessonId);
        if (lesson == null) return NotFound();

        var progress = await _db.LessonProgresses
            .FirstOrDefaultAsync(lp => lp.UserId == user.Id && lp.LessonId == lessonId);

        if (progress == null)
        {
            progress = new LessonProgress
            {
                UserId = user.Id,
                LessonId = lessonId,
                CourseId = lesson.CourseId,
                IsCompleted = false,
                WatchedSeconds = dto.WatchedSeconds,
                UpdatedAt = DateTime.UtcNow
            };
            _db.LessonProgresses.Add(progress);
        }
        else if (!progress.IsCompleted)
        {
            progress.WatchedSeconds = Math.Max(progress.WatchedSeconds, dto.WatchedSeconds);
            progress.UpdatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();
        return Ok(new { watchedSeconds = progress.WatchedSeconds });
    }

    // GET /api/progress/dashboard — full student learning dashboard stats
    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboard()
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        var enrollments = await _db.CourseEnrollments
            .Where(e => e.UserId == user.Id)
            .Include(e => e.Course)
            .ThenInclude(c => c.Instructor)
            .ToListAsync();

        var enrolledCourseIds = enrollments.Select(e => e.CourseId).ToList();

        var quizResults = await _db.QuizResults
            .Where(qr => qr.StudentId == user.Id)
            .Include(qr => qr.Quiz)
            .OrderByDescending(qr => qr.CompletedAt)
            .Take(10)
            .ToListAsync();

        var totalWatchSeconds = await _db.LessonProgresses
            .Where(lp => lp.UserId == user.Id)
            .SumAsync(lp => (long)lp.WatchedSeconds);

        var unreadNotifications = await _db.Notifications
            .CountAsync(n => n.UserId == user.Id && !n.IsRead);

        var recentLessons = await _db.LessonProgresses
            .Where(lp => lp.UserId == user.Id)
            .OrderByDescending(lp => lp.UpdatedAt)
            .Take(5)
            .Include(lp => lp.Lesson)
            .Include(lp => lp.Course)
            .Select(lp => new
            {
                lp.LessonId,
                lessonTitle = lp.Lesson.Title,
                lp.CourseId,
                courseTitle = lp.Course.Title,
                lp.IsCompleted,
                lp.WatchedSeconds,
                lp.UpdatedAt
            }).ToListAsync();

        return Ok(new
        {
            stats = new
            {
                enrolledCourses = enrollments.Count,
                completedCourses = enrollments.Count(e => e.ProgressPercentage >= 100),
                totalWatchHours = Math.Round(totalWatchSeconds / 3600.0, 1),
                quizzesTaken = quizResults.Count,
                quizzesPassed = quizResults.Count(qr => qr.Passed),
                unreadNotifications
            },
            enrollments = enrollments.Select(e => new
            {
                e.CourseId,
                courseTitle = e.Course?.Title ?? "Course",
                instructorName = e.Course?.Instructor != null
                    ? $"{e.Course.Instructor.FirstName} {e.Course.Instructor.LastName}".Trim()
                    : "Instructor",
                e.ProgressPercentage,
                e.EnrolledAt,
                isCompleted = e.ProgressPercentage >= 100
            }),
            recentActivity = recentLessons.Select(lp => new
            {
                lp.LessonId,
                lessonTitle = lp.lessonTitle ?? "Lesson",
                lp.CourseId,
                courseTitle = lp.courseTitle ?? "Course",
                lp.IsCompleted,
                lp.WatchedSeconds,
                lp.UpdatedAt
            }),
            quizResults = quizResults.Select(qr => new
            {
                qr.QuizId,
                quizTitle = qr.Quiz?.Title ?? "Quiz",
                qr.Score,
                isPassed = qr.Passed,
                takenAt = qr.CompletedAt
            }),
            recentQuizResults = quizResults.Select(qr => new
            {
                qr.QuizId,
                quizTitle = qr.Quiz?.Title ?? "Quiz",
                qr.Score,
                isPassed = qr.Passed,
                takenAt = qr.CompletedAt
            })
        });
    }

    // GET /api/progress/instructor/overview — instructor sees all student progress for their courses
    [HttpGet("instructor/overview")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> GetInstructorOverview()
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        var isAdmin = await _userManager.IsInRoleAsync(user, "Admin");

        var coursesQuery = _db.Courses.AsQueryable();
        if (!isAdmin) coursesQuery = coursesQuery.Where(c => c.InstructorId == user.Id);

        var courses = await coursesQuery
            .Select(c => new
            {
                c.Id,
                c.Title,
                totalEnrolled = c.Enrollments.Count,
                completedCount = c.Enrollments.Count(e => e.ProgressPercentage >= 100),
                averageProgress = c.Enrollments.Any()
                    ? c.Enrollments.Average(e => (double)e.ProgressPercentage)
                    : 0.0
            }).ToListAsync();

        return Ok(new { courses });
    }
}

public class LessonProgressDto
{
    public int WatchedSeconds { get; set; } = 0;
}
