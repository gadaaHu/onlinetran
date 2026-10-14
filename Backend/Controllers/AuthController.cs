using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using LmsApi.DTOs;
using LmsApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace LmsApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly IConfiguration _config;
    private readonly IWebHostEnvironment _env;

    public AuthController(
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        IConfiguration config,
        IWebHostEnvironment env)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _config = config;
        _env = env;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        var existing = await _userManager.FindByEmailAsync(dto.Email);
        if (existing != null)
            return BadRequest(new { Message = "An account with this email already exists." });

        var user = new ApplicationUser
        {
            UserName = dto.Email,
            Email = dto.Email,
            FirstName = dto.FirstName,
            LastName = dto.LastName,
            EmailConfirmed = false // Requires authorizer confirmation
        };

        var result = await _userManager.CreateAsync(user, dto.Password);
        if (!result.Succeeded)
            return BadRequest(new { Errors = result.Errors.Select(e => e.Description) });

        if (dto.IsInstructor)
        {
            await _userManager.AddToRoleAsync(user, "Instructor");
        }
        else
        {
            await _userManager.AddToRoleAsync(user, "Student");
        }

        return Ok(new
        {
            Message = "Registration successful! Your student account is pending confirmation by the authorizer before you can log in.",
            IsConfirmed = false,
            Email = user.Email
        });
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        var user = await _userManager.FindByEmailAsync(dto.Email)
            ?? await _userManager.FindByNameAsync(dto.Email);

        if (user == null && dto.Email.Equals("admin", StringComparison.OrdinalIgnoreCase))
        {
            user = await _userManager.FindByEmailAsync("admin@eduverse.com");
        }

        if (user == null)
            return Unauthorized(new { Message = "Invalid email or password." });

        var result = await _signInManager.CheckPasswordSignInAsync(user, dto.Password, false);
        if (!result.Succeeded)
            return Unauthorized(new { Message = "Invalid email or password." });

        var roles = await _userManager.GetRolesAsync(user);

        // Authorizer confirmation check: Students must be confirmed
        if (!user.EmailConfirmed && !roles.Contains("Admin"))
        {
            return StatusCode(403, new
            {
                Message = "Your student account is pending confirmation by the authorizer. Please wait for an administrator to approve your account.",
                IsConfirmed = false
            });
        }

        var token = await GenerateJwtToken(user);

        return Ok(new AuthResponseDto(token, user.Email!, $"{user.FirstName} {user.LastName}", roles, user.ProfilePictureUrl));
    }

    [HttpGet("students")]
    [Authorize(Roles = "Admin,Instructor")]
    public async Task<IActionResult> GetStudents()
    {
        var users = await _userManager.Users
            .OrderByDescending(u => u.CreatedAt)
            .ToListAsync();

        var list = new List<object>();
        foreach (var u in users)
        {
            var userRoles = await _userManager.GetRolesAsync(u);
            list.Add(new
            {
                Id = u.Id,
                Email = u.Email,
                FirstName = u.FirstName,
                LastName = u.LastName,
                FullName = $"{u.FirstName} {u.LastName}",
                IsConfirmed = u.EmailConfirmed,
                Roles = userRoles,
                CreatedAt = u.CreatedAt
            });
        }
        return Ok(list);
    }

    [HttpPost("confirm-student/{userId}")]
    [Authorize(Roles = "Admin,Instructor")]
    public async Task<IActionResult> ConfirmStudent(string userId)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null) return NotFound(new { Message = "Student not found." });

        user.EmailConfirmed = true;
        var res = await _userManager.UpdateAsync(user);
        if (!res.Succeeded)
            return BadRequest(new { Message = "Failed to confirm student." });

        return Ok(new { Success = true, Message = $"Student {user.FirstName} {user.LastName} ({user.Email}) has been confirmed and authorized!" });
    }

    [HttpPost("reject-student/{userId}")]
    [Authorize(Roles = "Admin,Instructor")]
    public async Task<IActionResult> RejectStudent(string userId)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null) return NotFound(new { Message = "Student not found." });

        user.EmailConfirmed = false;
        await _userManager.UpdateAsync(user);

        return Ok(new { Success = true, Message = $"Student {user.FirstName} {user.LastName} authorization status set to Pending/Rejected." });
    }

    [HttpPost("live-control")]
    [Authorize(Roles = "Instructor,Admin")]
    public IActionResult ControlLiveStudent([FromBody] LiveControlDto dto)
    {
        return Ok(new
        {
            Success = true,
            Action = dto.Action,
            StudentId = dto.StudentId,
            RoomName = dto.RoomName,
            Message = $"Instructor successfully applied action '{dto.Action}' to student {dto.StudentId}."
        });
    }

    [HttpPost("profile-picture")]
    [Authorize]
    public async Task<IActionResult> UploadProfilePicture([FromBody] UploadProfilePictureDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null) return NotFound("User not found.");

        if (string.IsNullOrEmpty(dto.Base64Image))
            return BadRequest(new { Message = "Image data is required." });

        try
        {
            var base64Data = dto.Base64Image;
            if (base64Data.Contains(","))
            {
                base64Data = base64Data.Split(',')[1];
            }
            
            var bytes = Convert.FromBase64String(base64Data);

            var uploadsFolder = Path.Combine(_env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"), "profiles");
            if (!Directory.Exists(uploadsFolder))
                Directory.CreateDirectory(uploadsFolder);

            var fileName = $"{user.Id}_{Guid.NewGuid()}.jpg";
            var filePath = Path.Combine(uploadsFolder, fileName);

            await System.IO.File.WriteAllBytesAsync(filePath, bytes);

            user.ProfilePictureUrl = fileName;
            await _userManager.UpdateAsync(user);

            return Ok(new { ProfilePictureUrl = fileName });
        }
        catch (Exception ex)
        {
            return BadRequest(new { Message = $"Invalid image format: {ex.Message}" });
        }
    }

    private async Task<string> GenerateJwtToken(ApplicationUser user)
    {
        var roles = await _userManager.GetRolesAsync(user);
        var key = new SymmetricSecurityKey(Encoding.ASCII.GetBytes(
            _config["Jwt:Key"] ?? throw new InvalidOperationException("JWT Key not configured")));

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id),
            new(ClaimTypes.Email, user.Email!),
            new(ClaimTypes.Name, $"{user.FirstName} {user.LastName}")
        };
        claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddDays(7),
            SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256Signature)
        };

        var handler = new JwtSecurityTokenHandler();
        var token = handler.CreateToken(tokenDescriptor);
        return handler.WriteToken(token);
    }
}
