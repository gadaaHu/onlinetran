using System.Security.Claims;
using LmsApi.Data;
using LmsApi.DTOs;
using LmsApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Hosting;

namespace LmsApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CoursesController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IWebHostEnvironment _env;

    public CoursesController(AppDbContext context, UserManager<ApplicationUser> userManager, IWebHostEnvironment env)
    {
        _context = context;
        _userManager = userManager;
        _env = env;
    }

    // GET /api/courses?page=1&pageSize=10
    [HttpGet]
    public async Task<IActionResult> GetCourses([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var query = _context.Courses
            .Include(c => c.Instructor)
            .Where(c => c.IsPublished);

        var total = await query.CountAsync();
        var courses = await query
            .OrderByDescending(c => c.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(c => new CourseDto(
                c.Id, c.Title, c.Description, c.Price, c.IsPublished,
                $"{c.Instructor.FirstName} {c.Instructor.LastName}", c.CreatedAt))
            .ToListAsync();

        return Ok(new PagedResult<CourseDto>(courses, total, page, pageSize));
    }

    // GET /api/courses/my-created
    [HttpGet("my-created")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> GetMyCreatedCourses()
    {
        var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (currentUserId == null) return Unauthorized();

        var courses = await _context.Courses
            .Include(c => c.Instructor)
            .Where(c => c.InstructorId == currentUserId)
            .OrderByDescending(c => c.CreatedAt)
            .Select(c => new CourseDto(
                c.Id, c.Title, c.Description, c.Price, c.IsPublished,
                $"{c.Instructor.FirstName} {c.Instructor.LastName}", c.CreatedAt))
            .ToListAsync();

        return Ok(courses);
    }

    // GET /api/courses/{id}
    [HttpGet("{id}")]
    public async Task<IActionResult> GetCourse(int id)
    {
        var course = await _context.Courses
            .Include(c => c.Instructor)
            .Include(c => c.Lessons.OrderBy(l => l.Order))
            .Include(c => c.Quizzes)
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == id);

        if (course == null) return NotFound();

        return Ok(new
        {
            course.Id, course.Title, course.Description,
            course.Price, course.IsPublished, course.CreatedAt,
            Instructor = $"{course.Instructor.FirstName} {course.Instructor.LastName}",
            Lessons = course.Lessons.Select(l => new LessonDto(
                l.Id, l.CourseId, l.Title, l.VideoUrl, l.Order, l.DurationInMinutes, l.IsLive, l.MeetingUrl, l.ResourceFilePath)),
            Quizzes = course.Quizzes.Select(q => new QuizDto(
                q.Id, q.CourseId, q.Title, q.PassingScore))
        });
    }

    // POST /api/courses  [Instructor/Admin only]
    [HttpPost]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> CreateCourse([FromBody] CreateCourseDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var course = new Course
        {
            Title = dto.Title,
            Description = dto.Description,
            Price = dto.Price,
            InstructorId = userId
        };
        _context.Courses.Add(course);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetCourse), new { id = course.Id }, course);
    }

    // PUT /api/courses/{id}
    [HttpPut("{id}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> UpdateCourse(int id, [FromBody] UpdateCourseDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var course = await _context.Courses.FindAsync(id);
        if (course == null) return NotFound();
        if (course.InstructorId != userId && !User.HasClaim(ClaimTypes.Role, "Admin")) return Forbid();

        course.Title = dto.Title;
        course.Description = dto.Description;
        course.Price = dto.Price;
        course.IsPublished = dto.IsPublished;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    // POST /api/courses/{id}/enroll
    [HttpPost("{id}/enroll")]
    [Authorize]
    public async Task<IActionResult> Enroll(int id)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var course = await _context.Courses.FindAsync(id);
        if (course == null) return NotFound();

        var alreadyEnrolled = await _context.CourseEnrollments
            .AnyAsync(e => e.CourseId == id && e.UserId == userId);
        if (alreadyEnrolled) return Conflict(new { Message = "Already enrolled." });

        _context.CourseEnrollments.Add(new CourseEnrollment { UserId = userId, CourseId = id });
        await _context.SaveChangesAsync();
        return Ok(new { Message = "Enrolled successfully." });
    }

    // GET /api/courses/my-enrollments
    [HttpGet("my-enrollments")]
    [Authorize]
    public async Task<IActionResult> MyEnrollments()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        
        // PERFORMANCE FIX: Batch-load all quiz results instead of per-enrollment query
        var enrollments = await _context.CourseEnrollments
            .Include(e => e.Course)
            .Where(e => e.UserId == userId)
            .AsNoTracking()
            .ToListAsync();

        // Fetch all quiz results for this user in one query
        var quizResults = await _context.QuizResults
            .Include(r => r.Quiz)
            .Where(r => r.StudentId == userId)
            .AsNoTracking()
            .ToListAsync();

        // Build a lookup: CourseId -> HasPassed
        var coursePassedLookup = quizResults
            .Where(r => r.Score >= r.Quiz.PassingScore)
            .GroupBy(r => r.Quiz.CourseId)
            .ToDictionary(g => g.Key, g => true);

        var result = enrollments.Select(e => new EnrollmentDto(
            e.Id,
            e.CourseId,
            e.Course.Title,
            e.ProgressPercentage,
            e.EnrolledAt,
            coursePassedLookup.ContainsKey(e.CourseId)
        )).ToList();

        return Ok(result);
    }

    [HttpPost("{id}/lessons")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> AddLesson(int id, [FromBody] CreateLessonDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var course = await _context.Courses.FindAsync(id);
        
        if (course == null) {
            Console.WriteLine($"Course {id} not found.");
            return NotFound();
        }
        if (course.InstructorId != userId && !User.HasClaim(ClaimTypes.Role, "Admin")) {
            Console.WriteLine($"Forbidden. Course Instructor: {course.InstructorId}, User: {userId}");
            return Forbid();
        }

        var lesson = new Lesson
        {
            CourseId = id,
            Title = dto.Title,
            VideoUrl = dto.VideoUrl,
            Order = dto.Order,
            DurationInMinutes = dto.DurationInMinutes,
            IsLive = dto.IsLive,
            MeetingUrl = dto.MeetingUrl
        };

        _context.Lessons.Add(lesson);
        await _context.SaveChangesAsync();
        
        return Ok(new LessonDto(lesson.Id, lesson.CourseId, lesson.Title, lesson.VideoUrl, lesson.Order, lesson.DurationInMinutes, lesson.IsLive, lesson.MeetingUrl, lesson.ResourceFilePath));
    }

    [HttpPost("{id}/lessons/{lessonId}/upload-resource")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> UploadResource(int id, int lessonId, IFormFile file)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        var course = await _context.Courses.FindAsync(id);
        
        if (course == null) return NotFound("Course not found");
        if (course.InstructorId != userId && !User.HasClaim(ClaimTypes.Role, "Admin")) return Forbid();

        var lesson = await _context.Lessons.FirstOrDefaultAsync(l => l.Id == lessonId && l.CourseId == id);
        if (lesson == null) return NotFound("Lesson not found");

        if (file.Length > 0)
        {
            var allowedExtensions = new[] { ".pdf", ".mp4", ".zip", ".docx", ".pptx", ".txt" };
            var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (string.IsNullOrEmpty(extension) || !allowedExtensions.Contains(extension))
            {
                return BadRequest("Invalid file type.");
            }

            var uploadsFolder = Path.Combine(_env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"), "resources");
            if (!Directory.Exists(uploadsFolder))
                Directory.CreateDirectory(uploadsFolder);

            var fileName = $"{Guid.NewGuid()}_{Path.GetFileName(file.FileName)}";
            var filePath = Path.Combine(uploadsFolder, fileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            lesson.ResourceFilePath = fileName;
            await _context.SaveChangesAsync();
            return Ok(new { resourceFilePath = fileName });
        }
        return BadRequest("Empty file");
    }

    [HttpGet("{id}/lessons/{lessonId}/download-resource")]
    [Authorize]
    public async Task<IActionResult> DownloadResource(int id, int lessonId)
    {
        var lesson = await _context.Lessons.FirstOrDefaultAsync(l => l.Id == lessonId && l.CourseId == id);
        if (lesson == null || string.IsNullOrEmpty(lesson.ResourceFilePath)) return NotFound();

        var uploadsFolder = Path.Combine(_env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"), "resources");
        var filePath = Path.Combine(uploadsFolder, lesson.ResourceFilePath);
        
        if (!System.IO.File.Exists(filePath)) return NotFound();

        var provider = new Microsoft.AspNetCore.StaticFiles.FileExtensionContentTypeProvider();
        if (!provider.TryGetContentType(filePath, out var contentType))
        {
            contentType = "application/octet-stream";
        }

        // PERFORMANCE FIX: Stream file directly instead of loading into memory
        return PhysicalFile(filePath, contentType, Path.GetFileName(lesson.ResourceFilePath), enableRangeProcessing: true);
    }
}
