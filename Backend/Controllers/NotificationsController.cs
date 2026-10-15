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
public class NotificationsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;

    public NotificationsController(AppDbContext db, UserManager<ApplicationUser> userManager)
    {
        _db = db;
        _userManager = userManager;
    }

    // GET /api/notifications — get current user's notifications
    [HttpGet]
    public async Task<IActionResult> GetMyNotifications([FromQuery] bool unreadOnly = false, [FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        var query = _db.Notifications
            .Where(n => n.UserId == user.Id);

        if (unreadOnly)
            query = query.Where(n => !n.IsRead);

        var total = await query.CountAsync();
        var notifications = await query
            .OrderByDescending(n => n.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(n => new
            {
                n.Id,
                n.Title,
                n.Message,
                n.Type,
                n.IsRead,
                n.ActionUrl,
                n.CreatedAt
            })
            .ToListAsync();

        return Ok(new { total, unreadCount = await _db.Notifications.CountAsync(n => n.UserId == user.Id && !n.IsRead), notifications });
    }

    // GET /api/notifications/unread-count
    [HttpGet("unread-count")]
    public async Task<IActionResult> GetUnreadCount()
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        var count = await _db.Notifications
            .CountAsync(n => n.UserId == user.Id && !n.IsRead);

        return Ok(new { count });
    }

    // POST /api/notifications/{id}/read — mark single notification as read
    [HttpPost("{id}/read")]
    public async Task<IActionResult> MarkRead(int id)
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        var notification = await _db.Notifications
            .FirstOrDefaultAsync(n => n.Id == id && n.UserId == user.Id);

        if (notification == null) return NotFound();

        notification.IsRead = true;
        await _db.SaveChangesAsync();
        return Ok(new { message = "Marked as read" });
    }

    // POST /api/notifications/read-all — mark all as read
    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead()
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        await _db.Notifications
            .Where(n => n.UserId == user.Id && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));

        return Ok(new { message = "All notifications marked as read" });
    }

    // DELETE /api/notifications/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var user = await _userManager.GetUserAsync(User);
        if (user == null) return Unauthorized();

        var notification = await _db.Notifications
            .FirstOrDefaultAsync(n => n.Id == id && n.UserId == user.Id);

        if (notification == null) return NotFound();

        _db.Notifications.Remove(notification);
        await _db.SaveChangesAsync();
        return Ok(new { message = "Deleted" });
    }

    // POST /api/notifications/send — Admin/Instructor sends notification to a user or broadcast
    [HttpPost("send")]
    [Authorize(Roles = "Admin,Instructor")]
    public async Task<IActionResult> Send([FromBody] SendNotificationDto dto)
    {
        if (dto.BroadcastToAll)
        {
            var allUsers = await _db.Users.Select(u => u.Id).ToListAsync();
            var bulkNotifications = allUsers.Select(uid => new Notification
            {
                UserId = uid,
                Title = dto.Title,
                Message = dto.Message,
                Type = dto.Type ?? "info",
                ActionUrl = dto.ActionUrl
            }).ToList();

            _db.Notifications.AddRange(bulkNotifications);
        }
        else if (!string.IsNullOrEmpty(dto.UserId))
        {
            _db.Notifications.Add(new Notification
            {
                UserId = dto.UserId,
                Title = dto.Title,
                Message = dto.Message,
                Type = dto.Type ?? "info",
                ActionUrl = dto.ActionUrl
            });
        }
        else
        {
            return BadRequest(new { message = "Specify UserId or set BroadcastToAll=true" });
        }

        await _db.SaveChangesAsync();
        return Ok(new { message = "Notification(s) sent" });
    }

    // POST /api/notifications/broadcast-class-time — sends class time simultaneously to all students
    [HttpPost("broadcast-class-time")]
    [Authorize(Roles = "Admin,Instructor")]
    public async Task<IActionResult> BroadcastClassTime([FromBody] BroadcastClassTimeDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.ClassTime))
            return BadRequest(new { message = "Class time is required." });

        List<string> targetUserIds;
        string courseTitle = "Live Training";
        string roomName = !string.IsNullOrWhiteSpace(dto.RoomName)
            ? dto.RoomName
            : $"eduverse-class-{(dto.CourseId.HasValue ? dto.CourseId.Value : 101)}";

        if (dto.CourseId.HasValue && dto.CourseId.Value > 0)
        {
            var course = await _db.Courses.FindAsync(dto.CourseId.Value);
            if (course != null) courseTitle = course.Title;

            targetUserIds = await _db.CourseEnrollments
                .Where(e => e.CourseId == dto.CourseId.Value)
                .Select(e => e.UserId)
                .Distinct()
                .ToListAsync();

            if (!targetUserIds.Any())
            {
                targetUserIds = await _db.Users
                    .Select(u => u.Id)
                    .ToListAsync();
            }
        }
        else
        {
            targetUserIds = await _db.Users
                .Select(u => u.Id)
                .ToListAsync();
        }

        var topicStr = string.IsNullOrWhiteSpace(dto.Topic) ? courseTitle : dto.Topic;
        var notificationTitle = $"⏰ Class Time Scheduled: {courseTitle}";
        var notificationMessage = $"Your live class on \"{topicStr}\" is scheduled for {dto.ClassTime}. Please join on time!";

        var notifications = targetUserIds.Select(userId => new Notification
        {
            UserId = userId,
            Title = notificationTitle,
            Message = notificationMessage,
            Type = "live",
            ActionUrl = $"/live/{roomName}",
            CreatedAt = DateTime.UtcNow
        }).ToList();

        _db.Notifications.AddRange(notifications);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            success = true,
            message = $"Class time sent simultaneously to {targetUserIds.Count} students.",
            recipientCount = targetUserIds.Count,
            classTime = dto.ClassTime,
            roomName,
            courseTitle
        });
    }
}

public class SendNotificationDto
{
    public string? UserId { get; set; }
    public bool BroadcastToAll { get; set; } = false;
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string? Type { get; set; }
    public string? ActionUrl { get; set; }
}

public class BroadcastClassTimeDto
{
    public int? CourseId { get; set; }
    public string ClassTime { get; set; } = string.Empty;
    public string Topic { get; set; } = string.Empty;
    public string? RoomName { get; set; }
}
