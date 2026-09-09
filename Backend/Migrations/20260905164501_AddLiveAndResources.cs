using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LmsApi.Migrations
{
    /// <inheritdoc />
    public partial class AddLiveAndResources : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsLive",
                table: "Lessons",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "MeetingUrl",
                table: "Lessons",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ResourceFilePath",
                table: "Lessons",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsLive",
                table: "Lessons");

            migrationBuilder.DropColumn(
                name: "MeetingUrl",
                table: "Lessons");

            migrationBuilder.DropColumn(
                name: "ResourceFilePath",
                table: "Lessons");
        }
    }
}
