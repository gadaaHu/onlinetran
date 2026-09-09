using LmsApi.Data;
using LmsApi.DTOs;
using LmsApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LmsApi.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public class AdminController : ControllerBase
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly AppDbContext _context;

    public AdminController(UserManager<ApplicationUser> userManager, AppDbContext context)
    {
        _userManager = userManager;
        _context = context;
    }

    // GET /api/admin/users?search=xxx
    [HttpGet("users")]
    public async Task<IActionResult> GetUsers([FromQuery] string? search)
    {
        var users = await _userManager.Users.ToListAsync();

        if (!string.IsNullOrWhiteSpace(search))
        {
            search = search.ToLower();
            users = users.Where(u =>
                u.Email!.ToLower().Contains(search) ||
                u.FirstName.ToLower().Contains(search) ||
                u.LastName.ToLower().Contains(search)
            ).ToList();
        }

        var result = new List<UserManagementDto>();
        foreach (var user in users)
        {
            var roles = await _userManager.GetRolesAsync(user);
            var enrollmentCount = await _context.CourseEnrollments.CountAsync(e => e.UserId == user.Id);
            result.Add(new UserManagementDto(
                user.Id,
                user.FirstName,
                user.LastName,
                user.Email!,
                user.LockoutEnd == null || user.LockoutEnd < DateTimeOffset.UtcNow,
                roles.ToList(),
                enrollmentCount
            ));
        }

        return Ok(result.OrderBy(u => u.FirstName));
    }

    // POST /api/admin/users/{id}/set-role
    [HttpPost("users/{id}/set-role")]
    public async Task<IActionResult> SetRole(string id, [FromBody] SetRoleDto dto)
    {
        var user = await _userManager.FindByIdAsync(id);
        if (user == null) return NotFound();

        var validRoles = new[] { "Student", "Instructor", "Admin" };
        if (!validRoles.Contains(dto.Role)) return BadRequest("Invalid role.");

        // Remove all existing roles and assign the new one
        var currentRoles = await _userManager.GetRolesAsync(user);
        await _userManager.RemoveFromRolesAsync(user, currentRoles);
        await _userManager.AddToRoleAsync(user, dto.Role);

        return Ok(new { Message = $"User role updated to {dto.Role}." });
    }

    // PUT /api/admin/users/{id}/toggle-status
    [HttpPut("users/{id}/toggle-status")]
    public async Task<IActionResult> ToggleStatus(string id)
    {
        var user = await _userManager.FindByIdAsync(id);
        if (user == null) return NotFound();

        var isCurrentlyActive = user.LockoutEnd == null || user.LockoutEnd < DateTimeOffset.UtcNow;

        if (isCurrentlyActive)
        {
            // Lock out the user indefinitely
            user.LockoutEnd = DateTimeOffset.MaxValue;
            user.LockoutEnabled = true;
        }
        else
        {
            // Unlock the user
            user.LockoutEnd = null;
        }

        await _userManager.UpdateAsync(user);
        return Ok(new { IsActive = !isCurrentlyActive });
    }

    // DELETE /api/admin/users/{id}
    [HttpDelete("users/{id}")]
    public async Task<IActionResult> DeleteUser(string id)
    {
        var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (currentUserId == id) return BadRequest("You cannot delete your own account.");

        var user = await _userManager.FindByIdAsync(id);
        if (user == null) return NotFound();

        await _userManager.DeleteAsync(user);
        return NoContent();
    }
}
