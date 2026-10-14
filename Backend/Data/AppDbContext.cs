using LmsApi.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace LmsApi.Data;

public class AppDbContext : IdentityDbContext<ApplicationUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Course> Courses { get; set; }
    public DbSet<Lesson> Lessons { get; set; }
    public DbSet<CourseEnrollment> CourseEnrollments { get; set; }
    public DbSet<Quiz> Quizzes { get; set; }
    public DbSet<Question> Questions { get; set; }
    public DbSet<AnswerOption> AnswerOptions { get; set; }
    public DbSet<QuizResult> QuizResults { get; set; }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Course -> Instructor relationship
        builder.Entity<Course>()
            .HasOne(c => c.Instructor)
            .WithMany(u => u.CreatedCourses)
            .HasForeignKey(c => c.InstructorId)
            .OnDelete(DeleteBehavior.Restrict);

        // CourseEnrollment -> User relationship
        builder.Entity<CourseEnrollment>()
            .HasOne(e => e.User)
            .WithMany(u => u.Enrollments)
            .HasForeignKey(e => e.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // CourseEnrollment -> Course relationship
        builder.Entity<CourseEnrollment>()
            .HasOne(e => e.Course)
            .WithMany(c => c.Enrollments)
            .HasForeignKey(e => e.CourseId)
            .OnDelete(DeleteBehavior.Cascade);
            
        // Course -> Lessons relationship
        builder.Entity<Lesson>()
            .HasOne(l => l.Course)
            .WithMany(c => c.Lessons)
            .HasForeignKey(l => l.CourseId)
            .OnDelete(DeleteBehavior.Cascade);
            
        // Course -> Quizzes relationship
        builder.Entity<Quiz>()
            .HasOne(q => q.Course)
            .WithMany(c => c.Quizzes)
            .HasForeignKey(q => q.CourseId)
            .OnDelete(DeleteBehavior.Cascade);

        // Quiz -> Questions relationship
        builder.Entity<Question>()
            .HasOne(q => q.Quiz)
            .WithMany(qz => qz.Questions)
            .HasForeignKey(q => q.QuizId)
            .OnDelete(DeleteBehavior.Cascade);

        // Question -> AnswerOptions relationship
        builder.Entity<AnswerOption>()
            .HasOne(a => a.Question)
            .WithMany(q => q.Options)
            .HasForeignKey(a => a.QuestionId)
            .OnDelete(DeleteBehavior.Cascade);

        // QuizResult -> Quiz relationship
        builder.Entity<QuizResult>()
            .HasOne(qr => qr.Quiz)
            .WithMany()
            .HasForeignKey(qr => qr.QuizId)
            .OnDelete(DeleteBehavior.Cascade);

        // QuizResult -> Student relationship
        builder.Entity<QuizResult>()
            .HasOne(qr => qr.Student)
            .WithMany()
            .HasForeignKey(qr => qr.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        // ============ CRITICAL PERFORMANCE INDEXES ============
        
        // Index for quiz results lookups by student and course
        builder.Entity<QuizResult>()
            .HasIndex(r => new { r.StudentId, r.QuizId })
            .HasDatabaseName("IX_QuizResults_StudentId_QuizId");

        // Index for course enrollments by user
        builder.Entity<CourseEnrollment>()
            .HasIndex(e => e.UserId)
            .HasDatabaseName("IX_CourseEnrollments_UserId");

        // Index for course enrollments by course
        builder.Entity<CourseEnrollment>()
            .HasIndex(e => e.CourseId)
            .HasDatabaseName("IX_CourseEnrollments_CourseId");

        // Index for lessons by course and order
        builder.Entity<Lesson>()
            .HasIndex(l => new { l.CourseId, l.Order })
            .HasDatabaseName("IX_Lessons_CourseId_Order");

        // Index for questions by quiz
        builder.Entity<Question>()
            .HasIndex(q => q.QuizId)
            .HasDatabaseName("IX_Questions_QuizId");

        // Index for courses by instructor
        builder.Entity<Course>()
            .HasIndex(c => c.InstructorId)
            .HasDatabaseName("IX_Courses_InstructorId");

        // Index for quizzes by course
        builder.Entity<Quiz>()
            .HasIndex(q => q.CourseId)
            .HasDatabaseName("IX_Quizzes_CourseId");
    }
}
