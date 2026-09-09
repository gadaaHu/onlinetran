using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using LmsApi.DTOs;
using LmsApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
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
        var user = new ApplicationUser
        {
            UserName = dto.Email,
            Email = dto.Email,
            FirstName = dto.FirstName,
            LastName = dto.LastName
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
        
        var token = await GenerateJwtToken(user);
        var roles = await _userManager.GetRolesAsync(user);

        return Ok(new AuthResponseDto(token, user.Email!, $"{user.FirstName} {user.LastName}", roles, user.ProfilePictureUrl));
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        var user = await _userManager.FindByEmailAsync(dto.Email);
        if (user == null)
            return Unauthorized(new { Message = "Invalid email or password." });

        var result = await _signInManager.CheckPasswordSignInAsync(user, dto.Password, false);
        if (!result.Succeeded)
            return Unauthorized(new { Message = "Invalid email or password." });

        var token = await GenerateJwtToken(user);
        var roles = await _userManager.GetRolesAsync(user);

        return Ok(new AuthResponseDto(token, user.Email!, $"{user.FirstName} {user.LastName}", roles, user.ProfilePictureUrl));
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
